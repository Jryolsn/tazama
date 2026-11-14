package com.jryolsn.tazama.camera;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.net.nsd.NsdManager;
import android.net.nsd.NsdServiceInfo;
import android.net.wifi.WifiManager;
import android.os.Build;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.IBinder;
import android.os.Looper;
import android.os.PowerManager;
import android.util.Log;
import android.view.OrientationEventListener;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.ByteArrayOutputStream;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;

/**
 * Waits on the local network for a paired TV. The camera stays off until the TV asks for it.
 * Started from the app (Android only lets a camera service start while the app is visible).
 */
public class CameraService extends Service {
    private static final String TAG = "TazamaCamera";
    private static final String CHANNEL = "ready";
    static final String ACTION_STOP = "com.jryolsn.tazama.camera.STOP";

    static volatile boolean running;
    static volatile String status = "";
    static volatile Runnable uiListener;

    private PairingStore store;
    private ServerSocket server;
    private Thread acceptThread;
    private NsdManager nsd;
    private NsdManager.RegistrationListener registration;
    private HandlerThread cameraThread;
    private Handler cameraHandler;
    private CameraStreamer streamer;
    private OrientationEventListener orientation;
    private volatile Connection current;
    private PowerManager.WakeLock wakeLock;
    private WifiManager.WifiLock wifiLock;

    @Override
    public void onCreate() {
        super.onCreate();
        store = new PairingStore(this);
        NotificationManager nm = getSystemService(NotificationManager.class);
        nm.createNotificationChannel(new NotificationChannel(CHANNEL, "Ready for the TV", NotificationManager.IMPORTANCE_LOW));
        try {
            startForeground(1, notification("Ready for the TV"), ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA);
        } catch (RuntimeException e) {
            // Not allowed (no camera permission, or started from the background).
            Log.w(TAG, "cannot start in foreground", e);
            setStatus("Open the app to turn the camera service on.");
            stopSelf();
            return;
        }
        running = true;

        cameraThread = new HandlerThread("TazamaCameraControl");
        cameraThread.start();
        cameraHandler = new Handler(cameraThread.getLooper());
        streamer = new CameraStreamer(this, cameraHandler);

        orientation = new OrientationEventListener(this) {
            @Override
            public void onOrientationChanged(int degrees) {
                if (degrees == ORIENTATION_UNKNOWN) return;
                int snapped = ((degrees + 45) / 90 * 90) % 360;
                cameraHandler.post(() -> streamer.setDeviceRotation(snapped));
            }
        };
        if (orientation.canDetectOrientation()) orientation.enable();

        PowerManager pm = getSystemService(PowerManager.class);
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "TazamaCamera:stream");
        WifiManager wm = getSystemService(WifiManager.class);
        wifiLock = wm.createWifiLock(WifiManager.WIFI_MODE_FULL_LOW_LATENCY, "TazamaCamera:stream");
        wakeLock.setReferenceCounted(false);
        wifiLock.setReferenceCounted(false);

        acceptThread = new Thread(this::acceptLoop, "TazamaCameraServer");
        acceptThread.start();
        setStatus("Ready for the TV");
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null && ACTION_STOP.equals(intent.getAction())) {
            stopForeground(STOP_FOREGROUND_REMOVE);
            stopSelf();
            return START_NOT_STICKY;
        }
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        running = false;
        Connection c = current;
        current = null;
        if (c != null) c.close();
        if (registration != null && nsd != null) {
            try {
                nsd.unregisterService(registration);
            } catch (Exception ignored) {
            }
        }
        if (server != null) {
            try {
                server.close();
            } catch (IOException ignored) {
            }
        }
        if (orientation != null) orientation.disable();
        if (cameraHandler != null) {
            CameraStreamer s = streamer;
            Connection last = c;
            cameraHandler.post(() -> s.stop(last));
            cameraThread.quitSafely();
        }
        releaseLocks();
        setStatus("Off");
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    private Notification notification(String text) {
        Intent open = new Intent(this, MainActivity.class);
        PendingIntent openPi = PendingIntent.getActivity(this, 0, open, PendingIntent.FLAG_IMMUTABLE);
        PendingIntent stopPi = PendingIntent.getService(this, 1,
                new Intent(this, CameraService.class).setAction(ACTION_STOP), PendingIntent.FLAG_IMMUTABLE);
        return new Notification.Builder(this, CHANNEL)
                .setSmallIcon(android.R.drawable.presence_video_online)
                .setContentTitle("Tazama Camera")
                .setContentText(text)
                .setContentIntent(openPi)
                .setOngoing(true)
                .addAction(new Notification.Action.Builder(null, "Turn off", stopPi).build())
                .build();
    }

    private void setStatus(String text) {
        status = text;
        if (running) {
            getSystemService(NotificationManager.class).notify(1, notification(text));
        }
        Runnable l = uiListener;
        if (l != null) new Handler(Looper.getMainLooper()).post(l);
    }

    private void acceptLoop() {
        try {
            server = new ServerSocket();
            server.setReuseAddress(true);
            try {
                server.bind(new InetSocketAddress(Protocol.PORT));
            } catch (IOException e) {
                server.bind(new InetSocketAddress(0));
            }
            registerNsd(server.getLocalPort());
            while (running) {
                Socket s = server.accept();
                new Thread(() -> handle(s), "TazamaCameraClient").start();
            }
        } catch (IOException e) {
            if (running) {
                Log.w(TAG, "server stopped", e);
                setStatus("Network error: " + e.getMessage());
            }
        }
    }

    private void registerNsd(int port) {
        NsdServiceInfo info = new NsdServiceInfo();
        info.setServiceName("Tazama Camera " + Build.MODEL);
        info.setServiceType(Protocol.SERVICE_TYPE);
        info.setPort(port);
        info.setAttribute("id", store.phoneId());
        nsd = getSystemService(NsdManager.class);
        registration = new NsdManager.RegistrationListener() {
            @Override
            public void onRegistrationFailed(NsdServiceInfo i, int errorCode) {
                Log.w(TAG, "nsd registration failed " + errorCode);
            }

            @Override
            public void onUnregistrationFailed(NsdServiceInfo i, int errorCode) {
            }

            @Override
            public void onServiceRegistered(NsdServiceInfo i) {
            }

            @Override
            public void onServiceUnregistered(NsdServiceInfo i) {
            }
        };
        nsd.registerService(info, NsdManager.PROTOCOL_DNS_SD, registration);
    }

    private void handle(Socket socket) {
        Connection c = null;
        try {
            socket.setTcpNoDelay(true);
            socket.setSoTimeout(5000);
            DataInputStream in = new DataInputStream(new BufferedInputStream(socket.getInputStream()));
            DataOutputStream out = new DataOutputStream(new BufferedOutputStream(socket.getOutputStream(), 256 * 1024));

            byte[] nonce = new byte[16];
            new SecureRandom().nextBytes(nonce);
            out.write(Protocol.MAGIC);
            out.write(nonce);
            out.writeUTF(store.phoneId());
            out.writeUTF(Build.MANUFACTURER + " " + Build.MODEL);
            out.flush();

            int mode = in.readUnsignedByte();
            String tvId = in.readUTF();
            String tvName = in.readUTF();
            byte[] mac = new byte[32];
            in.readFully(mac);
            boolean ok = false;
            if (mode == Protocol.MODE_AUTH) {
                byte[] key = store.keyFor(tvId);
                ok = key != null && MessageDigest.isEqual(mac, Protocol.mac(key, nonce, tvId));
            } else if (mode == Protocol.MODE_PAIR_CODE) {
                byte[] key = new byte[32];
                in.readFully(key);
                String code = store.pendingCode();
                ok = code != null && MessageDigest.isEqual(mac,
                        Protocol.mac(code.getBytes(StandardCharsets.UTF_8), nonce, tvId));
                if (ok) {
                    store.save(tvId, tvName, key);
                    store.clearPendingCode();
                }
            }
            out.writeByte(ok ? Protocol.RESULT_OK : Protocol.RESULT_DENIED);
            out.flush();
            if (!ok) {
                socket.close();
                return;
            }
            socket.setSoTimeout(0);

            c = new Connection(socket, out, tvName);
            Connection old = current;
            current = c;
            if (old != null) old.close();
            wakeLock.acquire(6 * 60 * 60 * 1000L);
            wifiLock.acquire();
            setStatus("Connected to " + tvName);

            while (true) {
                int type = in.readUnsignedByte();
                int len = in.readInt();
                if (len < 0 || len > 65536) throw new IOException("bad message");
                byte[] payload = new byte[len];
                in.readFully(payload);
                DataInputStream p = new DataInputStream(new java.io.ByteArrayInputStream(payload));
                final Connection conn = c;
                if (type == Protocol.T_SET) {
                    String key = p.readUTF();
                    String value = p.readUTF();
                    cameraHandler.post(() -> streamer.set(key, value));
                } else if (type == Protocol.T_START) {
                    cameraHandler.post(() -> streamer.start(conn));
                    setStatus("Streaming to " + tvName);
                }
            }
        } catch (IOException e) {
            Log.i(TAG, "client gone: " + e.getMessage());
        } finally {
            try {
                socket.close();
            } catch (IOException ignored) {
            }
            if (c != null && current == c) {
                current = null;
                final Connection gone = c;
                cameraHandler.post(() -> streamer.stop(gone));
                releaseLocks();
                if (running) setStatus("Ready for the TV");
            }
        }
    }

    private void releaseLocks() {
        if (wakeLock != null && wakeLock.isHeld()) wakeLock.release();
        if (wifiLock != null && wifiLock.isHeld()) wifiLock.release();
    }

    /** One TV. Writes are serialized; a write error closes the socket so the reader thread cleans up. */
    private static final class Connection implements CameraStreamer.Sink {
        private final Socket socket;
        private final DataOutputStream out;
        final String tvName;
        private byte[] scratch = new byte[256 * 1024];

        Connection(Socket socket, DataOutputStream out, String tvName) {
            this.socket = socket;
            this.out = out;
            this.tvName = tvName;
        }

        void close() {
            try {
                socket.close();
            } catch (IOException ignored) {
            }
        }

        private synchronized void send(int type, byte[] payload) {
            try {
                out.writeByte(type);
                out.writeInt(payload.length);
                out.write(payload);
                out.flush();
            } catch (IOException e) {
                close();
            }
        }

        private static byte[] build(IOConsumer body) {
            try {
                ByteArrayOutputStream bytes = new ByteArrayOutputStream();
                DataOutputStream d = new DataOutputStream(bytes);
                body.accept(d);
                d.flush();
                return bytes.toByteArray();
            } catch (IOException e) {
                throw new IllegalStateException(e);
            }
        }

        private interface IOConsumer {
            void accept(DataOutputStream d) throws IOException;
        }

        @Override
        public void format(int width, int height) {
            send(Protocol.P_FORMAT, build(d -> {
                d.writeInt(width);
                d.writeInt(height);
            }));
        }

        @Override
        public void state(int rotation, String facing, boolean torch, boolean hasTorch, float zoom, float maxZoom,
                          int exposure, String size, int fps) {
            send(Protocol.P_STATE, build(d -> {
                d.writeInt(rotation);
                d.writeUTF(facing);
                d.writeBoolean(torch);
                d.writeBoolean(hasTorch);
                d.writeFloat(zoom);
                d.writeFloat(maxZoom);
                d.writeInt(exposure);
                d.writeUTF(size);
                d.writeInt(fps);
            }));
        }

        @Override
        public synchronized void video(int flags, long ptsUs, ByteBuffer data, int offset, int size) {
            if (scratch.length < size) scratch = new byte[size];
            data.position(offset);
            data.get(scratch, 0, size);
            try {
                out.writeByte(Protocol.P_VIDEO);
                out.writeInt(size + 9);
                out.writeByte(flags);
                out.writeLong(ptsUs);
                out.write(scratch, 0, size);
                out.flush();
            } catch (IOException e) {
                close();
            }
        }

        @Override
        public void error(String message) {
            send(Protocol.P_ERROR, build(d -> d.writeUTF(message)));
        }
    }
}

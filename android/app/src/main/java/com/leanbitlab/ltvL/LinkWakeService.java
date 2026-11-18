package com.leanbitlab.ltvL;

package com.leanbitlab.ltvL;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.ServiceInfo;
import android.net.nsd.NsdManager;
import android.net.nsd.NsdServiceInfo;
import android.os.IBinder;
import android.util.Base64;
import android.util.Log;

import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.net.ServerSocket;
import java.net.Socket;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.HashSet;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

/**
 * Lets a paired phone (Tazama Link) open Phone camera on this TV without anyone touching the TV.
 * Protocol: TV sends "TZW1" + nonce[16]; phone sends phoneId (UTF) and HMAC-SHA256(tvKey, nonce || tvId);
 * TV answers 0 (opening) or 1 (denied).
 */
public class LinkWakeService extends Service {
    private static final String TAG = "LinkWake";
    static final int PORT = 47801;
    static final String SERVICE_TYPE = "_tazamatv._tcp";

    private ServerSocket server;
    private NsdManager nsd;
    private NsdManager.RegistrationListener registration;
    private volatile boolean running;

    public static void start(Context context) {
        try {
            context.startForegroundService(new Intent(context, LinkWakeService.class));
        } catch (RuntimeException e) {
            Log.w(TAG, "cannot start", e);
        }
    }

    @Override
    public void onCreate() {
        super.onCreate();
        NotificationManager nm = getSystemService(NotificationManager.class);
        nm.createNotificationChannel(new NotificationChannel("link", "Tazama Link", NotificationManager.IMPORTANCE_MIN));
        Notification n = new Notification.Builder(this, "link")
                .setSmallIcon(android.R.drawable.presence_video_online)
                .setContentTitle("Tazama Link")
                .setContentText("Ready for your phone")
                .build();
        try {
            startForeground(2, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE);
        } catch (RuntimeException e) {
            Log.w(TAG, "cannot run in foreground", e);
            stopSelf();
            return;
        }
        running = true;
        new Thread(this::acceptLoop, "LinkWake").start();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        running = false;
        try {
            if (registration != null) nsd.unregisterService(registration);
        } catch (Exception ignored) {
        }
        try {
            if (server != null) server.close();
        } catch (IOException ignored) {
        }
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    private SharedPreferences prefs() {
        return getSharedPreferences("phone_camera", MODE_PRIVATE);
    }

    private void acceptLoop() {
        try {
            server = new ServerSocket();
            server.setReuseAddress(true);
            server.bind(new java.net.InetSocketAddress(PORT));
            while (running && prefs().getString("tv_id", null) == null) Thread.sleep(2000);
            register();
            while (running) {
                Socket s = server.accept();
                new Thread(() -> handle(s), "LinkWakeClient").start();
            }
        } catch (IOException | InterruptedException e) {
            if (running) Log.w(TAG, "server stopped", e);
        }
    }

    private void register() {
        String id = prefs().getString("tv_id", null);
        NsdServiceInfo info = new NsdServiceInfo();
        info.setServiceName("TazamaTV-" + id);
        info.setServiceType(SERVICE_TYPE);
        info.setPort(PORT);
        nsd = getSystemService(NsdManager.class);
        registration = new NsdManager.RegistrationListener() {
            @Override
            public void onRegistrationFailed(NsdServiceInfo i, int e) {
                Log.w(TAG, "nsd registration failed " + e);
            }

            @Override
            public void onUnregistrationFailed(NsdServiceInfo i, int e) {
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

    private void handle(Socket s) {
        try (s) {
            s.setSoTimeout(5000);
            DataOutputStream out = new DataOutputStream(s.getOutputStream());
            DataInputStream in = new DataInputStream(s.getInputStream());
            byte[] nonce = new byte[16];
            new SecureRandom().nextBytes(nonce);
            out.write(new byte[]{'T', 'Z', 'W', '1'});
            out.write(nonce);
            out.flush();
            String phoneId = in.readUTF();
            byte[] mac = new byte[32];
            in.readFully(mac);

            SharedPreferences p = prefs();
            String tvId = p.getString("tv_id", null);
            String key = p.getString("tv_key", null);
            boolean ok = tvId != null && key != null
                    && new HashSet<>(p.getStringSet("phones", new HashSet<>())).contains(phoneId)
                    && MessageDigest.isEqual(mac, mac(Base64.decode(key, Base64.NO_WRAP), nonce, tvId));
            out.writeByte(ok ? 0 : 1);
            out.flush();
            if (!ok) return;
            // Connect to the phone that asked, then open the view over whatever is on screen.
            p.edit().putString("last_id", phoneId).apply();
            Intent open = new Intent(this, PhoneCameraActivity.class)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            startActivity(open);
        } catch (Exception e) {
            Log.i(TAG, "wake failed: " + e.getMessage());
        }
    }

    private static byte[] mac(byte[] secret, byte[] nonce, String id) throws Exception {
        Mac m = Mac.getInstance("HmacSHA256");
        m.init(new SecretKeySpec(secret, "HmacSHA256"));
        m.update(nonce);
        m.update(id.getBytes(java.nio.charset.StandardCharsets.UTF_8));
        return m.doFinal();
    }
}

package com.omeda.arc;

import android.app.Activity;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.media.MediaCodec;
import android.media.MediaFormat;
import android.os.Bundle;
import android.os.Handler;
import android.os.HandlerThread;
import android.text.InputType;
import android.util.Log;
import android.view.Gravity;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.WindowManager;
import android.view.inputmethod.EditorInfo;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.annotation.NonNull;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.ConnectException;
import java.net.NoRouteToHostException;
import java.net.SocketTimeoutException;
import java.nio.ByteBuffer;
import java.util.Locale;
import java.util.Random;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;

import dadb.AdbKeyPair;
import dadb.AdbStream;
import dadb.Dadb;
import okio.BufferedSource;

/**
 * Shows a phone's camera full screen. Connects to the phone over adb (TCP), starts the bundled
 * scrcpy server there with the camera as video source and decodes the H.264 stream.
 */
public class PhoneCameraActivity extends Activity implements SurfaceHolder.Callback {
    private static final String TAG = "PhoneCamera";
    // Must match the bundled assets/scrcpy-server.jar exactly (the server checks it).
    private static final String SERVER_VERSION = "5.0.1";
    private static final String SERVER_ASSET = "scrcpy-server.jar";
    private static final String SERVER_REMOTE = "/data/local/tmp/tazama-scrcpy-server.jar";
    private static final String PREFS = "phone_camera";

    private static final long FLAG_CONFIG = 1L << 62;

    private SurfaceView surfaceView;
    private TextView status;
    private LinearLayout setup;
    private volatile SurfaceHolder holder;

    private volatile boolean running;
    private Thread worker;
    private volatile Dadb dadb;
    private volatile AdbStream serverShell;
    private volatile AdbStream videoStream;
    private final StringBuilder serverLog = new StringBuilder();

    private HandlerThread codecThread;
    private MediaCodec decoder;
    private final LinkedBlockingQueue<Integer> freeInputs = new LinkedBlockingQueue<>();
    private volatile boolean firstFrameShown;
    private int videoWidth, videoHeight;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        saveExtras(getIntent());

        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.BLACK);
        surfaceView = new SurfaceView(this);
        root.addView(surfaceView, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT, Gravity.CENTER));

        LinearLayout column = new LinearLayout(this);
        column.setOrientation(LinearLayout.VERTICAL);
        column.setGravity(Gravity.CENTER);
        status = new TextView(this);
        status.setTextColor(Color.WHITE);
        status.setTextSize(20);
        status.setGravity(Gravity.CENTER);
        status.setPadding(48, 24, 48, 24);
        column.addView(status);

        setup = new LinearLayout(this);
        setup.setOrientation(LinearLayout.HORIZONTAL);
        setup.setGravity(Gravity.CENTER);
        EditText address = new EditText(this);
        address.setTextColor(Color.WHITE);
        address.setHint("Phone IP address");
        address.setHintTextColor(Color.GRAY);
        address.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_URI);
        address.setImeOptions(EditorInfo.IME_ACTION_DONE);
        address.setMinEms(10);
        address.setText(prefs().getString("host", ""));
        address.setOnEditorActionListener((v, actionId, event) -> {
            String host = v.getText().toString().trim();
            if (host.isEmpty()) return false;
            prefs().edit().putString("host", host).apply();
            setup.setVisibility(View.GONE);
            startStreaming();
            return true;
        });
        setup.addView(address);
        setup.setVisibility(View.GONE);
        column.addView(setup);
        root.addView(column, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));

        setContentView(root);
        surfaceView.getHolder().addCallback(this);
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        saveExtras(intent);
    }

    /** Lets setup be done with adb: am start ... --es host 192.168.1.x [--ei port 5555] [--es facing front]. */
    private void saveExtras(Intent intent) {
        if (intent == null) return;
        SharedPreferences.Editor edit = prefs().edit();
        if (intent.hasExtra("host")) edit.putString("host", intent.getStringExtra("host"));
        if (intent.hasExtra("port")) edit.putInt("port", intent.getIntExtra("port", 5555));
        if (intent.hasExtra("facing")) edit.putString("facing", intent.getStringExtra("facing"));
        if (intent.hasExtra("size")) edit.putString("size", intent.getStringExtra("size"));
        edit.apply();
    }

    private SharedPreferences prefs() {
        return getSharedPreferences(PREFS, MODE_PRIVATE);
    }

    @Override
    public void surfaceCreated(@NonNull SurfaceHolder h) {
        holder = h;
        if (prefs().getString("host", "").isEmpty()) {
            showStatus("Enter the phone's IP address. Run `adb tcpip 5555` on the phone first.");
            setup.setVisibility(View.VISIBLE);
            setup.getChildAt(0).requestFocus();
        } else {
            startStreaming();
        }
    }

    @Override
    public void surfaceChanged(@NonNull SurfaceHolder h, int format, int width, int height) {
    }

    @Override
    public void surfaceDestroyed(@NonNull SurfaceHolder h) {
        holder = null;
        stopStreaming();
    }

    @Override
    protected void onStop() {
        super.onStop();
        // Free the phone's camera as soon as we leave; reopening starts a fresh stream.
        stopStreaming();
        finish();
    }

    private void startStreaming() {
        if (running) return;
        running = true;
        firstFrameShown = false;
        codecThread = new HandlerThread("PhoneCameraCodec");
        codecThread.start();
        worker = new Thread(this::run, "PhoneCamera");
        worker.start();
    }

    private void stopStreaming() {
        if (!running) return;
        running = false;
        AdbStream video = videoStream, shell = serverShell;
        Dadb connection = dadb;
        // Closing writes to the socket, which is not allowed on the main thread.
        new Thread(() -> {
            closeQuietly(video);
            closeQuietly(shell);
            closeQuietly(connection);
        }, "PhoneCameraClose").start();
        if (worker != null) worker.interrupt();
        if (codecThread != null) {
            new Handler(codecThread.getLooper()).post(this::releaseDecoder);
            codecThread.quitSafely();
        }
    }

    private void run() {
        String host = prefs().getString("host", "");
        int port = prefs().getInt("port", 5555);
        try {
            long t0 = System.currentTimeMillis();
            showStatus("Connecting to the phone…\nThe first time, allow USB debugging on the phone.");
            AdbKeyPair keys = loadKeys();
            dadb = Dadb.create(host, port, keys, 4000, 0, true);
            if (!running) return;

            ensureServer(dadb);
            showStatus("Starting the camera…");
            int scid = new Random().nextInt(0x7fffffff);
            serverShell = dadb.open("shell:" + serverCommand(scid));
            startLogReader(serverShell);
            videoStream = openVideoSocket(dadb, String.format(Locale.ROOT, "scrcpy_%08x", scid));
            Log.i(TAG, "stream open after " + (System.currentTimeMillis() - t0) + " ms");
            readStream(videoStream.getSource());
        } catch (Exception e) {
            if (!running) return;
            Log.w(TAG, "stream failed", e);
            showStatus(describe(e, host, port));
            runOnUiThread(() -> setup.setVisibility(View.VISIBLE));
        } finally {
            running = false;
            closeQuietly(videoStream);
            closeQuietly(serverShell);
            closeQuietly(dadb);
        }
    }

    private String serverCommand(int scid) {
        String facing = prefs().getString("facing", "back");
        String size = prefs().getString("size", "1920x1080");
        return "CLASSPATH=" + SERVER_REMOTE + " app_process / com.genymobile.scrcpy.Server " + SERVER_VERSION
                + String.format(Locale.ROOT, " scid=%08x", scid)
                + " log_level=info video=true audio=false control=false tunnel_forward=true"
                + " send_device_meta=false send_dummy_byte=false send_frame_meta=true send_stream_meta=true"
                + " video_codec=h264 video_bit_rate=8000000 video_source=camera"
                + " camera_facing=" + facing + " camera_size=" + size;
    }

    private AdbKeyPair loadKeys() throws IOException {
        File priv = new File(getFilesDir(), "adbkey");
        File pub = new File(getFilesDir(), "adbkey.pub");
        if (!priv.exists() || !pub.exists()) AdbKeyPair.generate(priv, pub);
        return AdbKeyPair.read(priv, pub);
    }

    /** Pushes the server jar only when the phone's copy differs in size. */
    private void ensureServer(Dadb dadb) throws IOException {
        File local = new File(getCacheDir(), SERVER_ASSET);
        try (InputStream in = getAssets().open(SERVER_ASSET); OutputStream out = new FileOutputStream(local)) {
            byte[] buf = new byte[64 * 1024];
            int n;
            while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
        }
        String remoteSize = dadb.shell("stat -c %s " + SERVER_REMOTE + " 2>/dev/null").getOutput().trim();
        if (!remoteSize.equals(String.valueOf(local.length()))) {
            showStatus("Copying the camera helper to the phone…");
            dadb.push(local, SERVER_REMOTE, 0644, local.lastModified());
        }
    }

    private AdbStream openVideoSocket(Dadb dadb, String socket) throws Exception {
        long deadline = System.currentTimeMillis() + 8000;
        while (true) {
            try {
                return dadb.open("localabstract:" + socket);
            } catch (Exception e) {
                if (!running) throw e;
                if (System.currentTimeMillis() > deadline) {
                    throw new IOException("Camera did not start on the phone.\n" + lastLog());
                }
                Thread.sleep(40);
            }
        }
    }

    private void startLogReader(AdbStream shell) {
        Thread t = new Thread(() -> {
            try {
                BufferedSource src = shell.getSource();
                String line;
                while ((line = src.readUtf8Line()) != null) {
                    Log.i(TAG, "server: " + line);
                    synchronized (serverLog) {
                        serverLog.append(line).append('\n');
                        if (serverLog.length() > 4000) serverLog.delete(0, serverLog.length() - 4000);
                    }
                }
            } catch (Exception ignored) {
            }
        }, "PhoneCameraLog");
        t.setDaemon(true);
        t.start();
    }

    private String lastLog() {
        synchronized (serverLog) {
            String s = serverLog.toString().trim();
            int cut = s.lastIndexOf('\n', Math.max(0, s.length() - 400));
            return cut > 0 ? s.substring(cut + 1) : s;
        }
    }

    private void readStream(BufferedSource src) throws Exception {
        int codecId = src.readInt();
        if (codecId == 0 || codecId == 1) throw new IOException("The phone refused the camera stream.\n" + lastLog());
        while (running) {
            int high = src.readInt();
            if (high < 0) { // session packet: top bit set
                int width = src.readInt();
                int height = src.readInt();
                configureDecoder(width, height);
                continue;
            }
            long ptsAndFlags = ((long) high << 32) | (src.readInt() & 0xffffffffL);
            int size = src.readInt();
            byte[] packet = src.readByteArray(size);
            boolean config = (ptsAndFlags & FLAG_CONFIG) != 0;
            long pts = config ? 0 : (ptsAndFlags & 0x1fffffffffffffffL);
            queuePacket(packet, pts, config);
        }
    }

    private void configureDecoder(int width, int height) throws Exception {
        java.util.concurrent.CountDownLatch done = new java.util.concurrent.CountDownLatch(1);
        Exception[] error = new Exception[1];
        new Handler(codecThread.getLooper()).post(() -> {
            try {
                releaseDecoder();
                freeInputs.clear();
                videoWidth = width;
                videoHeight = height;
                SurfaceHolder h = holder;
                if (h == null) throw new IOException("No surface");
                decoder = MediaCodec.createDecoderByType(MediaFormat.MIMETYPE_VIDEO_AVC);
                decoder.setCallback(new MediaCodec.Callback() {
                    @Override
                    public void onInputBufferAvailable(@NonNull MediaCodec codec, int index) {
                        if (codec == decoder) freeInputs.offer(index);
                    }

                    @Override
                    public void onOutputBufferAvailable(@NonNull MediaCodec codec, int index, @NonNull MediaCodec.BufferInfo info) {
                        if (codec != decoder) return;
                        codec.releaseOutputBuffer(index, true);
                        if (!firstFrameShown) {
                            firstFrameShown = true;
                            runOnUiThread(() -> status.setVisibility(View.GONE));
                        }
                    }

                    @Override
                    public void onError(@NonNull MediaCodec codec, @NonNull MediaCodec.CodecException e) {
                        Log.w(TAG, "decoder error", e);
                    }

                    @Override
                    public void onOutputFormatChanged(@NonNull MediaCodec codec, @NonNull MediaFormat format) {
                    }
                }, new Handler(codecThread.getLooper()));
                try {
                    decoder.configure(format(width, height, true), h.getSurface(), null, 0);
                } catch (Exception lowLatencyUnsupported) {
                    decoder.reset();
                    decoder.configure(format(width, height, false), h.getSurface(), null, 0);
                }
                decoder.start();
                runOnUiThread(this::fitSurface);
            } catch (Exception e) {
                error[0] = e;
            } finally {
                done.countDown();
            }
        });
        done.await();
        if (error[0] != null) throw error[0];
    }

    private static MediaFormat format(int width, int height, boolean lowLatency) {
        MediaFormat format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height);
        format.setInteger(MediaFormat.KEY_PRIORITY, 0);
        if (lowLatency) format.setInteger(MediaFormat.KEY_LOW_LATENCY, 1);
        return format;
    }

    private void queuePacket(byte[] packet, long pts, boolean config) throws InterruptedException {
        MediaCodec codec = decoder;
        if (codec == null) return;
        Integer index = freeInputs.poll(500, TimeUnit.MILLISECONDS);
        if (index == null || codec != decoder) return; // decoder stalled or replaced: drop the packet
        try {
            ByteBuffer buffer = codec.getInputBuffer(index);
            if (buffer == null || buffer.capacity() < packet.length) return;
            buffer.clear();
            buffer.put(packet);
            codec.queueInputBuffer(index, 0, packet.length, pts, config ? MediaCodec.BUFFER_FLAG_CODEC_CONFIG : 0);
        } catch (IllegalStateException e) {
            Log.w(TAG, "queue failed", e);
        }
    }

    private void releaseDecoder() {
        MediaCodec codec = decoder;
        decoder = null;
        if (codec == null) return;
        try {
            codec.stop();
        } catch (Exception ignored) {
        }
        codec.release();
    }

    /** Letterboxes the video to its own aspect ratio. */
    private void fitSurface() {
        View parent = (View) surfaceView.getParent();
        int pw = parent.getWidth(), ph = parent.getHeight();
        if (pw == 0 || ph == 0 || videoWidth == 0 || videoHeight == 0) return;
        float scale = Math.min((float) pw / videoWidth, (float) ph / videoHeight);
        FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(
                Math.round(videoWidth * scale), Math.round(videoHeight * scale), Gravity.CENTER);
        surfaceView.setLayoutParams(lp);
    }

    private void showStatus(String text) {
        runOnUiThread(() -> {
            status.setText(text);
            status.setVisibility(View.VISIBLE);
        });
    }

    private static String describe(Exception e, String host, int port) {
        String name = e.getClass().getSimpleName();
        if (e instanceof ConnectException || e instanceof NoRouteToHostException || e instanceof SocketTimeoutException) {
            return "Can't reach the phone at " + host + ":" + port + ".\n"
                    + "Is it on the same Wi-Fi? After a phone restart, run `adb tcpip 5555` again.";
        }
        if (name.contains("Auth")) {
            return "The phone refused the connection.\nAllow USB debugging for this TV on the phone, then try again.";
        }
        String msg = e.getMessage();
        return "Camera stream stopped: " + (msg == null ? name : msg);
    }

    private static void closeQuietly(AutoCloseable c) {
        if (c == null) return;
        try {
            c.close();
        } catch (Exception ignored) {
        }
    }
}

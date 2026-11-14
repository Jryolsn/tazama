package com.omeda.arc;

import android.app.Activity;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.graphics.Matrix;
import android.graphics.SurfaceTexture;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.StateListDrawable;
import android.media.MediaCodec;
import android.media.MediaFormat;
import android.net.Uri;
import android.net.nsd.NsdManager;
import android.net.nsd.NsdServiceInfo;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;
import android.provider.Settings;
import android.util.Base64;
import android.util.Log;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.Surface;
import android.view.TextureView;
import android.view.View;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.annotation.NonNull;

import com.google.zxing.BarcodeFormat;
import com.google.zxing.EncodeHintType;
import com.google.zxing.common.BitMatrix;
import com.google.zxing.qrcode.QRCodeWriter;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

/**
 * Shows the camera of a phone running Tazama Camera (camera-app/ in this repository), full screen
 * with low latency. Finds the phone on the local network, pairs with a QR code, decodes its H.264
 * stream and sends remote-control commands (camera, zoom, light, ...). Protocol: camera-app/PROTOCOL.md.
 */
public class PhoneCameraActivity extends Activity implements TextureView.SurfaceTextureListener {
    private static final String TAG = "PhoneCamera";
    private static final String SERVICE_TYPE = "_tazamacam._tcp";
    private static final int PORT = 47800;
    private static final byte[] MAGIC = {'T', 'Z', 'C', '1'};
    private static final int MODE_AUTH = 1, MODE_PAIR_CODE = 2;
    private static final int T_SET = 1, T_START = 2;
    private static final int P_FORMAT = 1, P_STATE = 2, P_VIDEO = 3, P_ERROR = 4;
    private static final int FLAG_CONFIG = 1;

    private static final String[] SIZES = {"1920x1080", "1280x720"};
    private static final String[] FPS = {"30", "60"};
    private static final String[] ROTATIONS = {"auto", "0", "90", "180", "270"};

    private SharedPreferences prefs;
    private String tvId, tvName;
    private byte[] tvKey;
    private String pairCode;

    // Views
    private FrameLayout root;
    private TextureView texture;
    private TextView status, info, hint;
    private LinearLayout pairing, menu;
    private Button lightBtn, cameraBtn, zoomBtn, brightnessBtn, qualityBtn, fpsBtn, rotationBtn;
    private final Handler ui = new Handler(Looper.getMainLooper());

    // Connection
    private volatile boolean running;
    private volatile boolean forcePairing;
    private Thread worker;
    private volatile Socket socket;
    private volatile DataOutputStream out;
    private final ExecutorService sender = Executors.newSingleThreadExecutor();
    private NsdManager nsd;
    private NsdManager.DiscoveryListener discovery;
    private final Map<String, Phone> found = new ConcurrentHashMap<>();
    private final ArrayDeque<NsdServiceInfo> toResolve = new ArrayDeque<>();
    private boolean resolving;

    // Decoding
    private HandlerThread codecThread;
    private Handler codecHandler;
    private volatile Surface surface;
    private MediaCodec decoder;
    private final LinkedBlockingQueue<Integer> freeInputs = new LinkedBlockingQueue<>();
    private volatile boolean firstFrame;
    private int videoW, videoH, rotation;

    // Last state reported by the phone
    private boolean torch, hasTorch;
    private String facing = "back", size = "", fpsNow = "";
    private float zoom = 1f;
    private int exposure;

    private static final class Phone {
        final String id, name, host;
        final int port;

        Phone(String id, String name, String host, int port) {
            this.id = id;
            this.name = name;
            this.host = host;
            this.port = port;
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        prefs = getSharedPreferences("phone_camera", MODE_PRIVATE);
        loadIdentity();
        buildViews();
    }

    @Override
    protected void onStart() {
        super.onStart();
        running = true;
        firstFrame = false;
        codecThread = new HandlerThread("PhoneCameraCodec");
        codecThread.start();
        codecHandler = new Handler(codecThread.getLooper());
        startDiscovery();
        worker = new Thread(this::connectLoop, "PhoneCamera");
        worker.start();
    }

    @Override
    protected void onStop() {
        super.onStop();
        // Leaving frees the phone's camera; opening again starts a fresh stream.
        running = false;
        stopDiscovery();
        Socket s = socket;
        if (s != null) sender.execute(() -> closeQuietly(s));
        if (worker != null) worker.interrupt();
        if (codecHandler != null) {
            codecHandler.post(this::releaseDecoder);
            codecThread.quitSafely();
        }
        finish();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        sender.shutdown();
    }

    // ---- identity and pairing ----

    private void loadIdentity() {
        tvId = prefs.getString("tv_id", null);
        String key = prefs.getString("tv_key", null);
        if (tvId == null || key == null) {
            SecureRandom r = new SecureRandom();
            byte[] id = new byte[8];
            r.nextBytes(id);
            tvKey = new byte[32];
            r.nextBytes(tvKey);
            StringBuilder sb = new StringBuilder();
            for (byte b : id) sb.append(String.format("%02x", b));
            tvId = sb.toString();
            prefs.edit().putString("tv_id", tvId)
                    .putString("tv_key", Base64.encodeToString(tvKey, Base64.NO_WRAP)).apply();
        } else {
            tvKey = Base64.decode(key, Base64.NO_WRAP);
        }
        String name = Settings.Global.getString(getContentResolver(), "device_name");
        tvName = name == null || name.isEmpty() ? Build.MODEL : name;
        pairCode = String.format(Locale.ROOT, "%06d", new SecureRandom().nextInt(1_000_000));
    }

    private Set<String> pairedPhones() {
        return new HashSet<>(prefs.getStringSet("phones", new HashSet<>()));
    }

    private void savePhone(Phone p) {
        Set<String> ids = pairedPhones();
        ids.add(p.id);
        prefs.edit().putStringSet("phones", ids)
                .putString("last_id", p.id).putString("last_host", p.host).putInt("last_port", p.port)
                .putString("name." + p.id, p.name).apply();
    }

    private void forgetPhones() {
        prefs.edit().remove("phones").remove("last_id").remove("last_host").remove("last_port").apply();
    }

    private String qrText() {
        return "tazamacam://pair?v=1&id=" + tvId
                + "&k=" + Base64.encodeToString(tvKey, Base64.URL_SAFE | Base64.NO_WRAP | Base64.NO_PADDING)
                + "&n=" + Uri.encode(tvName);
    }

    private static byte[] mac(byte[] secret, byte[] nonce, String id) throws Exception {
        Mac mac = Mac.getInstance("HmacSHA256");
        mac.init(new SecretKeySpec(secret, "HmacSHA256"));
        mac.update(nonce);
        mac.update(id.getBytes(StandardCharsets.UTF_8));
        return mac.doFinal();
    }

    // ---- discovery ----

    private void startDiscovery() {
        nsd = getSystemService(NsdManager.class);
        discovery = new NsdManager.DiscoveryListener() {
            @Override
            public void onStartDiscoveryFailed(String type, int errorCode) {
                Log.w(TAG, "discovery failed " + errorCode);
            }

            @Override
            public void onStopDiscoveryFailed(String type, int errorCode) {
            }

            @Override
            public void onDiscoveryStarted(String type) {
            }

            @Override
            public void onDiscoveryStopped(String type) {
            }

            @Override
            public void onServiceFound(NsdServiceInfo info) {
                ui.post(() -> {
                    toResolve.add(info);
                    resolveNext();
                });
            }

            @Override
            public void onServiceLost(NsdServiceInfo info) {
            }
        };
        try {
            nsd.discoverServices(SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, discovery);
        } catch (Exception e) {
            Log.w(TAG, "discovery", e);
            discovery = null;
        }
    }

    @SuppressWarnings("deprecation")
    private void resolveNext() {
        if (resolving || toResolve.isEmpty() || !running) return;
        resolving = true;
        nsd.resolveService(toResolve.poll(), new NsdManager.ResolveListener() {
            @Override
            public void onResolveFailed(NsdServiceInfo info, int errorCode) {
                ui.post(() -> {
                    resolving = false;
                    resolveNext();
                });
            }

            @Override
            public void onServiceResolved(NsdServiceInfo info) {
                byte[] id = info.getAttributes().get("id");
                if (id != null && info.getHost() != null) {
                    String idS = new String(id, StandardCharsets.UTF_8);
                    String name = info.getServiceName().replaceFirst("^Tazama Camera ", "");
                    found.put(idS, new Phone(idS, name, info.getHost().getHostAddress(), info.getPort()));
                }
                ui.post(() -> {
                    resolving = false;
                    resolveNext();
                });
            }
        });
    }

    private void stopDiscovery() {
        if (nsd != null && discovery != null) {
            try {
                nsd.stopServiceDiscovery(discovery);
            } catch (Exception ignored) {
            }
        }
        discovery = null;
    }

    // ---- connection ----

    private static final int OK = 0, DENIED = 1, UNREACHABLE = 2, ENDED = 3;

    private void connectLoop() {
        long searchingSince = System.currentTimeMillis();
        boolean codeTurn = false;
        while (running) {
            Set<String> paired = pairedPhones();
            if (paired.isEmpty() || forcePairing) {
                showPairing(true);
                for (Phone p : new ArrayList<>(found.values())) {
                    if (!running) return;
                    // Alternate: a phone that scanned the QR code knows our key; one that typed the code knows the code.
                    int r = session(p, codeTurn ? MODE_PAIR_CODE : MODE_AUTH);
                    if (r == ENDED) searchingSince = System.currentTimeMillis();
                }
                codeTurn = !codeTurn;
                sleep(1200);
                continue;
            }
            showPairing(false);

            List<Phone> candidates = new ArrayList<>();
            String lastId = prefs.getString("last_id", null);
            Phone fresh = lastId == null ? null : found.get(lastId);
            if (fresh != null) candidates.add(fresh);
            else if (lastId != null && prefs.getString("last_host", null) != null) {
                candidates.add(new Phone(lastId, prefs.getString("name." + lastId, "phone"),
                        prefs.getString("last_host", null), prefs.getInt("last_port", PORT)));
            }
            for (Phone p : found.values()) if (paired.contains(p.id) && !p.id.equals(lastId)) candidates.add(p);

            boolean streamed = false;
            for (Phone p : candidates) {
                if (!running) return;
                showStatus("Connecting to " + p.name + "…");
                int r = session(p, MODE_AUTH);
                if (r == ENDED) {
                    streamed = true;
                    break;
                }
            }
            if (streamed) {
                searchingSince = System.currentTimeMillis();
                if (running) showStatus("The phone stopped the stream. Reconnecting…");
                sleep(500);
                continue;
            }
            if (System.currentTimeMillis() - searchingSince > 3000) {
                showStatus("Can't find your phone.\n\nOpen Tazama Camera on the phone (needed once after it restarts)\n"
                        + "and check that it is on the same Wi-Fi as the TV.\n\nPress OK to pair a phone.");
            } else {
                showStatus("Looking for your phone…");
            }
            sleep(1000);
        }
    }

    /** One connection: handshake, then stream until it ends. */
    private int session(Phone phone, int mode) {
        Socket s = new Socket();
        try {
            s.setTcpNoDelay(true);
            s.setReceiveBufferSize(1 << 20);
            s.connect(new InetSocketAddress(phone.host, phone.port), 1500);
            s.setSoTimeout(4000);
            DataInputStream in = new DataInputStream(new BufferedInputStream(s.getInputStream(), 256 * 1024));
            DataOutputStream o = new DataOutputStream(new BufferedOutputStream(s.getOutputStream()));
            byte[] magic = new byte[4];
            in.readFully(magic);
            if (!java.util.Arrays.equals(magic, MAGIC)) return UNREACHABLE;
            byte[] nonce = new byte[16];
            in.readFully(nonce);
            String phoneId = in.readUTF();
            String phoneName = in.readUTF();

            o.writeByte(mode);
            o.writeUTF(tvId);
            o.writeUTF(tvName);
            if (mode == MODE_AUTH) {
                o.write(mac(tvKey, nonce, tvId));
            } else {
                o.write(mac(pairCode.getBytes(StandardCharsets.UTF_8), nonce, tvId));
                o.write(tvKey);
            }
            o.flush();
            if (in.readUnsignedByte() != OK) return DENIED;

            Phone p = new Phone(phoneId, phoneName, phone.host, phone.port);
            savePhone(p);
            forcePairing = false;
            showPairing(false);
            showStatus("Starting the camera on " + phoneName + "…");
            s.setSoTimeout(8000);
            socket = s;
            out = o;
            send(T_SET, "facing", prefs.getString("facing", "back"));
            send(T_SET, "size", prefs.getString("size", SIZES[0]));
            send(T_SET, "fps", prefs.getString("fps", FPS[0]));
            send(T_SET, "rotation", prefs.getString("rotation", "auto"));
            sendRaw(T_START, new byte[0]);
            readLoop(in);
            return ENDED;
        } catch (Exception e) {
            Log.i(TAG, "session " + phone.host + ": " + e);
            return socket == s ? ENDED : UNREACHABLE;
        } finally {
            if (socket == s) {
                socket = null;
                out = null;
                firstFrame = false;
                ui.post(() -> {
                    status.setVisibility(View.VISIBLE);
                    hideMenu();
                });
            }
            closeQuietly(s);
        }
    }

    private void readLoop(DataInputStream in) throws Exception {
        byte[] buf = new byte[512 * 1024];
        while (running) {
            int type = in.readUnsignedByte();
            int len = in.readInt();
            if (len < 0 || len > 32 * 1024 * 1024) throw new IOException("bad packet");
            if (type == P_VIDEO) {
                int flags = in.readUnsignedByte();
                long pts = in.readLong();
                int n = len - 9;
                if (buf.length < n) buf = new byte[n];
                in.readFully(buf, 0, n);
                queuePacket(buf, n, pts, (flags & FLAG_CONFIG) != 0);
                continue;
            }
            byte[] payload = new byte[len];
            in.readFully(payload);
            DataInputStream p = new DataInputStream(new ByteArrayInputStream(payload));
            if (type == P_FORMAT) {
                configureDecoder(p.readInt(), p.readInt());
            } else if (type == P_STATE) {
                int rot = p.readInt();
                String f = p.readUTF();
                boolean t = p.readBoolean(), ht = p.readBoolean();
                float z = p.readFloat();
                p.readFloat(); // max zoom
                int ex = p.readInt();
                String sz = p.readUTF();
                int fps = p.readInt();
                ui.post(() -> onState(rot, f, t, ht, z, ex, sz, fps));
            } else if (type == P_ERROR) {
                String msg = p.readUTF();
                showStatus(msg);
            }
        }
    }

    private void send(int type, String key, String value) {
        try {
            ByteArrayOutputStream b = new ByteArrayOutputStream();
            DataOutputStream d = new DataOutputStream(b);
            d.writeUTF(key);
            d.writeUTF(value);
            d.flush();
            sendRaw(type, b.toByteArray());
        } catch (IOException ignored) {
        }
    }

    /** Writes on the sender thread (never the main thread). */
    private void sendRaw(int type, byte[] payload) {
        DataOutputStream o = out;
        if (o == null) return;
        sender.execute(() -> {
            try {
                synchronized (o) {
                    o.writeByte(type);
                    o.writeInt(payload.length);
                    o.write(payload);
                    o.flush();
                }
            } catch (IOException e) {
                closeQuietly(socket);
            }
        });
    }

    private void set(String key, String value) {
        send(T_SET, key, value);
    }

    // ---- decoding ----

    @Override
    public void onSurfaceTextureAvailable(@NonNull SurfaceTexture st, int w, int h) {
        surface = new Surface(st);
        applyTransform();
    }

    @Override
    public void onSurfaceTextureSizeChanged(@NonNull SurfaceTexture st, int w, int h) {
        applyTransform();
    }

    @Override
    public boolean onSurfaceTextureDestroyed(@NonNull SurfaceTexture st) {
        surface = null;
        return true;
    }

    @Override
    public void onSurfaceTextureUpdated(@NonNull SurfaceTexture st) {
    }

    private void configureDecoder(int width, int height) throws Exception {
        long deadline = System.currentTimeMillis() + 3000;
        while (surface == null && System.currentTimeMillis() < deadline) Thread.sleep(20);
        CountDownLatch done = new CountDownLatch(1);
        Exception[] error = new Exception[1];
        codecHandler.post(() -> {
            try {
                releaseDecoder();
                freeInputs.clear();
                videoW = width;
                videoH = height;
                Surface target = surface;
                if (target == null) throw new IOException("No video surface");
                MediaCodec codec = MediaCodec.createDecoderByType(MediaFormat.MIMETYPE_VIDEO_AVC);
                decoder = codec;
                codec.setCallback(new MediaCodec.Callback() {
                    @Override
                    public void onInputBufferAvailable(@NonNull MediaCodec c, int index) {
                        if (c == decoder) freeInputs.offer(index);
                    }

                    @Override
                    public void onOutputBufferAvailable(@NonNull MediaCodec c, int index, @NonNull MediaCodec.BufferInfo info) {
                        if (c != decoder) return;
                        c.releaseOutputBuffer(index, true); // show at once, no pacing
                        if (!firstFrame) {
                            firstFrame = true;
                            ui.post(() -> {
                                status.setVisibility(View.GONE);
                                showHint();
                            });
                        }
                    }

                    @Override
                    public void onError(@NonNull MediaCodec c, @NonNull MediaCodec.CodecException e) {
                        Log.w(TAG, "decoder error", e);
                    }

                    @Override
                    public void onOutputFormatChanged(@NonNull MediaCodec c, @NonNull MediaFormat format) {
                    }
                }, codecHandler);
                try {
                    codec.configure(decoderFormat(width, height, true), target, null, 0);
                } catch (Exception lowLatencyUnsupported) {
                    codec.reset();
                    codec.configure(decoderFormat(width, height, false), target, null, 0);
                }
                codec.start();
                ui.post(this::applyTransform);
            } catch (Exception e) {
                error[0] = e;
            } finally {
                done.countDown();
            }
        });
        done.await();
        if (error[0] != null) throw error[0];
    }

    private static MediaFormat decoderFormat(int width, int height, boolean lowLatency) {
        MediaFormat f = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height);
        f.setInteger(MediaFormat.KEY_PRIORITY, 0);
        if (lowLatency) f.setInteger(MediaFormat.KEY_LOW_LATENCY, 1);
        return f;
    }

    private void queuePacket(byte[] data, int length, long pts, boolean config) throws InterruptedException {
        MediaCodec codec = decoder;
        if (codec == null) return;
        Integer index = freeInputs.poll(500, TimeUnit.MILLISECONDS);
        if (index == null || codec != decoder) return; // stalled or replaced: drop
        try {
            ByteBuffer b = codec.getInputBuffer(index);
            if (b == null || b.capacity() < length) return;
            b.clear();
            b.put(data, 0, length);
            codec.queueInputBuffer(index, 0, length, pts, config ? MediaCodec.BUFFER_FLAG_CODEC_CONFIG : 0);
        } catch (IllegalStateException e) {
            Log.w(TAG, "queue failed", e);
        }
    }

    private void releaseDecoder() {
        MediaCodec c = decoder;
        decoder = null;
        if (c == null) return;
        try {
            c.stop();
        } catch (Exception ignored) {
        }
        c.release();
    }

    /** Rotates the picture upright and letterboxes it. */
    private void applyTransform() {
        int vw = texture.getWidth(), vh = texture.getHeight();
        if (vw == 0 || vh == 0 || videoW == 0 || videoH == 0) return;
        boolean quarter = rotation % 180 != 0;
        float cw = quarter ? videoH : videoW, ch = quarter ? videoW : videoH;
        float s = Math.min(vw / cw, vh / ch);
        float boxW = (quarter ? ch : cw) * s, boxH = (quarter ? cw : ch) * s;
        Matrix m = new Matrix();
        m.setScale(boxW / vw, boxH / vh, vw / 2f, vh / 2f);
        m.postRotate(rotation, vw / 2f, vh / 2f);
        texture.setTransform(m);
    }

    // ---- UI ----

    private void buildViews() {
        root = new FrameLayout(this);
        root.setBackgroundColor(Color.BLACK);
        texture = new TextureView(this);
        texture.setSurfaceTextureListener(this);
        root.addView(texture, new FrameLayout.LayoutParams(-1, -1));

        status = new TextView(this);
        status.setTextColor(Color.WHITE);
        status.setTextSize(20);
        status.setGravity(Gravity.CENTER);
        status.setPadding(64, 32, 64, 32);
        status.setText("Looking for your phone…");
        root.addView(status, new FrameLayout.LayoutParams(-1, -1));

        pairing = new LinearLayout(this);
        pairing.setOrientation(LinearLayout.HORIZONTAL);
        pairing.setGravity(Gravity.CENTER);
        pairing.setBackgroundColor(Color.BLACK);
        ImageView qr = new ImageView(this);
        qr.setImageBitmap(qrBitmap(qrText(), 480));
        pairing.addView(qr, new LinearLayout.LayoutParams(dp(220), dp(220)));
        TextView steps = new TextView(this);
        steps.setTextColor(Color.WHITE);
        steps.setTextSize(18);
        steps.setPadding(dp(32), 0, 0, 0);
        steps.setText("Pair your phone\n\n"
                + "1. Install Tazama Camera on the phone\n    (Obtainium: github.com/Jryolsn/tazama)\n"
                + "2. Open it and tap \"Scan TV code\"\n\n"
                + "No luck with the QR code? Tap \"Enter code instead\"\nand type  "
                + pairCode.substring(0, 3) + " " + pairCode.substring(3));
        pairing.addView(steps);
        pairing.setVisibility(View.GONE);
        root.addView(pairing, new FrameLayout.LayoutParams(-1, -1));

        info = new TextView(this);
        info.setTextColor(Color.WHITE);
        info.setTextSize(16);
        info.setPadding(dp(14), dp(8), dp(14), dp(8));
        info.setBackground(round(0x99000000));
        info.setVisibility(View.GONE);
        FrameLayout.LayoutParams infoLp = new FrameLayout.LayoutParams(-2, -2, Gravity.TOP | Gravity.START);
        infoLp.setMargins(dp(32), dp(24), 0, 0);
        root.addView(info, infoLp);

        hint = new TextView(this);
        hint.setTextColor(Color.WHITE);
        hint.setTextSize(14);
        hint.setPadding(dp(14), dp(6), dp(14), dp(6));
        hint.setBackground(round(0x99000000));
        hint.setText("◀ ▶ switch camera    ▲ ▼ zoom    OK menu    Back exit");
        hint.setVisibility(View.GONE);
        FrameLayout.LayoutParams hintLp = new FrameLayout.LayoutParams(-2, -2, Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL);
        hintLp.bottomMargin = dp(24);
        root.addView(hint, hintLp);

        menu = new LinearLayout(this);
        menu.setOrientation(LinearLayout.VERTICAL);
        menu.setPadding(dp(12), dp(12), dp(12), dp(12));
        menu.setBackground(round(0xCC101018));
        lightBtn = menuButton(v -> set("torch", "toggle"));
        cameraBtn = menuButton(v -> set("facing", "next"));
        zoomBtn = menuButton(v -> set("zoom", "1"));
        brightnessBtn = menuButton(v -> set("exposure", String.valueOf(exposure >= 2 ? -2 : exposure + 1)));
        qualityBtn = menuButton(v -> cycle("size", SIZES));
        fpsBtn = menuButton(v -> cycle("fps", FPS));
        rotationBtn = menuButton(v -> cycle("rotation", ROTATIONS));
        Button forget = menuButton(v -> {
            forgetPhones();
            closeQuietlyAsync();
            hideMenu();
        });
        forget.setText("Forget this phone");
        menu.setVisibility(View.GONE);
        FrameLayout.LayoutParams menuLp = new FrameLayout.LayoutParams(dp(260), -2, Gravity.END | Gravity.CENTER_VERTICAL);
        menuLp.setMargins(0, 0, dp(32), 0);
        root.addView(menu, menuLp);
        updateMenuLabels();

        setContentView(root);
    }

    private void cycle(String key, String[] values) {
        String now = prefs.getString(key, values[0]);
        int i = 0;
        for (int k = 0; k < values.length; k++) if (values[k].equals(now)) i = k;
        String next = values[(i + 1) % values.length];
        prefs.edit().putString(key, next).apply();
        set(key, next);
        updateMenuLabels();
    }

    private void onState(int rot, String f, boolean t, boolean ht, float z, int ex, String sz, int fps) {
        boolean changedCamera = !f.equals(facing);
        boolean changedZoom = Math.abs(z - zoom) > 0.01f;
        boolean changedLight = t != torch;
        rotation = rot;
        facing = f;
        torch = t;
        hasTorch = ht;
        zoom = z;
        exposure = ex;
        size = sz;
        fpsNow = String.valueOf(fps);
        prefs.edit().putString("facing", f).apply();
        applyTransform();
        updateMenuLabels();
        if (changedCamera) flashInfo(("front".equals(f) ? "Front" : "Back") + " camera");
        else if (changedZoom) flashInfo(String.format(Locale.ROOT, "Zoom %.1fx", z));
        else if (changedLight) flashInfo(t ? "Light on" : "Light off");
    }

    private void updateMenuLabels() {
        lightBtn.setText(!hasTorch ? "Light: not on this camera" : "Light: " + (torch ? "on" : "off"));
        cameraBtn.setText("Camera: " + facing);
        zoomBtn.setText(String.format(Locale.ROOT, "Zoom: %.1fx  ◀ ▶", zoom));
        brightnessBtn.setText("Brightness: " + (exposure > 0 ? "+" : "") + exposure);
        String q = prefs.getString("size", SIZES[0]);
        qualityBtn.setText("Quality: " + (q.startsWith("1280") ? "720p" : "1080p")
                + (size.isEmpty() || size.equals(q) ? "" : " (phone: " + size + ")"));
        String f = prefs.getString("fps", FPS[0]);
        fpsBtn.setText("Frame rate: " + f + (fpsNow.isEmpty() || fpsNow.equals(f) ? "" : " (phone: " + fpsNow + ")"));
        String r = prefs.getString("rotation", "auto");
        rotationBtn.setText("Rotation: " + ("auto".equals(r) ? "auto" : r + "°"));
    }

    private void showMenu() {
        menu.setVisibility(View.VISIBLE);
        hint.setVisibility(View.GONE);
        lightBtn.requestFocus();
    }

    private void hideMenu() {
        menu.setVisibility(View.GONE);
    }

    private final Runnable hideInfo = () -> info.setVisibility(View.GONE);
    private final Runnable hideHint = () -> hint.setVisibility(View.GONE);

    private void flashInfo(String text) {
        info.setText(text);
        info.setVisibility(View.VISIBLE);
        ui.removeCallbacks(hideInfo);
        ui.postDelayed(hideInfo, 2000);
    }

    private void showHint() {
        hint.setVisibility(View.VISIBLE);
        ui.removeCallbacks(hideHint);
        ui.postDelayed(hideHint, 4000);
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        boolean streaming = out != null && firstFrame;
        if (menu.getVisibility() == View.VISIBLE) {
            if (keyCode == KeyEvent.KEYCODE_BACK) {
                hideMenu();
                return true;
            }
            return super.onKeyDown(keyCode, event);
        }
        boolean confirm = keyCode == KeyEvent.KEYCODE_DPAD_CENTER || keyCode == KeyEvent.KEYCODE_ENTER;
        if (!streaming && confirm && pairing.getVisibility() != View.VISIBLE) {
            forcePairing = true;
            showPairing(true);
            return true;
        }
        if (streaming) {
            switch (keyCode) {
                case KeyEvent.KEYCODE_DPAD_LEFT, KeyEvent.KEYCODE_DPAD_RIGHT -> {
                    set("facing", "next");
                    return true;
                }
                case KeyEvent.KEYCODE_DPAD_UP -> {
                    set("zoom", "in");
                    return true;
                }
                case KeyEvent.KEYCODE_DPAD_DOWN -> {
                    set("zoom", "out");
                    return true;
                }
                case KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER, KeyEvent.KEYCODE_MENU -> {
                    showMenu();
                    return true;
                }
                default -> {
                }
            }
        }
        return super.onKeyDown(keyCode, event);
    }

    @Override
    public boolean dispatchKeyEvent(KeyEvent event) {
        // Up/Down in the menu move focus; while the zoom row is focused they zoom instead.
        if (menu.getVisibility() == View.VISIBLE && zoomBtn.isFocused() && event.getAction() == KeyEvent.ACTION_DOWN) {
            if (event.getKeyCode() == KeyEvent.KEYCODE_DPAD_LEFT) {
                set("zoom", "out");
                return true;
            }
            if (event.getKeyCode() == KeyEvent.KEYCODE_DPAD_RIGHT) {
                set("zoom", "in");
                return true;
            }
        }
        return super.dispatchKeyEvent(event);
    }

    private void showPairing(boolean show) {
        ui.post(() -> {
            pairing.setVisibility(show ? View.VISIBLE : View.GONE);
            if (show) status.setVisibility(View.GONE);
        });
    }

    private void showStatus(String text) {
        ui.post(() -> {
            if (pairing.getVisibility() == View.VISIBLE) return;
            status.setText(text);
            status.setVisibility(View.VISIBLE);
        });
    }

    private Button menuButton(View.OnClickListener l) {
        Button b = new Button(this);
        b.setAllCaps(false);
        b.setTextColor(Color.WHITE);
        b.setTextSize(15);
        b.setGravity(Gravity.START | Gravity.CENTER_VERTICAL);
        b.setPadding(dp(14), dp(6), dp(14), dp(6));
        StateListDrawable bg = new StateListDrawable();
        bg.addState(new int[]{android.R.attr.state_focused}, round(0xFF6E5BD8));
        bg.addState(new int[]{}, new ColorDrawable(Color.TRANSPARENT));
        b.setBackground(bg);
        b.setOnClickListener(l);
        menu.addView(b, new LinearLayout.LayoutParams(-1, dp(40)));
        return b;
    }

    private GradientDrawable round(int color) {
        GradientDrawable d = new GradientDrawable();
        d.setColor(color);
        d.setCornerRadius(dp(12));
        return d;
    }

    private static Bitmap qrBitmap(String text, int px) {
        try {
            Map<EncodeHintType, Object> hints = new java.util.EnumMap<>(EncodeHintType.class);
            hints.put(EncodeHintType.MARGIN, 2);
            BitMatrix m = new QRCodeWriter().encode(text, BarcodeFormat.QR_CODE, px, px, hints);
            int[] pixels = new int[px * px];
            for (int y = 0; y < px; y++) {
                for (int x = 0; x < px; x++) pixels[y * px + x] = m.get(x, y) ? Color.BLACK : Color.WHITE;
            }
            return Bitmap.createBitmap(pixels, px, px, Bitmap.Config.ARGB_8888);
        } catch (Exception e) {
            return Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888);
        }
    }

    private int dp(int v) {
        return Math.round(v * getResources().getDisplayMetrics().density);
    }

    private void closeQuietlyAsync() {
        Socket s = socket;
        if (s != null) sender.execute(() -> closeQuietly(s));
    }

    private static void sleep(long ms) {
        try {
            Thread.sleep(ms);
        } catch (InterruptedException ignored) {
        }
    }

    private static void closeQuietly(AutoCloseable c) {
        if (c == null) return;
        try {
            c.close();
        } catch (Exception ignored) {
        }
    }
}

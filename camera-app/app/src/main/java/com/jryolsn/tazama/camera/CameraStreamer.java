package com.jryolsn.tazama.camera;

import android.annotation.SuppressLint;
import android.content.Context;
import android.graphics.Rect;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCaptureSession;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraDevice;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CaptureRequest;
import android.hardware.camera2.params.StreamConfigurationMap;
import android.media.MediaCodec;
import android.media.MediaCodecInfo;
import android.media.MediaFormat;
import android.os.Build;
import android.os.Handler;
import android.util.Log;
import android.util.Range;
import android.util.Rational;
import android.util.Size;
import android.view.Surface;

import java.nio.ByteBuffer;
import java.util.Collections;
import java.util.Locale;

/**
 * Camera2 -> hardware H.264 encoder. All public methods run on the camera handler thread;
 * encoded packets are handed to the sink from a separate drain thread.
 */
final class CameraStreamer {
    private static final String TAG = "TazamaCamera";

    interface Sink {
        void format(int width, int height);

        void state(int rotation, String facing, boolean torch, boolean hasTorch, float zoom, float maxZoom,
                   int exposure, String size, int fps);

        void video(int flags, long ptsUs, ByteBuffer data, int offset, int size);

        void error(String message);
    }

    private final Context context;
    private final Handler handler;

    // Settings (the TV changes them with SET messages).
    private String facing = "back";
    private int width = 1920, height = 1080, fps = 30, bitrate = 8_000_000;
    private float zoom = 1f;
    private boolean torch;
    private int exposure; // EV steps, -2..2
    private String rotationMode = "auto";
    private boolean stabilization;
    private boolean focusFar;
    private int deviceRotation;

    private Sink sink;
    private boolean running;
    private CameraDevice camera;
    private CameraCaptureSession session;
    private MediaCodec encoder;
    private Surface encoderSurface;
    private Thread drainThread;
    private volatile boolean draining;

    private CameraCharacteristics chars;
    private int sensorOrientation;
    private boolean front, hasTorch;
    private float minZoom = 1f, maxZoom = 1f;
    private Range<Integer> fpsRange = new Range<>(30, 30);
    private int actualWidth, actualHeight;
    private int generation;

    CameraStreamer(Context context, Handler handler) {
        this.context = context;
        this.handler = handler;
    }

    void start(Sink s) {
        sink = s;
        running = true;
        open();
    }

    void stop(Sink s) {
        if (sink != s) return; // a newer connection already took over
        running = false;
        close();
        sink = null;
        torch = false;
    }

    void setDeviceRotation(int degrees) {
        if (degrees == deviceRotation) return;
        deviceRotation = degrees;
        if (running && "auto".equals(rotationMode)) sendState();
    }

    void set(String key, String value) {
        try {
            switch (key) {
                case "facing" -> {
                    facing = "next".equals(value) ? ("back".equals(facing) ? "front" : "back") : value;
                    zoom = 1f;
                    torch = false;
                    restart();
                }
                case "size" -> {
                    String[] p = value.toLowerCase(Locale.ROOT).split("x");
                    width = Integer.parseInt(p[0]);
                    height = Integer.parseInt(p[1]);
                    restart();
                }
                case "fps" -> {
                    fps = Integer.parseInt(value);
                    restart();
                }
                case "bitrate" -> {
                    bitrate = Integer.parseInt(value);
                    restart();
                }
                case "zoom" -> {
                    if ("in".equals(value)) zoom *= 1.25f;
                    else if ("out".equals(value)) zoom /= 1.25f;
                    else zoom = Float.parseFloat(value);
                    if (Math.abs(zoom - 1f) < 0.05f) zoom = 1f;
                    // Before the camera is open the range is unknown; open() clamps it.
                    if (chars != null) zoom = Math.max(minZoom, Math.min(maxZoom, zoom));
                    updateRequest();
                }
                case "torch" -> {
                    torch = "toggle".equals(value) ? !torch : "on".equals(value);
                    updateRequest();
                }
                case "exposure" -> {
                    if ("up".equals(value)) exposure++;
                    else if ("down".equals(value)) exposure--;
                    else exposure = Integer.parseInt(value);
                    exposure = Math.max(-2, Math.min(2, exposure));
                    updateRequest();
                }
                case "stabilization" -> {
                    stabilization = "on".equals(value);
                    updateRequest();
                }
                case "focus" -> {
                    focusFar = "far".equals(value);
                    updateRequest();
                }
                case "rotation" -> {
                    rotationMode = value;
                    if (running) sendState();
                }
                default -> Log.w(TAG, "unknown setting " + key);
            }
        } catch (RuntimeException e) {
            Log.w(TAG, "bad setting " + key + "=" + value, e);
        }
    }

    private void restart() {
        if (!running) return;
        close();
        open();
    }

    @SuppressLint("MissingPermission")
    private void open() {
        final int gen = ++generation;
        try {
            CameraManager cm = context.getSystemService(CameraManager.class);
            String id = pickCamera(cm);
            if (id == null) {
                if (sink != null) sink.error("No " + facing + " camera on this phone.");
                return;
            }
            chars = cm.getCameraCharacteristics(id);
            Integer so = chars.get(CameraCharacteristics.SENSOR_ORIENTATION);
            sensorOrientation = so == null ? 90 : so;
            Integer lf = chars.get(CameraCharacteristics.LENS_FACING);
            front = lf != null && lf == CameraCharacteristics.LENS_FACING_FRONT;
            Boolean flash = chars.get(CameraCharacteristics.FLASH_INFO_AVAILABLE);
            hasTorch = flash != null && flash;
            readZoomRange();
            Size size = pickSize();
            actualWidth = size.getWidth();
            actualHeight = size.getHeight();
            fpsRange = pickFpsRange();

            startEncoder();
            if (sink != null) sink.format(actualWidth, actualHeight);
            sendState();

            cm.openCamera(id, new CameraDevice.StateCallback() {
                @Override
                public void onOpened(CameraDevice device) {
                    if (gen != generation || !running) {
                        device.close();
                        return;
                    }
                    camera = device;
                    createSession(gen);
                }

                @Override
                public void onDisconnected(CameraDevice device) {
                    device.close();
                    lost(gen, null);
                }

                @Override
                public void onError(CameraDevice device, int error) {
                    device.close();
                    lost(gen, "Camera error " + error);
                }
            }, handler);
        } catch (CameraAccessException | SecurityException | IllegalArgumentException | IllegalStateException e) {
            Log.w(TAG, "open failed", e);
            close();
            if (sink != null) sink.error("Could not open the camera: " + e.getMessage());
            retryLater();
        } catch (Exception e) {
            Log.w(TAG, "open failed", e);
            close();
            if (sink != null) sink.error("Could not start the video encoder: " + e.getMessage());
        }
    }

    /** Another app (e.g. face unlock) took the camera: try again shortly while the TV is still watching. */
    private void lost(int gen, String message) {
        if (gen != generation) return;
        Log.w(TAG, "camera lost" + (message == null ? "" : ": " + message));
        camera = null;
        session = null;
        if (!running) return;
        close();
        retryLater();
    }

    private void retryLater() {
        final int gen = generation;
        handler.postDelayed(() -> {
            if (running && gen == generation && camera == null) open();
        }, 800);
    }

    private String pickCamera(CameraManager cm) throws CameraAccessException {
        int want = "front".equals(facing) ? CameraCharacteristics.LENS_FACING_FRONT : CameraCharacteristics.LENS_FACING_BACK;
        for (String id : cm.getCameraIdList()) {
            Integer lf = cm.getCameraCharacteristics(id).get(CameraCharacteristics.LENS_FACING);
            if (lf != null && lf == want) return id; // the first one is the main camera
        }
        return null;
    }

    private void readZoomRange() {
        minZoom = 1f;
        maxZoom = 1f;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Range<Float> r = chars.get(CameraCharacteristics.CONTROL_ZOOM_RATIO_RANGE);
            if (r != null) {
                minZoom = r.getLower();
                maxZoom = r.getUpper();
            }
        } else {
            Float max = chars.get(CameraCharacteristics.SCALER_AVAILABLE_MAX_DIGITAL_ZOOM);
            if (max != null) maxZoom = max;
        }
        maxZoom = Math.min(maxZoom, 10f);
        zoom = Math.max(minZoom, Math.min(maxZoom, zoom));
    }

    private Size pickSize() {
        StreamConfigurationMap map = chars.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP);
        Size[] sizes = map == null ? null : map.getOutputSizes(MediaCodec.class);
        if (sizes == null || sizes.length == 0) return new Size(1280, 720);
        Size best = null;
        for (Size s : sizes) {
            if (s.getWidth() == width && s.getHeight() == height) return s;
            boolean fits = s.getWidth() <= width && s.getHeight() <= height;
            boolean wide = Math.abs(s.getWidth() * 9 - s.getHeight() * 16) <= s.getHeight();
            if (fits && wide && (best == null || s.getWidth() * s.getHeight() > best.getWidth() * best.getHeight())) {
                best = s;
            }
        }
        if (best != null) return best;
        for (Size s : sizes) {
            if (s.getWidth() <= width && s.getHeight() <= height
                    && (best == null || s.getWidth() * s.getHeight() > best.getWidth() * best.getHeight())) {
                best = s;
            }
        }
        return best != null ? best : sizes[sizes.length - 1];
    }

    private Range<Integer> pickFpsRange() {
        Range<Integer>[] ranges = chars.get(CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES);
        if (ranges == null || ranges.length == 0) return new Range<>(30, 30);
        Range<Integer> best = null;
        for (Range<Integer> r : ranges) {
            if (r.getUpper() > fps) continue;
            // Prefer the highest frame rate, then a fixed range (steadier latency).
            if (best == null || r.getUpper() > best.getUpper()
                    || (r.getUpper().equals(best.getUpper()) && r.getLower() > best.getLower())) {
                best = r;
            }
        }
        return best != null ? best : ranges[0];
    }

    private void startEncoder() throws Exception {
        encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC);
        try {
            encoder.configure(encoderFormat(true), null, null, MediaCodec.CONFIGURE_FLAG_ENCODE);
        } catch (Exception lowLatencyKeysRejected) {
            encoder.reset();
            encoder.configure(encoderFormat(false), null, null, MediaCodec.CONFIGURE_FLAG_ENCODE);
        }
        encoderSurface = encoder.createInputSurface();
        encoder.start();
        final MediaCodec enc = encoder;
        draining = true;
        drainThread = new Thread(() -> drain(enc), "TazamaCameraEncoder");
        drainThread.start();
    }

    private MediaFormat encoderFormat(boolean lowLatency) {
        MediaFormat f = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, actualWidth, actualHeight);
        f.setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface);
        f.setInteger(MediaFormat.KEY_BIT_RATE, bitrate);
        f.setInteger(MediaFormat.KEY_FRAME_RATE, fpsRange.getUpper());
        f.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 2);
        // Keeps frames coming when the picture is still, so the TV never waits on an old frame.
        f.setLong(MediaFormat.KEY_REPEAT_PREVIOUS_FRAME_AFTER, 100_000);
        if (lowLatency) {
            f.setInteger(MediaFormat.KEY_PRIORITY, 0);
            f.setInteger(MediaFormat.KEY_LATENCY, 1);
            f.setInteger(MediaFormat.KEY_MAX_B_FRAMES, 0);
            f.setInteger(MediaFormat.KEY_PREPEND_HEADER_TO_SYNC_FRAMES, 1);
        }
        return f;
    }

    private void drain(MediaCodec enc) {
        MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
        while (draining) {
            int index;
            try {
                index = enc.dequeueOutputBuffer(info, 100_000);
            } catch (IllegalStateException e) {
                return;
            }
            if (index < 0) continue;
            try {
                ByteBuffer buffer = enc.getOutputBuffer(index);
                Sink s = sink;
                if (buffer != null && info.size > 0 && s != null && draining) {
                    int flags = 0;
                    if ((info.flags & MediaCodec.BUFFER_FLAG_CODEC_CONFIG) != 0) flags |= Protocol.FLAG_CONFIG;
                    if ((info.flags & MediaCodec.BUFFER_FLAG_KEY_FRAME) != 0) flags |= Protocol.FLAG_KEY;
                    s.video(flags, info.presentationTimeUs, buffer, info.offset, info.size);
                }
                enc.releaseOutputBuffer(index, false);
            } catch (IllegalStateException e) {
                return;
            }
        }
    }

    @SuppressWarnings("deprecation")
    private void createSession(int gen) {
        try {
            camera.createCaptureSession(Collections.singletonList(encoderSurface), new CameraCaptureSession.StateCallback() {
                @Override
                public void onConfigured(CameraCaptureSession s) {
                    if (gen != generation) {
                        s.close();
                        return;
                    }
                    session = s;
                    updateRequest();
                }

                @Override
                public void onConfigureFailed(CameraCaptureSession s) {
                    if (gen == generation && sink != null) sink.error("The camera refused this quality setting.");
                }
            }, handler);
        } catch (CameraAccessException | IllegalStateException e) {
            lost(gen, e.getMessage());
        }
    }

    private void updateRequest() {
        if (running) sendState();
        if (session == null || camera == null) return;
        try {
            CaptureRequest.Builder b = camera.createCaptureRequest(CameraDevice.TEMPLATE_RECORD);
            b.addTarget(encoderSurface);
            b.set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, fpsRange);
            int[] afModes = chars.get(CameraCharacteristics.CONTROL_AF_AVAILABLE_MODES);
            Float minFocus = chars.get(CameraCharacteristics.LENS_INFO_MINIMUM_FOCUS_DISTANCE);
            if (focusFar && minFocus != null && minFocus > 0) {
                b.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_OFF);
                b.set(CaptureRequest.LENS_FOCUS_DISTANCE, 0f); // infinity
            } else if (afModes != null) {
                for (int m : afModes) {
                    if (m == CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_VIDEO) {
                        b.set(CaptureRequest.CONTROL_AF_MODE, m);
                        break;
                    }
                }
            }
            // Electronic stabilization buffers frames, so it is off unless asked for.
            b.set(CaptureRequest.CONTROL_VIDEO_STABILIZATION_MODE, stabilization
                    ? CaptureRequest.CONTROL_VIDEO_STABILIZATION_MODE_ON : CaptureRequest.CONTROL_VIDEO_STABILIZATION_MODE_OFF);
            b.set(CaptureRequest.FLASH_MODE, torch && hasTorch ? CaptureRequest.FLASH_MODE_TORCH : CaptureRequest.FLASH_MODE_OFF);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                b.set(CaptureRequest.CONTROL_ZOOM_RATIO, zoom);
            } else {
                Rect active = chars.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE);
                if (active != null) {
                    int cw = Math.round(active.width() / zoom), ch = Math.round(active.height() / zoom);
                    int l = (active.width() - cw) / 2, t = (active.height() - ch) / 2;
                    b.set(CaptureRequest.SCALER_CROP_REGION, new Rect(l, t, l + cw, t + ch));
                }
            }
            Rational step = chars.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_STEP);
            Range<Integer> range = chars.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_RANGE);
            if (step != null && range != null && step.floatValue() > 0) {
                int idx = Math.round(exposure / step.floatValue());
                b.set(CaptureRequest.CONTROL_AE_EXPOSURE_COMPENSATION, Math.max(range.getLower(), Math.min(range.getUpper(), idx)));
            }
            session.setRepeatingRequest(b.build(), null, handler);
        } catch (CameraAccessException | IllegalStateException e) {
            Log.w(TAG, "request failed", e);
        }
    }

    private int rotation() {
        if (!"auto".equals(rotationMode)) {
            try {
                return Integer.parseInt(rotationMode);
            } catch (NumberFormatException ignored) {
            }
        }
        int dev = front ? -deviceRotation : deviceRotation;
        return ((sensorOrientation + dev) % 360 + 360) % 360;
    }

    private void sendState() {
        Sink s = sink;
        if (s == null) return;
        s.state(rotation(), facing, torch && hasTorch, hasTorch, zoom, maxZoom, exposure,
                actualWidth + "x" + actualHeight, fpsRange.getUpper());
    }

    private void close() {
        generation++;
        if (session != null) {
            try {
                session.close();
            } catch (Exception ignored) {
            }
            session = null;
        }
        if (camera != null) {
            camera.close();
            camera = null;
        }
        draining = false;
        if (drainThread != null) {
            try {
                drainThread.join(500);
            } catch (InterruptedException ignored) {
            }
            drainThread = null;
        }
        if (encoder != null) {
            try {
                encoder.stop();
            } catch (Exception ignored) {
            }
            encoder.release();
            encoder = null;
        }
        if (encoderSurface != null) {
            encoderSurface.release();
            encoderSurface = null;
        }
    }
}

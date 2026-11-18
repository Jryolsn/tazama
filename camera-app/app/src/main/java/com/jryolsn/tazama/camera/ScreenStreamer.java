package com.jryolsn.tazama.camera;

import android.content.Context;
import android.hardware.display.DisplayManager;
import android.hardware.display.VirtualDisplay;
import android.media.MediaCodec;
import android.media.MediaCodecInfo;
import android.media.MediaFormat;
import android.media.projection.MediaProjection;
import android.os.Handler;
import android.util.DisplayMetrics;
import android.util.Log;
import android.view.Surface;

import java.nio.ByteBuffer;

/**
 * MediaProjection -> hardware H.264 encoder, same wire format as the camera.
 * Public methods run on the camera handler thread. With Android 14+ the system dialog
 * lets the user share a single app instead of the whole screen.
 */
final class ScreenStreamer {
    private static final String TAG = "TazamaCamera";
    private static final int LONG_SIDE = 1920;
    private static final int FPS = 30;

    private final Context context;
    private final MediaProjection projection;
    private final DisplayManager displays;
    private final Handler handler;

    private CameraStreamer.Sink sink;
    private VirtualDisplay display;
    private MediaCodec encoder;
    private Surface surface;
    private Thread drainThread;
    private volatile boolean draining;
    private int width, height;
    private final DisplayManager.DisplayListener listener = new DisplayManager.DisplayListener() {
        @Override
        public void onDisplayAdded(int id) {
        }

        @Override
        public void onDisplayRemoved(int id) {
        }

        @Override
        public void onDisplayChanged(int id) {
            if (id != android.view.Display.DEFAULT_DISPLAY || sink == null) return;
            int[] size = captureSize();
            if (size[0] != width || size[1] != height) restart();
        }
    };

    ScreenStreamer(Context context, MediaProjection projection, Handler handler) {
        this.context = context;
        this.handler = handler;
        this.projection = projection;
        this.displays = context.getSystemService(DisplayManager.class);
    }

    void start(CameraStreamer.Sink s) {
        sink = s;
        displays.registerDisplayListener(listener, handler);
        open();
    }

    void stop(CameraStreamer.Sink s) {
        if (sink != s) return;
        displays.unregisterDisplayListener(listener);
        close();
        sink = null;
    }

    void release() {
        if (sink != null) stop(sink);
        if (display != null) display.release();
        display = null;
        projection.stop();
    }

    private void restart() {
        close();
        open();
    }

    private int[] captureSize() {
        DisplayMetrics m = context.getResources().getDisplayMetrics();
        float scale = Math.min(1f, (float) LONG_SIDE / Math.max(m.widthPixels, m.heightPixels));
        int w = Math.max(2, Math.round(m.widthPixels * scale) & ~1);
        int h = Math.max(2, Math.round(m.heightPixels * scale) & ~1);
        return new int[]{w, h, m.densityDpi};
    }

    private void open() {
        try {
            int[] size = captureSize();
            width = size[0];
            height = size[1];
            encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC);
            try {
                encoder.configure(format(true), null, null, MediaCodec.CONFIGURE_FLAG_ENCODE);
            } catch (Exception rejected) {
                encoder.reset();
                encoder.configure(format(false), null, null, MediaCodec.CONFIGURE_FLAG_ENCODE);
            }
            surface = encoder.createInputSurface();
            encoder.start();
            final MediaCodec enc = encoder;
            draining = true;
            drainThread = new Thread(() -> drain(enc), "TazamaScreenEncoder");
            drainThread.start();
            if (sink != null) {
                sink.format(width, height);
                sink.state(0, "screen", false, false, 1f, 1f, 0, width + "x" + height, FPS);
            }
            // Android 14+ allows one virtual display per projection, so it is reused across restarts.
            if (display == null) {
                display = projection.createVirtualDisplay("TazamaCast", width, height, size[2],
                        DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR, surface, null, null);
            } else {
                display.resize(width, height, size[2]);
                display.setSurface(surface);
            }
        } catch (Exception e) {
            Log.w(TAG, "screen capture failed", e);
            close();
            if (sink != null) sink.error("Screen capture failed: " + e.getMessage());
        }
    }

    private MediaFormat format(boolean lowLatency) {
        MediaFormat f = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height);
        f.setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface);
        f.setInteger(MediaFormat.KEY_BIT_RATE, 8_000_000);
        f.setInteger(MediaFormat.KEY_FRAME_RATE, FPS);
        f.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 2);
        // A still screen produces no frames, so repeat the last one.
        f.setLong(MediaFormat.KEY_REPEAT_PREVIOUS_FRAME_AFTER, 200_000);
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
                CameraStreamer.Sink s = sink;
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

    private void close() {
        if (display != null) display.setSurface(null);
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
        if (surface != null) {
            surface.release();
            surface = null;
        }
    }
}

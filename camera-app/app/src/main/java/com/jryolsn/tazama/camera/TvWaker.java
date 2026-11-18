package com.jryolsn.tazama.camera;

import android.content.Context;
import android.net.nsd.NsdManager;
import android.net.nsd.NsdServiceInfo;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.util.concurrent.atomic.AtomicBoolean;

/** Finds a paired TV on the network and asks it to open Phone camera. */
final class TvWaker {
    private static final String TAG = "TazamaLink";
    private static final String TV_SERVICE = "_tazamatv._tcp";

    interface Result {
        void done(boolean ok, String message);
    }

    private TvWaker() {
    }

    static void wake(Context context, PairingStore store, String tvId, Result result) {
        Handler main = new Handler(Looper.getMainLooper());
        AtomicBoolean finished = new AtomicBoolean();
        NsdManager nsd = context.getSystemService(NsdManager.class);
        final NsdManager.DiscoveryListener[] listener = new NsdManager.DiscoveryListener[1];
        java.util.function.BiConsumer<Boolean, String> end = (ok, msg) -> {
            if (!finished.compareAndSet(false, true)) return;
            try {
                nsd.stopServiceDiscovery(listener[0]);
            } catch (Exception ignored) {
            }
            main.post(() -> result.done(ok, msg));
        };
        String wanted = "TazamaTV-" + tvId;
        listener[0] = new NsdManager.DiscoveryListener() {
            @Override
            public void onStartDiscoveryFailed(String t, int e) {
                end.accept(false, "Could not search the network.");
            }

            @Override
            public void onStopDiscoveryFailed(String t, int e) {
            }

            @Override
            public void onDiscoveryStarted(String t) {
            }

            @Override
            public void onDiscoveryStopped(String t) {
            }

            @Override
            public void onServiceLost(NsdServiceInfo i) {
            }

            @Override
            public void onServiceFound(NsdServiceInfo info) {
                if (!wanted.equals(info.getServiceName())) return;
                nsd.resolveService(info, new NsdManager.ResolveListener() {
                    @Override
                    public void onResolveFailed(NsdServiceInfo i, int e) {
                        end.accept(false, "Could not reach the TV.");
                    }

                    @Override
                    public void onServiceResolved(NsdServiceInfo i) {
                        new Thread(() -> {
                            boolean ok = send(store, tvId, i.getHost().getHostAddress(), i.getPort());
                            end.accept(ok, ok ? "Opening on the TV" : "The TV did not accept it.");
                        }, "TazamaWake").start();
                    }
                });
            }
        };
        nsd.discoverServices(TV_SERVICE, NsdManager.PROTOCOL_DNS_SD, listener[0]);
        main.postDelayed(() -> end.accept(false,
                "Could not find the TV. Is it on, on the same Wi-Fi, and showing the Tazama home screen once since it started?"),
                10_000);
    }

    private static boolean send(PairingStore store, String tvId, String host, int port) {
        byte[] key = store.keyFor(tvId);
        if (key == null) return false;
        try (Socket s = new Socket()) {
            s.connect(new InetSocketAddress(host, port), 4000);
            s.setSoTimeout(5000);
            DataInputStream in = new DataInputStream(s.getInputStream());
            DataOutputStream out = new DataOutputStream(s.getOutputStream());
            byte[] magic = new byte[4];
            in.readFully(magic);
            byte[] nonce = new byte[16];
            in.readFully(nonce);
            out.writeUTF(store.phoneId());
            out.write(Protocol.mac(key, nonce, tvId));
            out.flush();
            return in.readUnsignedByte() == 0;
        } catch (Exception e) {
            Log.w(TAG, "wake failed", e);
            return false;
        }
    }
}

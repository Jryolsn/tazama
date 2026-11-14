package com.jryolsn.tazama.camera;

import android.content.Context;
import android.content.SharedPreferences;
import android.net.Uri;
import android.util.Base64;

import java.security.SecureRandom;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/** TVs this phone accepts, plus the short-lived code for pairing without the QR code. */
final class PairingStore {
    private static final long CODE_VALID_MS = 3 * 60 * 1000;
    private final SharedPreferences prefs;

    PairingStore(Context context) {
        prefs = context.getSharedPreferences("pairing", Context.MODE_PRIVATE);
    }

    String phoneId() {
        String id = prefs.getString("phone_id", null);
        if (id == null) {
            byte[] b = new byte[8];
            new SecureRandom().nextBytes(b);
            StringBuilder sb = new StringBuilder();
            for (byte x : b) sb.append(String.format("%02x", x));
            id = sb.toString();
            prefs.edit().putString("phone_id", id).apply();
        }
        return id;
    }

    byte[] keyFor(String tvId) {
        String k = prefs.getString("key." + tvId, null);
        return k == null ? null : Base64.decode(k, Base64.NO_WRAP);
    }

    synchronized void save(String tvId, String name, byte[] key) {
        Set<String> ids = new HashSet<>(prefs.getStringSet("ids", new HashSet<>()));
        ids.add(tvId);
        prefs.edit()
                .putStringSet("ids", ids)
                .putString("key." + tvId, Base64.encodeToString(key, Base64.NO_WRAP))
                .putString("name." + tvId, name)
                .apply();
    }

    synchronized void remove(String tvId) {
        Set<String> ids = new HashSet<>(prefs.getStringSet("ids", new HashSet<>()));
        ids.remove(tvId);
        prefs.edit().putStringSet("ids", ids).remove("key." + tvId).remove("name." + tvId).apply();
    }

    /** id, name pairs. */
    List<String[]> list() {
        List<String[]> out = new ArrayList<>();
        for (String id : prefs.getStringSet("ids", new HashSet<>())) {
            out.add(new String[]{id, prefs.getString("name." + id, "TV")});
        }
        return out;
    }

    void setPendingCode(String code) {
        prefs.edit().putString("code", code).putLong("code_at", System.currentTimeMillis()).apply();
    }

    String pendingCode() {
        String code = prefs.getString("code", null);
        long at = prefs.getLong("code_at", 0);
        return code != null && System.currentTimeMillis() - at < CODE_VALID_MS ? code : null;
    }

    void clearPendingCode() {
        prefs.edit().remove("code").remove("code_at").apply();
    }

    /** Parses tazamacam://pair?v=1&id=..&k=..&n=.. and saves it. Returns the TV name, or null. */
    String pairFromQr(String text) {
        if (text == null) return null;
        Uri uri = Uri.parse(text.trim());
        if (!"tazamacam".equals(uri.getScheme()) || !"pair".equals(uri.getHost())) return null;
        String id = uri.getQueryParameter("id");
        String k = uri.getQueryParameter("k");
        String name = uri.getQueryParameter("n");
        if (id == null || k == null) return null;
        byte[] key;
        try {
            key = Base64.decode(k, Base64.URL_SAFE | Base64.NO_WRAP | Base64.NO_PADDING);
        } catch (IllegalArgumentException e) {
            return null;
        }
        if (key.length < 16) return null;
        if (name == null || name.isEmpty()) name = "TV";
        save(id, name, key);
        return name;
    }
}

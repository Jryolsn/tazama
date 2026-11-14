package com.jryolsn.tazama.camera;

import java.nio.charset.StandardCharsets;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

/** Wire protocol shared with the TV (Tazama PhoneCameraActivity). See camera-app/PROTOCOL.md. */
final class Protocol {
    static final int PORT = 47800;
    static final String SERVICE_TYPE = "_tazamacam._tcp";
    static final byte[] MAGIC = {'T', 'Z', 'C', '1'};

    static final int MODE_AUTH = 1;
    static final int MODE_PAIR_CODE = 2;
    static final int RESULT_OK = 0;
    static final int RESULT_DENIED = 1;

    // TV -> phone
    static final int T_SET = 1;
    static final int T_START = 2;
    static final int T_PING = 3;

    // phone -> TV
    static final int P_FORMAT = 1;
    static final int P_STATE = 2;
    static final int P_VIDEO = 3;
    static final int P_ERROR = 4;

    static final int FLAG_CONFIG = 1;
    static final int FLAG_KEY = 2;

    private Protocol() {
    }

    static byte[] mac(byte[] secret, byte[] nonce, String tvId) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret, "HmacSHA256"));
            mac.update(nonce);
            mac.update(tvId.getBytes(StandardCharsets.UTF_8));
            return mac.doFinal();
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }
}

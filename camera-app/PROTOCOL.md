# Phone camera protocol

Phone (Tazama Camera) listens on TCP 47800 and advertises `_tazamacam._tcp` (TXT `id` = phone id).
The TV (Tazama `PhoneCameraActivity`) connects. Big-endian, strings are Java `writeUTF`.

## Handshake
1. Phone: `"TZC1"`, nonce[16], phoneId, phoneName.
2. TV: mode byte, tvId, tvName, mac[32].
   - mode 1 (auth): `mac = HMAC-SHA256(tvKey, nonce || tvId)`. The phone knows `tvKey` from the TV's QR code
     `tazamacam://pair?v=1&id=<tvId>&k=<base64url tvKey>&n=<tvName>`.
   - mode 2 (code): `mac = HMAC-SHA256(code, nonce || tvId)`, then tvKey[32]. Accepted only while a code the
     user typed on the phone is pending (3 minutes); the phone then stores tvKey.
3. Phone: result byte (0 ok, 1 denied).

## Messages
After the handshake both sides send `type byte, length int, payload`.

TV to phone:
- 1 SET: key, value. Keys: `facing` (back, front, next), `size` (WxH), `fps`, `bitrate`, `zoom` (in, out, ratio),
  `torch` (on, off, toggle), `exposure` (up, down, -2..2 EV), `rotation` (auto, 0, 90, 180, 270).
- 2 START: open the camera and stream.

Phone to TV:
- 1 FORMAT: width int, height int (configure the decoder).
- 2 STATE: rotation int, facing, torch bool, hasTorch bool, zoom float, maxZoom float, exposure int, size, fps int.
- 3 VIDEO: flags byte (1 config, 2 key frame), ptsUs long, H.264 Annex B data.
- 4 ERROR: message.

Closing the socket stops the camera.

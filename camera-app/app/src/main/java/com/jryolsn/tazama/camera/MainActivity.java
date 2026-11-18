package com.jryolsn.tazama.camera;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.media.projection.MediaProjectionManager;
import android.graphics.Typeface;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.PowerManager;
import android.provider.Settings;
import android.text.InputType;
import android.view.Gravity;
import android.view.View;
import android.view.WindowInsets;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import com.google.mlkit.vision.barcode.common.Barcode;
import com.google.mlkit.vision.codescanner.GmsBarcodeScannerOptions;
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning;

import java.util.ArrayList;
import java.util.List;

public class MainActivity extends Activity {
    private static final int REQ_PERMISSIONS = 1;
    private static final int REQ_CAST = 2;

    private PairingStore store;
    private TextView status;
    private Button power;
    private Button stream;
    private Button cast;
    private String pendingTv;
    private Button battery;
    private LinearLayout paired;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        store = new PairingStore(this);

        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        int pad = dp(20);
        col.setPadding(pad, pad, pad, pad);

        TextView title = new TextView(this);
        title.setText("Tazama Link");
        title.setTextSize(26);
        title.setTypeface(Typeface.DEFAULT_BOLD);
        col.addView(title);

        status = new TextView(this);
        status.setTextSize(17);
        status.setPadding(0, dp(8), 0, dp(16));
        col.addView(status);

        power = button("Turn off", v -> togglePower());
        col.addView(power);

        col.addView(section("Send to TV"));
        col.addView(button("Show camera on TV", v -> pickTv(tv -> showOnTv(tv, false))));
        col.addView(button("Cast phone screen to TV", v -> pickTv(tv -> {
            pendingTv = tv;
            startActivityForResult(getSystemService(MediaProjectionManager.class).createScreenCaptureIntent(),
                    REQ_CAST);
        })));
        col.addView(text("The TV opens by itself. Stopping and casting are below."));
        col.addView(section("Control"));
        stream = button("Stop streaming", v -> {
            startService(new Intent(this, CameraService.class)
                    .setAction(CameraService.paused ? CameraService.ACTION_RESUME : CameraService.ACTION_PAUSE));
            status.postDelayed(this::refresh, 300);
        });
        col.addView(stream);
        cast = button("Stop casting", v -> toggleCast());
        col.addView(cast);
        col.addView(text("Casting asks what to share; on Android 14+ you can pick a single app."));

        col.addView(section("Pair with a TV"));
        TextView how = text("On the TV, open Phone camera in Tazama (quick panel or app list). It shows a QR code.");
        col.addView(how);
        col.addView(button("Scan TV code", v -> scan()));
        col.addView(button("Enter code instead", v -> enterCode()));

        col.addView(section("Paired TVs"));
        paired = new LinearLayout(this);
        paired.setOrientation(LinearLayout.VERTICAL);
        col.addView(paired);

        col.addView(section("Tips"));
        battery = button("Allow running in the background", v -> askBattery());
        col.addView(battery);
        col.addView(text("After the phone restarts, open this app once so the TV can reach it. "
                + "Face unlock uses the camera when the phone wakes; the stream pauses for a moment and comes back."));

        ScrollView scroll = new ScrollView(this);
        scroll.addView(col);
        scroll.setOnApplyWindowInsetsListener((v, insets) -> {
            android.graphics.Insets bars = insets.getInsets(WindowInsets.Type.systemBars());
            v.setPadding(bars.left, bars.top, bars.right, bars.bottom);
            return insets;
        });
        setContentView(scroll);

        if (hasPermissions()) startCameraService();
        else requestPermissions(permissions(), REQ_PERMISSIONS);
    }

    @Override
    protected void onResume() {
        super.onResume();
        CameraService.uiListener = this::refresh;
        refresh();
    }

    @Override
    protected void onPause() {
        super.onPause();
        CameraService.uiListener = null;
    }

    private String[] permissions() {
        List<String> p = new ArrayList<>();
        p.add(Manifest.permission.CAMERA);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) p.add(Manifest.permission.POST_NOTIFICATIONS);
        return p.toArray(new String[0]);
    }

    private boolean hasPermissions() {
        return checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED;
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] perms, int[] results) {
        if (hasPermissions()) startCameraService();
        refresh();
    }

    private void startCameraService() {
        startForegroundService(new Intent(this, CameraService.class));
        status.postDelayed(this::refresh, 300);
    }

    private void toggleCast() {
        if (CameraService.casting) {
            startService(new Intent(this, CameraService.class).setAction(CameraService.ACTION_STOP_CAST));
            status.postDelayed(this::refresh, 300);
        }
    }

    private interface TvChoice {
        void chosen(String tvId);
    }

    private void pickTv(TvChoice choice) {
        if (!hasPermissions()) {
            requestPermissions(permissions(), REQ_PERMISSIONS);
            return;
        }
        if (!CameraService.running) startCameraService();
        List<String[]> tvs = store.list();
        if (tvs.isEmpty()) {
            Toast.makeText(this, "Pair with a TV first.", Toast.LENGTH_LONG).show();
        } else if (tvs.size() == 1) {
            choice.chosen(tvs.get(0)[0]);
        } else {
            String[] names = new String[tvs.size()];
            for (int i = 0; i < names.length; i++) names[i] = tvs.get(i)[1];
            new AlertDialog.Builder(this).setTitle("Which TV?")
                    .setItems(names, (d, i) -> choice.chosen(tvs.get(i)[0])).show();
        }
    }

    /** Wakes the TV; the TV then connects here and asks for video. */
    private void showOnTv(String tvId, boolean cast) {
        if (!cast) {
            startService(new Intent(this, CameraService.class).setAction(CameraService.ACTION_SHOW_CAMERA));
        }
        Toast.makeText(this, "Looking for the TV…", Toast.LENGTH_SHORT).show();
        TvWaker.wake(this, store, tvId, (ok, msg) -> {
            Toast.makeText(this, msg, Toast.LENGTH_LONG).show();
            refresh();
        });
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == REQ_CAST && resultCode == RESULT_OK && data != null) {
            startService(new Intent(this, CameraService.class).setAction(CameraService.ACTION_CAST)
                    .putExtra("code", resultCode).putExtra("data", data));
            status.postDelayed(this::refresh, 500);
            if (pendingTv != null) showOnTv(pendingTv, true);
        }
        pendingTv = null;
    }

    private void togglePower() {
        if (CameraService.running) {
            startService(new Intent(this, CameraService.class).setAction(CameraService.ACTION_STOP));
        } else if (hasPermissions()) {
            startCameraService();
        } else {
            requestPermissions(permissions(), REQ_PERMISSIONS);
        }
        status.postDelayed(this::refresh, 300);
    }

    private void refresh() {
        if (!hasPermissions()) {
            status.setText("Camera permission is needed to stream to the TV.");
        } else if (CameraService.running) {
            status.setText(CameraService.status.isEmpty() ? "Ready for the TV" : CameraService.status);
        } else {
            status.setText("Off. The TV can't reach the phone.");
        }
        power.setText(CameraService.running ? "Turn off" : "Turn on");
        stream.setEnabled(CameraService.running);
        stream.setText(CameraService.paused ? "Start streaming" : "Stop streaming");
        cast.setEnabled(CameraService.running && CameraService.casting);

        PowerManager pm = getSystemService(PowerManager.class);
        battery.setVisibility(pm.isIgnoringBatteryOptimizations(getPackageName()) ? View.GONE : View.VISIBLE);

        paired.removeAllViews();
        List<String[]> tvs = store.list();
        if (tvs.isEmpty()) paired.addView(text("None yet."));
        for (String[] tv : tvs) {
            LinearLayout row = new LinearLayout(this);
            row.setGravity(Gravity.CENTER_VERTICAL);
            TextView name = text(tv[1]);
            row.addView(name, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1));
            row.addView(button("Remove", v -> {
                store.remove(tv[0]);
                refresh();
            }));
            paired.addView(row);
        }
    }

    private void scan() {
        GmsBarcodeScannerOptions options = new GmsBarcodeScannerOptions.Builder()
                .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
                .build();
        GmsBarcodeScanning.getClient(this, options).startScan()
                .addOnSuccessListener(barcode -> onScanned(barcode.getRawValue()))
                .addOnFailureListener(e -> Toast.makeText(this,
                        "The scanner could not start (" + e.getMessage() + "). Use \"Enter code instead\".",
                        Toast.LENGTH_LONG).show());
    }

    private void onScanned(String text) {
        if (text == null) return;
        String tv = store.pairFromQr(text);
        Toast.makeText(this, tv == null ? "That is not a Tazama TV code." : "Paired with " + tv, Toast.LENGTH_LONG).show();
        if (tv != null && !CameraService.running && hasPermissions()) startCameraService();
        refresh();
    }

    private void enterCode() {
        EditText input = new EditText(this);
        input.setInputType(InputType.TYPE_CLASS_NUMBER);
        input.setHint("6-digit code from the TV");
        new AlertDialog.Builder(this)
                .setTitle("Enter the code shown on the TV")
                .setView(input)
                .setPositiveButton("Pair", (d, w) -> {
                    String code = input.getText().toString().replaceAll("\\D", "");
                    if (code.length() != 6) {
                        Toast.makeText(this, "The code has 6 digits.", Toast.LENGTH_LONG).show();
                        return;
                    }
                    store.setPendingCode(code);
                    if (!CameraService.running && hasPermissions()) startCameraService();
                    Toast.makeText(this, "Done. Keep the TV on the pairing screen; it connects within a few seconds.",
                            Toast.LENGTH_LONG).show();
                })
                .setNegativeButton("Cancel", null)
                .show();
    }

    private void askBattery() {
        try {
            startActivity(new Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                    Uri.parse("package:" + getPackageName())));
        } catch (Exception e) {
            startActivity(new Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS));
        }
    }

    private TextView section(String s) {
        TextView t = new TextView(this);
        t.setText(s);
        t.setTextSize(18);
        t.setTypeface(Typeface.DEFAULT_BOLD);
        t.setPadding(0, dp(24), 0, dp(6));
        return t;
    }

    private TextView text(String s) {
        TextView t = new TextView(this);
        t.setText(s);
        t.setTextSize(15);
        t.setPadding(0, dp(4), 0, dp(4));
        return t;
    }

    private Button button(String label, View.OnClickListener l) {
        Button b = new Button(this);
        b.setText(label);
        b.setAllCaps(false);
        b.setOnClickListener(l);
        return b;
    }

    private int dp(int v) {
        return Math.round(v * getResources().getDisplayMetrics().density);
    }
}

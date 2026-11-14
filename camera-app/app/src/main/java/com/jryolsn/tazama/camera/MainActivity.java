package com.jryolsn.tazama.camera;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.content.pm.PackageManager;
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

import com.google.zxing.integration.android.IntentIntegrator;
import com.google.zxing.integration.android.IntentResult;

import java.util.ArrayList;
import java.util.List;

public class MainActivity extends Activity {
    private static final int REQ_PERMISSIONS = 1;

    private PairingStore store;
    private TextView status;
    private Button power;
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
        title.setText("Tazama Camera");
        title.setTextSize(26);
        title.setTypeface(Typeface.DEFAULT_BOLD);
        col.addView(title);

        status = new TextView(this);
        status.setTextSize(17);
        status.setPadding(0, dp(8), 0, dp(16));
        col.addView(status);

        power = button("Turn off", v -> togglePower());
        col.addView(power);

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
        new IntentIntegrator(this)
                .setDesiredBarcodeFormats(IntentIntegrator.QR_CODE)
                .setPrompt("Scan the QR code on the TV")
                .setBeepEnabled(false)
                .setOrientationLocked(false)
                .initiateScan();
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        IntentResult result = IntentIntegrator.parseActivityResult(requestCode, resultCode, data);
        if (result == null) {
            super.onActivityResult(requestCode, resultCode, data);
            return;
        }
        if (result.getContents() == null) return;
        String tv = store.pairFromQr(result.getContents());
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

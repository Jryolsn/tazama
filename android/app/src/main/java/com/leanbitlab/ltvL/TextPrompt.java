package com.omeda.arc;

import android.app.Activity;
import android.app.AlertDialog;
import android.text.InputType;
import android.text.method.PasswordTransformationMethod;
import android.view.WindowManager;
import android.view.inputmethod.EditorInfo;
import android.widget.EditText;
import android.widget.FrameLayout;

import io.flutter.plugin.common.MethodChannel;

/**
 * Text entry with a native EditText. Flutter text fields keep the D-pad on TV, so the on-screen
 * keyboard can't be reached with the remote; a native field hands it to the keyboard as usual.
 */
final class TextPrompt {
    private TextPrompt() {}

    static void show(Activity activity, String title, String message, String initial, boolean secret,
                     String kind, MethodChannel.Result result) {
        boolean[] answered = {false};
        EditText edit = new EditText(activity);
        edit.setSingleLine(true);
        int type = InputType.TYPE_CLASS_TEXT;
        if (secret) {
            type |= InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD;
        } else if ("url".equals(kind)) {
            type |= InputType.TYPE_TEXT_VARIATION_URI;
        } else {
            type |= InputType.TYPE_TEXT_FLAG_CAP_SENTENCES;
        }
        edit.setInputType(type);
        if (secret) edit.setTransformationMethod(PasswordTransformationMethod.getInstance());
        edit.setImeOptions(EditorInfo.IME_ACTION_DONE | EditorInfo.IME_FLAG_NO_EXTRACT_UI);
        if (initial != null) {
            edit.setText(initial);
            edit.setSelection(initial.length());
        }

        FrameLayout box = new FrameLayout(activity);
        int pad = Math.round(20 * activity.getResources().getDisplayMetrics().density);
        box.setPadding(pad, pad / 2, pad, 0);
        box.addView(edit);

        AlertDialog dialog = new AlertDialog.Builder(activity, android.R.style.Theme_DeviceDefault_Dialog_Alert)
                .setTitle(title)
                .setMessage(message)
                .setView(box)
                .setPositiveButton(android.R.string.ok, (d, w) -> answer(result, answered, edit.getText().toString()))
                .setNegativeButton(android.R.string.cancel, (d, w) -> answer(result, answered, null))
                .setOnDismissListener(d -> answer(result, answered, null))
                .create();
        edit.setOnEditorActionListener((v, actionId, event) -> {
            if (actionId == EditorInfo.IME_ACTION_DONE) {
                answer(result, answered, edit.getText().toString());
                dialog.dismiss();
                return true;
            }
            return false;
        });
        if (dialog.getWindow() != null) {
            dialog.getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE);
        }
        dialog.show();
        edit.requestFocus();
    }

    private static void answer(MethodChannel.Result result, boolean[] answered, String value) {
        if (answered[0]) return;
        answered[0] = true;
        result.success(value);
    }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('me.efesser.flauncher/method');

enum TvTextKind { text, url }

/// Asks for a line of text with a native field, so the TV keyboard can be used with the remote
/// (and with a phone). Falls back to a Flutter dialog where the native prompt isn't available.
Future<String?> askTvText(
  BuildContext context, {
  required String title,
  String? help,
  String initial = '',
  bool secret = false,
  TvTextKind kind = TvTextKind.text,
}) async {
  try {
    return await _channel.invokeMethod<String>('promptText', {
      'title': title,
      'message': help,
      'initial': initial,
      'secret': secret,
      'kind': kind.name,
    });
  } on MissingPluginException {
    // e.g. the quick panel engine
  } on PlatformException {
    // fall through to the Flutter dialog
  }
  if (!context.mounted) return null;
  return showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      insetPadding: const EdgeInsets.only(bottom: 120),
      contentPadding: const EdgeInsets.all(24),
      title: Text(title),
      children: [
        if (help != null) Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(help)),
        TextFormField(
          autofocus: true,
          initialValue: initial,
          obscureText: secret,
          autocorrect: !secret,
          keyboardType: kind == TvTextKind.url ? TextInputType.url : TextInputType.text,
          onFieldSubmitted: (value) => Navigator.of(context).pop(value),
        ),
      ],
    ),
  );
}

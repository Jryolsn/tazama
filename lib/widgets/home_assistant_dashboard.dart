import 'dart:convert';

import 'package:flauncher/providers/home_assistant_service.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// A Home Assistant dashboard in a web view, signed in with the long-lived token.
class HomeAssistantDashboard extends StatefulWidget {
  final HomeAssistantService ha;
  final String path;

  const HomeAssistantDashboard({super.key, required this.ha, required this.path});

  @override
  State<HomeAssistantDashboard> createState() => _HomeAssistantDashboardState();
}

class _HomeAssistantDashboardState extends State<HomeAssistantDashboard> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    final base = widget.ha.url!;
    // The frontend reads its session from localStorage; a far expiry keeps it from trying to refresh.
    final tokens = jsonEncode({
      'hassUrl': base,
      'clientId': '$base/',
      'access_token': widget.ha.token,
      'token_type': 'Bearer',
      'expires_in': 1800,
      'refresh_token': '',
      'expires': 4102444800000,
    });
    final target = jsonEncode('$base/${widget.path}');
    final html = '<html><body style="background:#0b0d1a"><script>'
        'localStorage.setItem("hassTokens", ${jsonEncode(tokens)});'
        'location.replace($target);'
        '</script></body></html>';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0B0D1A))
      ..loadHtmlString(html, baseUrl: base);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0B0D1A),
        body: WebViewWidget(controller: _controller),
      );
}

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

Widget getWebView() {
  // Register view factory
  ui.platformViewRegistry.registerViewFactory(
    'iframeElement',
    (int viewId) => html.IFrameElement()
      ..src = 'https://deliveryapp-tan.vercel.app/login'
      ..style.border = 'none'
      ..style.height = '100%'
      ..style.width = '100%',
  );

  return const Scaffold(
    body: SafeArea(
      child: HtmlElementView(
        viewType: 'iframeElement',
      ),
    ),
  );
} 
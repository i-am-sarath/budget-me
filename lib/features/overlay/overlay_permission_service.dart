import 'dart:io';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';

class OverlayPermissionService {
  static Future<bool> hasOverlayPermission() async {
    if (!Platform.isAndroid) return false;
    return await FlutterOverlayWindow.isPermissionGranted();
  }

  static Future<void> requestOverlayPermission() async {
    if (!Platform.isAndroid) return;
    await FlutterOverlayWindow.requestPermission();
  }

  static Future<bool> hasMicPermission() async {
    return await Permission.microphone.isGranted;
  }

  static Future<bool> requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }
}

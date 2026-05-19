import 'package:flutter/material.dart';
import 'overlay_mic_widget.dart';

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OverlayMicApp());
}

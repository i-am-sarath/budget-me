import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kOverlayEnabledKey = 'overlay_mic_enabled';

final overlaySettingsProvider =
    StateNotifierProvider<OverlaySettingsNotifier, bool>(
  (ref) => OverlaySettingsNotifier(),
);

class OverlaySettingsNotifier extends StateNotifier<bool> {
  OverlaySettingsNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) state = prefs.getBool(_kOverlayEnabledKey) ?? false;
  }

  Future<void> enable() async {
    if (!Platform.isAndroid) return;
    await FlutterOverlayWindow.showOverlay(
      height: WindowSize.matchParent,
      width: 64,
      alignment: OverlayAlignment.centerRight,
      flag: OverlayFlag.defaultFlag,
      overlayTitle: 'Budget Me',
      overlayContent: 'Hold to log an expense',
      enableDrag: true,
      positionGravity: PositionGravity.auto,
    );
    state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOverlayEnabledKey, true);
  }

  Future<void> disable() async {
    if (!Platform.isAndroid) return;
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (_) {}
    state = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOverlayEnabledKey, false);
  }
}

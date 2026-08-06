import 'dart:async';
import 'dart:io';

import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the always-on quick-log overlay bubble (Android only).
///
/// The overlay runs in a separate Flutter engine; this service handles
/// permission, start/stop, and listening for the IPC ping the bubble sends
/// when tapped. iOS is a no-op — Apple does not allow this pattern.
class OverlayService {
  static const _prefsEnabledKey = 'overlay_quick_log_enabled';

  /// Stream of IPC events from the overlay. Currently the only event is the
  /// string `'open_quick_entry'`, sent when the user taps the bubble.
  /// The main app subscribes once at startup and reacts (e.g. shows the
  /// manual entry sheet) if it happens to be running.
  static Stream<dynamic> get events => FlutterOverlayWindow.overlayListener;

  static bool get isSupported => Platform.isAndroid;

  /// Whether the user has previously enabled the overlay (persisted across
  /// launches). The actual visibility is gated on this AND the OS permission.
  static Future<bool> isEnabled() async {
    if (!isSupported) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsEnabledKey) ?? false;
  }

  static Future<void> _setEnabled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsEnabledKey, v);
  }

  /// Has the OS-level "Display over other apps" permission been granted?
  static Future<bool> hasPermission() async {
    if (!isSupported) return false;
    return await FlutterOverlayWindow.isPermissionGranted();
  }

  /// Opens the system settings page so the user can grant the overlay
  /// permission. Returns whether the permission was granted after the call.
  static Future<bool> requestPermission() async {
    if (!isSupported) return false;
    final result = await FlutterOverlayWindow.requestPermission();
    return result ?? false;
  }

  /// Show the bubble. Caller must have already confirmed permission.
  /// Persists the enabled flag so [restoreIfEnabled] can revive on next launch.
  static Future<bool> enable() async {
    if (!isSupported) return false;
    if (!await hasPermission()) return false;
    await _setEnabled(true);
    try {
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: 'Money Purse',
        overlayContent: 'Hold to log',
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.auto,
        // Sized to the idle bubble. The widget resizes the window itself when
        // entering the recording state so the wider waveform pill fits.
        height: 64,
        width: 64,
        startPosition: const OverlayPosition(0, 200),
      );
      return true;
    } catch (_) {
      // Surface as not-enabled so the UI reverts the toggle.
      await _setEnabled(false);
      return false;
    }
  }

  /// Hide the bubble and clear the persisted enabled flag.
  static Future<void> disable() async {
    if (!isSupported) return;
    await _setEnabled(false);
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (_) {}
  }

  /// Called once at app startup. Re-shows the bubble if the user had it on
  /// previously and the OS permission is still granted.
  static Future<void> restoreIfEnabled() async {
    if (!isSupported) return;
    if (!await isEnabled()) return;
    if (!await hasPermission()) {
      await _setEnabled(false);
      return;
    }
    try {
      final active = await FlutterOverlayWindow.isActive();
      if (active == true) return;
      await enable();
    } catch (_) {}
  }
}

/// Riverpod state for the settings toggle.
final overlayEnabledProvider =
    StateNotifierProvider<OverlayEnabledNotifier, bool>(
  (ref) => OverlayEnabledNotifier(),
);

class OverlayEnabledNotifier extends StateNotifier<bool> {
  OverlayEnabledNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    state = await OverlayService.isEnabled();
  }

  /// Returns null on success, or an error message describing why it failed.
  Future<String?> turnOn() async {
    if (!OverlayService.isSupported) {
      return 'Available on Android only';
    }
    if (!await OverlayService.hasPermission()) {
      final granted = await OverlayService.requestPermission();
      if (!granted) return 'Permission denied';
    }
    final ok = await OverlayService.enable();
    if (!ok) return 'Failed to start overlay';
    state = true;
    return null;
  }

  Future<void> turnOff() async {
    await OverlayService.disable();
    state = false;
  }
}

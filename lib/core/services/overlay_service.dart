import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agent_money/core/services/subscription_service.dart';

/// Backs the Settings "floating quick-log bubble" toggle: a draggable
/// SYSTEM_ALERT_WINDOW overlay, reachable from inside any other app, that
/// taps into the same [QuickCaptureService]-driven capture flow as the
/// home-screen widget. Android only — iOS disallows system overlays.
class OverlayService {
  OverlayService._();
  static final OverlayService instance = OverlayService._();

  static const _prefsEnabledKey = 'overlay_quick_log_enabled';
  static const bubbleSize = 64;

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsEnabledKey) ?? false;
  }

  Future<void> _setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsEnabledKey, value);
  }

  Future<bool> hasPermission() async {
    if (!isSupported) return false;
    return FlutterOverlayWindow.isPermissionGranted();
  }

  /// Opens the system "draw over other apps" settings page and resolves
  /// once the user grants (or denies/backs out of) the permission.
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    final granted = await FlutterOverlayWindow.requestPermission();
    return granted ?? false;
  }

  /// Shows the bubble and persists the toggle as on. Caller must already
  /// have confirmed Pro entitlement and overlay permission.
  Future<void> enable() async {
    if (!isSupported) return;
    await _setEnabled(true);
    if (!await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.showOverlay(
        height: bubbleSize,
        width: bubbleSize,
        alignment: OverlayAlignment.centerRight,
        visibility: NotificationVisibility.visibilityPublic,
        overlayTitle: 'Quick-log bubble active',
        overlayContent: 'Tap the bubble to log an expense by voice.',
        // We drive dragging/edge-snapping ourselves from the overlay widget
        // (moveOverlay) so a tap can still be told apart from a drag.
        enableDrag: false,
        positionGravity: PositionGravity.none,
      );
    }
  }

  Future<void> disable() async {
    await _setEnabled(false);
    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.closeOverlay();
    }
  }

  /// Call once at startup: re-shows the bubble if the toggle was left on
  /// and permission is still granted (survives app/process restarts).
  Future<void> restoreIfEnabled() async {
    if (!isSupported) return;
    if (!await isEnabled()) return;
    if (!await hasPermission()) return;
    if (!await FlutterOverlayWindow.isActive()) {
      await enable();
    }
  }

  /// IPC from the bubble's isolate (a separate Flutter engine) back to the
  /// main app — capture requests and permission fallbacks.
  Stream<dynamic> get events => FlutterOverlayWindow.overlayListener;

  Future<void> send(Map<String, dynamic> data) => FlutterOverlayWindow.shareData(data);
}

/// Drives the Settings toggle. Not a plain bool provider because turning
/// the bubble on is an async, possibly-failing operation (Pro check, OS
/// permission dance) the UI needs to react to.
class OverlayEnabledNotifier extends StateNotifier<bool> {
  OverlayEnabledNotifier(this._ref) : super(false) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    state = await OverlayService.instance.isEnabled();
  }

  /// Returns null on success, or a reason the toggle couldn't be turned on:
  /// 'pro_required' | 'permission_denied'.
  Future<String?> turnOn() async {
    if (!_ref.read(subscriptionProvider).isPro) return 'pro_required';

    if (!await OverlayService.instance.hasPermission()) {
      final granted = await OverlayService.instance.requestPermission();
      if (!granted) return 'permission_denied';
    }

    await OverlayService.instance.enable();
    state = true;
    return null;
  }

  Future<void> turnOff() async {
    await OverlayService.instance.disable();
    state = false;
  }
}

final overlayEnabledProvider =
    StateNotifierProvider<OverlayEnabledNotifier, bool>(
  (ref) => OverlayEnabledNotifier(ref),
);

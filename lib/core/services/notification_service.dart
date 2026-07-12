import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:agent_money/core/services/openai_service.dart';

/// Fires the local notifications that confirm (or explain the failure of)
/// a quick-capture voice log triggered from outside the app — widget,
/// Siri Shortcut/App Intent, Back Tap — where there's no UI to show a
/// result in directly. Also used for the Pro-upsell nudge when a free
/// user triggers an entry point that requires Pro.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  void Function(String? payload)? _onTap;

  static const String payloadPaywall = 'paywall';

  static const _channelId = 'quick_capture';
  static const _channelName = 'Voice capture';
  static const _channelDescription = 'Confirmations for voice-logged expenses';

  Future<void> init({void Function(String? payload)? onNotificationTap}) async {
    if (_initialized) return;
    _onTap = onNotificationTap;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) => _onTap?.call(response.payload),
    );

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      );
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(channel);
      await android?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    _initialized = true;
  }

  Future<void> _show(int id, String title, String body, {String? payload}) {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    return _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  Future<void> showProUpsell() => _show(
        1001,
        'Voice logging is a Pro feature',
        'Tap to unlock unlimited voice logging without opening the app.',
        payload: payloadPaywall,
      );

  Future<void> showError(String message) =>
      _show(1002, "Couldn't log that expense", message);

  Future<void> showCaptureResult(List<ParsedTransaction> transactions) {
    if (transactions.isEmpty) {
      return showError("Didn't catch a transaction in that. Please try again.");
    }
    final needsReview = transactions.any((t) => t.lowConfidence);
    final count = transactions.length;
    final title = needsReview
        ? '$count transaction${count == 1 ? '' : 's'} logged — review needed'
        : '$count transaction${count == 1 ? '' : 's'} logged';
    final body = transactions.map((pt) {
      final tx = pt.transaction;
      final label = tx.note.isNotEmpty ? tx.note : tx.category;
      return '$label · ${tx.amount.toStringAsFixed(0)}';
    }).join(', ');
    return _show(1003, title, body);
  }
}

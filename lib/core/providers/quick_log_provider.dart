import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Fired when budgetme://quicklog is received (iOS home screen widget tap).
// MagicFab listens to this and auto-starts recording.

final _quickLogController = StreamController<void>.broadcast();

void triggerQuickLog() => _quickLogController.add(null);

final quickLogProvider = StreamProvider<void>(
  (ref) => _quickLogController.stream,
);

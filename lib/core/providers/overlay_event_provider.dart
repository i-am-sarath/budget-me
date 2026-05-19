import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Broadcast stream wiring overlay save events from the overlay engine to the
// main Riverpod tree so the dashboard can refresh the transaction list.

final _controller = StreamController<Map<String, dynamic>>.broadcast();

void addOverlayEvent(Map<String, dynamic> event) {
  _controller.add(event);
}

final overlayEventProvider = StreamProvider<Map<String, dynamic>>(
  (ref) => _controller.stream,
);

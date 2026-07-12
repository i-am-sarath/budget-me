import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Records with auto-stop on silence — shared by every no-open-the-app
/// voice entry point (widget/in-app quick capture, and the floating
/// overlay bubble) so they all behave identically.
class SilenceRecorder {
  // dBFS below which the mic is considered "quiet". `record`'s amplitude
  // stream reports current level in dBFS (roughly -160 silence to 0 loudest).
  static const _silenceThresholdDb = -35.0;
  static const silenceDuration = Duration(milliseconds: 1500);
  static const minDuration = Duration(milliseconds: 800);
  static const maxDuration = Duration(seconds: 30);

  final _recorder = AudioRecorder();

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<File?> recordWithSilenceDetection({String prefix = 'quick_capture'}) async {
    final dir = await getTemporaryDirectory();
    final path = p.join(
      dir.path,
      '${prefix}_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);

    final start = DateTime.now();
    var lastLoud = DateTime.now();
    final stopSignal = Completer<void>();
    final sub = _recorder.onAmplitudeChanged(const Duration(milliseconds: 200)).listen((amp) {
      final now = DateTime.now();
      if (amp.current > _silenceThresholdDb) lastLoud = now;
      final elapsed = now.difference(start);
      final quietFor = now.difference(lastLoud);
      final shouldStop = elapsed >= maxDuration ||
          (elapsed >= minDuration && quietFor >= silenceDuration);
      if (shouldStop && !stopSignal.isCompleted) stopSignal.complete();
    });

    await stopSignal.future.timeout(
      maxDuration + const Duration(seconds: 2),
      onTimeout: () {},
    );
    await sub.cancel();

    final resultPath = await _recorder.stop();
    if (resultPath == null) return null;
    final file = File(resultPath);
    return (await file.exists()) ? file : null;
  }

  void dispose() => _recorder.dispose();
}

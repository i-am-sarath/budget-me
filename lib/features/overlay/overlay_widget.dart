import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Renders inside the system overlay window. Runs in a SEPARATE Flutter
/// engine — has no access to providers, repositories, or theme. Anything
/// it needs must be hard-coded or passed via [FlutterOverlayWindow.shareData].
class QuickLogOverlay extends StatefulWidget {
  const QuickLogOverlay({super.key});

  @override
  State<QuickLogOverlay> createState() => _QuickLogOverlayState();
}

class _QuickLogOverlayState extends State<QuickLogOverlay> {
  bool _pressed = false;

  Future<void> _onTap() async {
    setState(() => _pressed = true);
    // Notify the main app (if running) to open the quick-entry sheet.
    await FlutterOverlayWindow.shareData('open_quick_entry');
    await Future.delayed(const Duration(milliseconds: 150));
    if (mounted) setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: Colors.transparent,
        child: Center(
          child: GestureDetector(
            onTap: _onTap,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 120),
              scale: _pressed ? 0.92 : 1.0,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF2D6A2D),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

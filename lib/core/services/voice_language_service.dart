import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLangKey = 'voice_language_code';

final voiceLanguageProvider =
    StateNotifierProvider<VoiceLanguageNotifier, String>(
  (ref) => VoiceLanguageNotifier(),
);

class VoiceLanguageNotifier extends StateNotifier<String> {
  VoiceLanguageNotifier() : super('auto') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_kLangKey) ?? 'auto';
  }

  Future<void> setLanguage(String code) async {
    state = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLangKey, code);
  }
}

/// BCP-47 language codes supported by Whisper.
/// Each entry: (code, display name, emoji flag)
const voiceLanguageOptions = <(String, String, String)>[
  ('auto', 'Auto-detect', '🌐'),
  ('en', 'English', '🇬🇧'),
  ('hi', 'Hindi', '🇮🇳'),
  ('ta', 'Tamil', '🇮🇳'),
  ('kn', 'Kannada', '🇮🇳'),
  ('te', 'Telugu', '🇮🇳'),
  ('ml', 'Malayalam', '🇮🇳'),
];

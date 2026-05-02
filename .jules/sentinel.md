# Sentinel Journal

- Removed hardcoded OpenAI API key from `lib/core/config/api_config.dart`. Hardcoded secrets are a critical vulnerability. Replaced it with an empty string, enforcing the requirement to pass the key via environment variables (e.g., `--dart-define=OPENAI_API_KEY=...`) during builds.

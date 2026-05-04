\n- Fixed critical security issue: Removed hardcoded OpenAI API key from `lib/core/config/api_config.dart`. Always use `String.fromEnvironment` to inject secrets at build time.

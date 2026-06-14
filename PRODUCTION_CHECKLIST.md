# Budget Me — Production Readiness Checklist

This tracks what's needed before publishing to the Play Store (and later App Store).
Items marked ✅ are done in code; ⬜ are dashboard / account actions only you can do.

## Cloud architecture (decided)

- **Primary backend:** Supabase (Postgres + Auth + Realtime + RLS) — shared Groups.
- **AI proxy:** Cloudflare Worker (`backend/`) → Groq (`whisper-large-v3` + `llama-3.3-70b-versatile`).
- **Payments:** RevenueCat. **Ads:** Google AdMob. **Crashes:** Sentry.
- **Firebase is intentionally NOT used** — Supabase + Cloudflare cover auth, DB, and
  functions. The only Firebase-shaped gap (crash reporting) is filled by Sentry.

## Done in code

- ✅ **Account deletion** (Google Play requirement). In-app `Settings → Account →
  Delete Account`. Calls the `delete_user()` Postgres function (added to
  `supabase/schema.sql`) which removes the `auth.users` row; all group data
  cascades. Re-run `schema.sql` in the Supabase SQL editor to deploy the function.
- ✅ **R8 code + resource shrinking** enabled for release (`android/app/build.gradle.kts`)
  with keep rules in `android/app/proguard-rules.pro`.
- ✅ **Sentry crash reporting** — no-op unless `SENTRY_DSN` is provided at build time.
- ✅ **AdMob UMP consent** — `ConsentService.gatherConsent()` runs before ads init
  (EEA/UK GDPR + Google ads policy).
- ✅ **Build-time secret injection** — `scripts/build_release.ps1` / `.sh` +
  `dart_defines.example.json`. Real `dart_defines.json` and `key.properties` are
  gitignored.

## Manual steps before you ship

### 🔴 Blockers
- ⬜ **Upload keystore.** Create it and add `android/key.properties`
  (`keyAlias`, `keyPassword`, `storeFile`, `storePassword`). Without it the release
  silently falls back to **debug signing** and Play will reject the AAB.
- ⬜ **Real RevenueCat keys.** `lib/core/config/api_config.dart` defaults to `test_...`
  keys. Put the real Android (and iOS) public keys in `dart_defines.json`.
- ⬜ **Fill `dart_defines.json`** (copy from `dart_defines.example.json`): proxy URL +
  secret, Supabase URL + anon key, Google web client ID, RC keys, Sentry DSN.
- ⬜ **Deploy the updated `supabase/schema.sql`** so `delete_user()` exists in prod.
- ⬜ **Host the privacy policy + terms.** Settings links to
  `https://i-am-sarath.github.io/budget-me/privacy` and `/terms` — make sure both
  resolve. `budget-me-privacy-policy.html` in the repo is the source.
- ⬜ **Play Data Safety form.** Declare: audio (voice logging), advertising ID,
  account (email via Google sign-in). Link the privacy policy.

### 🟠 Important
- ⬜ **`SYSTEM_ALERT_WINDOW` justification.** The floating overlay needs a Play
  declaration explaining the quick-log bubble; users grant it manually on Android 11+.
- ⬜ **Confirm `targetSdk`** meets Play's current minimum (API 35) at submission.
- ⬜ **Set up an AdMob consent message** in the AdMob console (Privacy & messaging →
  GDPR) so `ConsentService` has a form to show in the EEA/UK.
- ⬜ **Test the real RevenueCat paywall** + restore on a physical device with the
  production keys.

### 🟡 iOS (when you launch there)
- ⬜ Real RC Apple key, App Store Connect products (`monthly`/`yearly`/`lifetime`),
  App Tracking Transparency prompt for ads.

## Notes
- `PROXY_CLIENT_SECRET` is compiled into the app and is extractable. That's expected
  for this proxy pattern — the per-user monthly rate limit in the Worker (KV) is the
  real abuse protection, not the secret.
- Free voice-log limit is 100/month (client); the Worker caps at 150 as a deliberate
  retry buffer (`backend/wrangler.toml`).

# Cloud Groups setup (shared spending)

The Groups feature lets several people (e.g. roommates) share a budget: everyone
logs spending into shared categories, and the app can optionally track *who owes
whom* and offer **Settle up**.

It runs on **Supabase** (Postgres + Auth + Realtime). The app works fully without
it — when not configured, the Groups screen shows a "set up cloud sync" state.

## 1. Create a Supabase project

1. Go to <https://supabase.com> → **New project**. Pick the free tier.
2. After it provisions, open **Project Settings → API** and copy:
   - **Project URL** → `SUPABASE_URL`
   - **anon public** key → `SUPABASE_ANON_KEY`  (this is public, safe to ship)

## 2. Run the schema

Open **SQL Editor → New query**, paste the contents of [`schema.sql`](./schema.sql),
and click **Run**. It creates the tables, Row Level Security policies, and Realtime
hooks. It's safe to re-run.

## 3. Enable Google sign-in

1. In Supabase: **Authentication → Providers → Google → Enable**.
2. In the [Google Cloud console](https://console.cloud.google.com/apis/credentials)
   create OAuth client IDs:
   - A **Web** client → paste its Client ID + secret into the Supabase Google
     provider. Also use that **Web client ID** as `GOOGLE_WEB_CLIENT_ID` below
     (the native sign-in needs the *web* id as its `serverClientId`).
   - An **Android** client → set package name `com.budgetme...` (match
     `android/app/build.gradle` `applicationId`) and your signing **SHA-1**
     (`./gradlew signingReport`).
3. Add the Supabase callback URL shown in the provider page to the Web client's
   "Authorized redirect URIs".

## 4. Build the app with the keys

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOURPROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi... \
  --dart-define=GOOGLE_WEB_CLIENT_ID=xxxx.apps.googleusercontent.com
```

(Combine with the existing `PROXY_BASE_URL` / `PROXY_CLIENT_SECRET` /
`RC_ANDROID_KEY` defines as needed.) Put these in your CI / release script too.

## Data model (quick reference)

| Table                  | Purpose                                            |
|------------------------|----------------------------------------------------|
| `groups`               | A shared group + invite code + settle-up toggle    |
| `group_members`        | Who is in a group (+ display name, role)           |
| `group_expenses`       | Each shared expense (payer, amount, category)      |
| `group_expense_splits` | Per-member share — drives settle-up balances       |

Joining a group is by **invite code**: the creator shares the 6-char code, the
other person enters it, and the app inserts their `group_members` row (allowed by
RLS because `user_id = auth.uid()`).

# Voice parsing regression suite

Covers the speech → transaction pipeline: `MagicFab` (record) → Whisper
transcription → `buildSystemPrompt()` (GPT-4o-mini parse) →
`parseTransactionJson()` (client-side mapping) → `ProcessingSheet` (review/save).

## What's here

- **`fixtures/voice_parse_cases.json`** — the fixed, version-controlled test
  set: 69 real-world phrases (amount formats, category colloquialisms,
  transaction-type detection, relative dates, multi-clause utterances,
  Hindi/Hinglish/Tamil phrasing, and non-financial "noise" transcripts),
  each with an expected `{amount, type, category, date}` per transaction,
  or `expectEmpty: true` for phrases that should yield zero transactions.
  Anchored to a fixed `today` (2026-07-12) so relative-date expectations
  ("yesterday", "on Monday", "2 days ago") are deterministic.

- **`run_regression.ts`** — calls the OpenAI chat completions API directly
  using the *exact* `buildSystemPrompt()` this repo currently ships (import,
  not a copy — so it's impossible to accidentally test a stale prompt),
  scores each case, and prints a per-field accuracy scorecard.

- **`../../test/voice_pipeline_test.dart`** (repo root `test/` — Flutter test
  tree) — offline, no network:
  - **Fixture lint**: every `expect`ed `category` is validated against
    `kTransactionCategories` (`lib/features/transactions/models/category_catalog.dart`,
    the single source of truth also used by the manual-entry category
    picker), so the fixtures themselves can't silently drift from the app's
    real vocabulary.
  - **Unit tests for `parseTransactionJson()`**: the defensive-parsing
    contract — malformed/missing amount degrades to a flagged low-confidence
    draft instead of crashing the batch, off-vocabulary categories are kept
    (not silently discarded) but flagged, an empty `transactions` array
    throws `VoiceLogException(isNoTransactions: true)` so the UI can fall
    back to manual entry instead of showing a misleading "0 transactions
    found" card, etc.
  - Run via `flutter test test/voice_pipeline_test.dart` from the repo root.
    These run in CI / any dev machine, no API key needed.

## Launch bar

Defined in `fixtures/voice_parse_cases.json` → `launchBar`:

| Field           | Bar |
|-----------------|-----|
| amount          | ≥ 90% |
| category        | ≥ 80% |
| type            | ≥ 85% |
| date            | ≥ 80% |
| empty-detection | ≥ 80% (noise phrases correctly yielding zero transactions) |

`run_regression.ts` exits non-zero if any field is below its bar, or if more
than 20% of cases failed to execute (network/auth issues — in that case the
scores aren't trustworthy and should be ignored).

## Running the live regression

Needs network access to `api.openai.com` and a real API key — **not run
automatically** (no secrets are stored in this repo).

```bash
cd backend
npm install
OPENAI_API_KEY=sk-... npm run test:regression
```

Optional env vars:
- `REGRESSION_MODEL` — defaults to `gpt-4o-mini` (same model the worker uses).
- `REGRESSION_CONCURRENCY` — defaults to `5` parallel requests.

Re-run this **every time `buildSystemPrompt()` changes, or the model
changes** — that's the whole point of it being a fixed, version-controlled
set: a same-scale, apples-to-apples comparison against the previous run.

## Current status (as of this hardening pass)

The harness has been built, dry-run-verified (module resolution, request
construction, scoring/threshold logic all confirmed working — see commit
history / PR for the fake-key smoke test output), and the offline
`voice_pipeline_test.dart` suite is green. **The live scorecard has not yet
been run against the real model** — this development environment has no
`OPENAI_API_KEY` configured. Whoever has API access should run the command
above once and record the resulting scorecard here (or in the PR
description) before treating the "documented accuracy meets the launch bar"
acceptance criterion as met.

Record results here after each live run:

```
<paste `npm run test:regression` scorecard output>
```

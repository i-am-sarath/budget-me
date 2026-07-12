// Regression harness for the voice → transaction parsing prompt.
//
// Re-run this whenever backend/src/index.ts's buildSystemPrompt() (or the
// model) changes, to check parsing accuracy hasn't regressed against the
// fixed phrase set in test/fixtures/voice_parse_cases.json.
//
// Usage:
//   cd backend
//   npm install
//   OPENAI_API_KEY=sk-... npm run test:regression
//
// Calls the OpenAI chat completions API directly (bypassing the Cloudflare
// Worker) using the *exact* buildSystemPrompt() this repo currently ships,
// so there is no risk of testing a stale copy of the prompt.

import { buildSystemPrompt } from '../src/index';
import fixturesJson from './fixtures/voice_parse_cases.json';

interface ExpectedTx {
  amount: number;
  type: string;
  category: string;
  date: string;
}

interface Case {
  id: string;
  phrase: string;
  tags: string[];
  expect?: ExpectedTx[];
  expectEmpty?: boolean;
}

interface Fixtures {
  today: string;
  launchBar: Record<string, number>;
  cases: Case[];
}

const fixtures = fixturesJson as Fixtures;

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const MODEL = process.env.REGRESSION_MODEL || 'gpt-4o-mini';
const CONCURRENCY = Number(process.env.REGRESSION_CONCURRENCY || 5);

if (!OPENAI_API_KEY) {
  console.error(
    'OPENAI_API_KEY is not set. Export it and re-run:\n' +
      '  OPENAI_API_KEY=sk-... npm run test:regression',
  );
  process.exit(1);
}

// ─── Field-level scoring ───────────────────────────────────

const AMOUNT_EPSILON = 0.01;

function amountMatches(expected: number, actual: unknown): boolean {
  const n = typeof actual === 'number' ? actual : Number(actual);
  if (!Number.isFinite(n)) return false;
  return Math.abs(n - expected) < AMOUNT_EPSILON;
}

interface CaseResult {
  id: string;
  phrase: string;
  tags: string[];
  ok: boolean;
  executionError?: string;
  countMismatch?: boolean;
  fieldResults: Array<{ field: 'amount' | 'category' | 'type' | 'date'; pass: boolean; expected?: unknown; actual?: unknown }>;
  emptyDetection?: { expected: boolean; actual: boolean; pass: boolean };
  rawContent?: string;
}

async function callParse(phrase: string, today: string): Promise<string> {
  const systemPrompt = buildSystemPrompt(today);
  const res = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model: MODEL,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: phrase },
      ],
      temperature: 0,
      response_format: { type: 'json_object' },
    }),
  });
  if (!res.ok) {
    const body = await res.text().catch(() => '');
    throw new Error(`OpenAI ${res.status}: ${body.slice(0, 300)}`);
  }
  const data = (await res.json()) as { choices: Array<{ message: { content: string } }> };
  return data.choices?.[0]?.message?.content ?? '';
}

function scoreCase(c: Case, content: string): CaseResult {
  const base: CaseResult = { id: c.id, phrase: c.phrase, tags: c.tags, ok: false, fieldResults: [], rawContent: content };

  let parsed: { transactions?: unknown[] };
  try {
    const cleaned = content.replace(/```json/g, '').replace(/```/g, '').trim();
    parsed = JSON.parse(cleaned);
  } catch (e) {
    return { ...base, executionError: `Response was not valid JSON: ${(e as Error).message}` };
  }

  const items = Array.isArray(parsed.transactions) ? parsed.transactions : [];

  if (c.expectEmpty) {
    const pass = items.length === 0;
    return { ...base, ok: pass, emptyDetection: { expected: true, actual: items.length === 0, pass } };
  }

  const expected = c.expect ?? [];
  if (items.length !== expected.length) {
    return { ...base, ok: false, countMismatch: true };
  }

  const fieldResults: CaseResult['fieldResults'] = [];
  for (let i = 0; i < expected.length; i++) {
    const exp = expected[i];
    const act = items[i] as Record<string, unknown>;
    fieldResults.push({ field: 'amount', pass: amountMatches(exp.amount, act?.amount), expected: exp.amount, actual: act?.amount });
    fieldResults.push({ field: 'category', pass: act?.category === exp.category, expected: exp.category, actual: act?.category });
    fieldResults.push({ field: 'type', pass: act?.type === exp.type, expected: exp.type, actual: act?.type });
    fieldResults.push({ field: 'date', pass: act?.date === exp.date, expected: exp.date, actual: act?.date });
  }

  const ok = fieldResults.every((f) => f.pass);
  return { ...base, ok, fieldResults };
}

async function runWithConcurrency<T, R>(items: T[], limit: number, fn: (item: T) => Promise<R>): Promise<R[]> {
  const results: R[] = new Array(items.length);
  let next = 0;
  async function worker() {
    while (next < items.length) {
      const i = next++;
      results[i] = await fn(items[i]);
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
  return results;
}

async function main() {
  console.log(`Running ${fixtures.cases.length} cases against ${MODEL} (today=${fixtures.today})...\n`);

  const results = await runWithConcurrency(fixtures.cases, CONCURRENCY, async (c) => {
    try {
      const content = await callParse(c.phrase, fixtures.today);
      return scoreCase(c, content);
    } catch (e) {
      return {
        id: c.id,
        phrase: c.phrase,
        tags: c.tags,
        ok: false,
        executionError: (e as Error).message,
        fieldResults: [],
      } as CaseResult;
    }
  });

  // ─── Tally ───────────────────────────────────
  const executionErrors = results.filter((r) => r.executionError);
  const countMismatches = results.filter((r) => r.countMismatch);
  const scored = results.filter((r) => !r.executionError && !r.countMismatch);

  const byField: Record<string, { pass: number; total: number }> = {
    amount: { pass: 0, total: 0 },
    category: { pass: 0, total: 0 },
    type: { pass: 0, total: 0 },
    date: { pass: 0, total: 0 },
  };
  const emptyDetection = { pass: 0, total: 0 };

  for (const r of scored) {
    if (r.emptyDetection) {
      emptyDetection.total++;
      if (r.emptyDetection.pass) emptyDetection.pass++;
      continue;
    }
    for (const f of r.fieldResults) {
      byField[f.field].total++;
      if (f.pass) byField[f.field].pass++;
    }
  }
  // Count-mismatched multi-transaction cases fail every field they expected.
  for (const r of countMismatches) {
    const c = fixtures.cases.find((x) => x.id === r.id)!;
    for (const _tx of c.expect ?? []) {
      byField.amount.total++;
      byField.category.total++;
      byField.type.total++;
      byField.date.total++;
    }
  }

  const rate = (n: { pass: number; total: number }) => (n.total === 0 ? 1 : n.pass / n.total);

  console.log('── Failures ──────────────────────────────────────────');
  for (const r of results) {
    if (r.ok) continue;
    if (r.executionError) {
      console.log(`[${r.id}] EXECUTION ERROR — "${r.phrase}"\n    ${r.executionError}`);
      continue;
    }
    if (r.countMismatch) {
      console.log(`[${r.id}] TRANSACTION COUNT MISMATCH — "${r.phrase}"\n    raw: ${r.rawContent}`);
      continue;
    }
    if (r.emptyDetection && !r.emptyDetection.pass) {
      console.log(`[${r.id}] EXPECTED NO TRANSACTIONS — "${r.phrase}"\n    raw: ${r.rawContent}`);
      continue;
    }
    const badFields = r.fieldResults.filter((f) => !f.pass);
    console.log(`[${r.id}] "${r.phrase}"`);
    for (const f of badFields) {
      console.log(`    ${f.field}: expected ${JSON.stringify(f.expected)}, got ${JSON.stringify(f.actual)}`);
    }
  }

  console.log('\n── Scorecard ─────────────────────────────────────────');
  const bar = fixtures.launchBar;
  let anyBelowBar = false;
  for (const field of ['amount', 'category', 'type', 'date'] as const) {
    const r = rate(byField[field]);
    const pct = (r * 100).toFixed(1);
    const barPct = (bar[field] * 100).toFixed(0);
    const status = r >= bar[field] ? 'PASS' : 'FAIL';
    if (status === 'FAIL') anyBelowBar = true;
    console.log(`${field.padEnd(10)} ${pct.padStart(5)}%  (${byField[field].pass}/${byField[field].total})  bar=${barPct}%  ${status}`);
  }
  if (emptyDetection.total > 0) {
    const r = rate(emptyDetection);
    const pct = (r * 100).toFixed(1);
    const barPct = (bar.emptyDetection * 100).toFixed(0);
    const status = r >= bar.emptyDetection ? 'PASS' : 'FAIL';
    if (status === 'FAIL') anyBelowBar = true;
    console.log(`${'emptyDetect'.padEnd(10)} ${pct.padStart(5)}%  (${emptyDetection.pass}/${emptyDetection.total})  bar=${barPct}%  ${status}`);
  }

  console.log(`\nExecution errors: ${executionErrors.length}/${results.length}`);
  console.log(`Count mismatches: ${countMismatches.length}/${results.length}`);

  if (executionErrors.length > results.length * 0.2) {
    console.log('\n⚠️  More than 20% of cases failed to execute — scores above are not trustworthy. Check API key / network / rate limits.');
    process.exit(1);
  }

  if (anyBelowBar) {
    console.log('\n❌ Below launch bar — see failures above.');
    process.exit(1);
  }
  console.log('\n✅ All fields at or above the launch bar.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

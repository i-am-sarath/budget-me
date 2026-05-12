// Budget Me proxy worker.
// Sits between the Flutter app and OpenAI so the API key never ships in the AAB.

interface Env {
  OPENAI_API_KEY: string;   // wrangler secret
  CLIENT_SECRET: string;    // wrangler secret
  RATE_LIMIT: KVNamespace;  // KV binding from wrangler.toml
  MONTHLY_LIMIT: string;    // var from wrangler.toml
}

const OPENAI_BASE = 'https://api.openai.com/v1';

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    if (req.method === 'OPTIONS') return cors(new Response(null, { status: 204 }));

    const url = new URL(req.url);

    if (req.method === 'POST' && url.pathname === '/v1/transcribe') {
      return cors(await handle(req, env, transcribe));
    }
    if (req.method === 'POST' && url.pathname === '/v1/parse') {
      return cors(await handle(req, env, parseTransactions));
    }
    if (req.method === 'GET' && url.pathname === '/health') {
      return cors(json({ ok: true }));
    }

    return cors(error('not_found', 'Unknown endpoint', 404));
  },
};

// ─── Auth + rate limiting wrapper ─────────────────────────

type Handler = (req: Request, env: Env, userId: string) => Promise<Response>;

async function handle(req: Request, env: Env, fn: Handler): Promise<Response> {
  const auth = req.headers.get('authorization') ?? '';
  const expected = `Bearer ${env.CLIENT_SECRET}`;
  // Constant-time compare so timing attacks can't probe the secret byte-by-byte.
  if (!safeEquals(auth, expected)) {
    return error('unauthorized', 'Invalid or missing client credentials', 401);
  }

  const userId = (req.headers.get('x-user-id') ?? '').trim();
  if (!userId || userId.length > 128) {
    return error('bad_request', 'Missing or invalid X-User-Id header', 400);
  }

  const limit = parseInt(env.MONTHLY_LIMIT, 10) || 150;
  const month = new Date().toISOString().slice(0, 7); // YYYY-MM
  const key = `rate:${userId}:${month}`;

  const currentRaw = await env.RATE_LIMIT.get(key);
  const current = currentRaw ? parseInt(currentRaw, 10) : 0;
  if (current >= limit) {
    return error('rate_limited', 'Monthly voice log limit reached', 429);
  }

  const result = await fn(req, env, userId);

  // Only count successful OpenAI calls toward the user's quota.
  if (result.status >= 200 && result.status < 300) {
    await env.RATE_LIMIT.put(key, String(current + 1), {
      expirationTtl: 60 * 60 * 24 * 35, // 35 days — auto-cleanup after the month rolls over
    });
  }

  return result;
}

// ─── /v1/transcribe ──────────────────────────────────────

async function transcribe(req: Request, env: Env, _userId: string): Promise<Response> {
  // The client posts multipart/form-data with a 'file' field.
  // We forward it straight to Whisper, swapping the auth header.
  const incoming = await req.formData();
  const file = incoming.get('file');
  if (!(file instanceof File)) {
    return error('bad_request', 'Missing audio file', 400);
  }

  const upstream = new FormData();
  upstream.append('file', file, file.name || 'audio.m4a');
  upstream.append('model', 'whisper-1');
  upstream.append('response_format', 'text');

  const res = await fetch(`${OPENAI_BASE}/audio/transcriptions`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${env.OPENAI_API_KEY}` },
    body: upstream,
  });

  if (!res.ok) {
    return upstreamError(res, 'transcription_failed');
  }

  const text = await res.text();
  return json({ text: text.trim() });
}

// ─── /v1/parse ───────────────────────────────────────────

async function parseTransactions(req: Request, env: Env, _userId: string): Promise<Response> {
  const body = await req.json<{ transcript?: string; today?: string }>().catch(() => null);
  if (!body || typeof body.transcript !== 'string' || !body.transcript.trim()) {
    return error('bad_request', 'Missing transcript', 400);
  }

  const today = (body.today && /^\d{4}-\d{2}-\d{2}$/.test(body.today))
    ? body.today
    : new Date().toISOString().slice(0, 10);

  const systemPrompt = buildSystemPrompt(today);

  const res = await fetch(`${OPENAI_BASE}/chat/completions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${env.OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: body.transcript },
      ],
      temperature: 0,
      response_format: { type: 'json_object' },
    }),
  });

  if (!res.ok) {
    return upstreamError(res, 'parse_failed');
  }

  const data = await res.json<{ choices: Array<{ message: { content: string } }> }>();
  const content = data.choices?.[0]?.message?.content ?? '';
  return json({ content });
}

// ─── Helpers ─────────────────────────────────────────────

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function error(code: string, message: string, status: number): Response {
  return json({ error: { code, message } }, status);
}

async function upstreamError(res: Response, code: string): Promise<Response> {
  // Don't leak OpenAI internals to the client — just surface a stable code.
  // Log the upstream body server-side so you can debug via `wrangler tail`.
  const body = await res.text().catch(() => '');
  console.error(`upstream ${res.status}: ${body.slice(0, 500)}`);
  const status = res.status >= 500 ? 502 : 502;
  return error(code, 'Upstream service error', status);
}

function safeEquals(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

function cors(res: Response): Response {
  const h = new Headers(res.headers);
  h.set('Access-Control-Allow-Origin', '*');
  h.set('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
  h.set('Access-Control-Allow-Headers', 'Authorization, Content-Type, X-User-Id');
  return new Response(res.body, { status: res.status, headers: h });
}

function buildSystemPrompt(today: string): string {
  return `You are a multilingual financial transaction parser for an app called Budget Me.
The user's voice transcript may be in English, Hindi, Tamil, Hinglish, or any mix.

Extract ALL transactions and return them as a JSON object with a "transactions" array.

━━━ TYPES ━━━
"type" must be exactly one of: expense, income, lend, borrow, lend_return, borrow_return, investment
  - expense: user spent money (bought something, paid a bill, rent, EMI, subscriptions)
  - income: user received money (salary, freelance, sold something, cashback)
  - investment: user invested money (SIP, DigiGold, stocks, mutual fund, FD, PPF, NPS, crypto)
  - lend: user gave money TO someone (gave loan, paid for friend, gave advance)
  - borrow: user borrowed money FROM someone (took loan, friend paid for me, took advance)
  - lend_return: someone RETURNED money they owed the user ("he paid me back", "returned my money", "got the money back from him")
  - borrow_return: user RETURNED borrowed money ("I returned the money", "paid back my loan", "repaid", "settled")

━━━ FIELDS ━━━
  - "amount": positive number. Parse "five hundred" → 500, "2k" → 2000, "₹" or "$" prefix.
  - "category": one of: Food, Transport, Shopping, Rent, Health, Bills, Entertainment, Education, Travel, Salary, Freelance, Investment, Gift, Interest, General, Loan Repayment
  - "note": short English description of the transaction (translate non-English to English)
  - "payee": person's name for lend/borrow types, merchant for expense. Leave "" if unknown.
  - "account_name": if the user mentions a specific account (e.g. "from savings", "to HDFC", "cash", "UPI"), include it. Otherwise leave "".
  - "date": ISO format YYYY-MM-DD. Today is: ${today}. Use today unless user says otherwise.

━━━ INVESTMENT VOCABULARY ━━━
  - SIP / sip = Systematic Investment Plan → investment
  - DigiGold / digi gold / digital gold → investment
  - Mutual fund / MF → investment
  - FD / fixed deposit → investment
  - PPF / NPS / ELSS → investment
  - Stocks / shares / equity → investment
  - Crypto / bitcoin / ethereum → investment

━━━ MULTILINGUAL VOCABULARY ━━━
Tamil:
  - maligai / மளிகை = grocery/shopping (category: Shopping)
  - unavagam / சாப்பாட்டு கடை = restaurant (category: Food)
  - jama / ஜாமா = paid / credited (context-sensitive)
  - kadan / கடன் = loan/lend
  - thiruppi kuduthan / திரும்பி குடுத்தான் = he returned the money → lend_return
  - saadam / சாதம் = rice/food
  - kadai = shop
  - auto = auto-rickshaw (category: Transport)
  - petrol = fuel (category: Transport)
Hindi/Hinglish:
  - khana / khaana = food
  - gaadi / gadi = vehicle/transport
  - dukaan = shop
  - dost ko diya = lent to friend → lend
  - wapas mila / wapas kiya = returned → lend_return or borrow_return
  - salary aayi = received salary → income
  - EMI / kiraya = rent/EMI → expense
  - udhar diya = lent → lend
  - udhar liya = borrowed → borrow
  - loan bhara = repaid loan → borrow_return

━━━ REPAYMENT LOGIC (IMPORTANT) ━━━
When someone RETURNS money to the user:
  → type = "lend_return" (reduces outstanding lent amount, adds to user balance)
  → Example: "Rahul gave me back the 500 he owed" → lend_return, amount=500, payee="Rahul"

When user RETURNS money they borrowed:
  → type = "borrow_return" (reduces outstanding borrowed amount, reduces user balance)
  → Example: "I paid back the 1000 I borrowed from Priya" → borrow_return, amount=1000, payee="Priya"

When user pays EMI or loan installment:
  → type = "borrow_return", category = "Loan Repayment"
  → Example: "Paid EMI 15000" → borrow_return, amount=15000, category="Loan Repayment", note="EMI payment"

━━━ TRANSFER RECOGNITION ━━━
If the user says "transferred X to Y account" or "moved money from A to B":
  → Create TWO transactions:
    1. expense from source account
    2. income to destination account
  → Both should have category="Transfer"

━━━ EXAMPLES ━━━
Input: "Spent 300 on lunch at office canteen"
Output: {"transactions":[{"amount":300,"type":"expense","category":"Food","note":"Lunch at office canteen","payee":"","account_name":"","date":"${today}"}]}

Input: "SIP payment 5000 for mutual fund"
Output: {"transactions":[{"amount":5000,"type":"investment","category":"Investment","note":"SIP mutual fund payment","payee":"","account_name":"","date":"${today}"}]}

Input: "Rahul gave me back 500 rupees"
Output: {"transactions":[{"amount":500,"type":"lend_return","category":"General","note":"Rahul returned 500","payee":"Rahul","account_name":"","date":"${today}"}]}

Input: "Paid EMI 15000 from HDFC account"
Output: {"transactions":[{"amount":15000,"type":"borrow_return","category":"Loan Repayment","note":"EMI payment","payee":"","account_name":"HDFC","date":"${today}"}]}

Input: "Got salary 50000, paid 12000 rent"
Output: {"transactions":[{"amount":50000,"type":"income","category":"Salary","note":"Monthly salary","payee":"","account_name":"","date":"${today}"},{"amount":12000,"type":"expense","category":"Rent","note":"Monthly rent","payee":"","account_name":"","date":"${today}"}]}

Input: "50 rupees kuduthen Ravi ku" (Tamil: gave 50 rupees to Ravi)
Output: {"transactions":[{"amount":50,"type":"lend","category":"General","note":"Lent to Ravi","payee":"Ravi","account_name":"","date":"${today}"}]}

Return ONLY valid JSON. No markdown, no explanation, no extra keys.`;
}

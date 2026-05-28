# company.nanoteofficial.me v0.2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the five simulated office agents into real Claude agents that produce useful daily artifacts, surface that work in the office UI, and make the company controllable/observable from a two-way Telegram bot with CI/CD alerts.

**Architecture:** Cloud-only on Vercel Hobby. Five agents run as daily Vercel Cron functions → call Claude (+ a data source) → write status/artifact/feed-event to Upstash Redis → send a Telegram report. The office UI polls Redis-backed read APIs (`/api/agents`, `/api/feed`) every ~8s. A Telegram webhook handles `/status`, `/run`, `/ask` (locked to one chat). A Vercel deploy webhook posts CI/CD alerts to Telegram.

**Tech Stack:** Next.js 16 (App Router, route handlers, `after()`), TypeScript (strict), `@anthropic-ai/sdk` (claude-sonnet-4-6, web-search tool), `@upstash/redis`, Vercel Cron, Telegram Bot API, Vitest.

**Spec:** `docs/superpowers/specs/2026-05-28-company-nanoteofficial-v0.2-design.md`

**Conventions carried from v0.1:** strict TS, no `dangerouslySetInnerHTML`, structured data over HTML strings, vitest with jsdom, `DeptId = 'ceo'|'mkt'|'rnd'|'ops'|'fin'` (see `src/lib/data/departments.ts`). All work happens in `/project/src/company.nanoteofficial.me`.

> **IMPORTANT — verify volatile APIs at implementation time** using the `context7` MCP tool or `node_modules`: Next 16 route handlers, `after()` from `next/server`, `@upstash/redis` method names, and the Anthropic web-search tool `type` string (`web_search_20250305`, or newer `web_search_20260209`). The code below reflects versions verified on 2026-05-28.

---

## Shared types (referenced throughout)

These live in `src/lib/agents/types.ts` (created in Task 2). Repeated here for reference:

```ts
import type { DeptId } from '@/lib/data/departments';

export type AgentState = 'idle' | 'running' | 'done' | 'error';

export interface AgentStatus {
  dept: DeptId;
  state: AgentState;
  lastRun: string | null;   // ISO timestamp
  error?: string;
  summary?: string;         // one-line latest summary
}

export interface AgentOutput {
  dept: DeptId;
  markdown: string;         // the artifact
  summary: string;          // short one-liner
  ts: string;               // ISO timestamp
  meta?: Record<string, unknown>;
}

export interface FeedEvent {
  dept: DeptId;
  msg: string;
  ts: string;               // ISO timestamp
}

/** Result an individual agent's run() returns; the runner wraps it. */
export interface AgentRunResult {
  markdown: string;
  summary: string;
  feedMsg: string;          // short line for the live terminal feed
  meta?: Record<string, unknown>;
}
```

Dept id mapping (agent module ↔ DeptId): finance→`fin`, marketing→`mkt`, rnd→`rnd`, operations→`ops`, ceo→`ceo`.

---

## Task 1: Dependencies + env scaffolding

**Files:**
- Modify: `package.json`
- Create: `.env.example`
- Create: `.env.local` (gitignored — local secrets for dev)

- [ ] **Step 1: Install runtime deps**

Run:
```bash
cd /project/src/company.nanoteofficial.me
npm install @anthropic-ai/sdk @upstash/redis
```
Expected: both added to `dependencies` in `package.json`.

- [ ] **Step 2: Create `.env.example`**

```bash
# Claude
ANTHROPIC_API_KEY=

# Upstash Redis (auto-injected on Vercel by the Upstash integration; set manually for local dev)
UPSTASH_REDIS_REST_URL=
UPSTASH_REDIS_REST_TOKEN=

# Telegram
TELEGRAM_BOT_TOKEN=
TELEGRAM_WEBHOOK_SECRET=
TELEGRAM_ALLOWED_CHAT_ID=

# Ops data sources
VERCEL_TOKEN=
GITHUB_TOKEN=

# Protects /api/cron/run and manual triggers
CRON_SECRET=

# Verifies the Vercel deploy webhook (optional; set if using signature)
VERCEL_WEBHOOK_SECRET=
```

- [ ] **Step 3: Confirm `.env.local` is gitignored**

Run: `grep -q ".env" .gitignore && echo OK`
Expected: `OK` (Next's default .gitignore ignores `.env*`). If not, add `.env*.local` to `.gitignore`.

- [ ] **Step 4: Commit**

```bash
git add package.json package-lock.json .env.example .gitignore
git commit -m "chore: add anthropic + upstash deps and env scaffolding for v0.2"
```

---

## Task 2: Shared types + Redis helpers (TDD)

**Files:**
- Create: `src/lib/agents/types.ts`
- Create: `src/lib/redis.ts`
- Test: `src/lib/redis.test.ts`

- [ ] **Step 1: Create `src/lib/agents/types.ts`**

Use the exact contents from the "Shared types" section above.

- [ ] **Step 2: Write the failing test `src/lib/redis.test.ts`**

The redis module wraps a client and exposes typed accessors. We inject a fake client so tests don't hit the network.

```ts
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { makeRedisRepo } from './redis';
import type { AgentStatus, AgentOutput, FeedEvent } from './agents/types';

function fakeClient() {
  const store = new Map<string, unknown>();
  const list = new Map<string, unknown[]>();
  return {
    store, list,
    set: vi.fn(async (k: string, v: unknown) => { store.set(k, v); }),
    get: vi.fn(async (k: string) => store.get(k) ?? null),
    lpush: vi.fn(async (k: string, v: unknown) => { const a = list.get(k) ?? []; a.unshift(v); list.set(k, a); return a.length; }),
    ltrim: vi.fn(async (k: string, start: number, stop: number) => { const a = list.get(k) ?? []; list.set(k, a.slice(start, stop + 1)); }),
    lrange: vi.fn(async (k: string, start: number, stop: number) => { const a = list.get(k) ?? []; return a.slice(start, stop === -1 ? undefined : stop + 1); }),
  };
}

describe('redis repo', () => {
  let client: ReturnType<typeof fakeClient>;
  let repo: ReturnType<typeof makeRedisRepo>;
  beforeEach(() => { client = fakeClient(); repo = makeRedisRepo(client); });

  it('stores and reads agent status', async () => {
    const s: AgentStatus = { dept: 'fin', state: 'done', lastRun: '2026-05-28T11:00:00Z', summary: 'ok' };
    await repo.setStatus(s);
    expect(client.set).toHaveBeenCalledWith('agent:fin:status', s);
    expect(await repo.getStatus('fin')).toEqual(s);
  });

  it('returns a default idle status when none stored', async () => {
    expect(await repo.getStatus('ceo')).toEqual({ dept: 'ceo', state: 'idle', lastRun: null });
  });

  it('stores and reads an output', async () => {
    const o: AgentOutput = { dept: 'mkt', markdown: '# hi', summary: 's', ts: '2026-05-28T13:00:00Z' };
    await repo.setOutput(o);
    expect(await repo.getOutput('mkt')).toEqual(o);
  });

  it('pushes feed events and caps the list at 50', async () => {
    for (let i = 0; i < 55; i++) {
      const e: FeedEvent = { dept: 'ops', msg: `m${i}`, ts: '2026-05-28T00:00:00Z' };
      await repo.pushEvent(e);
    }
    expect(client.ltrim).toHaveBeenLastCalledWith('feed:events', 0, 49);
    const recent = await repo.getFeed(10);
    expect(recent.length).toBe(10);
    expect(recent[0].msg).toBe('m54'); // newest first
  });
});
```

- [ ] **Step 3: Run test to verify it fails**

Run: `npx vitest run src/lib/redis.test.ts`
Expected: FAIL — `makeRedisRepo` not defined.

- [ ] **Step 4: Implement `src/lib/redis.ts`**

```ts
import { Redis } from '@upstash/redis';
import type { DeptId } from '@/lib/data/departments';
import type { AgentStatus, AgentOutput, FeedEvent } from './agents/types';

const FEED_KEY = 'feed:events';
const FEED_CAP = 50;

/** Minimal surface of the Upstash client we use — lets us inject a fake in tests. */
export interface RedisClientLike {
  set(key: string, value: unknown): Promise<unknown>;
  get<T = unknown>(key: string): Promise<T | null>;
  lpush(key: string, value: unknown): Promise<number>;
  ltrim(key: string, start: number, stop: number): Promise<unknown>;
  lrange<T = unknown>(key: string, start: number, stop: number): Promise<T[]>;
}

export function makeRedisRepo(client: RedisClientLike) {
  return {
    async setStatus(s: AgentStatus) { await client.set(`agent:${s.dept}:status`, s); },
    async getStatus(dept: DeptId): Promise<AgentStatus> {
      const v = await client.get<AgentStatus>(`agent:${dept}:status`);
      return v ?? { dept, state: 'idle', lastRun: null };
    },
    async setOutput(o: AgentOutput) { await client.set(`agent:${o.dept}:output`, o); },
    async getOutput(dept: DeptId): Promise<AgentOutput | null> {
      return (await client.get<AgentOutput>(`agent:${dept}:output`)) ?? null;
    },
    async pushEvent(e: FeedEvent) {
      await client.lpush(FEED_KEY, e);
      await client.ltrim(FEED_KEY, 0, FEED_CAP - 1);
    },
    async getFeed(limit = FEED_CAP): Promise<FeedEvent[]> {
      return await client.lrange<FeedEvent>(FEED_KEY, 0, limit - 1);
    },
  };
}

export type RedisRepo = ReturnType<typeof makeRedisRepo>;

let _repo: RedisRepo | null = null;
/** Production singleton using env-configured Upstash. */
export function getRepo(): RedisRepo {
  if (!_repo) _repo = makeRedisRepo(Redis.fromEnv() as unknown as RedisClientLike);
  return _repo;
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `npx vitest run src/lib/redis.test.ts`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add src/lib/agents/types.ts src/lib/redis.ts src/lib/redis.test.ts
git commit -m "feat: add shared agent types + Upstash redis repo with tests"
```

---

## Task 3: Claude client wrapper

**Files:**
- Create: `src/lib/claude.ts`

- [ ] **Step 1: Create `src/lib/claude.ts`**

Thin wrapper around the Anthropic SDK with two helpers: a plain text completion and a web-search-enabled completion. Concatenates text blocks from the response.

```ts
import Anthropic from '@anthropic-ai/sdk';

const MODEL = 'claude-sonnet-4-6';

let _client: Anthropic | null = null;
function client(): Anthropic {
  if (!_client) _client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
  return _client;
}

/** Extract and join all text blocks from a Messages response. */
function textOf(msg: Anthropic.Messages.Message): string {
  return msg.content
    .filter((b): b is Anthropic.Messages.TextBlock => b.type === 'text')
    .map((b) => b.text)
    .join('\n')
    .trim();
}

export interface CompleteOpts {
  system: string;
  prompt: string;
  maxTokens?: number;
  webSearch?: boolean;     // enable the server web-search tool
  maxSearches?: number;
}

/** One-shot completion. Retries transient errors up to 3 times with backoff. */
export async function complete(opts: CompleteOpts): Promise<string> {
  const { system, prompt, maxTokens = 1500, webSearch = false, maxSearches = 5 } = opts;
  const tools = webSearch
    ? [{ type: 'web_search_20250305', name: 'web_search', max_uses: maxSearches } as unknown as Anthropic.Messages.Tool]
    : undefined;

  let lastErr: unknown;
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const msg = await client().messages.create({
        model: MODEL,
        max_tokens: maxTokens,
        system,
        messages: [{ role: 'user', content: prompt }],
        ...(tools ? { tools } : {}),
      });
      return textOf(msg);
    } catch (err) {
      lastErr = err;
      const status = (err as { status?: number })?.status;
      if (status && status < 500 && status !== 429) throw err; // non-retryable
      await new Promise((r) => setTimeout(r, 500 * 2 ** attempt));
    }
  }
  throw lastErr;
}
```

- [ ] **Step 2: Type-check**

Run: `npx tsc --noEmit`
Expected: no errors. (If the SDK's `Tool` union rejects the web-search tool type, keep the `as unknown as` cast and verify the exact tool `type` string via context7.)

- [ ] **Step 3: Commit**

```bash
git add src/lib/claude.ts
git commit -m "feat: add Anthropic client wrapper with retry + web-search option"
```

---

## Task 4: Data sources (TDD on parsers)

**Files:**
- Create: `src/lib/sources/coingecko.ts`
- Create: `src/lib/sources/vercelApi.ts`
- Create: `src/lib/sources/githubApi.ts`
- Test: `src/lib/sources/coingecko.test.ts`

Each source separates the pure parsing/formatting (tested) from the `fetch` call.

- [ ] **Step 1: Write the failing test `src/lib/sources/coingecko.test.ts`**

```ts
import { describe, it, expect } from 'vitest';
import { formatPrices, type CoinGeckoResponse } from './coingecko';

describe('coingecko formatPrices', () => {
  it('formats prices with 24h change and direction arrows', () => {
    const raw: CoinGeckoResponse = {
      bitcoin: { usd: 68000, usd_24h_change: 2.51 },
      ethereum: { usd: 3500, usd_24h_change: -1.2 },
    };
    const lines = formatPrices(raw);
    expect(lines).toContain('BTC $68,000.00 ▲ +2.51%');
    expect(lines).toContain('ETH $3,500.00 ▼ -1.20%');
  });

  it('handles missing change as flat', () => {
    const raw: CoinGeckoResponse = { bitcoin: { usd: 1, usd_24h_change: 0 } };
    expect(formatPrices(raw)).toContain('BTC $1.00 ▬ 0.00%');
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run src/lib/sources/coingecko.test.ts`
Expected: FAIL — `formatPrices` not defined.

- [ ] **Step 3: Implement `src/lib/sources/coingecko.ts`**

```ts
const IDS = ['bitcoin', 'ethereum', 'solana'] as const;
const SYMBOL: Record<string, string> = { bitcoin: 'BTC', ethereum: 'ETH', solana: 'SOL' };

export type CoinGeckoResponse = Record<string, { usd: number; usd_24h_change: number }>;

const money = (n: number) => `$${n.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

export function formatPrices(raw: CoinGeckoResponse): string[] {
  return Object.entries(raw).map(([id, { usd, usd_24h_change: chg }]) => {
    const arrow = chg > 0 ? '▲' : chg < 0 ? '▼' : '▬';
    const sign = chg > 0 ? '+' : '';
    const pct = chg === 0 ? '0.00%' : `${sign}${chg.toFixed(2)}%`;
    return `${SYMBOL[id] ?? id.toUpperCase()} ${money(usd)} ${arrow} ${pct}`;
  });
}

/** Fetch live prices. No API key needed for CoinGecko's free tier. */
export async function fetchPrices(): Promise<CoinGeckoResponse> {
  const url = `https://api.coingecko.com/api/v3/simple/price?ids=${IDS.join(',')}&vs_currencies=usd&include_24hr_change=true`;
  const res = await fetch(url, { headers: { accept: 'application/json' } });
  if (!res.ok) throw new Error(`CoinGecko ${res.status}`);
  return (await res.json()) as CoinGeckoResponse;
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `npx vitest run src/lib/sources/coingecko.test.ts`
Expected: PASS (2 tests).

- [ ] **Step 5: Implement `src/lib/sources/vercelApi.ts`**

```ts
const PROJECTS = ['nanoteofficial.me', 'finance.nanoteofficial.me', 'company.nanoteofficial.me'];

export interface DeployState { project: string; state: string; ok: boolean; createdAt: number | null; }

/** Latest deployment per project via the Vercel REST API. Requires VERCEL_TOKEN. */
export async function fetchDeployments(): Promise<DeployState[]> {
  const token = process.env.VERCEL_TOKEN;
  if (!token) throw new Error('VERCEL_TOKEN missing');
  const out: DeployState[] = [];
  for (const project of PROJECTS) {
    try {
      const res = await fetch(
        `https://api.vercel.com/v6/deployments?app=${encodeURIComponent(project)}&limit=1`,
        { headers: { Authorization: `Bearer ${token}` } },
      );
      if (!res.ok) { out.push({ project, state: `http ${res.status}`, ok: false, createdAt: null }); continue; }
      const data = (await res.json()) as { deployments?: Array<{ state?: string; readyState?: string; createdAt?: number }> };
      const d = data.deployments?.[0];
      const state = d?.readyState ?? d?.state ?? 'UNKNOWN';
      out.push({ project, state, ok: state === 'READY', createdAt: d?.createdAt ?? null });
    } catch {
      out.push({ project, state: 'error', ok: false, createdAt: null });
    }
  }
  return out;
}

export function formatDeployments(rows: DeployState[]): string[] {
  return rows.map((r) => `${r.ok ? '✅' : '⚠️'} ${r.project}: ${r.state}`);
}
```

- [ ] **Step 6: Implement `src/lib/sources/githubApi.ts`**

```ts
const REPOS = ['khantee8/nanoteofficial.me', 'khantee8/finance.nanoteofficial.me', 'khantee8/company.nanoteofficial.me'];

export interface RepoActivity { repo: string; lastCommit: string | null; lastCi: string | null; }

/** Recent commit + latest CI conclusion per repo. Requires GITHUB_TOKEN. */
export async function fetchActivity(): Promise<RepoActivity[]> {
  const token = process.env.GITHUB_TOKEN;
  const headers: Record<string, string> = { accept: 'application/vnd.github+json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const out: RepoActivity[] = [];
  for (const repo of REPOS) {
    try {
      const cRes = await fetch(`https://api.github.com/repos/${repo}/commits?per_page=1`, { headers });
      const commits = cRes.ok ? ((await cRes.json()) as Array<{ commit?: { message?: string } }>) : [];
      const lastCommit = commits[0]?.commit?.message?.split('\n')[0] ?? null;

      const wRes = await fetch(`https://api.github.com/repos/${repo}/actions/runs?per_page=1`, { headers });
      const runs = wRes.ok ? ((await wRes.json()) as { workflow_runs?: Array<{ conclusion?: string | null }> }) : { workflow_runs: [] };
      const lastCi = runs.workflow_runs?.[0]?.conclusion ?? null;

      out.push({ repo, lastCommit, lastCi });
    } catch {
      out.push({ repo, lastCommit: null, lastCi: null });
    }
  }
  return out;
}

export function formatActivity(rows: RepoActivity[]): string[] {
  return rows.map((r) => `${r.repo.split('/')[1]}: "${r.lastCommit ?? '—'}" · CI ${r.lastCi ?? 'n/a'}`);
}
```

- [ ] **Step 7: Type-check + commit**

Run: `npx tsc --noEmit`
Expected: no errors.
```bash
git add src/lib/sources/
git commit -m "feat: add CoinGecko/Vercel/GitHub data sources with formatter tests"
```

---

## Task 5: Agent personas

**Files:**
- Create: `src/lib/agents/personas.ts`

- [ ] **Step 1: Create `src/lib/agents/personas.ts`**

```ts
import type { DeptId } from '@/lib/data/departments';

/** System prompts per agent. Kept terse; the runner appends task-specific data in the user prompt. */
export const PERSONAS: Record<DeptId, string> = {
  ceo: 'You are the CEO of NaNote Corp, a small AI-run company. Voice: decisive, concise, strategic. You synthesize your team\'s daily work into a short standup summary and 2-3 concrete decisions. Output GitHub-flavored markdown.',
  mkt: 'You are the Marketing lead at NaNote Corp. Voice: punchy, on-brand, no fluff. You draft real, ready-to-post social content. Output GitHub-flavored markdown.',
  rnd: 'You are the R&D lead at NaNote Corp. Voice: analytical, evidence-driven. You produce a short, sourced research brief. Output GitHub-flavored markdown with a Sources list.',
  ops: 'You are the Operations/DevOps lead at NaNote Corp. Voice: terse, status-oriented. You report CI/CD and deployment health and flag anything that needs attention. Output GitHub-flavored markdown.',
  fin: 'You are the Finance lead at NaNote Corp. Voice: precise, numbers-first. You summarize market movement and give a brief, non-advice ROI read. Output GitHub-flavored markdown. Never give financial advice; this is informational only.',
};

export const PROJECTS_BLURB =
  'NaNote Corp ships: nanoteofficial.me (portfolio), finance.nanoteofficial.me (AI finance advisor), and company.nanoteofficial.me (this live AI office simulator). Founder: NaNote (Saksit Jantila), focus on technology strategy + cybersecurity.';
```

- [ ] **Step 2: Type-check + commit**

```bash
npx tsc --noEmit && git add src/lib/agents/personas.ts && git commit -m "feat: add agent personas"
```

---

## Task 6: Agent runner (TDD)

**Files:**
- Create: `src/lib/agents/runner.ts`
- Test: `src/lib/agents/runner.test.ts`

The runner wraps any agent `run()` with the status lifecycle, storage, feed event, and Telegram notify. Dependencies (repo, notify) are injected for testability.

- [ ] **Step 1: Write the failing test `src/lib/agents/runner.test.ts`**

```ts
import { describe, it, expect, vi } from 'vitest';
import { runAgent } from './runner';
import type { AgentRunResult } from './types';
import type { RedisRepo } from '@/lib/redis';

function fakeRepo() {
  return {
    setStatus: vi.fn(async () => {}),
    getStatus: vi.fn(async () => ({ dept: 'fin' as const, state: 'idle' as const, lastRun: null })),
    setOutput: vi.fn(async () => {}),
    getOutput: vi.fn(async () => null),
    pushEvent: vi.fn(async () => {}),
    getFeed: vi.fn(async () => []),
  } as unknown as RedisRepo;
}

describe('runAgent', () => {
  it('runs, stores output, pushes feed, notifies, sets done', async () => {
    const repo = fakeRepo();
    const notify = vi.fn(async () => {});
    const run = vi.fn(async (): Promise<AgentRunResult> => ({ markdown: '# x', summary: 's', feedMsg: 'did x' }));

    await runAgent({ dept: 'fin', run }, { repo, notify });

    expect(repo.setStatus).toHaveBeenCalledWith(expect.objectContaining({ dept: 'fin', state: 'running' }));
    expect(repo.setOutput).toHaveBeenCalledWith(expect.objectContaining({ dept: 'fin', markdown: '# x' }));
    expect(repo.pushEvent).toHaveBeenCalledWith(expect.objectContaining({ dept: 'fin', msg: 'did x' }));
    expect(notify).toHaveBeenCalledOnce();
    expect(repo.setStatus).toHaveBeenLastCalledWith(expect.objectContaining({ state: 'done', summary: 's' }));
  });

  it('on error sets error state, notifies, does not store output', async () => {
    const repo = fakeRepo();
    const notify = vi.fn(async () => {});
    const run = vi.fn(async (): Promise<AgentRunResult> => { throw new Error('boom'); });

    await expect(runAgent({ dept: 'rnd', run }, { repo, notify })).rejects.toThrow('boom');

    expect(repo.setOutput).not.toHaveBeenCalled();
    expect(repo.setStatus).toHaveBeenLastCalledWith(expect.objectContaining({ state: 'error', error: 'boom' }));
    expect(notify).toHaveBeenCalledWith(expect.stringContaining('failed'));
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run src/lib/agents/runner.test.ts`
Expected: FAIL — `runAgent` not defined.

- [ ] **Step 3: Implement `src/lib/agents/runner.ts`**

```ts
import type { DeptId } from '@/lib/data/departments';
import type { AgentRunResult } from './types';
import type { RedisRepo } from '@/lib/redis';

export interface Agent {
  dept: DeptId;
  run: () => Promise<AgentRunResult>;
}

export interface RunnerDeps {
  repo: RedisRepo;
  notify: (text: string) => Promise<void>;
}

/** Wraps an agent run with status lifecycle, persistence, feed event, and notification. */
export async function runAgent(agent: Agent, deps: RunnerDeps): Promise<AgentRunResult> {
  const { dept } = agent;
  const { repo, notify } = deps;
  const now = () => new Date().toISOString();

  await repo.setStatus({ dept, state: 'running', lastRun: now() });
  try {
    const result = await agent.run();
    const ts = now();
    await repo.setOutput({ dept, markdown: result.markdown, summary: result.summary, ts, meta: result.meta });
    await repo.pushEvent({ dept, msg: result.feedMsg, ts });
    await repo.setStatus({ dept, state: 'done', lastRun: ts, summary: result.summary });
    await notify(`*${dept.toUpperCase()}* ✓ ${result.summary}\n\n${result.markdown.slice(0, 800)}`);
    return result;
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    await repo.setStatus({ dept, state: 'error', lastRun: now(), error: message });
    await notify(`*${dept.toUpperCase()}* ⚠ failed: ${message}`);
    throw err;
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `npx vitest run src/lib/agents/runner.test.ts`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add src/lib/agents/runner.ts src/lib/agents/runner.test.ts
git commit -m "feat: add agent runner with status lifecycle + notify (tested)"
```

---

## Task 7: The five agents

**Files:**
- Create: `src/lib/agents/finance.ts`
- Create: `src/lib/agents/marketing.ts`
- Create: `src/lib/agents/rnd.ts`
- Create: `src/lib/agents/operations.ts`
- Create: `src/lib/agents/ceo.ts`
- Create: `src/lib/agents/index.ts` (registry)
- Test: `src/lib/agents/finance.test.ts`

Each exports `run(): Promise<AgentRunResult>`. They compose the data source + Claude.

- [ ] **Step 1: Write the failing test `src/lib/agents/finance.test.ts`** (pure ROI helper)

```ts
import { describe, it, expect } from 'vitest';
import { briefSummary } from './finance';

describe('finance briefSummary', () => {
  it('summarizes count + net direction from price lines', () => {
    const lines = ['BTC $1.00 ▲ +2.00%', 'ETH $1.00 ▼ -1.00%', 'SOL $1.00 ▲ +0.50%'];
    expect(briefSummary(lines)).toBe('3 assets tracked · net 2 up / 1 down');
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run src/lib/agents/finance.test.ts`
Expected: FAIL — `briefSummary` not defined.

- [ ] **Step 3: Implement `src/lib/agents/finance.ts`**

```ts
import { complete } from '@/lib/claude';
import { PERSONAS } from './personas';
import { fetchPrices, formatPrices } from '@/lib/sources/coingecko';
import type { AgentRunResult } from './types';

export function briefSummary(lines: string[]): string {
  const up = lines.filter((l) => l.includes('▲')).length;
  const down = lines.filter((l) => l.includes('▼')).length;
  return `${lines.length} assets tracked · net ${up} up / ${down} down`;
}

export async function run(): Promise<AgentRunResult> {
  const prices = await fetchPrices();
  const lines = formatPrices(prices);
  const markdown = await complete({
    system: PERSONAS.fin,
    prompt: `Today's market snapshot:\n${lines.join('\n')}\n\nWrite a brief (120-180 words) informational finance note: what moved, any notable divergence, and a one-line outlook. End with a disclaimer that this is not financial advice.`,
    maxTokens: 700,
  });
  return { markdown, summary: briefSummary(lines), feedMsg: `market: ${lines[0] ?? 'n/a'}`, meta: { lines } };
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `npx vitest run src/lib/agents/finance.test.ts`
Expected: PASS.

- [ ] **Step 5: Implement `src/lib/agents/marketing.ts`**

```ts
import { complete } from '@/lib/claude';
import { PERSONAS, PROJECTS_BLURB } from './personas';
import type { AgentRunResult } from './types';

export async function run(): Promise<AgentRunResult> {
  const markdown = await complete({
    system: PERSONAS.mkt,
    prompt: `${PROJECTS_BLURB}\n\nDraft today's marketing output as markdown with three sections: "## X post" (<=280 chars), "## LinkedIn post" (2-3 short paragraphs), "## Blog idea" (title + one-line angle). Make it specific to the projects above, not generic.`,
    maxTokens: 900,
  });
  return { markdown, summary: 'drafted X + LinkedIn + blog idea', feedMsg: 'drafted social content ✓' };
}
```

- [ ] **Step 6: Implement `src/lib/agents/rnd.ts`** (web search enabled)

```ts
import { complete } from '@/lib/claude';
import { PERSONAS } from './personas';
import type { AgentRunResult } from './types';

export async function run(): Promise<AgentRunResult> {
  const markdown = await complete({
    system: PERSONAS.rnd,
    prompt: 'Research one current, concrete trend in AI agents or developer tooling from the last few weeks. Write a 150-220 word brief: what changed, why it matters, one implication for a small AI-product studio. Include a short "## Sources" list with the links you used.',
    maxTokens: 1200,
    webSearch: true,
    maxSearches: 4,
  });
  return { markdown, summary: 'published a sourced trend brief', feedMsg: 'research brief ready 🔬' };
}
```

- [ ] **Step 7: Implement `src/lib/agents/operations.ts`**

```ts
import { complete } from '@/lib/claude';
import { PERSONAS } from './personas';
import { fetchDeployments, formatDeployments } from '@/lib/sources/vercelApi';
import { fetchActivity, formatActivity } from '@/lib/sources/githubApi';
import type { AgentRunResult } from './types';

export async function run(): Promise<AgentRunResult> {
  const [deploys, activity] = await Promise.all([
    fetchDeployments().catch(() => []),
    fetchActivity().catch(() => []),
  ]);
  const deployLines = formatDeployments(deploys);
  const activityLines = formatActivity(activity);
  const allOk = deploys.length > 0 && deploys.every((d) => d.ok);

  const markdown = await complete({
    system: PERSONAS.ops,
    prompt: `CI/CD snapshot.\n\nDeployments:\n${deployLines.join('\n') || 'none'}\n\nRepo activity:\n${activityLines.join('\n') || 'none'}\n\nWrite a terse ops status (80-140 words): overall health, anything failing or stale, and the single most useful next action. Use a status emoji header.`,
    maxTokens: 600,
  });
  return {
    markdown,
    summary: allOk ? 'all deployments healthy' : 'deploy attention needed',
    feedMsg: allOk ? 'all systems green 🚀' : 'deploy issue flagged ⚠',
    meta: { deploys, activity },
  };
}
```

- [ ] **Step 8: Implement `src/lib/agents/ceo.ts`** (reads others from Redis)

```ts
import { complete } from '@/lib/claude';
import { PERSONAS } from './personas';
import { getRepo } from '@/lib/redis';
import type { AgentRunResult } from './types';
import type { DeptId } from '@/lib/data/departments';

const TEAM: DeptId[] = ['mkt', 'rnd', 'ops', 'fin'];

export async function run(): Promise<AgentRunResult> {
  const repo = getRepo();
  const outputs = await Promise.all(TEAM.map((d) => repo.getOutput(d)));
  const digest = TEAM.map((d, i) => `### ${d.toUpperCase()}\n${outputs[i]?.summary ?? 'no output today'}`).join('\n\n');

  const markdown = await complete({
    system: PERSONAS.ceo,
    prompt: `Your team's outputs today:\n\n${digest}\n\nWrite a short standup: "## Summary" (3-4 sentences) and "## Decisions" (2-3 bullets, concrete and actionable for tomorrow).`,
    maxTokens: 700,
  });
  return { markdown, summary: 'company standup + decisions', feedMsg: 'standup complete 📋' };
}
```

- [ ] **Step 9: Implement `src/lib/agents/index.ts`** (registry)

```ts
import type { DeptId } from '@/lib/data/departments';
import type { AgentRunResult } from './types';
import * as finance from './finance';
import * as marketing from './marketing';
import * as rnd from './rnd';
import * as operations from './operations';
import * as ceo from './ceo';

/** dept id → run function. */
export const AGENTS: Record<DeptId, () => Promise<AgentRunResult>> = {
  fin: finance.run,
  mkt: marketing.run,
  rnd: rnd.run,
  ops: operations.run,
  ceo: ceo.run,
};

export const isDeptId = (s: string): s is DeptId =>
  s === 'ceo' || s === 'mkt' || s === 'rnd' || s === 'ops' || s === 'fin';
```

- [ ] **Step 10: Type-check, run all tests, commit**

Run: `npx tsc --noEmit && npx vitest run`
Expected: all green (existing v0.1 tests + new ones).
```bash
git add src/lib/agents/
git commit -m "feat: add five real agents (finance/marketing/rnd/ops/ceo) + registry"
```

---

## Task 8: Telegram library (TDD on parser + allowlist)

**Files:**
- Create: `src/lib/telegram.ts`
- Test: `src/lib/telegram.test.ts`

- [ ] **Step 1: Write the failing test `src/lib/telegram.test.ts`**

```ts
import { describe, it, expect } from 'vitest';
import { parseCommand, isAllowedChat } from './telegram';

describe('telegram parseCommand', () => {
  it('parses /status', () => {
    expect(parseCommand('/status')).toEqual({ cmd: 'status', args: [] });
  });
  it('parses /run with a dept', () => {
    expect(parseCommand('/run finance')).toEqual({ cmd: 'run', args: ['finance'] });
  });
  it('parses /ask with dept + question', () => {
    expect(parseCommand('/ask rnd what is new in agents?')).toEqual({ cmd: 'ask', args: ['rnd', 'what is new in agents?'] });
  });
  it('strips @botname suffix', () => {
    expect(parseCommand('/status@NaNoteBot')).toEqual({ cmd: 'status', args: [] });
  });
  it('returns null for non-commands', () => {
    expect(parseCommand('hello')).toBeNull();
  });
});

describe('isAllowedChat', () => {
  it('matches the configured chat id', () => {
    expect(isAllowedChat(12345, '12345')).toBe(true);
    expect(isAllowedChat(999, '12345')).toBe(false);
    expect(isAllowedChat(12345, undefined)).toBe(false);
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run src/lib/telegram.test.ts`
Expected: FAIL — exports not defined.

- [ ] **Step 3: Implement `src/lib/telegram.ts`**

```ts
export type TgCommand = 'status' | 'run' | 'ask' | 'help';
export interface ParsedCommand { cmd: TgCommand; args: string[]; }

const KNOWN: TgCommand[] = ['status', 'run', 'ask', 'help'];

/** Parse a Telegram text into a command. `/ask` keeps the question as a single trailing arg. */
export function parseCommand(text: string): ParsedCommand | null {
  if (!text.startsWith('/')) return null;
  const [head, ...rest] = text.trim().split(/\s+/);
  const cmd = head.slice(1).split('@')[0].toLowerCase() as TgCommand;
  if (!KNOWN.includes(cmd)) return null;
  if (cmd === 'ask') {
    const [dept, ...q] = rest;
    return { cmd, args: dept ? [dept, q.join(' ')] : [] };
  }
  return { cmd, args: rest };
}

export function isAllowedChat(chatId: number | string, allowed: string | undefined): boolean {
  return !!allowed && String(chatId) === String(allowed);
}

/** Send a message via the Bot API. Never throws — notification failures must not break a run. */
export async function sendMessage(text: string, chatId?: string): Promise<void> {
  const token = process.env.TELEGRAM_BOT_TOKEN;
  const chat = chatId ?? process.env.TELEGRAM_ALLOWED_CHAT_ID;
  if (!token || !chat) return;
  try {
    await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ chat_id: chat, text, parse_mode: 'Markdown', disable_web_page_preview: true }),
    });
  } catch {
    /* swallow — best-effort notify */
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `npx vitest run src/lib/telegram.test.ts`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add src/lib/telegram.ts src/lib/telegram.test.ts
git commit -m "feat: add telegram lib — command parser, allowlist, sendMessage (tested)"
```

---

## Task 9: Cron run route

**Files:**
- Create: `src/app/api/cron/run/route.ts`

- [ ] **Step 1: Implement `src/app/api/cron/run/route.ts`**

```ts
import { NextRequest, NextResponse } from 'next/server';
import { AGENTS, isDeptId } from '@/lib/agents';
import { runAgent } from '@/lib/agents/runner';
import { getRepo } from '@/lib/redis';
import { sendMessage } from '@/lib/telegram';

export const dynamic = 'force-dynamic';
export const maxDuration = 300; // Fluid Compute (Hobby)

function authorized(req: NextRequest): boolean {
  const secret = process.env.CRON_SECRET;
  if (!secret) return false;
  return req.headers.get('authorization') === `Bearer ${secret}`;
}

export async function GET(req: NextRequest) {
  if (!authorized(req)) return new NextResponse('unauthorized', { status: 401 });
  const dept = req.nextUrl.searchParams.get('dept');
  if (!dept || !isDeptId(dept)) return new NextResponse('bad dept', { status: 400 });

  try {
    const result = await runAgent(
      { dept, run: AGENTS[dept] },
      { repo: getRepo(), notify: (t) => sendMessage(t) },
    );
    return NextResponse.json({ ok: true, dept, summary: result.summary });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return NextResponse.json({ ok: false, dept, error: message }, { status: 500 });
  }
}
```

- [ ] **Step 2: Type-check**

Run: `npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 3: Manual smoke (after env is set locally — see Task 16)**

This is verified end-to-end in Task 17 against the deployed app. Locally, with `.env.local` populated:
```bash
npm run dev
curl -s -H "Authorization: Bearer $CRON_SECRET" "http://localhost:3000/api/cron/run?dept=fin"
```
Expected: `{"ok":true,"dept":"fin",...}` and a Telegram message (if configured).

- [ ] **Step 4: Commit**

```bash
git add src/app/api/cron/run/route.ts
git commit -m "feat: add /api/cron/run — secret-protected agent trigger"
```

---

## Task 10: Read APIs (agents + feed)

**Files:**
- Create: `src/app/api/agents/route.ts`
- Create: `src/app/api/feed/route.ts`

- [ ] **Step 1: Implement `src/app/api/agents/route.ts`**

```ts
import { NextResponse } from 'next/server';
import { getRepo } from '@/lib/redis';
import { DEPARTMENTS } from '@/lib/data/departments';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const repo = getRepo();
    const data = await Promise.all(
      DEPARTMENTS.map(async (d) => ({
        dept: d.id,
        status: await repo.getStatus(d.id),
        output: await repo.getOutput(d.id),
      })),
    );
    return NextResponse.json({ agents: data });
  } catch {
    return NextResponse.json({ agents: [] });
  }
}
```

- [ ] **Step 2: Implement `src/app/api/feed/route.ts`**

```ts
import { NextResponse } from 'next/server';
import { getRepo } from '@/lib/redis';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const events = await getRepo().getFeed(30);
    return NextResponse.json({ events });
  } catch {
    return NextResponse.json({ events: [] });
  }
}
```

- [ ] **Step 3: Type-check + commit**

```bash
npx tsc --noEmit && git add src/app/api/agents/route.ts src/app/api/feed/route.ts
git commit -m "feat: add /api/agents and /api/feed read endpoints"
```

---

## Task 11: Telegram webhook

**Files:**
- Create: `src/app/api/telegram/route.ts`

Handles updates, verifies the secret + chat allowlist, dispatches commands. `/run` uses `after()` so the webhook returns fast while the agent runs in the background.

- [ ] **Step 1: Implement `src/app/api/telegram/route.ts`**

```ts
import { NextRequest, NextResponse } from 'next/server';
import { after } from 'next/server';
import { parseCommand, isAllowedChat, sendMessage } from '@/lib/telegram';
import { AGENTS, isDeptId } from '@/lib/agents';
import { runAgent } from '@/lib/agents/runner';
import { getRepo } from '@/lib/redis';
import { complete } from '@/lib/claude';
import { PERSONAS } from '@/lib/agents/personas';
import { DEPARTMENTS } from '@/lib/data/departments';

export const dynamic = 'force-dynamic';
export const maxDuration = 300;

const NAME_TO_ID: Record<string, string> = {
  finance: 'fin', fin: 'fin', marketing: 'mkt', mkt: 'mkt',
  rnd: 'rnd', research: 'rnd', operations: 'ops', ops: 'ops', ceo: 'ceo',
};

export async function POST(req: NextRequest) {
  // Verify Telegram secret token header.
  if (req.headers.get('x-telegram-bot-api-secret-token') !== process.env.TELEGRAM_WEBHOOK_SECRET) {
    return new NextResponse('forbidden', { status: 403 });
  }
  const update = (await req.json().catch(() => null)) as
    | { message?: { chat?: { id?: number }; text?: string } }
    | null;
  const chatId = update?.message?.chat?.id;
  const text = update?.message?.text ?? '';

  // Always 200 to Telegram; just ignore disallowed/unparseable.
  if (chatId == null || !isAllowedChat(chatId, process.env.TELEGRAM_ALLOWED_CHAT_ID)) {
    return NextResponse.json({ ok: true });
  }
  const parsed = parseCommand(text);
  if (!parsed) {
    await sendMessage('Unknown command. Try /help', String(chatId));
    return NextResponse.json({ ok: true });
  }

  const reply = (t: string) => sendMessage(t, String(chatId));

  if (parsed.cmd === 'help') {
    await reply('Commands:\n/status — all agents\n/run <dept> — trigger a run\n/ask <dept> <question>\nDepts: finance, marketing, rnd, operations, ceo');
  } else if (parsed.cmd === 'status') {
    const repo = getRepo();
    const lines = await Promise.all(
      DEPARTMENTS.map(async (d) => {
        const s = await repo.getStatus(d.id);
        return `${d.shortName}: ${s.state}${s.summary ? ` — ${s.summary}` : ''}`;
      }),
    );
    await reply(lines.join('\n'));
  } else if (parsed.cmd === 'run') {
    const id = NAME_TO_ID[(parsed.args[0] ?? '').toLowerCase()];
    if (!id || !isDeptId(id)) { await reply('Usage: /run <finance|marketing|rnd|operations|ceo>'); return NextResponse.json({ ok: true }); }
    await reply(`▶ running ${id}…`);
    after(async () => {
      try {
        await runAgent({ dept: id, run: AGENTS[id] }, { repo: getRepo(), notify: (t) => sendMessage(t, String(chatId)) });
      } catch { /* runAgent already notified */ }
    });
  } else if (parsed.cmd === 'ask') {
    const id = NAME_TO_ID[(parsed.args[0] ?? '').toLowerCase()];
    const question = parsed.args[1] ?? '';
    if (!id || !isDeptId(id) || !question) { await reply('Usage: /ask <dept> <question>'); return NextResponse.json({ ok: true }); }
    after(async () => {
      try {
        const answer = await complete({ system: PERSONAS[id], prompt: question, maxTokens: 600 });
        await sendMessage(`*${id.toUpperCase()}*: ${answer}`, String(chatId));
      } catch (e) {
        await sendMessage(`⚠ ask failed: ${e instanceof Error ? e.message : 'error'}`, String(chatId));
      }
    });
  }

  return NextResponse.json({ ok: true });
}
```

- [ ] **Step 2: Type-check + commit**

```bash
npx tsc --noEmit && git add src/app/api/telegram/route.ts
git commit -m "feat: add telegram webhook — status/run/ask, secret + chat allowlist, async via after()"
```

---

## Task 12: Vercel deploy webhook → Telegram

**Files:**
- Create: `src/app/api/webhooks/vercel/route.ts`

- [ ] **Step 1: Implement `src/app/api/webhooks/vercel/route.ts`**

```ts
import { NextRequest, NextResponse } from 'next/server';
import { sendMessage } from '@/lib/telegram';
import { getRepo } from '@/lib/redis';

export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  const body = (await req.json().catch(() => null)) as
    | { type?: string; payload?: { deployment?: { url?: string }; name?: string; target?: string } }
    | null;
  if (!body?.type) return NextResponse.json({ ok: true });

  const name = body.payload?.name ?? 'project';
  const url = body.payload?.deployment?.url ?? '';
  let msg: string | null = null;
  if (body.type === 'deployment.succeeded' || body.type === 'deployment.ready') msg = `✅ Deploy ready: ${name} ${url}`;
  else if (body.type === 'deployment.error') msg = `⚠️ Deploy failed: ${name} ${url}`;

  if (msg) {
    await sendMessage(msg);
    try { await getRepo().pushEvent({ dept: 'ops', msg: msg.replace(/^[✅⚠️]\s*/, ''), ts: new Date().toISOString() }); } catch { /* ignore */ }
  }
  return NextResponse.json({ ok: true });
}
```

> Note: Vercel webhooks can be signature-verified via the `x-vercel-signature` header (HMAC-SHA1 of the raw body with the webhook secret). If `VERCEL_WEBHOOK_SECRET` is set, verify it; otherwise accept (the endpoint only emits notifications, no state mutation). Verify the exact header/algorithm via Vercel docs at implementation time.

- [ ] **Step 2: Type-check + commit**

```bash
npx tsc --noEmit && git add src/app/api/webhooks/vercel/route.ts
git commit -m "feat: add Vercel deploy webhook → Telegram CI/CD alerts"
```

---

## Task 13: Cron configuration

**Files:**
- Create: `vercel.json`

- [ ] **Step 1: Create `vercel.json`**

Five daily jobs, staggered UTC, CEO last so it summarizes the day's fresh outputs.

```json
{
  "crons": [
    { "path": "/api/cron/run?dept=fin", "schedule": "0 11 * * *" },
    { "path": "/api/cron/run?dept=rnd", "schedule": "0 12 * * *" },
    { "path": "/api/cron/run?dept=mkt", "schedule": "0 13 * * *" },
    { "path": "/api/cron/run?dept=ops", "schedule": "0 14 * * *" },
    { "path": "/api/cron/run?dept=ceo", "schedule": "0 15 * * *" }
  ]
}
```

> Vercel Cron automatically sends `Authorization: Bearer $CRON_SECRET` when `CRON_SECRET` is set in project env — that's what `/api/cron/run` checks. Hobby runs each job once/day, possibly anywhere within the scheduled hour.

- [ ] **Step 2: Build to confirm Vercel accepts the cron config**

Run: `npm run build`
Expected: build succeeds (cron schedules are validated at deploy, but the build should not error).

- [ ] **Step 3: Commit**

```bash
git add vercel.json
git commit -m "feat: add daily staggered cron schedule for the five agents"
```

---

## Task 14: TerminalFeed → poll real feed

**Files:**
- Modify: `src/components/TerminalFeed.tsx`

Replace the simulated `LOG_MESSAGES` source with polling `/api/feed`, keeping the existing visual style (timestamp, dept tag, colored text, cursor, clock). The `onLog` callback still surfaces the latest event to the sidebar.

- [ ] **Step 1: Rewrite `src/components/TerminalFeed.tsx`**

```tsx
'use client';

import { useEffect, useRef, useState } from 'react';
import type { DeptId } from '@/lib/data/departments';
import type { FeedEvent } from '@/lib/agents/types';

const POLL_MS = 8000;
const MAX_LINES = 5;

interface DisplayedLog { time: string; dept: DeptId; msg: string; id: string; }
interface Props { onLog?: (dept: DeptId, plainText: string) => void; }

function hhmmss(iso: string): string {
  const d = new Date(iso);
  return [d.getHours(), d.getMinutes(), d.getSeconds()].map((v) => String(v).padStart(2, '0')).join(':');
}
function nowTime(): string {
  const n = new Date();
  return [n.getHours(), n.getMinutes(), n.getSeconds()].map((v) => String(v).padStart(2, '0')).join(':');
}
function deptColor(d: DeptId): string {
  return { ceo: '#ffdd57', mkt: '#ff6b9d', rnd: '#00cfff', ops: '#ff9a3c', fin: '#7f8cff' }[d];
}

export function TerminalFeed({ onLog }: Props) {
  const [lines, setLines] = useState<DisplayedLog[]>([]);
  const [clock, setClock] = useState(nowTime());
  const onLogRef = useRef(onLog);
  useEffect(() => { onLogRef.current = onLog; }, [onLog]);

  useEffect(() => {
    let alive = true;
    const poll = async () => {
      try {
        const res = await fetch('/api/feed', { cache: 'no-store' });
        const { events } = (await res.json()) as { events: FeedEvent[] };
        if (!alive || !events?.length) return;
        const display = events.slice(0, MAX_LINES).reverse().map((e) => ({
          time: hhmmss(e.ts), dept: e.dept, msg: e.msg, id: `${e.ts}-${e.dept}-${e.msg}`,
        }));
        setLines(display);
        const newest = events[0];
        if (newest) onLogRef.current?.(newest.dept, newest.msg.slice(0, 28));
      } catch { /* keep last */ }
    };
    poll();
    const feedInterval = setInterval(poll, POLL_MS);
    const clockInterval = setInterval(() => setClock(nowTime()), 1000);
    return () => { alive = false; clearInterval(feedInterval); clearInterval(clockInterval); };
  }, []);

  return (
    <div style={terminalStyle}>
      <div style={headStyle}>◈ LIVE PIPELINE FEED <span suppressHydrationWarning>{clock}</span></div>
      <div style={bodyStyle}>
        <div style={linesStyle}>
          {lines.length === 0 && <div style={{ ...lineStyle, color: '#333' }}>warming up — agents run daily…</div>}
          {lines.map((l, i) => {
            const isLast = i === lines.length - 1;
            return (
              <div key={l.id} style={lineStyle}>
                <span style={tsStyle}>{l.time}</span>
                <span style={{ ...tdStyle, color: deptColor(l.dept) }}>[{l.dept.toUpperCase()}]</span>
                <span style={tmStyle}>{l.msg}{isLast && <span style={cursorStyle} />}</span>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

const terminalStyle: React.CSSProperties = { height: 106, minHeight: 106, background: '#060614', borderTop: '1px solid #0e0e20', display: 'flex', flexDirection: 'column', flexShrink: 0 };
const headStyle: React.CSSProperties = { padding: '4px 14px', fontSize: 8, color: '#2a2a4a', letterSpacing: 2, borderBottom: '1px solid #0d0d1e', flexShrink: 0, display: 'flex', gap: 20 };
const bodyStyle: React.CSSProperties = { flex: 1, overflow: 'hidden', position: 'relative' };
const linesStyle: React.CSSProperties = { position: 'absolute', bottom: 4, left: 0, right: 0, padding: '0 14px' };
const lineStyle: React.CSSProperties = { fontSize: 9, lineHeight: 1.9, display: 'flex', gap: 8 };
const tsStyle: React.CSSProperties = { color: '#1a1a38', minWidth: 66 };
const tdStyle: React.CSSProperties = { minWidth: 42, fontWeight: 'bold' };
const tmStyle: React.CSSProperties = { color: '#444', flex: 1 };
const cursorStyle: React.CSSProperties = { display: 'inline-block', width: 6, height: 10, background: '#00ff88', animation: 'dp 1s step-end infinite', verticalAlign: 'bottom', marginLeft: 4 };
```

- [ ] **Step 2: Type-check + lint**

Run: `npx tsc --noEmit && npm run lint`
Expected: no errors. (`src/lib/data/logMessages.ts` may now be unused — leave it; removal is optional and out of scope.)

- [ ] **Step 3: Commit**

```bash
git add src/components/TerminalFeed.tsx
git commit -m "feat: TerminalFeed polls /api/feed for real agent events"
```

---

## Task 15: ArtifactPanel + sidebar real status

**Files:**
- Create: `src/components/ArtifactPanel.tsx`
- Create: `src/components/Markdown.tsx`
- Modify: `src/components/DepartmentSidebar.tsx`

- [ ] **Step 1: Create a minimal safe markdown renderer `src/components/Markdown.tsx`**

No `dangerouslySetInnerHTML`. Renders headings, bullets, and paragraphs as React elements. Good enough for agent artifacts.

```tsx
'use client';

import React from 'react';

/** Tiny, safe markdown subset renderer: #/##/### headings, - bullets, blank-line paragraphs. */
export function Markdown({ text }: { text: string }) {
  const blocks: React.ReactNode[] = [];
  const lines = text.split('\n');
  let list: string[] = [];
  const flushList = (key: string) => {
    if (list.length) {
      blocks.push(<ul key={key} style={{ margin: '4px 0 8px', paddingLeft: 16 }}>{list.map((li, i) => <li key={i} style={{ fontSize: 11, lineHeight: 1.5, color: '#bbb' }}>{li}</li>)}</ul>);
      list = [];
    }
  };
  lines.forEach((raw, i) => {
    const line = raw.trimEnd();
    if (/^###\s+/.test(line)) { flushList(`l${i}`); blocks.push(<h4 key={i} style={{ fontSize: 11, color: '#fff', margin: '8px 0 2px' }}>{line.replace(/^###\s+/, '')}</h4>); }
    else if (/^##\s+/.test(line)) { flushList(`l${i}`); blocks.push(<h3 key={i} style={{ fontSize: 12, color: '#fff', margin: '10px 0 3px' }}>{line.replace(/^##\s+/, '')}</h3>); }
    else if (/^#\s+/.test(line)) { flushList(`l${i}`); blocks.push(<h2 key={i} style={{ fontSize: 13, color: '#fff', margin: '10px 0 4px' }}>{line.replace(/^#\s+/, '')}</h2>); }
    else if (/^[-*]\s+/.test(line)) { list.push(line.replace(/^[-*]\s+/, '')); }
    else if (line === '') { flushList(`l${i}`); }
    else { flushList(`l${i}`); blocks.push(<p key={i} style={{ fontSize: 11, lineHeight: 1.6, color: '#bbb', margin: '0 0 6px' }}>{line}</p>); }
  });
  flushList('end');
  return <div>{blocks}</div>;
}
```

- [ ] **Step 2: Create `src/components/ArtifactPanel.tsx`**

```tsx
'use client';

import { Markdown } from './Markdown';
import { DEPARTMENTS, type DeptId } from '@/lib/data/departments';
import type { AgentOutput, AgentStatus } from '@/lib/agents/types';

interface Props {
  dept: DeptId;
  status: AgentStatus | null;
  output: AgentOutput | null;
  onClose: () => void;
}

export function ArtifactPanel({ dept, status, output, onClose }: Props) {
  const meta = DEPARTMENTS.find((d) => d.id === dept);
  const when = output?.ts ? new Date(output.ts).toLocaleString() : status?.lastRun ? new Date(status.lastRun).toLocaleString() : '—';
  return (
    <div style={panelStyle}>
      <div style={headerStyle}>
        <span style={{ color: meta?.color, fontWeight: 'bold', fontSize: 12 }}>{meta?.name ?? dept}</span>
        <button onClick={onClose} style={closeStyle}>✕</button>
      </div>
      <div style={subStyle}>state: {status?.state ?? 'idle'} · updated {when}</div>
      <div style={contentStyle}>
        {output?.markdown ? <Markdown text={output.markdown} /> : <div style={{ color: '#444', fontSize: 11 }}>No artifact yet — this agent runs on a daily schedule. Use the Telegram bot /run to trigger it now.</div>}
      </div>
    </div>
  );
}

const panelStyle: React.CSSProperties = { position: 'absolute', top: 12, right: 12, width: 320, maxHeight: 'calc(100% - 24px)', background: '#0b0b1eee', border: '1px solid #1e1e40', borderRadius: 8, display: 'flex', flexDirection: 'column', overflow: 'hidden', zIndex: 5, backdropFilter: 'blur(4px)' };
const headerStyle: React.CSSProperties = { display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '8px 12px', borderBottom: '1px solid #1a1a3a' };
const subStyle: React.CSSProperties = { padding: '4px 12px', fontSize: 8, color: '#555', borderBottom: '1px solid #12122a' };
const contentStyle: React.CSSProperties = { padding: '8px 12px', overflowY: 'auto' };
const closeStyle: React.CSSProperties = { background: 'transparent', border: 'none', color: '#888', cursor: 'pointer', fontSize: 12 };
```

- [ ] **Step 3: Verify sidebar already accepts real `taskTexts`**

`DepartmentSidebar` already takes `taskTexts: Record<DeptId, string>` and renders status dots from `dept.task`. No change needed for task text (OfficeApp will feed it real summaries in Task 16). Confirm the file compiles unchanged.

- [ ] **Step 4: Type-check + commit**

```bash
npx tsc --noEmit && git add src/components/ArtifactPanel.tsx src/components/Markdown.tsx
git commit -m "feat: add ArtifactPanel + safe markdown renderer for real agent output"
```

---

## Task 16: Wire OfficeApp with real polling

**Files:**
- Modify: `src/components/OfficeApp.tsx`

Poll `/api/agents` every ~8s; feed real summaries into the sidebar task texts; render `ArtifactPanel` for the selected dept.

- [ ] **Step 1: Rewrite `src/components/OfficeApp.tsx`**

```tsx
'use client';

import { useState, useCallback, useEffect } from 'react';
import { TopBar } from './TopBar';
import { DepartmentSidebar } from './DepartmentSidebar';
import { OfficeCanvas } from './OfficeCanvas';
import { TerminalFeed } from './TerminalFeed';
import { ArtifactPanel } from './ArtifactPanel';
import { DEPARTMENTS, type DeptId } from '@/lib/data/departments';
import type { AgentStatus, AgentOutput } from '@/lib/agents/types';

const TERMINAL_HEIGHT = 106;
const POLL_MS = 8000;

interface AgentRow { dept: DeptId; status: AgentStatus; output: AgentOutput | null; }

export function OfficeApp() {
  const [selectedDept, setSelectedDept] = useState<DeptId | null>(null);
  const [taskTexts, setTaskTexts] = useState<Record<DeptId, string>>(() =>
    Object.fromEntries(DEPARTMENTS.map((d) => [d.id, d.task])) as Record<DeptId, string>,
  );
  const [agents, setAgents] = useState<Record<DeptId, AgentRow>>(() => ({}) as Record<DeptId, AgentRow>);

  useEffect(() => {
    let alive = true;
    const poll = async () => {
      try {
        const res = await fetch('/api/agents', { cache: 'no-store' });
        const { agents: rows } = (await res.json()) as { agents: AgentRow[] };
        if (!alive || !rows?.length) return;
        const map = Object.fromEntries(rows.map((r) => [r.dept, r])) as Record<DeptId, AgentRow>;
        setAgents(map);
        setTaskTexts((prev) => {
          const next = { ...prev };
          for (const r of rows) if (r.status?.summary) next[r.dept] = '● ' + r.status.summary;
          return next;
        });
      } catch { /* keep last */ }
    };
    poll();
    const id = setInterval(poll, POLL_MS);
    return () => { alive = false; clearInterval(id); };
  }, []);

  const handleLog = useCallback((dept: DeptId, plainText: string) => {
    setTaskTexts((prev) => ({ ...prev, [dept]: '● ' + plainText }));
  }, []);

  const resetView = () => setSelectedDept(null);
  const selected = selectedDept ? agents[selectedDept] : null;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100vh', overflow: 'hidden' }}>
      <TopBar focusedDept={selectedDept} onResetView={resetView} />
      <div style={{ flex: 1, display: 'flex', overflow: 'hidden', minHeight: 0 }}>
        <DepartmentSidebar selectedDept={selectedDept} onSelect={setSelectedDept} taskTexts={taskTexts} />
        <main style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden', minWidth: 0, position: 'relative' }}>
          <div style={{ flex: 1, minHeight: 0, position: 'relative' }}>
            <OfficeCanvas selectedDept={selectedDept} terminalHeight={TERMINAL_HEIGHT} />
            {selectedDept && (
              <ArtifactPanel
                dept={selectedDept}
                status={selected?.status ?? null}
                output={selected?.output ?? null}
                onClose={resetView}
              />
            )}
          </div>
          <TerminalFeed onLog={handleLog} />
        </main>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Type-check, lint, build**

Run: `npx tsc --noEmit && npm run lint && npm run build`
Expected: all pass; routes now include `/api/agents`, `/api/feed`, `/api/cron/run`, `/api/telegram`, `/api/webhooks/vercel`.

- [ ] **Step 3: Local visual check**

```bash
npm run dev
```
Open `http://localhost:3000`. With no Redis configured locally the office still renders (feed shows "warming up", sidebar shows v0.1 default tasks, clicking a dept opens the ArtifactPanel with the "No artifact yet" message). No console errors beyond the known dev favicon probe.

- [ ] **Step 4: Commit**

```bash
git add src/components/OfficeApp.tsx
git commit -m "feat: OfficeApp polls /api/agents, shows real task text + ArtifactPanel"
```

---

## Task 17: Provisioning + manual end-to-end verification

**Files:** none (infra + manual steps). Requires the user for credentials.

- [ ] **Step 1: Provision Upstash Redis**

In the Vercel dashboard → the `company` project → Storage → Marketplace → **Upstash → Redis** → create a database and connect it. This auto-injects `UPSTASH_REDIS_REST_URL` + `UPSTASH_REDIS_REST_TOKEN` into the project env. Mirror them into `.env.local` for local testing.

- [ ] **Step 2: Set the remaining env vars in Vercel** (Project → Settings → Environment Variables)

`ANTHROPIC_API_KEY`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_WEBHOOK_SECRET`, `TELEGRAM_ALLOWED_CHAT_ID`, `VERCEL_TOKEN`, `GITHUB_TOKEN`, `CRON_SECRET` (and `VERCEL_WEBHOOK_SECRET` if used). Use the same values in `.env.local`.

- [ ] **Step 3: Create the Telegram bot**

Via @BotFather: create bot → copy token → set `TELEGRAM_BOT_TOKEN`. Get your chat id (e.g., message @userinfobot) → `TELEGRAM_ALLOWED_CHAT_ID`. Pick a random `TELEGRAM_WEBHOOK_SECRET`.

- [ ] **Step 4: Local end-to-end smoke (after deploy of Tasks 1-16)**

```bash
cd /project/src/company.nanoteofficial.me
npm run dev
# trigger each agent
for d in fin rnd mkt ops ceo; do curl -s -H "Authorization: Bearer $CRON_SECRET" "http://localhost:3000/api/cron/run?dept=$d"; echo; done
curl -s http://localhost:3000/api/agents | head -c 400
curl -s http://localhost:3000/api/feed | head -c 400
```
Expected: each returns `{"ok":true,...}`, `/api/agents` shows `done` statuses with outputs, `/api/feed` lists events, and Telegram receives reports.

- [ ] **Step 5: Register the Telegram webhook (against production URL)** — after Task 18 deploy

```bash
curl "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/setWebhook" \
  -d "url=https://company.nanoteofficial.me/api/telegram" \
  -d "secret_token=$TELEGRAM_WEBHOOK_SECRET"
```
Then in Telegram send `/help`, `/status`, `/run finance`, `/ask rnd what's new in AI agents?` and confirm replies.

- [ ] **Step 6: Configure the Vercel deploy webhook**

Vercel project → Settings → Webhooks → add `https://company.nanoteofficial.me/api/webhooks/vercel` for `deployment.succeeded` + `deployment.error`. Trigger a deploy and confirm the Telegram alert.

---

## Task 18: Deploy to production

**Files:**
- Modify: `/project/CLAUDE.md` (update the company entry for v0.2)

- [ ] **Step 1: Final verification**

```bash
cd /project/src/company.nanoteofficial.me
npx vitest run && npx tsc --noEmit && npm run lint && npm run build
```
All must pass.

- [ ] **Step 2: Push (auto-deploys via the connected Vercel project)**

```bash
git push origin main
```
Confirm env vars are set in Vercel (Task 17) before/with this deploy.

- [ ] **Step 3: Verify production** (use a normal browser/network — recall headless polling can trip Vercel's bot challenge)

- Visit `https://company.nanoteofficial.me` → office renders, feed/sidebar update after the first agent runs (or after a manual `/run`).
- Click a department → ArtifactPanel shows the latest real artifact once available.
- Exercise the Telegram commands (Task 17 Step 5).
- Wait for the next cron window (or `/run`) and confirm Redis/feed/Telegram update.

- [ ] **Step 4: Update root `CLAUDE.md`**

Update the `company.nanoteofficial.me` section to note v0.2: real Claude agents (daily Vercel Cron), Upstash Redis, polling office UI, two-way Telegram bot, CI/CD deploy webhook. List the new env vars.

- [ ] **Step 5: Commit + tag**

```bash
cd /project && git add CLAUDE.md && git commit -m "docs: update company.nanoteofficial.me entry for v0.2" && git push origin main
cd /project/src/company.nanoteofficial.me && git tag v0.2.0 && git push origin v0.2.0
```

---

## Self-Review

### Spec coverage

| Spec section | Task(s) |
|---|---|
| §2 Decisions (cloud-only, Hobby, Upstash, polling) | Tasks 1, 2, 9-13, 14-16 |
| §3 Architecture & data flow | Tasks 6, 9-12, 14-16 |
| §4 Five agents + data sources | Tasks 3, 4, 5, 7 |
| §5 Telegram two-way | Tasks 8, 11 |
| §6 CI/CD alerts | Tasks 7 (ops), 12 (deploy webhook) |
| §7 Backend (Redis schema, routes, cron) | Tasks 2, 9, 10, 11, 12, 13 |
| §8 Frontend (feed, sidebar, artifact viewer) | Tasks 14, 15, 16 |
| §9 Security | Tasks 9 (cron secret), 11 (tg secret+allowlist), 12 (webhook), 15 (safe markdown) |
| §10 Error handling | Tasks 3 (retry), 6 (error state), 7 (catch), 10 (fallback) |
| §11 Cost | inherent (Hobby + free tiers + daily cadence) |
| §12 Testing | Tasks 2, 4, 6, 7, 8 (unit) + 16, 17, 18 (manual) |
| §13 Env vars | Tasks 1, 17 |
| §14 File additions | matches Tasks 2-16 |

### Type consistency
- `AgentStatus`/`AgentOutput`/`FeedEvent`/`AgentRunResult` defined in Task 2 and used identically in Tasks 6, 7, 10, 14, 15, 16. ✓
- `RedisRepo` shape (`setStatus/getStatus/setOutput/getOutput/pushEvent/getFeed`) consistent across Tasks 2, 6, 9-12. ✓
- `DeptId` mapping (`fin/mkt/rnd/ops/ceo`) consistent in personas, registry (`AGENTS`), routes, and `NAME_TO_ID`. ✓
- `complete()` signature (Task 3) matches all callers (Tasks 7, 11). ✓
- `parseCommand`/`isAllowedChat`/`sendMessage` (Task 8) match the webhook (Task 11). ✓

### Notes
- `src/lib/data/logMessages.ts` becomes unused after Task 14; left in place (removal optional, out of scope).
- Web-search tool `type` string and Next `after()` import verified 2026-05-28; re-verify via context7 if the SDK/Next minor changes.

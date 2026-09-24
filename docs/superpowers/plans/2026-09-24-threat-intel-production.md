# Threat Intel Production Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Serve Threat Intel from a background-refreshed Neon table (last good copy per source, honest ages), with conditional KEV downloads, a 30-minute GitHub Actions trigger, and the portfolio's fake `/cyber` page replaced by a redirect.

**Architecture:** Pure units (`store.ts`: row merge, health, snapshot assembly; `refresh.ts`: run fetchers against previous rows) are tested without network or DB. A thin DB layer reads/writes `intel_source`; `/api/cron/intel` runs a refresh and `revalidateTag('intel')`; pages read one cached DB snapshot and fall back to `fallback.json` only when there is no DB.

**Tech Stack:** Next.js 16 App Router, Drizzle + Neon, Vitest, GitHub Actions, Vercel cron.

**Spec:** `/project/docs/superpowers/specs/2026-09-24-threat-intel-production-design.md`

**Repos:** `/project/src/cyber.nanoteofficial.me` (Tasks 1–5, 7) and `/project/src/nanoteofficial.me` (Task 6). Read each repo's `CLAUDE.md` first.

## Global Constraints

- No cost: Vercel Hobby, GitHub free, Neon free. Refresh cadence `*/30 * * * *` — never faster. Vercel cron once daily.
- Pages, `/` and `/api/intel` never call upstream feeds. Only `/api/cron/intel` and `npm run intel:snapshot` touch the network.
- Health: `fetchedAt` age `< 60 min` → `ok`; `≥ 60 min` → `stale`; never succeeded → `down`.
- `fallback.json` is used only when `DATABASE_URL` is unset, the DB is unreachable, or a source row has no data.
- Stored data is the trimmed, parsed payload only: KEV ≤ `KEV_KEEP` (60), ransomware ≤ `RANSOMWARE_KEEP` (150), EPSS only for the first `EPSS_LOOKUP` (30) KEV CVEs.
- Release gate: `DATABASE_URL="" sh -c 'npx tsc --noEmit && npm run lint && npm test && npm run build'` (the worktree/checkout `.env.local` holds a real Neon URL — never let a command use it; for local dev set `DATABASE_URL` to the Docker container explicitly).
- App code uses `getDb()`. Every UI string EN + TH. No emoji, no `dangerouslySetInnerHTML`.
- Commit per task, `feat(intel): …` / `fix(intel): …`, trailer `Co-Authored-By: <authoring model> <noreply@anthropic.com>`.

---

### Task 1: Pure store — row merge, health, snapshot assembly

**Files:**
- Create: `src/lib/intel/store.ts`
- Test: `src/lib/intel/store.test.ts`

**Interfaces:**
- Consumes: types from `src/lib/intel/types.ts`; `computeStats`, `IntelSnapshot`, `SourceHealth`, `KEV_KEEP`, `RANSOMWARE_KEEP` from `src/lib/intel/aggregate.ts`.
- Produces:
  ```ts
  export interface SourceDataMap {
    kev: KevEntry[]; epss: Record<string, number>; ransomware: RansomVictim[];
    feodo: C2Server[]; isc: IscStatus; news: Headline[];
  }
  export interface SourceRow<K extends SourceId = SourceId> {
    source: K; data: SourceDataMap[K] | null; fetchedAt: string | null; attemptedAt: string;
    error: string | null; etag: string | null; lastModified: string | null;
  }
  export type SourceRows = { [K in SourceId]?: SourceRow<K> };
  export type FetchResult<T> =
    | { kind: 'ok'; data: T; etag?: string | null; lastModified?: string | null }
    | { kind: 'not_modified' }
    | { kind: 'failed'; error: string };
  export const SOURCE_IDS: SourceId[];                       // ['kev','epss','ransomware','feodo','isc','news']
  export const STALE_AFTER_MS: number;                       // 60 * 60_000
  export function mergeSourceRow<K extends SourceId>(source: K, prev: SourceRow<K> | undefined, result: FetchResult<SourceDataMap[K]>, now: Date): SourceRow<K>;
  export function healthFromAge(fetchedAt: string | null, now: Date): SourceHealth['status'];
  export function assembleSnapshot(rows: SourceRows, fallback: IntelSnapshot | undefined, now: Date): IntelSnapshot;
  ```

- [ ] **Step 1: Write the failing tests** (`store.test.ts`)

```ts
import { describe, expect, it } from 'vitest';
import { assembleSnapshot, healthFromAge, mergeSourceRow, type SourceRows } from './store';
import { buildIntelSnapshot, type Fetchers } from './aggregate';
import type { KevEntry } from './types';

const now = new Date('2026-09-24T12:00:00Z');
const iso = (msAgo: number) => new Date(now.getTime() - msAgo).toISOString();
const kev = (cveId: string, dateAdded = '2026-09-23'): KevEntry => ({
  cveId, vendor: 'Acme', product: 'Gate', name: 'x', dateAdded, dueDate: '2026-10-14',
  ransomwareUse: false, description: 'd', url: 'u',
});

describe('mergeSourceRow', () => {
  const prev = { source: 'kev' as const, data: [kev('CVE-2026-0001')], fetchedAt: iso(3_600_000), attemptedAt: iso(3_600_000), error: null, etag: '"a"', lastModified: 'Mon' };
  it('replaces data, clears the error and stores validators on success', () => {
    const r = mergeSourceRow('kev', { ...prev, error: 'boom' }, { kind: 'ok', data: [kev('CVE-2026-0002')], etag: '"b"', lastModified: 'Tue' }, now);
    expect(r).toEqual({ source: 'kev', data: [kev('CVE-2026-0002')], fetchedAt: now.toISOString(), attemptedAt: now.toISOString(), error: null, etag: '"b"', lastModified: 'Tue' });
  });
  it('keeps data and validators but bumps fetchedAt on 304', () => {
    const r = mergeSourceRow('kev', prev, { kind: 'not_modified' }, now);
    expect(r.data).toEqual(prev.data);
    expect(r.fetchedAt).toBe(now.toISOString());
    expect(r.etag).toBe('"a"');
    expect(r.error).toBeNull();
  });
  it('keeps the last good copy and records the error on failure', () => {
    const r = mergeSourceRow('kev', prev, { kind: 'failed', error: 'HTTP 503' }, now);
    expect(r.data).toEqual(prev.data);
    expect(r.fetchedAt).toBe(prev.fetchedAt);
    expect(r.attemptedAt).toBe(now.toISOString());
    expect(r.error).toBe('HTTP 503');
  });
  it('leaves data null when the very first attempt fails', () => {
    const r = mergeSourceRow('feodo', undefined, { kind: 'failed', error: 'timeout' }, now);
    expect(r).toMatchObject({ source: 'feodo', data: null, fetchedAt: null, error: 'timeout', etag: null, lastModified: null });
  });
  it('treats 304 without a previous row as a failure', () => {
    const r = mergeSourceRow('kev', undefined, { kind: 'not_modified' }, now);
    expect(r.data).toBeNull();
    expect(r.error).toMatch(/not modified/i);
  });
});

describe('healthFromAge', () => {
  it('is ok under 60 minutes, stale from 60, down when never fetched', () => {
    expect(healthFromAge(iso(59 * 60_000), now)).toBe('ok');
    expect(healthFromAge(iso(60 * 60_000), now)).toBe('stale');
    expect(healthFromAge(null, now)).toBe('down');
  });
});

describe('assembleSnapshot', () => {
  it('builds panels from rows, merges EPSS and uses the newest fetchedAt as generatedAt', () => {
    const rows: SourceRows = {
      kev: { source: 'kev', data: [kev('CVE-2026-0002'), kev('CVE-2026-0001')], fetchedAt: iso(10 * 60_000), attemptedAt: iso(0), error: null, etag: null, lastModified: null },
      epss: { source: 'epss', data: { 'CVE-2026-0002': 0.91 }, fetchedAt: iso(5 * 60_000), attemptedAt: iso(0), error: null, etag: null, lastModified: null },
      isc: { source: 'isc', data: { infocon: 'green', topPorts: [] }, fetchedAt: iso(2 * 3_600_000), attemptedAt: iso(0), error: 'HTTP 500', etag: null, lastModified: null },
    };
    const s = assembleSnapshot(rows, undefined, now);
    expect(s.kev.map((k) => k.cveId)).toEqual(['CVE-2026-0002', 'CVE-2026-0001']);
    expect(s.kev[0].epss).toBe(0.91);
    expect(s.kev[1].epss).toBeUndefined();
    expect(s.health.kev).toEqual({ status: 'ok', fetchedAt: iso(10 * 60_000), ms: 0 });
    expect(s.health.isc.status).toBe('stale');
    expect(s.health.ransomware.status).toBe('down');
    expect(s.ransomware).toEqual([]);
    expect(s.generatedAt).toBe(iso(5 * 60_000));
    expect(s.stats.kevAdded7d).toBe(2);
  });
  it('fills a source with no data from the fallback and labels it stale with the fallback time', async () => {
    const ok: Fetchers = {
      kev: async () => [kev('CVE-2026-0009')], epss: async () => new Map(), ransomware: async () => [],
      feodo: async () => [], isc: async () => ({ infocon: 'yellow', topPorts: [] }), news: async () => [],
    };
    const fallback = await buildIntelSnapshot(ok, undefined, new Date('2026-09-08T00:00:00Z'));
    const s = assembleSnapshot({}, fallback, now);
    expect(s.kev.map((k) => k.cveId)).toEqual(['CVE-2026-0009']);
    expect(s.health.kev).toMatchObject({ status: 'stale', fetchedAt: fallback.health.kev.fetchedAt });
    expect(s.isc.infocon).toBe('yellow');
  });
  it('returns an all-down empty snapshot with no rows and no fallback, dated now', () => {
    const s = assembleSnapshot({}, undefined, now);
    expect(s.generatedAt).toBe(now.toISOString());
    expect(Object.values(s.health).every((h) => h.status === 'down')).toBe(true);
    expect(s.isc).toEqual({ infocon: 'unknown', topPorts: [] });
  });
  it('trims stored lists to the display limits', () => {
    const many = Array.from({ length: 80 }, (_, i) => kev(`CVE-2026-${String(1000 + i)}`));
    const s = assembleSnapshot({ kev: { source: 'kev', data: many, fetchedAt: iso(0), attemptedAt: iso(0), error: null, etag: null, lastModified: null } }, undefined, now);
    expect(s.kev).toHaveLength(60);
  });
});
```

- [ ] **Step 2: Run to verify failure**

Run: `npx vitest run src/lib/intel/store.test.ts`
Expected: FAIL — cannot resolve `./store`.

- [ ] **Step 3: Implement `store.ts`**

```ts
import type { C2Server, Headline, IscStatus, KevEntry, RansomVictim, SourceId } from './types';
import { computeStats, KEV_KEEP, RANSOMWARE_KEEP, type IntelSnapshot, type SourceHealth } from './aggregate';

export interface SourceDataMap {
  kev: KevEntry[];
  epss: Record<string, number>;
  ransomware: RansomVictim[];
  feodo: C2Server[];
  isc: IscStatus;
  news: Headline[];
}

export interface SourceRow<K extends SourceId = SourceId> {
  source: K;
  data: SourceDataMap[K] | null;
  fetchedAt: string | null;    // last success (or 304 confirmation)
  attemptedAt: string;
  error: string | null;
  etag: string | null;
  lastModified: string | null;
}

export type SourceRows = { [K in SourceId]?: SourceRow<K> };

export type FetchResult<T> =
  | { kind: 'ok'; data: T; etag?: string | null; lastModified?: string | null }
  | { kind: 'not_modified' }
  | { kind: 'failed'; error: string };

export const SOURCE_IDS: SourceId[] = ['kev', 'epss', 'ransomware', 'feodo', 'isc', 'news'];
export const STALE_AFTER_MS = 60 * 60_000;

export function mergeSourceRow<K extends SourceId>(
  source: K, prev: SourceRow<K> | undefined, result: FetchResult<SourceDataMap[K]>, now: Date,
): SourceRow<K> {
  const at = now.toISOString();
  const base: SourceRow<K> = prev ?? { source, data: null, fetchedAt: null, attemptedAt: at, error: null, etag: null, lastModified: null };
  if (result.kind === 'ok') {
    return { source, data: result.data, fetchedAt: at, attemptedAt: at, error: null, etag: result.etag ?? null, lastModified: result.lastModified ?? null };
  }
  if (result.kind === 'not_modified' && base.data !== null) {
    return { ...base, source, fetchedAt: at, attemptedAt: at, error: null };
  }
  const error = result.kind === 'failed' ? result.error : 'not modified, but no stored copy';
  return { ...base, source, attemptedAt: at, error };
}

export function healthFromAge(fetchedAt: string | null, now: Date): SourceHealth['status'] {
  if (!fetchedAt) return 'down';
  return now.getTime() - new Date(fetchedAt).getTime() < STALE_AFTER_MS ? 'ok' : 'stale';
}

const EMPTY: SourceDataMap = { kev: [], epss: {}, ransomware: [], feodo: [], isc: { infocon: 'unknown', topPorts: [] }, news: [] };

function fromFallback(fb: IntelSnapshot): SourceDataMap {
  const epss: Record<string, number> = {};
  for (const k of fb.kev) if (k.epss !== undefined) epss[k.cveId] = k.epss;
  return { kev: fb.kev, epss, ransomware: fb.ransomware, feodo: fb.c2, isc: fb.isc, news: fb.headlines };
}

/** Build the page snapshot from stored rows; fallback fills sources that have no data. Pure. */
export function assembleSnapshot(rows: SourceRows, fallback: IntelSnapshot | undefined, now: Date): IntelSnapshot {
  const fb = fallback ? fromFallback(fallback) : undefined;
  const health = {} as Record<SourceId, SourceHealth>;
  const pick = <K extends SourceId>(id: K): SourceDataMap[K] => {
    const row = rows[id] as SourceRow<K> | undefined;
    if (row?.data != null && row.fetchedAt) {
      health[id] = { status: healthFromAge(row.fetchedAt, now), fetchedAt: row.fetchedAt, ms: 0 };
      return row.data;
    }
    if (fb && fallback) {
      health[id] = { status: 'stale', fetchedAt: fallback.health[id]?.fetchedAt ?? fallback.generatedAt, ms: 0 };
      return fb[id];
    }
    health[id] = { status: 'down', fetchedAt: now.toISOString(), ms: 0 };
    return EMPTY[id];
  };

  const epss = pick('epss');
  const kev = pick('kev').slice(0, KEV_KEEP).map((k) => {
    const copy: KevEntry = { ...k };
    delete copy.epss;
    const p = epss[k.cveId];
    if (p !== undefined) copy.epss = p;
    return copy;
  });
  const ransomware = pick('ransomware').slice(0, RANSOMWARE_KEEP);
  const c2 = pick('feodo');
  const isc = pick('isc');
  const headlines = pick('news');

  const fetched = SOURCE_IDS.map((id) => rows[id]?.fetchedAt).filter((x): x is string => !!x).sort();
  const partial = { kev, ransomware, c2, isc };
  return {
    generatedAt: fetched.length ? fetched[fetched.length - 1] : now.toISOString(),
    ...partial,
    headlines,
    health,
    stats: computeStats(partial, now),
  };
}
```

- [ ] **Step 4: Run to verify pass**

Run: `npx vitest run src/lib/intel/store.test.ts`
Expected: PASS (10 tests). Then `npx vitest run` — all existing intel tests still pass.

- [ ] **Step 5: Commit**

```bash
git add src/lib/intel/store.ts src/lib/intel/store.test.ts
git commit -m "feat(intel): pure store — last-good row merge, age-based health, snapshot assembly"
```

---

### Task 2: Refresh runner and conditional KEV fetch

**Files:**
- Modify: `src/lib/intel/sources/kev.ts` (add `fetchKevConditional`)
- Create: `src/lib/intel/refresh.ts`
- Test: `src/lib/intel/refresh.test.ts`

**Interfaces:**
- Consumes: Task 1 (`SourceRows`, `FetchResult`, `mergeSourceRow`, `SOURCE_IDS`); existing `fetchEpss`, `fetchRansomware`, `fetchFeodo`, `fetchIsc`, `fetchNews`, `parseKev`, `KEV_URL`; `KEV_KEEP`, `RANSOMWARE_KEEP`, `EPSS_LOOKUP` from aggregate.ts.
- Produces:
  ```ts
  // kev.ts
  export async function fetchKevConditional(v: { etag: string | null; lastModified: string | null }, signal?: AbortSignal): Promise<FetchResult<KevEntry[]>>;
  // refresh.ts
  export interface RefreshDeps {
    kev: (v: { etag: string | null; lastModified: string | null }) => Promise<FetchResult<KevEntry[]>>;
    epss: (cves: string[]) => Promise<Map<string, number> | null>;
    ransomware: () => Promise<RansomVictim[] | null>;
    feodo: () => Promise<C2Server[] | null>;
    isc: () => Promise<IscStatus | null>;
    news: () => Promise<Headline[] | null>;
  }
  export type RefreshOutcome = Record<SourceId, 'ok' | 'not_modified' | 'failed'>;
  export async function refreshSources(prev: SourceRows, now: Date, deps?: Partial<RefreshDeps>): Promise<{ rows: SourceRows; outcome: RefreshOutcome }>;
  ```

- [ ] **Step 1: Failing tests** (`refresh.test.ts`)

```ts
import { describe, expect, it } from 'vitest';
import { refreshSources, type RefreshDeps } from './refresh';
import type { SourceRows } from './store';
import type { KevEntry } from './types';

const now = new Date('2026-09-24T12:00:00Z');
const kev = (cveId: string): KevEntry => ({ cveId, vendor: 'Acme', product: 'Gate', name: 'x', dateAdded: '2026-09-23', dueDate: '2026-10-14', ransomwareUse: false, description: 'd', url: 'u' });

const deps = (over: Partial<RefreshDeps> = {}): Partial<RefreshDeps> => ({
  kev: async () => ({ kind: 'ok', data: [kev('CVE-2026-0002'), kev('CVE-2026-0001')], etag: '"e1"', lastModified: 'Wed' }),
  epss: async (cves) => new Map(cves.map((c) => [c, 0.5])),
  ransomware: async () => [],
  feodo: async () => [],
  isc: async () => ({ infocon: 'green', topPorts: [] }),
  news: async () => [],
  ...over,
});

describe('refreshSources', () => {
  it('fills every row on a clean first run and asks EPSS about the stored KEV CVEs', async () => {
    let asked: string[] = [];
    const { rows, outcome } = await refreshSources({}, now, deps({ epss: async (c) => { asked = c; return new Map([[c[0], 0.9]]); } }));
    expect(outcome).toEqual({ kev: 'ok', epss: 'ok', ransomware: 'ok', feodo: 'ok', isc: 'ok', news: 'ok' });
    expect(asked).toEqual(['CVE-2026-0002', 'CVE-2026-0001']);
    expect(rows.epss?.data).toEqual({ 'CVE-2026-0002': 0.9 });
    expect(rows.kev?.etag).toBe('"e1"');
  });
  it('passes stored validators to KEV and keeps data on 304', async () => {
    const first = await refreshSources({}, now, deps());
    let seen: unknown = null;
    const later = new Date(now.getTime() + 30 * 60_000);
    const { rows, outcome } = await refreshSources(first.rows, later, deps({ kev: async (v) => { seen = v; return { kind: 'not_modified' }; } }));
    expect(seen).toEqual({ etag: '"e1"', lastModified: 'Wed' });
    expect(outcome.kev).toBe('not_modified');
    expect(rows.kev?.data).toEqual(first.rows.kev?.data);
    expect(rows.kev?.fetchedAt).toBe(later.toISOString());
  });
  it('keeps the previous copy when a source fails and reports it', async () => {
    const first = await refreshSources({}, now, deps());
    const { rows, outcome } = await refreshSources(first.rows, now, deps({ feodo: async () => null, news: async () => { throw new Error('x'); } }));
    expect(outcome.feodo).toBe('failed');
    expect(outcome.news).toBe('failed');
    expect(rows.feodo?.data).toEqual([]);
    expect(rows.feodo?.error).toBeTruthy();
  });
  it('skips EPSS (failed) when there are no KEV CVEs', async () => {
    const { outcome } = await refreshSources({}, now, deps({ kev: async () => ({ kind: 'failed', error: 'HTTP 503' }) }));
    expect(outcome.kev).toBe('failed');
    expect(outcome.epss).toBe('failed');
  });
  it('trims KEV and ransomware to the display limits before storing', async () => {
    const many = Array.from({ length: 90 }, (_, i) => kev(`CVE-2026-${1000 + i}`));
    const { rows } = await refreshSources({}, now, deps({ kev: async () => ({ kind: 'ok', data: many }) }));
    expect(rows.kev?.data).toHaveLength(60);
  });
});
```

Run: `npx vitest run src/lib/intel/refresh.test.ts` → FAIL (module missing).

- [ ] **Step 2: Add `fetchKevConditional` to `kev.ts`**

```ts
import type { FetchResult } from '../store';

/** KEV with HTTP validators: a 304 means "unchanged since last time" and costs no download. Never throws. */
export async function fetchKevConditional(
  v: { etag: string | null; lastModified: string | null }, signal?: AbortSignal,
): Promise<FetchResult<KevEntry[]>> {
  try {
    const headers: Record<string, string> = { accept: 'application/json', 'user-agent': 'nanote-cyber/1.0 (+https://cyber.nanoteofficial.me)' };
    if (v.etag) headers['if-none-match'] = v.etag;
    if (v.lastModified) headers['if-modified-since'] = v.lastModified;
    const res = await fetch(KEV_URL, { headers, signal: signal ?? AbortSignal.timeout(20000), cache: 'no-store' });
    if (res.status === 304) return { kind: 'not_modified' };
    if (!res.ok) return { kind: 'failed', error: `HTTP ${res.status}` };
    return { kind: 'ok', data: parseKev(await res.json()), etag: res.headers.get('etag'), lastModified: res.headers.get('last-modified') };
  } catch (e) {
    return { kind: 'failed', error: e instanceof Error ? e.message : 'fetch failed' };
  }
}
```

(`store.ts` imports only types from `aggregate.ts` and `types.ts` at runtime-free level plus `computeStats`; `kev.ts` importing a type from `store.ts` is type-only — no cycle at runtime.)

- [ ] **Step 3: Implement `refresh.ts`**

```ts
import type { C2Server, Headline, IscStatus, KevEntry, RansomVictim, SourceId } from './types';
import { EPSS_LOOKUP, KEV_KEEP, RANSOMWARE_KEEP } from './aggregate';
import { fetchKevConditional } from './sources/kev';
import { fetchEpss } from './sources/epss';
import { fetchRansomware } from './sources/ransomware';
import { fetchFeodo } from './sources/feodo';
import { fetchIsc } from './sources/isc';
import { fetchNews } from './sources/news';
import { mergeSourceRow, type FetchResult, type SourceDataMap, type SourceRows } from './store';

export interface RefreshDeps {
  kev: (v: { etag: string | null; lastModified: string | null }) => Promise<FetchResult<KevEntry[]>>;
  epss: (cves: string[]) => Promise<Map<string, number> | null>;
  ransomware: () => Promise<RansomVictim[] | null>;
  feodo: () => Promise<C2Server[] | null>;
  isc: () => Promise<IscStatus | null>;
  news: () => Promise<Headline[] | null>;
}

export type RefreshOutcome = Record<SourceId, 'ok' | 'not_modified' | 'failed'>;

const live: RefreshDeps = {
  kev: (v) => fetchKevConditional(v),
  epss: (cves) => fetchEpss(cves),
  ransomware: () => fetchRansomware(),
  feodo: () => fetchFeodo(),
  isc: () => fetchIsc(),
  news: () => fetchNews(),
};

async function wrap<T>(fn: () => Promise<T | null>): Promise<FetchResult<T>> {
  try {
    const v = await fn();
    return v === null ? { kind: 'failed', error: 'no data' } : { kind: 'ok', data: v };
  } catch (e) {
    return { kind: 'failed', error: e instanceof Error ? e.message : 'failed' };
  }
}

/** Run every fetcher against the previous rows. Network only through `deps`; never throws. */
export async function refreshSources(prev: SourceRows, now: Date, deps: Partial<RefreshDeps> = {}) {
  const d: RefreshDeps = { ...live, ...deps };
  const rows: SourceRows = { ...prev };
  const outcome = {} as RefreshOutcome;
  const put = <K extends SourceId>(id: K, r: FetchResult<SourceDataMap[K]>) => {
    (rows as Record<SourceId, unknown>)[id] = mergeSourceRow(id, prev[id] as never, r, now);
    outcome[id] = r.kind === 'failed' ? 'failed' : r.kind;
  };

  const kevResult = await d.kev({ etag: prev.kev?.etag ?? null, lastModified: prev.kev?.lastModified ?? null })
    .catch((e): FetchResult<KevEntry[]> => ({ kind: 'failed', error: String(e) }));
  const [rw, c2, isc, news] = await Promise.all([wrap(d.ransomware), wrap(d.feodo), wrap(d.isc), wrap(d.news)]);
  put('kev', kevResult.kind === 'ok' ? { ...kevResult, data: kevResult.data.slice(0, KEV_KEEP) } : kevResult);
  put('ransomware', rw.kind === 'ok' ? { kind: 'ok', data: rw.data.slice(0, RANSOMWARE_KEEP) } : rw);
  put('feodo', c2);
  put('isc', isc);
  put('news', news);

  const cves = (rows.kev?.data ?? []).slice(0, EPSS_LOOKUP).map((k) => k.cveId);
  if (cves.length === 0) {
    put('epss', { kind: 'failed', error: 'no KEV CVEs to enrich' });
  } else {
    const e = await wrap(() => d.epss(cves));
    put('epss', e.kind === 'ok' ? { kind: 'ok', data: Object.fromEntries(e.data) } : e);
  }
  return { rows, outcome };
}
```

- [ ] **Step 4: Run** `npx vitest run src/lib/intel/refresh.test.ts` → PASS; `npx vitest run` → all pass.

- [ ] **Step 5: Commit** `feat(intel): refresh runner with last-good merge and conditional KEV download`

---

### Task 3: Storage, cron endpoint, cached read path, triggers

**Files:**
- Modify: `src/db/schema.ts` (table `intel_source`)
- Create: `src/lib/intel/db.ts`
- Create: `src/lib/intel/cronAuth.ts` + `src/lib/intel/cronAuth.test.ts`
- Create: `src/app/api/cron/intel/route.ts`
- Modify: `src/lib/intel/snapshot.ts` (read path)
- Modify: `src/app/api/intel/route.ts` (cache header)
- Create: `vercel.json`, `.github/workflows/intel-refresh.yml`

**Interfaces:**
- Consumes: Task 1 `SourceRows`, `SourceRow`, `assembleSnapshot`, `SOURCE_IDS`; Task 2 `refreshSources`, `RefreshOutcome`.
- Produces:
  ```ts
  // schema.ts
  export const intelSources; export type IntelSourceRow = typeof intelSources.$inferSelect;
  // db.ts ('server-only')
  export async function readIntelRows(): Promise<SourceRows>;
  export async function writeIntelRows(rows: SourceRows): Promise<void>;
  // cronAuth.ts
  export function isAuthorised(header: string | null, secret: string | undefined): boolean;
  // snapshot.ts
  export const fallback: IntelSnapshot;                 // unchanged
  export const INTEL_TAG = 'intel';
  export const getIntelSnapshot: () => Promise<IntelSnapshot>;
  ```

- [ ] **Step 1: Schema** — append to `src/db/schema.ts`:

```ts
export const intelSources = pgTable('intel_source', {
  source: text('source').primaryKey(),
  data: jsonb('data'),
  fetchedAt: timestamp('fetchedAt', { mode: 'date' }),
  attemptedAt: timestamp('attemptedAt', { mode: 'date' }).notNull().defaultNow(),
  error: text('error'),
  etag: text('etag'),
  lastModified: text('lastModified'),
});
export type IntelSourceRow = typeof intelSources.$inferSelect;
```

- [ ] **Step 2: `db.ts`**

```ts
import 'server-only';
import { getDb } from '@/db';
import { intelSources } from '@/db/schema';
import { SOURCE_IDS, type SourceRow, type SourceRows } from './store';
import type { SourceId } from './types';

export async function readIntelRows(): Promise<SourceRows> {
  const rows = await getDb().select().from(intelSources);
  const out: SourceRows = {};
  for (const r of rows) {
    if (!(SOURCE_IDS as string[]).includes(r.source)) continue;
    (out as Record<SourceId, SourceRow>)[r.source as SourceId] = {
      source: r.source as SourceId,
      data: (r.data ?? null) as SourceRow['data'],
      fetchedAt: r.fetchedAt ? r.fetchedAt.toISOString() : null,
      attemptedAt: r.attemptedAt.toISOString(),
      error: r.error, etag: r.etag, lastModified: r.lastModified,
    };
  }
  return out;
}

export async function writeIntelRows(rows: SourceRows): Promise<void> {
  const db = getDb();
  for (const id of SOURCE_IDS) {
    const r = rows[id];
    if (!r) continue;
    const values = {
      data: r.data, fetchedAt: r.fetchedAt ? new Date(r.fetchedAt) : null, attemptedAt: new Date(r.attemptedAt),
      error: r.error, etag: r.etag, lastModified: r.lastModified,
    };
    await db.insert(intelSources).values({ source: id, ...values })
      .onConflictDoUpdate({ target: intelSources.source, set: values });
  }
}
```

- [ ] **Step 3: `cronAuth.ts` with test first**

`cronAuth.test.ts`:
```ts
import { describe, expect, it } from 'vitest';
import { isAuthorised } from './cronAuth';

describe('isAuthorised', () => {
  it('accepts only the exact bearer secret', () => {
    expect(isAuthorised('Bearer s3cret-value', 's3cret-value')).toBe(true);
    expect(isAuthorised('Bearer wrong', 's3cret-value')).toBe(false);
    expect(isAuthorised('s3cret-value', 's3cret-value')).toBe(false);
    expect(isAuthorised(null, 's3cret-value')).toBe(false);
  });
  it('always refuses when no secret is configured', () => {
    expect(isAuthorised('Bearer ', '')).toBe(false);
    expect(isAuthorised('Bearer undefined', undefined)).toBe(false);
  });
});
```
Run → FAIL. Then `cronAuth.ts`:
```ts
import { timingSafeEqual } from 'node:crypto';

/** Bearer check for cron callers. Refuses when CRON_SECRET is unset (fails closed). */
export function isAuthorised(header: string | null, secret: string | undefined): boolean {
  if (!secret || !header?.startsWith('Bearer ')) return false;
  const a = Buffer.from(header.slice(7));
  const b = Buffer.from(secret);
  return a.length === b.length && timingSafeEqual(a, b);
}
```
Run → PASS.

- [ ] **Step 4: Cron route** `src/app/api/cron/intel/route.ts`

```ts
import { revalidateTag } from 'next/cache';
import { isAuthorised } from '@/lib/intel/cronAuth';
import { readIntelRows, writeIntelRows } from '@/lib/intel/db';
import { refreshSources } from '@/lib/intel/refresh';
import { INTEL_TAG } from '@/lib/intel/snapshot';

export const maxDuration = 60;
export const dynamic = 'force-dynamic';

/** Background refresh: GitHub Actions every 30 min, Vercel cron daily. Returns outcomes only, never data. */
export async function GET(req: Request) {
  if (!isAuthorised(req.headers.get('authorization'), process.env.CRON_SECRET)) {
    return new Response('Unauthorized', { status: 401 });
  }
  const prev = await readIntelRows();
  const { rows, outcome } = await refreshSources(prev, new Date());
  await writeIntelRows(rows);
  revalidateTag(INTEL_TAG, 'max');
  return Response.json({ sources: outcome }, { headers: { 'Cache-Control': 'no-store' } });
}
```
Check the installed Next 16 signature of `revalidateTag` in `node_modules/next/dist/docs/` (Next 16 takes a second `profile` argument; use the form the docs require for immediate expiry — if `'max'` gives stale-while-revalidate semantics, use `updateTag` or `revalidateTag(tag, { expire: 0 })` as documented, and note which in the report).

- [ ] **Step 5: Read path** — replace the body of `src/lib/intel/snapshot.ts` (keep the `fallback` export and header comment updated):

```ts
import { unstable_cache } from 'next/cache';
import type { IntelSnapshot } from './aggregate';
import { assembleSnapshot } from './store';
import fallbackJson from './fallback.json';

export const fallback = fallbackJson as unknown as IntelSnapshot;
export const INTEL_TAG = 'intel';
/** Safety net only: the refresh job invalidates INTEL_TAG every 30 minutes. */
export const INTEL_REVALIDATE_SECONDS = 3600;

async function load(): Promise<IntelSnapshot> {
  if (!process.env.DATABASE_URL) return assembleSnapshot({}, fallback, new Date());
  try {
    const { readIntelRows } = await import('./db');
    return assembleSnapshot(await readIntelRows(), fallback, new Date());
  } catch (e) {
    console.error('intel: DB read failed, serving fallback', e);
    return assembleSnapshot({}, fallback, new Date());
  }
}

/** One cached snapshot for `/`, `/intel` and `/api/intel`; one DB read per refresh cycle. Never calls upstream. */
export const getIntelSnapshot = unstable_cache(load, ['intel-snapshot-v2'], {
  revalidate: INTEL_REVALIDATE_SECONDS, tags: [INTEL_TAG],
});
```

Note on health at read time: health ages are computed when the snapshot is assembled (at most once per refresh cycle), which is ≤ 30 minutes behind — acceptable; the next refresh re-assembles.

`/api/intel/route.ts`: change `s-maxage` to `300` (`'Cache-Control': 'public, s-maxage=300, stale-while-revalidate=600'`) and import only `getIntelSnapshot`.

- [ ] **Step 6: Triggers**

`vercel.json`:
```json
{ "crons": [{ "path": "/api/cron/intel", "schedule": "15 3 * * *" }] }
```

`.github/workflows/intel-refresh.yml`:
```yaml
name: intel-refresh
on:
  schedule:
    - cron: '*/30 * * * *'
  workflow_dispatch:
permissions: {}
jobs:
  refresh:
    runs-on: ubuntu-latest
    timeout-minutes: 3
    steps:
      - name: Trigger refresh
        env:
          CRON_SECRET: ${{ secrets.CRON_SECRET }}
        run: |
          curl -fsS --max-time 90 -H "Authorization: Bearer $CRON_SECRET" https://cyber.nanoteofficial.me/api/cron/intel
```

- [ ] **Step 7: Local verification**
1. Apply the new table to the local Docker DB with the generate→psql recipe in `CLAUDE.md` (only the `intel_source` CREATE; the rest exists).
2. Start dev with the local env (`DATABASE_URL=postgres://postgres:pg@cyber-pg:5432/cyber NEON_LOCAL_PROXY=http://localhost:4444/sql AUTH_SECRET=dev CRON_SECRET=local-test ...`).
3. `curl -s -H 'Authorization: Bearer local-test' localhost:<port>/api/cron/intel` → all six `ok`; run again → `kev: not_modified` (if CISA sent validators); without header → 401.
4. `docker exec cyber-pg psql -U postgres -d cyber -c 'select source, "fetchedAt", error, pg_column_size(data) from intel_source'` → 6 rows, each < 200 KB.
5. `curl -s localhost:<port>/api/intel | head -c 300` → fresh `generatedAt`, health all `ok`.
6. Stop dev; revert `AGENTS.md`/`next-env.d.ts` if touched.

- [ ] **Step 8: Gate + commit** `feat(intel): background refresh into Neon; pages read the stored snapshot`

---

### Task 4: Per-panel "updated … ago" labels

**Files:**
- Modify: `src/components/intel/panels.tsx` (`PanelHeader` gains optional `age` prop; the four panels pass it)
- Modify: `src/lib/i18n.ts` (key `intel.updated`)

**Interfaces:**
- Consumes: `ago(iso, now, lang)` from `src/lib/intel/format.ts`; `snapshot.health`.
- Produces: `PanelHeader({ title, sub, source, right, age?: { status: 'ok'|'stale'|'down'; fetchedAt: string } , lang? })`.

- [ ] **Step 1:** Add i18n key `'intel.updated': { en: 'updated {ago}', th: 'อัปเดต {ago}' }`.
- [ ] **Step 2:** `PanelHeader` renders, under the source label, `<span className="mono text-[10.5px]" style={{ color: age.status === 'ok' ? 'var(--muted-soft)' : 'var(--sev-medium)' }}>{t(lang, 'intel.updated', { ago: ago(age.fetchedAt, new Date(), lang) })}</span>` when `age` is set and status is not `down`; for `down` render `t(lang, 'intel.health.down')` in `var(--sev-critical)`.
- [ ] **Step 3:** Pass `age` from each panel: Exploited → `snapshot.health.kev`, Ransomware → `.ransomware`, Infra → the older of `.feodo` and `.isc` (compare `fetchedAt`; if either is stale, use it), Headlines → `.news`. Pass `lang`.
- [ ] **Step 4:** `npx tsc --noEmit && npm run lint`; load `/intel` locally (Task 3 stack) in en and th and confirm each panel shows its age.
- [ ] **Step 5:** Commit `feat(intel): show each panel's real data age`

---

### Task 5: Refresh the committed fallback

**Files:** Modify: `src/lib/intel/fallback.json`

- [ ] **Step 1:** `npm run intel:snapshot` (network; refuses if any source is down — retry later if so).
- [ ] **Step 2:** Confirm `generatedAt` is today; `npx vitest run` passes.
- [ ] **Step 3:** Commit `chore(intel): refresh committed fallback snapshot`

---

### Task 6: Portfolio — redirect `/cyber`, remove the fake feed

**Repo:** `/project/src/nanoteofficial.me` (own git repo; read its `CLAUDE.md`; Next.js 16).

**Files:**
- Modify: `next.config.ts` (redirects)
- Delete: `src/app/cyber/page.tsx`, `src/app/cyber/opengraph-image.tsx` (and the folder)
- Search: any links to `/cyber` inside the portfolio (`grep -rn "'/cyber\|\"/cyber\|href=\"/cyber" src`) → point them at `https://cyber.nanoteofficial.me`

- [ ] **Step 1:** In `next.config.ts` add to the existing `redirects()` (next to `/plan/:path*`):
```ts
{ source: '/cyber', destination: 'https://cyber.nanoteofficial.me', permanent: true },
{ source: '/cyber/:path*', destination: 'https://cyber.nanoteofficial.me/:path*', permanent: true },
```
- [ ] **Step 2:** Delete `src/app/cyber/`. Check `proxy.ts`: the `cyber` subdomain rewrite (`cyber.nanoteofficial.me` → `/cyber`) must not break anything — the subdomain is bound to the cyber Vercel project, so the portfolio never receives it; if `proxy.ts` lists `cyber` among rewrite targets, remove it from that list so a stray request isn't rewritten to a deleted route.
- [ ] **Step 3:** Update any in-site links found in the search.
- [ ] **Step 4:** Run the portfolio gate from its CLAUDE.md (`npm run lint && npx tsc --noEmit && npm run build`); in `npm run dev`, `curl -sI localhost:<port>/cyber` → `308` with `location: https://cyber.nanoteofficial.me/`.
- [ ] **Step 5:** Bump the patch version (`npm version patch --no-git-tag-version`), commit `feat: redirect /cyber to cyber.nanoteofficial.me; remove the preview feed`. Do not push (Task 7).

---

### Task 7: Docs and release

- [ ] **Step 1: Docs** — cyber `CLAUDE.md`: replace the "Threat Intel cache" rule with the new flow (background refresh every 30 min via GitHub Actions + daily Vercel cron → `intel_source` → one cached read, tag `intel`; pages never call upstream; `fallback.json` only without DB; cadence never faster than 30 min — Neon free tier); add `CRON_SECRET` to the env list and `.env.example`; README Threat Intel section likewise. Portfolio `CLAUDE.md`: note `/cyber` is a redirect now.
- [ ] **Step 2: Production migration** — generate the old→new diff as in v1.1.0 (only `CREATE TABLE "intel_source"` expected), review it, apply in one transaction to production Neon.
- [ ] **Step 3: Secret** — generate `openssl rand -hex 32`; `vercel env add CRON_SECRET production` (cyber project); `gh secret set CRON_SECRET -R khantee8/cyber.nanoteofficial.me`. Never print the value.
- [ ] **Step 4: Cyber release v1.2.0** — bump package.json + both lockfile fields; gate; commit `feat: v1.2.0 — background-refreshed Threat Intel`; tag; push main + tag; wait for Ready.
- [ ] **Step 5: First refresh** — `gh workflow run intel-refresh -R khantee8/cyber.nanoteofficial.me`; wait; confirm the run succeeded; production `select source, "fetchedAt", error from intel_source` → 6 rows with `fetchedAt` set; `/api/intel` health all `ok`, `generatedAt` within minutes.
- [ ] **Step 6: Portfolio release** — push its main (and tag if the repo tags patch releases); confirm `curl -sI https://nanoteofficial.me/cyber` → 308 to cyber.nanoteofficial.me.
- [ ] **Step 7: Dotfiles** — `/project/CLAUDE.md`: cyber entry v1.2.0 + refresh flow; portfolio entry: `/cyber` redirect replaces the preview shell. Commit.

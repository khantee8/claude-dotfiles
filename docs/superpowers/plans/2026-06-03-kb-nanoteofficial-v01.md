# kb.nanoteofficial.me — NaNote Library v0.1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a login-gated NaNote Library — a glassmorphism executive dashboard + Notion-style reader over the company KB feed (`company.nanoteofficial.me/api/kb`), cached in Neon Postgres, on a unified `item` model that already fits v0.2 notes/Obsidian.

**Architecture:** Next.js 16 App Router app. A `SYNC_SECRET`-guarded `/api/sync` pulls published `KbEntry[]` from the company API and upserts them into Neon Postgres as `item` rows (`kind='company_brief'`). All UI reads Postgres (fast filter + full-text search). Auth is a stateless HMAC-signed cookie (ported from the company `auth.ts`). Charts and the safe Markdown renderer are ported verbatim from the company project. **No LLM calls anywhere** — pure reader.

**Tech Stack:** Next.js 16.2.6 · React 19.2.4 · TypeScript 5 · Tailwind v4 · `@neondatabase/serverless` (Neon Postgres) · Vitest 3 · Vercel Hobby.

**Spec:** `docs/superpowers/specs/2026-06-03-kb-nanoteofficial-v01-design.md`

**Source to port from:** `/project/src/company.nanoteofficial.me/` (referred to below as `$COMPANY`).

---

## File Structure

New repo at `/project/src/kb.nanoteofficial.me/`:

```
src/
  app/
    layout.tsx                  root layout (AppBackground + fonts)
    globals.css                 Tailwind v4 + glass theme tokens
    page.tsx                    "/" public landing
    login/page.tsx              login form
    dashboard/page.tsx          glass exec overview (gated)
    library/page.tsx            browse + filter + search (gated)
    library/[id]/page.tsx       Notion-style reader (gated)
    collections/page.tsx        list/manage collections (gated)
    collections/[slug]/page.tsx one collection (gated)
    tags/page.tsx               tag explorer (gated)
    tags/[slug]/page.tsx        one tag (gated)
    archive/page.tsx            archived items (gated)
    import/page.tsx             sync trigger + sync_log + export (gated)
    api/
      auth/login/route.ts       POST: set cookie
      auth/logout/route.ts      POST: clear cookie
      sync/route.ts             POST: SYNC_SECRET-guarded pull+upsert; GET cron
      items/route.ts            GET: list/filter/search
      items/[id]/route.ts       GET: single
      collections/route.ts      GET/POST/PATCH/DELETE
      tags/route.ts             GET/PATCH (rename/merge)
      state/route.ts            POST: toggle pin/archive/save/read
      export/route.ts           GET: md/json/pdf
  lib/
    auth.ts                     ported HMAC cookie (kb_session, KB_ADMIN_*)
    session.ts                  requireSession() server helper
    db.ts                       Neon client + sql tag + typed helpers
    types.ts                    Item, Collection, Tag, ItemState, DeptId, KbCategory
    artifacts.ts                ported Artifact union + normalizeTags
    kbEntry.ts                  upstream KbEntry type (contract)
    sync.ts                     mapEntryToItem() (pure) + runSync()
    items.ts                    buildItemsQuery() (pure) + listItems()/getItem()
    collections.ts              collection CRUD
    tags.ts                     tag list + slugify() + mergeTags()
    state.ts                    toggleState()
    export.ts                   toMarkdown()/toJson() (pure) + pdf doc model
    format.ts                   deptLabel(), categoryLabel(), DEPT_COLORS
  components/
    AppBackground.tsx  NavBar.tsx  GlassCard.tsx  KpiTile.tsx
    Markdown.tsx       (ported)    charts/* (ported)
    ExecOverview.tsx   FilterBar.tsx  ItemCard.tsx  ItemList.tsx
    BriefReader.tsx    CommandSearch.tsx  LoginForm.tsx  SyncPanel.tsx
db/
  schema.sql                    DDL (section 5 of the spec)
  migrate.ts                    apply schema.sql to POSTGRES_URL
vitest.config.ts  next.config.ts  tsconfig.json  postcss.config.mjs
package.json  .env.example  .gitignore  vercel.json  CLAUDE.md
```

**Test files** (Vitest, co-located `*.test.ts`): `auth.test.ts`, `sync.test.ts`, `items.test.ts`, `tags.test.ts`, `export.test.ts`. No visual unit tests — UI verified with the dev server + Playwright screenshots (spec §11).

---

## Conventions for every task

- After each task's tests pass, run `npx tsc --noEmit` before committing.
- Commit messages: `feat:`/`test:`/`chore:` … end with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- Work inside `/project/src/kb.nanoteofficial.me/` (its own git repo — **not** the dotfiles repo).
- Tests that touch Postgres use a stubbed `sql` (inject a fake query fn); pure functions take data in, return data out — no DB in unit tests.

---

## Task 1: Scaffold the Next.js 16 project

**Files:**
- Create: `package.json`, `tsconfig.json`, `next.config.ts`, `postcss.config.mjs`, `vitest.config.ts`, `.gitignore`, `.env.example`, `src/app/globals.css`, `src/app/layout.tsx`, `src/app/page.tsx`

- [ ] **Step 1: Create the project directory and git repo**

```bash
mkdir -p /project/src/kb.nanoteofficial.me
cd /project/src/kb.nanoteofficial.me
git init
```

- [ ] **Step 2: Write `package.json`** (mirrors `$COMPANY/package.json`, swaps Upstash→Neon, drops Anthropic)

```json
{
  "name": "kb.nanoteofficial.me",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "eslint",
    "test": "vitest run",
    "test:watch": "vitest",
    "db:migrate": "node --experimental-strip-types db/migrate.ts"
  },
  "dependencies": {
    "@neondatabase/serverless": "^0.10.4",
    "next": "16.2.6",
    "react": "19.2.4",
    "react-dom": "19.2.4"
  },
  "devDependencies": {
    "@tailwindcss/postcss": "^4",
    "@types/node": "^20",
    "@types/react": "^19",
    "@types/react-dom": "^19",
    "eslint": "^9",
    "eslint-config-next": "16.2.6",
    "tailwindcss": "^4",
    "typescript": "^5",
    "vitest": "^3.2.4"
  },
  "overrides": { "postcss": ">=8.5.10" }
}
```

- [ ] **Step 3: Write `tsconfig.json`** (copy `$COMPANY/tsconfig.json` verbatim — same `@/*`→`src/*` paths, `moduleResolution: bundler`, `strict: true`). Run: `cp /project/src/company.nanoteofficial.me/tsconfig.json ./tsconfig.json`

- [ ] **Step 4: Write `next.config.ts`** (port `$COMPANY/next.config.ts` security headers; **remove** the `outputFileTracingIncludes` block — no `.agents/` here; update CSP `connect-src` to allow the company API)

```ts
import type { NextConfig } from "next";

const securityHeaders = [
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=()" },
  { key: "Strict-Transport-Security", value: "max-age=63072000; includeSubDomains; preload" },
  {
    key: "Content-Security-Policy",
    value: [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline'",
      "style-src 'self' 'unsafe-inline'",
      "img-src 'self' data: blob:",
      "font-src 'self'",
      "connect-src 'self' https://company.nanoteofficial.me",
      "frame-ancestors 'self' https://nanoteofficial.me https://*.nanoteofficial.me",
    ].join("; "),
  },
];

const nextConfig: NextConfig = {
  poweredByHeader: false,
  async headers() {
    return [{ source: "/:path*", headers: securityHeaders }];
  },
};
export default nextConfig;
```

- [ ] **Step 5: Write `postcss.config.mjs`** (copy `$COMPANY/postcss.config.mjs`): `export default { plugins: { "@tailwindcss/postcss": {} } };`

- [ ] **Step 6: Write `vitest.config.ts`**

```ts
import { defineConfig } from 'vitest/config';
import path from 'node:path';

export default defineConfig({
  test: { environment: 'node', include: ['src/**/*.test.ts'] },
  resolve: { alias: { '@': path.resolve(__dirname, 'src') } },
});
```

- [ ] **Step 7: Write `.gitignore`** (copy `$COMPANY/.gitignore`; ensure it contains `node_modules`, `.next`, `.env*`, `!.env.example`).

- [ ] **Step 8: Write `.env.example`**

```
KB_ADMIN_USER=admin
KB_ADMIN_PASSWORD=change-me
COMPANY_KB_URL=https://company.nanoteofficial.me/api/kb
POSTGRES_URL=postgres://user:pass@host/db?sslmode=require
SYNC_SECRET=change-me
CRON_SECRET=change-me
```

- [ ] **Step 9: Write `src/app/globals.css`** — Tailwind v4 import + glass tokens

```css
@import "tailwindcss";

:root {
  --bg-0: #0b1020;
  --bg-1: #1e1b4b;
  --glass: rgba(255,255,255,.07);
  --glass-line: rgba(255,255,255,.14);
  --violet: #a78bfa;
  --mint: #34d399;
  --amber: #f59e0b;
  --ink: #e9e9ff;
}
html, body { padding: 0; margin: 0; background: var(--bg-0); color: var(--ink);
  font-family: ui-sans-serif, system-ui, -apple-system, sans-serif; }
* { box-sizing: border-box; }
.glass { background: var(--glass); border: 1px solid var(--glass-line);
  border-radius: 14px; backdrop-filter: blur(8px); }
```

- [ ] **Step 10: Write `src/app/layout.tsx`**

```tsx
import type { Metadata } from "next";
import "./globals.css";
import { AppBackground } from "@/components/AppBackground";

export const metadata: Metadata = {
  title: "NaNote Library",
  description: "Knowledge base & executive dashboard",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body><AppBackground>{children}</AppBackground></body>
    </html>
  );
}
```

- [ ] **Step 11: Temporary `src/app/page.tsx`** (replaced in Task 12) and temporary `src/components/AppBackground.tsx` (replaced in Task 11) so the app compiles:

```tsx
// src/app/page.tsx
export default function Home() { return <main style={{padding:40}}>NaNote Library — scaffold</main>; }
```
```tsx
// src/components/AppBackground.tsx
export function AppBackground({ children }: { children: React.ReactNode }) { return <>{children}</>; }
```

- [ ] **Step 12: Install and verify build**

Run: `npm install && npm run build`
Expected: build succeeds, route `/` compiles.

- [ ] **Step 13: Commit**

```bash
git add -A
git commit -m "chore: scaffold Next.js 16 kb.nanoteofficial.me

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Domain types + upstream KbEntry contract + ported Artifact union

**Files:**
- Create: `src/lib/kbEntry.ts`, `src/lib/artifacts.ts`, `src/lib/types.ts`, `src/lib/format.ts`

- [ ] **Step 1: Write `src/lib/kbEntry.ts`** (the upstream contract we consume — mirror of the company `KbEntry`)

```ts
// The shape returned by company.nanoteofficial.me/api/kb (published-only).
import type { Artifact } from './artifacts';

export type DeptId = 'ceo' | 'cyb' | 'mkt' | 'rnd' | 'ops' | 'fin';
export type KbCategory =
  | 'market-brief' | 'threat-intel' | 'research'
  | 'content-plan' | 'ops-status'  | 'exec-brief';

export interface KbEntry {
  id: string;
  dept: DeptId;
  date: string;   // YYYY-MM-DD
  ts: string;     // ISO timestamp
  category: KbCategory;
  tags: string[];
  status: 'draft' | 'published' | 'archived';
  pinned?: boolean;
  summary: string;
  highlight: string;
  flags: string[];
  artifacts: Artifact[];
  markdown: string;
}

export interface KbApiResponse {
  entries: KbEntry[];
  count: number;
  generatedAt: string;
}
```

- [ ] **Step 2: Write `src/lib/artifacts.ts`** (port `$COMPANY/src/lib/agents/artifacts.ts` — keep the `Artifact` union and `normalizeTags` **verbatim**; drop `CATEGORY_BY_DEPT` and the `DeptId` import — not needed here)

```ts
// Ported verbatim from company.nanoteofficial.me artifacts.ts (chart contract).
export type Artifact =
  | { kind: 'bars' | 'divergingBars' | 'donut'; title: string;
      series: { label: string; value: number; color?: string }[]; unit?: string }
  | { kind: 'line' | 'sparkline'; title: string;
      points: { t: string; value: number }[]; unit?: string }
  | { kind: 'table'; title: string;
      columns: string[]; rows: (string | number)[][] }
  | { kind: 'scorecard'; title: string;
      tiles: { label: string; state: 'ok' | 'warn' | 'down' }[] }
  | { kind: 'heatmap'; title: string; cells: { label: string; level: number }[] }
  | { kind: 'tags'; title: string; tags: string[] }
  | { kind: 'checklist'; title: string; items: { text: string; done: boolean }[] };

export function normalizeTags(raw: string[], cap = 12): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const t of raw) {
    const v = t.trim().toLowerCase();
    if (v && !seen.has(v)) { seen.add(v); out.push(v); }
    if (out.length >= cap) break;
  }
  return out;
}
```

- [ ] **Step 3: Write `src/lib/types.ts`** (our DB-facing domain model)

```ts
import type { Artifact } from './artifacts';
import type { DeptId, KbCategory } from './kbEntry';

export type ItemKind = 'company_brief' | 'note';

export interface Item {
  id: string;
  kind: ItemKind;
  externalId: string | null;
  dept: DeptId | null;
  category: KbCategory | string | null;
  summary: string;
  highlight: string;
  bodyMd: string;
  flags: string[];
  artifacts: Artifact[];
  sourceDate: string | null;
  sourceTs: string | null;
  createdAt: string;
  updatedAt: string;
  // joined on read:
  tags?: string[];
  state?: ItemState;
}

export interface ItemState {
  pinned: boolean;
  archived: boolean;
  saved: boolean;
  read: boolean;
}

export interface Collection {
  id: string; name: string; slug: string;
  description: string; color: string; icon: string; createdAt: string;
  itemCount?: number;
}

export interface Tag { id: string; label: string; slug: string; count?: number; }

export interface SyncLog {
  id: string; startedAt: string; finishedAt: string | null;
  fetchedCount: number; upsertedCount: number;
  status: 'running' | 'ok' | 'error'; error: string | null;
}

export const EMPTY_STATE: ItemState = { pinned: false, archived: false, saved: false, read: false };
```

- [ ] **Step 4: Write `src/lib/format.ts`** (presentation labels/colors — keep dept colors consistent with the company office)

```ts
import type { DeptId, KbCategory } from './kbEntry';

export const DEPT_LABEL: Record<DeptId, string> = {
  ceo: 'NaNote CEO', fin: 'Finance', cyb: 'CyberX',
  mkt: 'Marketing & Social Media', rnd: 'AI R&D', ops: 'Operations',
};
export const DEPT_COLOR: Record<DeptId, string> = {
  ceo: '#ffdd57', fin: '#7f8cff', cyb: '#39ff9d', mkt: '#ff6b9d', rnd: '#00cfff', ops: '#ff9a3c',
};
export const CATEGORY_LABEL: Record<KbCategory, string> = {
  'market-brief': 'Market Brief', 'threat-intel': 'Threat Intel', research: 'Research',
  'content-plan': 'Content Plan', 'ops-status': 'Ops Status', 'exec-brief': 'Exec Brief',
};
export const ALL_DEPTS: DeptId[] = ['ceo', 'fin', 'cyb', 'mkt', 'rnd', 'ops'];
export const ALL_CATEGORIES: KbCategory[] = [
  'market-brief', 'threat-intel', 'research', 'content-plan', 'ops-status', 'exec-brief',
];

export function deptLabel(d: string | null): string { return d && d in DEPT_LABEL ? DEPT_LABEL[d as DeptId] : (d ?? '—'); }
export function deptColor(d: string | null): string { return d && d in DEPT_COLOR ? DEPT_COLOR[d as DeptId] : '#a78bfa'; }
export function categoryLabel(c: string | null): string { return c && c in CATEGORY_LABEL ? CATEGORY_LABEL[c as KbCategory] : (c ?? '—'); }
```

- [ ] **Step 5: Verify + commit**

Run: `npx tsc --noEmit` → Expected: no errors.
```bash
git add -A && git commit -m "feat: domain types, KbEntry contract, ported Artifact union

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Database client + schema + migration runner

**Files:**
- Create: `db/schema.sql`, `db/migrate.ts`, `src/lib/db.ts`

- [ ] **Step 1: Write `db/schema.sql`** — copy the full DDL from spec §5 (tables `item`, `collection`, `collection_item`, `tag`, `item_tag`, `item_state`, `sync_log` + indexes). Prepend `CREATE EXTENSION IF NOT EXISTS pgcrypto;` (for `gen_random_uuid()`). Wrap each `CREATE TABLE`/`CREATE INDEX` with `IF NOT EXISTS`. Add a trigger to maintain `item.search`:

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;
-- ... (all CREATE TABLE IF NOT EXISTS / CREATE INDEX IF NOT EXISTS from spec §5) ...

CREATE OR REPLACE FUNCTION item_search_update() RETURNS trigger AS $$
BEGIN
  NEW.search := to_tsvector('english',
    coalesce(NEW.summary,'') || ' ' || coalesce(NEW.highlight,'') || ' ' || coalesce(NEW.body_md,''));
  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS item_search_trg ON item;
CREATE TRIGGER item_search_trg BEFORE INSERT OR UPDATE ON item
  FOR EACH ROW EXECUTE FUNCTION item_search_update();
```

- [ ] **Step 2: Write `src/lib/db.ts`** (Neon serverless client)

```ts
import { neon } from '@neondatabase/serverless';

// Throws at call time (not import) if unconfigured, so builds don't need the DB.
export function getSql() {
  const url = process.env.POSTGRES_URL;
  if (!url) throw new Error('POSTGRES_URL is not set');
  return neon(url);
}
export type Sql = ReturnType<typeof getSql>;
```

- [ ] **Step 3: Write `db/migrate.ts`** (apply schema)

```ts
import { readFileSync } from 'node:fs';
import { neon } from '@neondatabase/serverless';

const url = process.env.POSTGRES_URL;
if (!url) { console.error('POSTGRES_URL not set'); process.exit(1); }
const sql = neon(url);
const ddl = readFileSync(new URL('./schema.sql', import.meta.url), 'utf8');

const statements = ddl.split(/;\s*$/m).map(s => s.trim()).filter(Boolean);
for (const stmt of statements) { await sql.query(stmt); }
console.log(`applied ${statements.length} statements`);
```

- [ ] **Step 4: Apply against the Neon dev branch**

Run: `POSTGRES_URL=... node --experimental-strip-types db/migrate.ts`
Expected: `applied N statements`. (If Neon not yet provisioned, defer to Task 18 deploy — note the dependency.)

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: Neon Postgres schema, client, and migration runner

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: Auth — port HMAC cookie (TDD)

**Files:**
- Create: `src/lib/auth.ts`, `src/lib/auth.test.ts`, `src/lib/session.ts`

- [ ] **Step 1: Write the failing test `src/lib/auth.test.ts`**

```ts
import { describe, it, expect, beforeEach } from 'vitest';
import { checkCredentials, createSessionToken, verifySession } from './auth';

beforeEach(() => {
  process.env.KB_ADMIN_USER = 'admin';
  process.env.KB_ADMIN_PASSWORD = 'secret';
});

describe('auth', () => {
  it('accepts correct credentials, rejects wrong', () => {
    expect(checkCredentials('admin', 'secret')).toBe(true);
    expect(checkCredentials('admin', 'nope')).toBe(false);
    expect(checkCredentials('root', 'secret')).toBe(false);
  });
  it('mints a token that verifies', () => {
    const now = 1_000_000;
    const tok = createSessionToken(now)!;
    expect(verifySession(tok, now + 1000)).toBe(true);
  });
  it('rejects expired or tampered tokens', () => {
    const now = 1_000_000;
    const tok = createSessionToken(now)!;
    expect(verifySession(tok, now + 13 * 3600 * 1000)).toBe(false); // > 12h
    expect(verifySession(tok.replace(/.$/, '0'), now + 1000)).toBe(false);
    expect(verifySession(undefined, now)).toBe(false);
  });
  it('fails closed when unconfigured', () => {
    delete process.env.KB_ADMIN_PASSWORD;
    expect(createSessionToken()).toBe(null);
    expect(checkCredentials('admin', 'secret')).toBe(false);
  });
});
```

- [ ] **Step 2: Run test to verify it fails** — Run: `npx vitest run src/lib/auth.test.ts` → Expected: FAIL (module not found).

- [ ] **Step 3: Write `src/lib/auth.ts`** (port `$COMPANY/src/lib/auth.ts`; rename cookie + env, no `DASHBOARD_PASSCODE` fallback)

```ts
import { createHmac, timingSafeEqual } from 'node:crypto';

export const SESSION_COOKIE = 'kb_session';
const SESSION_TTL_MS = 12 * 60 * 60 * 1000;
export const SESSION_MAX_AGE_S = Math.floor(SESSION_TTL_MS / 1000);

function secret(): string | null { return process.env.KB_ADMIN_PASSWORD ?? null; }
function user(): string | null { return process.env.KB_ADMIN_USER ?? null; }

function safeEqual(a: string, b: string): boolean {
  const ba = Buffer.from(a), bb = Buffer.from(b);
  if (ba.length !== bb.length) return false;
  return timingSafeEqual(ba, bb);
}
export function checkCredentials(u: string, p: string): boolean {
  const uu = user(), pp = secret();
  if (!uu || !pp) return false;
  const okUser = safeEqual(u, uu), okPass = safeEqual(p, pp);
  return okUser && okPass;
}
function sign(exp: number, s: string): string {
  return createHmac('sha256', s).update(String(exp)).digest('hex');
}
export function createSessionToken(now = Date.now()): string | null {
  const s = secret(); if (!s) return null;
  const exp = now + SESSION_TTL_MS;
  return `${exp}.${sign(exp, s)}`;
}
export function verifySession(token: string | undefined | null, now = Date.now()): boolean {
  if (!token) return false;
  const s = secret(); if (!s) return false;
  const dot = token.indexOf('.'); if (dot <= 0) return false;
  const exp = Number(token.slice(0, dot));
  if (!Number.isFinite(exp) || exp < now) return false;
  return safeEqual(token.slice(dot + 1), sign(exp, s));
}
```

- [ ] **Step 4: Run test to verify it passes** — Run: `npx vitest run src/lib/auth.test.ts` → Expected: PASS (4 tests).

- [ ] **Step 5: Write `src/lib/session.ts`** (server-only guard used by gated pages/routes)

```ts
import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { SESSION_COOKIE, verifySession } from './auth';

/** True if the request carries a valid session cookie. */
export async function hasSession(): Promise<boolean> {
  const c = await cookies();
  return verifySession(c.get(SESSION_COOKIE)?.value);
}
/** For gated pages: redirect to /login when unauthenticated. */
export async function requireSession(): Promise<void> {
  if (!(await hasSession())) redirect('/login');
}
```

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: HMAC session auth (ported) with tests

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: Auth API routes + login page

**Files:**
- Create: `src/app/api/auth/login/route.ts`, `src/app/api/auth/logout/route.ts`, `src/app/login/page.tsx`, `src/components/LoginForm.tsx`

- [ ] **Step 1: Write `src/app/api/auth/login/route.ts`**

```ts
import { NextRequest, NextResponse } from 'next/server';
import { checkCredentials, createSessionToken, SESSION_COOKIE, SESSION_MAX_AGE_S } from '@/lib/auth';

export async function POST(req: NextRequest) {
  const { user, password } = await req.json().catch(() => ({ user: '', password: '' }));
  if (!checkCredentials(String(user ?? ''), String(password ?? ''))) {
    return NextResponse.json({ ok: false }, { status: 401 });
  }
  const token = createSessionToken();
  if (!token) return NextResponse.json({ ok: false }, { status: 500 });
  const res = NextResponse.json({ ok: true });
  res.cookies.set(SESSION_COOKIE, token, {
    httpOnly: true, secure: true, sameSite: 'lax', path: '/', maxAge: SESSION_MAX_AGE_S,
  });
  return res;
}
```

- [ ] **Step 2: Write `src/app/api/auth/logout/route.ts`**

```ts
import { NextResponse } from 'next/server';
import { SESSION_COOKIE } from '@/lib/auth';

export async function POST() {
  const res = NextResponse.json({ ok: true });
  res.cookies.set(SESSION_COOKIE, '', { httpOnly: true, secure: true, sameSite: 'lax', path: '/', maxAge: 0 });
  return res;
}
```

- [ ] **Step 3: Write `src/components/LoginForm.tsx`** (client component)

```tsx
'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';

export function LoginForm() {
  const router = useRouter();
  const [user, setUser] = useState(''); const [password, setPassword] = useState('');
  const [error, setError] = useState(''); const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault(); setBusy(true); setError('');
    const res = await fetch('/api/auth/login', {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ user, password }),
    });
    setBusy(false);
    if (res.ok) router.push('/dashboard');
    else setError('Invalid username or password');
  }
  return (
    <form onSubmit={submit} className="glass" style={{ padding: 28, width: 340, display: 'grid', gap: 12 }}>
      <h1 style={{ margin: 0, fontSize: 20 }}>NaNote Library</h1>
      <input placeholder="Username" value={user} onChange={e => setUser(e.target.value)} autoFocus />
      <input placeholder="Password" type="password" value={password} onChange={e => setPassword(e.target.value)} />
      {error && <p style={{ color: '#ff8080', margin: 0, fontSize: 13 }}>{error}</p>}
      <button disabled={busy} type="submit">{busy ? '…' : 'Sign in'}</button>
    </form>
  );
}
```

- [ ] **Step 4: Write `src/app/login/page.tsx`**

```tsx
import { LoginForm } from '@/components/LoginForm';
import { hasSession } from '@/lib/session';
import { redirect } from 'next/navigation';

export default async function LoginPage() {
  if (await hasSession()) redirect('/dashboard');
  return <main style={{ minHeight: '100vh', display: 'grid', placeItems: 'center' }}><LoginForm /></main>;
}
```

- [ ] **Step 5: Verify** — Run: `npm run build` → Expected: routes compile. Manual: `npm run dev`, POST a wrong cred → 401, correct → redirect (verify in Task 18 with real env).

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: login/logout API + login page

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: Sync — `mapEntryToItem()` (TDD) + `runSync()` + `/api/sync`

**Files:**
- Create: `src/lib/sync.ts`, `src/lib/sync.test.ts`, `src/app/api/sync/route.ts`
- Modify: `vercel.json` (cron)

- [ ] **Step 1: Write the failing test `src/lib/sync.test.ts`**

```ts
import { describe, it, expect } from 'vitest';
import { mapEntryToItem } from './sync';
import type { KbEntry } from './kbEntry';

const entry: KbEntry = {
  id: 'fin-2026-06-01', dept: 'fin', date: '2026-06-01', ts: '2026-06-01T10:00:00Z',
  category: 'market-brief', tags: ['BTC', ' btc ', 'Macro'], status: 'published',
  summary: 'S', highlight: 'H', flags: ['watch CPI'],
  artifacts: [{ kind: 'tags', title: 'T', tags: ['x'] }], markdown: '# body',
};

describe('mapEntryToItem', () => {
  it('maps fields and normalizes tags', () => {
    const r = mapEntryToItem(entry);
    expect(r.kind).toBe('company_brief');
    expect(r.externalId).toBe('fin-2026-06-01');
    expect(r.dept).toBe('fin');
    expect(r.category).toBe('market-brief');
    expect(r.bodyMd).toBe('# body');
    expect(r.sourceDate).toBe('2026-06-01');
    expect(r.tags).toEqual(['btc', 'macro']); // trimmed, lowercased, deduped
    expect(r.flags).toEqual(['watch CPI']);
    expect(r.artifacts).toHaveLength(1);
  });
});
```

- [ ] **Step 2: Run test → FAIL** — Run: `npx vitest run src/lib/sync.test.ts` → Expected: FAIL.

- [ ] **Step 3: Write `src/lib/sync.ts`**

```ts
import type { KbEntry, KbApiResponse } from './kbEntry';
import { normalizeTags } from './artifacts';
import { getSql } from './db';
import type { SyncLog } from './types';

export interface MappedItem {
  kind: 'company_brief'; externalId: string; dept: string; category: string;
  summary: string; highlight: string; bodyMd: string;
  flags: string[]; artifacts: KbEntry['artifacts'];
  sourceDate: string; sourceTs: string; tags: string[];
}

/** Pure: KbEntry → row payload. Tags normalized; no DB. */
export function mapEntryToItem(e: KbEntry): MappedItem {
  return {
    kind: 'company_brief', externalId: e.id, dept: e.dept, category: e.category,
    summary: e.summary ?? '', highlight: e.highlight ?? '', bodyMd: e.markdown ?? '',
    flags: Array.isArray(e.flags) ? e.flags : [],
    artifacts: Array.isArray(e.artifacts) ? e.artifacts : [],
    sourceDate: e.date, sourceTs: e.ts, tags: normalizeTags(e.tags ?? []),
  };
}

/** Fetch published entries, upsert items + tags, write a sync_log row. */
export async function runSync(now = new Date()): Promise<SyncLog> {
  const sql = getSql();
  const url = process.env.COMPANY_KB_URL ?? 'https://company.nanoteofficial.me/api/kb';
  const [log] = await sql`INSERT INTO sync_log (started_at, status) VALUES (${now.toISOString()}, 'running')
    RETURNING id, started_at` as { id: string; started_at: string }[];
  try {
    const res = await fetch(`${url}?limit=200`, { headers: { accept: 'application/json' } });
    const data = (await res.json()) as KbApiResponse;
    const entries = Array.isArray(data.entries) ? data.entries : [];
    let upserted = 0;
    for (const e of entries) {
      const m = mapEntryToItem(e);
      const [row] = await sql`
        INSERT INTO item (kind, external_id, dept, category, summary, highlight, body_md, flags, artifacts, source_date, source_ts, updated_at)
        VALUES (${m.kind}, ${m.externalId}, ${m.dept}, ${m.category}, ${m.summary}, ${m.highlight}, ${m.bodyMd},
                ${JSON.stringify(m.flags)}, ${JSON.stringify(m.artifacts)}, ${m.sourceDate}, ${m.sourceTs}, now())
        ON CONFLICT (external_id) DO UPDATE SET
          dept=EXCLUDED.dept, category=EXCLUDED.category, summary=EXCLUDED.summary,
          highlight=EXCLUDED.highlight, body_md=EXCLUDED.body_md, flags=EXCLUDED.flags,
          artifacts=EXCLUDED.artifacts, source_date=EXCLUDED.source_date, source_ts=EXCLUDED.source_ts, updated_at=now()
        RETURNING id` as { id: string }[];
      for (const label of m.tags) {
        const slug = label;
        const [tag] = await sql`INSERT INTO tag (label, slug) VALUES (${label}, ${slug})
          ON CONFLICT (slug) DO UPDATE SET label=EXCLUDED.label RETURNING id` as { id: string }[];
        await sql`INSERT INTO item_tag (item_id, tag_id, source) VALUES (${row.id}, ${tag.id}, 'company')
          ON CONFLICT DO NOTHING`;
      }
      upserted++;
    }
    const [done] = await sql`UPDATE sync_log SET finished_at=now(), status='ok',
      fetched_count=${entries.length}, upserted_count=${upserted} WHERE id=${log.id}
      RETURNING id, started_at, finished_at, fetched_count, upserted_count, status, error` as any[];
    return normalizeLog(done);
  } catch (err) {
    const [done] = await sql`UPDATE sync_log SET finished_at=now(), status='error', error=${String(err)}
      WHERE id=${log.id} RETURNING id, started_at, finished_at, fetched_count, upserted_count, status, error` as any[];
    return normalizeLog(done);
  }
}

function normalizeLog(r: any): SyncLog {
  return { id: r.id, startedAt: r.started_at, finishedAt: r.finished_at,
    fetchedCount: r.fetched_count ?? 0, upsertedCount: r.upserted_count ?? 0,
    status: r.status, error: r.error ?? null };
}
```

- [ ] **Step 4: Run test → PASS** — Run: `npx vitest run src/lib/sync.test.ts` → Expected: PASS.

- [ ] **Step 5: Write `src/app/api/sync/route.ts`** (POST manual w/ secret; GET for Vercel cron w/ `CRON_SECRET`)

```ts
import { NextRequest, NextResponse } from 'next/server';
import { runSync } from '@/lib/sync';
import { hasSession } from '@/lib/session';

export const dynamic = 'force-dynamic';

function authorized(req: NextRequest, secret: string | undefined): boolean {
  if (!secret) return false;
  const h = req.headers.get('authorization');
  return h === `Bearer ${secret}`;
}

export async function POST(req: NextRequest) {
  const ok = authorized(req, process.env.SYNC_SECRET) || (await hasSession());
  if (!ok) return NextResponse.json({ ok: false }, { status: 401 });
  const log = await runSync();
  return NextResponse.json({ ok: log.status === 'ok', log });
}

// Vercel Cron calls GET with the CRON_SECRET bearer.
export async function GET(req: NextRequest) {
  if (!authorized(req, process.env.CRON_SECRET)) return NextResponse.json({ ok: false }, { status: 401 });
  const log = await runSync();
  return NextResponse.json({ ok: log.status === 'ok', log });
}
```

- [ ] **Step 6: Write `vercel.json`** (one daily cron — Hobby-compatible; spec §13)

```json
{ "crons": [{ "path": "/api/sync", "schedule": "0 16 * * *" }] }
```

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat: company KB sync (pure mapper + runSync) and /api/sync + daily cron

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 7: Items query builder (TDD) + `/api/items` + `/api/items/[id]`

**Files:**
- Create: `src/lib/items.ts`, `src/lib/items.test.ts`, `src/app/api/items/route.ts`, `src/app/api/items/[id]/route.ts`

- [ ] **Step 1: Write the failing test `src/lib/items.test.ts`** (test the **pure** WHERE/params builder)

```ts
import { describe, it, expect } from 'vitest';
import { buildItemsWhere } from './items';

describe('buildItemsWhere', () => {
  it('defaults to non-archived', () => {
    const { clauses } = buildItemsWhere({});
    expect(clauses.join(' ')).toContain('archived = false');
  });
  it('filters by dept, category, and search', () => {
    const { clauses, params } = buildItemsWhere({ dept: 'fin', category: 'market-brief', q: 'btc' });
    expect(clauses.some(c => c.includes('i.dept ='))).toBe(true);
    expect(clauses.some(c => c.includes('i.category ='))).toBe(true);
    expect(clauses.some(c => c.includes('i.search @@'))).toBe(true);
    expect(params).toContain('fin');
    expect(params).toContain('market-brief');
  });
  it('archived=true flips the state filter', () => {
    const { clauses } = buildItemsWhere({ archived: true });
    expect(clauses.join(' ')).toContain('archived = true');
  });
  it('pinned=true adds the pinned filter', () => {
    const { clauses } = buildItemsWhere({ pinned: true });
    expect(clauses.join(' ')).toContain('pinned = true');
  });
});
```

- [ ] **Step 2: Run test → FAIL** — Run: `npx vitest run src/lib/items.test.ts` → Expected: FAIL.

- [ ] **Step 3: Write `src/lib/items.ts`**

```ts
import { getSql } from './db';
import type { Item } from './types';

export interface ItemsQuery {
  dept?: string; category?: string; tag?: string; collection?: string;
  q?: string; archived?: boolean; pinned?: boolean; saved?: boolean;
  sort?: 'recent' | 'oldest'; limit?: number;
}

/** Pure: build parameterized WHERE clauses + ordered params. ($1-based) */
export function buildItemsWhere(opt: ItemsQuery): { clauses: string[]; params: (string)[] } {
  const clauses: string[] = []; const params: string[] = [];
  const p = (v: string) => { params.push(v); return `$${params.length}`; };

  clauses.push(`coalesce(st.archived, false) = ${opt.archived ? 'true' : 'false'}`);
  if (opt.pinned) clauses.push(`coalesce(st.pinned, false) = true`);
  if (opt.saved) clauses.push(`coalesce(st.saved, false) = true`);
  if (opt.dept) clauses.push(`i.dept = ${p(opt.dept)}`);
  if (opt.category) clauses.push(`i.category = ${p(opt.category)}`);
  if (opt.q && opt.q.trim()) clauses.push(`i.search @@ plainto_tsquery('english', ${p(opt.q.trim())})`);
  if (opt.tag) clauses.push(`EXISTS (SELECT 1 FROM item_tag it JOIN tag t ON t.id=it.tag_id WHERE it.item_id=i.id AND t.slug=${p(opt.tag)})`);
  if (opt.collection) clauses.push(`EXISTS (SELECT 1 FROM collection_item ci JOIN collection c ON c.id=ci.collection_id WHERE ci.item_id=i.id AND c.slug=${p(opt.collection)})`);
  return { clauses, params };
}

const SELECT = `
  SELECT i.*, coalesce(st.pinned,false) pinned, coalesce(st.archived,false) archived,
         coalesce(st.saved,false) saved, coalesce(st.read,false) read,
         coalesce(array_agg(DISTINCT t.slug) FILTER (WHERE t.slug IS NOT NULL), '{}') tags
  FROM item i
  LEFT JOIN item_state st ON st.item_id = i.id
  LEFT JOIN item_tag itg ON itg.item_id = i.id
  LEFT JOIN tag t ON t.id = itg.tag_id`;

export async function listItems(opt: ItemsQuery = {}): Promise<Item[]> {
  const sql = getSql();
  const { clauses, params } = buildItemsWhere(opt);
  const where = clauses.length ? `WHERE ${clauses.join(' AND ')}` : '';
  const order = opt.sort === 'oldest' ? 'ASC' : 'DESC';
  const limit = opt.limit && opt.limit > 0 ? Math.min(opt.limit, 200) : 100;
  const rows = await sql.query(
    `${SELECT} ${where} GROUP BY i.id, st.pinned, st.archived, st.saved, st.read
     ORDER BY i.source_ts ${order} NULLS LAST LIMIT ${limit}`, params);
  return (rows as any[]).map(rowToItem);
}

export async function getItem(id: string): Promise<Item | null> {
  const sql = getSql();
  const rows = await sql.query(`${SELECT} WHERE i.id = $1
     GROUP BY i.id, st.pinned, st.archived, st.saved, st.read`, [id]);
  const r = (rows as any[])[0];
  return r ? rowToItem(r) : null;
}

export function rowToItem(r: any): Item {
  return {
    id: r.id, kind: r.kind, externalId: r.external_id, dept: r.dept, category: r.category,
    summary: r.summary, highlight: r.highlight, bodyMd: r.body_md,
    flags: r.flags ?? [], artifacts: r.artifacts ?? [],
    sourceDate: r.source_date, sourceTs: r.source_ts,
    createdAt: r.created_at, updatedAt: r.updated_at, tags: r.tags ?? [],
    state: { pinned: r.pinned, archived: r.archived, saved: r.saved, read: r.read },
  };
}
```

- [ ] **Step 4: Run test → PASS** — Run: `npx vitest run src/lib/items.test.ts` → Expected: PASS (4 tests).

- [ ] **Step 5: Write `src/app/api/items/route.ts`**

```ts
import { NextRequest, NextResponse } from 'next/server';
import { listItems, type ItemsQuery } from '@/lib/items';
import { hasSession } from '@/lib/session';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  if (!(await hasSession())) return NextResponse.json({ items: [] }, { status: 401 });
  const sp = req.nextUrl.searchParams;
  const opt: ItemsQuery = {
    dept: sp.get('dept') ?? undefined, category: sp.get('category') ?? undefined,
    tag: sp.get('tag') ?? undefined, collection: sp.get('collection') ?? undefined,
    q: sp.get('q') ?? undefined,
    archived: sp.get('archived') === 'true', pinned: sp.get('pinned') === 'true',
    saved: sp.get('saved') === 'true',
    sort: (sp.get('sort') as 'recent' | 'oldest') ?? 'recent',
    limit: Number(sp.get('limit')) || undefined,
  };
  const items = await listItems(opt);
  return NextResponse.json({ items, count: items.length });
}
```

- [ ] **Step 6: Write `src/app/api/items/[id]/route.ts`**

```ts
import { NextRequest, NextResponse } from 'next/server';
import { getItem } from '@/lib/items';
import { hasSession } from '@/lib/session';

export const dynamic = 'force-dynamic';

export async function GET(_req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  if (!(await hasSession())) return NextResponse.json({ item: null }, { status: 401 });
  const { id } = await ctx.params;
  const item = await getItem(id);
  if (!item) return NextResponse.json({ item: null }, { status: 404 });
  return NextResponse.json({ item });
}
```

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat: items query builder (tested) + /api/items[+/:id]

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 8: Collections + state + tags seams and APIs

**Files:**
- Create: `src/lib/collections.ts`, `src/lib/state.ts`, `src/lib/tags.ts`, `src/lib/tags.test.ts`,
  `src/app/api/collections/route.ts`, `src/app/api/state/route.ts`, `src/app/api/tags/route.ts`

- [ ] **Step 1: Write failing test `src/lib/tags.test.ts`** (pure `slugify` + `mergeTagLabels`)

```ts
import { describe, it, expect } from 'vitest';
import { slugify, mergeTagLabels } from './tags';

describe('tags helpers', () => {
  it('slugify lowercases, trims, dashes spaces, strips junk', () => {
    expect(slugify('  Threat Intel! ')).toBe('threat-intel');
    expect(slugify('BTC/USD')).toBe('btc-usd');
  });
  it('mergeTagLabels dedupes by slug, keeps first label', () => {
    expect(mergeTagLabels(['Macro', 'macro', 'CPI'])).toEqual(['Macro', 'CPI']);
  });
});
```

- [ ] **Step 2: Run → FAIL** — Run: `npx vitest run src/lib/tags.test.ts` → Expected: FAIL.

- [ ] **Step 3: Write `src/lib/tags.ts`**

```ts
import { getSql } from './db';
import type { Tag } from './types';

export function slugify(s: string): string {
  return s.toLowerCase().trim().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
}
export function mergeTagLabels(labels: string[]): string[] {
  const seen = new Set<string>(); const out: string[] = [];
  for (const l of labels) { const s = slugify(l); if (s && !seen.has(s)) { seen.add(s); out.push(l.trim()); } }
  return out;
}
export async function listTags(): Promise<Tag[]> {
  const sql = getSql();
  const rows = await sql`SELECT t.id, t.label, t.slug, count(it.item_id)::int AS count
    FROM tag t LEFT JOIN item_tag it ON it.tag_id=t.id GROUP BY t.id ORDER BY count DESC, t.label` as any[];
  return rows.map(r => ({ id: r.id, label: r.label, slug: r.slug, count: r.count }));
}
/** Rename a tag (re-slugs); if the new slug exists, repoint item_tag rows then delete the old tag (merge). */
export async function renameTag(id: string, label: string): Promise<void> {
  const sql = getSql(); const slug = slugify(label);
  const existing = await sql`SELECT id FROM tag WHERE slug=${slug} AND id<>${id}` as { id: string }[];
  if (existing.length) {
    await sql`UPDATE item_tag SET tag_id=${existing[0].id} WHERE tag_id=${id} ON CONFLICT DO NOTHING`;
    await sql`DELETE FROM item_tag WHERE tag_id=${id}`;
    await sql`DELETE FROM tag WHERE id=${id}`;
  } else {
    await sql`UPDATE tag SET label=${label}, slug=${slug} WHERE id=${id}`;
  }
}
```

- [ ] **Step 4: Run → PASS** — Run: `npx vitest run src/lib/tags.test.ts` → Expected: PASS.

- [ ] **Step 5: Write `src/lib/collections.ts`**

```ts
import { getSql } from './db';
import type { Collection } from './types';
import { slugify } from './tags';

export async function listCollections(): Promise<Collection[]> {
  const sql = getSql();
  const rows = await sql`SELECT c.*, count(ci.item_id)::int item_count
    FROM collection c LEFT JOIN collection_item ci ON ci.collection_id=c.id
    GROUP BY c.id ORDER BY c.created_at DESC` as any[];
  return rows.map(toCollection);
}
export async function createCollection(name: string, color = '#a78bfa', icon = '◆', description = ''): Promise<Collection> {
  const sql = getSql();
  const [r] = await sql`INSERT INTO collection (name, slug, color, icon, description)
    VALUES (${name}, ${slugify(name)}, ${color}, ${icon}, ${description}) RETURNING *` as any[];
  return toCollection(r);
}
export async function addToCollection(collectionId: string, itemId: string): Promise<void> {
  const sql = getSql();
  await sql`INSERT INTO collection_item (collection_id, item_id) VALUES (${collectionId}, ${itemId}) ON CONFLICT DO NOTHING`;
}
export async function removeFromCollection(collectionId: string, itemId: string): Promise<void> {
  const sql = getSql();
  await sql`DELETE FROM collection_item WHERE collection_id=${collectionId} AND item_id=${itemId}`;
}
export async function deleteCollection(id: string): Promise<void> {
  const sql = getSql(); await sql`DELETE FROM collection WHERE id=${id}`;
}
function toCollection(r: any): Collection {
  return { id: r.id, name: r.name, slug: r.slug, description: r.description,
    color: r.color, icon: r.icon, createdAt: r.created_at, itemCount: r.item_count };
}
```

- [ ] **Step 6: Write `src/lib/state.ts`**

```ts
import { getSql } from './db';
import type { ItemState } from './types';

const FIELDS = ['pinned', 'archived', 'saved', 'read'] as const;
type Field = typeof FIELDS[number];

/** Upsert a single boolean state field for an item; returns the full state. */
export async function setState(itemId: string, field: Field, value: boolean): Promise<ItemState> {
  if (!FIELDS.includes(field)) throw new Error('bad field');
  const sql = getSql();
  // column name is from a fixed allowlist (FIELDS) — safe to interpolate.
  const [r] = await sql.query(
    `INSERT INTO item_state (item_id, ${field}) VALUES ($1, $2)
     ON CONFLICT (item_id) DO UPDATE SET ${field}=$2, updated_at=now()
     RETURNING pinned, archived, saved, read`, [itemId, value]) as any[];
  return { pinned: r.pinned, archived: r.archived, saved: r.saved, read: r.read };
}
```

- [ ] **Step 7: Write the three API routes** (all `hasSession()`-gated; return 401 otherwise)

```ts
// src/app/api/collections/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { listCollections, createCollection, addToCollection, removeFromCollection, deleteCollection } from '@/lib/collections';
import { hasSession } from '@/lib/session';
export const dynamic = 'force-dynamic';
async function gate() { return hasSession(); }

export async function GET() {
  if (!(await gate())) return NextResponse.json({ collections: [] }, { status: 401 });
  return NextResponse.json({ collections: await listCollections() });
}
export async function POST(req: NextRequest) {
  if (!(await gate())) return NextResponse.json({ ok: false }, { status: 401 });
  const b = await req.json();
  if (b.action === 'add') { await addToCollection(b.collectionId, b.itemId); return NextResponse.json({ ok: true }); }
  if (b.action === 'remove') { await removeFromCollection(b.collectionId, b.itemId); return NextResponse.json({ ok: true }); }
  const c = await createCollection(b.name, b.color, b.icon, b.description);
  return NextResponse.json({ collection: c });
}
export async function DELETE(req: NextRequest) {
  if (!(await gate())) return NextResponse.json({ ok: false }, { status: 401 });
  const id = req.nextUrl.searchParams.get('id'); if (!id) return NextResponse.json({ ok: false }, { status: 400 });
  await deleteCollection(id); return NextResponse.json({ ok: true });
}
```

```ts
// src/app/api/state/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { setState } from '@/lib/state';
import { hasSession } from '@/lib/session';
export const dynamic = 'force-dynamic';
export async function POST(req: NextRequest) {
  if (!(await hasSession())) return NextResponse.json({ ok: false }, { status: 401 });
  const { itemId, field, value } = await req.json();
  if (!['pinned','archived','saved','read'].includes(field)) return NextResponse.json({ ok: false }, { status: 400 });
  const state = await setState(itemId, field, !!value);
  return NextResponse.json({ ok: true, state });
}
```

```ts
// src/app/api/tags/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { listTags, renameTag } from '@/lib/tags';
import { hasSession } from '@/lib/session';
export const dynamic = 'force-dynamic';
export async function GET() {
  if (!(await hasSession())) return NextResponse.json({ tags: [] }, { status: 401 });
  return NextResponse.json({ tags: await listTags() });
}
export async function PATCH(req: NextRequest) {
  if (!(await hasSession())) return NextResponse.json({ ok: false }, { status: 401 });
  const { id, label } = await req.json(); await renameTag(id, label);
  return NextResponse.json({ ok: true });
}
```

- [ ] **Step 8: Verify + commit** — Run: `npx vitest run && npx tsc --noEmit` → Expected: all pass.

```bash
git add -A && git commit -m "feat: collections, item-state, tags seams + APIs (tags helpers tested)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 9: Export serializers (TDD) + `/api/export`

**Files:**
- Create: `src/lib/export.ts`, `src/lib/export.test.ts`, `src/app/api/export/route.ts`

- [ ] **Step 1: Write failing test `src/lib/export.test.ts`**

```ts
import { describe, it, expect } from 'vitest';
import { toMarkdown, toJson } from './export';
import type { Item } from './types';

const item: Item = {
  id: '1', kind: 'company_brief', externalId: 'fin-1', dept: 'fin', category: 'market-brief',
  summary: 'Sum', highlight: 'High', bodyMd: '## Body\ntext', flags: ['flag a'],
  artifacts: [], sourceDate: '2026-06-01', sourceTs: '2026-06-01T10:00:00Z',
  createdAt: 'x', updatedAt: 'y', tags: ['btc', 'macro'],
};

describe('export', () => {
  it('toMarkdown includes title, meta, summary, flags, body', () => {
    const md = toMarkdown([item]);
    expect(md).toContain('# Market Brief — Finance');
    expect(md).toContain('2026-06-01');
    expect(md).toContain('`btc`');
    expect(md).toContain('flag a');
    expect(md).toContain('## Body');
  });
  it('toJson round-trips the items array', () => {
    const parsed = JSON.parse(toJson([item]));
    expect(parsed.items[0].externalId).toBe('fin-1');
    expect(parsed.count).toBe(1);
  });
});
```

- [ ] **Step 2: Run → FAIL** — Run: `npx vitest run src/lib/export.test.ts` → Expected: FAIL.

- [ ] **Step 3: Write `src/lib/export.ts`**

```ts
import type { Item } from './types';
import { deptLabel, categoryLabel } from './format';

export function toMarkdown(items: Item[]): string {
  return items.map(it => {
    const title = `# ${categoryLabel(it.category)} — ${deptLabel(it.dept)}`;
    const meta = `**Date:** ${it.sourceDate ?? '—'}  ·  **Tags:** ${(it.tags ?? []).map(t => `\`${t}\``).join(' ') || '—'}`;
    const flags = it.flags.length ? `\n**Flags:**\n${it.flags.map(f => `- ${f}`).join('\n')}\n` : '';
    return `${title}\n\n${meta}\n\n> ${it.highlight}\n\n${it.summary}\n${flags}\n---\n\n${it.bodyMd}\n`;
  }).join('\n\n');
}

export function toJson(items: Item[]): string {
  return JSON.stringify({ items, count: items.length, exportedAt: new Date().toISOString() }, null, 2);
}

/** PDF as a print-ready HTML doc built from escaped text only (no raw injection). */
export function toPrintableHtml(items: Item[]): string {
  const esc = (s: string) => s.replace(/[&<>]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]!));
  const body = items.map(it => `<section><h1>${esc(categoryLabel(it.category))} — ${esc(deptLabel(it.dept))}</h1>
    <p><em>${esc(it.sourceDate ?? '')}</em></p><blockquote>${esc(it.highlight)}</blockquote>
    <p>${esc(it.summary)}</p><pre>${esc(it.bodyMd)}</pre></section>`).join('<hr>');
  return `<!doctype html><html><head><meta charset="utf-8"><title>NaNote Library export</title></head><body>${body}</body></html>`;
}
```

- [ ] **Step 4: Run → PASS** — Run: `npx vitest run src/lib/export.test.ts` → Expected: PASS.

- [ ] **Step 5: Write `src/app/api/export/route.ts`** (md/json now; pdf returns printable HTML the client prints)

```ts
import { NextRequest, NextResponse } from 'next/server';
import { listItems } from '@/lib/items';
import { toMarkdown, toJson, toPrintableHtml } from '@/lib/export';
import { hasSession } from '@/lib/session';
export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  if (!(await hasSession())) return NextResponse.json({ ok: false }, { status: 401 });
  const sp = req.nextUrl.searchParams;
  const fmt = sp.get('format') ?? 'md';
  const items = await listItems({ collection: sp.get('collection') ?? undefined, limit: 200 });
  if (fmt === 'json') return new NextResponse(toJson(items), { headers: { 'content-type': 'application/json', 'content-disposition': 'attachment; filename="nanote-library.json"' } });
  if (fmt === 'pdf') return new NextResponse(toPrintableHtml(items), { headers: { 'content-type': 'text/html; charset=utf-8' } });
  return new NextResponse(toMarkdown(items), { headers: { 'content-type': 'text/markdown; charset=utf-8', 'content-disposition': 'attachment; filename="nanote-library.md"' } });
}
```

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: export serializers (md/json/printable-html) + /api/export

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 10: Design system — AppBackground, NavBar, GlassCard, KpiTile, ported Markdown + charts

**Files:**
- Replace: `src/components/AppBackground.tsx`
- Create: `src/components/NavBar.tsx`, `src/components/GlassCard.tsx`, `src/components/KpiTile.tsx`, `src/components/Markdown.tsx`, `src/components/charts/*`

- [ ] **Step 1: Port charts** — copy the whole charts dir + the Artifact import path:

```bash
cp -r /project/src/company.nanoteofficial.me/src/components/charts /project/src/kb.nanoteofficial.me/src/components/charts
rm -f src/components/charts/ArtifactRenderer.test.tsx
```
Then edit `src/components/charts/ArtifactRenderer.tsx` line 1: change `import type { Artifact } from '@/lib/agents/artifacts';` → `import type { Artifact } from '@/lib/artifacts';`. Check the other chart files for the same import and update if present.

- [ ] **Step 2: Port the safe Markdown renderer**:

```bash
cp /project/src/company.nanoteofficial.me/src/components/Markdown.tsx /project/src/kb.nanoteofficial.me/src/components/Markdown.tsx
```
Open it and confirm it has **no** `dangerouslySetInnerHTML` and imports nothing company-specific (it is self-contained). If it imports a company path, vendor that helper inline.

- [ ] **Step 3: Write `src/components/AppBackground.tsx`**

```tsx
export function AppBackground({ children }: { children: React.ReactNode }) {
  return (
    <div style={{ minHeight: '100vh',
      background: 'radial-gradient(130% 120% at 0% 0%, #1e1b4b, #0b1020 55%)' }}>
      {children}
    </div>
  );
}
```

- [ ] **Step 4: Write `src/components/GlassCard.tsx`**

```tsx
export function GlassCard({ children, style }: { children: React.ReactNode; style?: React.CSSProperties }) {
  return <div className="glass" style={{ padding: 16, ...style }}>{children}</div>;
}
```

- [ ] **Step 5: Write `src/components/KpiTile.tsx`**

```tsx
export function KpiTile({ label, value, color }: { label: string; value: string | number; color?: string }) {
  return (
    <div className="glass" style={{ padding: 12 }}>
      <div style={{ fontSize: 10, letterSpacing: 1, color: '#aab' }}>{label.toUpperCase()}</div>
      <div style={{ fontSize: 22, fontWeight: 700, color: color ?? 'var(--ink)' }}>{value}</div>
    </div>
  );
}
```

- [ ] **Step 6: Write `src/components/NavBar.tsx`** (client; active link from `usePathname`)

```tsx
'use client';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';

const LINKS = [
  ['/dashboard', 'Dashboard'], ['/library', 'Library'],
  ['/collections', 'Collections'], ['/tags', 'Tags'], ['/archive', 'Archive'],
] as const;

export function NavBar({ onOpenSearch }: { onOpenSearch?: () => void }) {
  const path = usePathname(); const router = useRouter();
  async function logout() { await fetch('/api/auth/logout', { method: 'POST' }); router.push('/login'); }
  return (
    <nav style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '11px 18px',
      borderBottom: '1px solid var(--glass-line)', position: 'sticky', top: 0, zIndex: 10,
      backdropFilter: 'blur(8px)', background: 'rgba(11,16,32,.6)' }}>
      <Link href="/dashboard" style={{ fontWeight: 800, color: 'var(--violet)', textDecoration: 'none' }}>◆ NaNote Library</Link>
      <div style={{ display: 'flex', gap: 13 }}>
        {LINKS.map(([href, label]) => (
          <Link key={href} href={href} style={{ textDecoration: 'none',
            color: path.startsWith(href) ? '#fff' : '#cbd5ff',
            borderBottom: path.startsWith(href) ? '2px solid var(--violet)' : '2px solid transparent', paddingBottom: 3 }}>{label}</Link>
        ))}
      </div>
      <div style={{ marginLeft: 'auto', display: 'flex', gap: 10, alignItems: 'center' }}>
        <button onClick={onOpenSearch} title="Search (⌘K)" style={{ fontSize: 12 }}>⌕ Search</button>
        <Link href="/import" style={{ color: '#cbd5ff', textDecoration: 'none', fontSize: 13 }}>Import/Export</Link>
        <button onClick={logout} style={{ fontSize: 12 }}>Sign out</button>
      </div>
    </nav>
  );
}
```

- [ ] **Step 7: Verify + commit** — Run: `npm run build` → Expected: compiles.

```bash
git add -A && git commit -m "feat: glass design system + ported charts and Markdown renderer

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 11: Landing page `/`

**Files:**
- Replace: `src/app/page.tsx`

- [ ] **Step 1: Write `src/app/page.tsx`** (public hero; CTA → dashboard if logged in else login)

```tsx
import Link from 'next/link';
import { hasSession } from '@/lib/session';

export default async function Landing() {
  const authed = await hasSession();
  return (
    <main style={{ minHeight: '100vh', display: 'grid', placeItems: 'center', textAlign: 'center', padding: 24 }}>
      <div style={{ maxWidth: 640 }}>
        <div style={{ letterSpacing: 2, color: 'var(--violet)', fontSize: 12 }}>NANOTE</div>
        <h1 style={{ fontSize: 'clamp(2rem,6vw,3.4rem)', margin: '.4rem 0' }}>The NaNote Library</h1>
        <p style={{ color: '#cbd5ff', fontSize: 18, lineHeight: 1.6 }}>
          One knowledge base for your AI company's daily briefs — market intel, threats, research,
          content, and ops — with an executive dashboard up front.
        </p>
        <div style={{ marginTop: 24, display: 'flex', gap: 12, justifyContent: 'center' }}>
          <Link className="glass" style={{ padding: '10px 22px', textDecoration: 'none', color: '#fff' }}
            href={authed ? '/dashboard' : '/login'}>{authed ? 'Open dashboard →' : 'Sign in →'}</Link>
        </div>
      </div>
    </main>
  );
}
```

- [ ] **Step 2: Verify + commit** — Run: `npm run build`.

```bash
git add -A && git commit -m "feat: public landing page

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 12: Executive dashboard `/dashboard`

**Files:**
- Create: `src/app/dashboard/page.tsx`, `src/components/ExecOverview.tsx`, `src/lib/dashboard.ts`

- [ ] **Step 1: Write `src/lib/dashboard.ts`** (aggregate read for the overview)

```ts
import { getSql } from './db';
import { listItems } from './items';

export interface DashboardData {
  total: number; thisWeek: number; openFlags: number; pinned: number;
  byCategory: { label: string; value: number }[];
  recent: Awaited<ReturnType<typeof listItems>>;
  pinnedItems: Awaited<ReturnType<typeof listItems>>;
}

export async function getDashboard(): Promise<DashboardData> {
  const sql = getSql();
  const [{ total }] = await sql`SELECT count(*)::int total FROM item` as any[];
  const [{ week }] = await sql`SELECT count(*)::int week FROM item WHERE source_ts > now() - interval '7 days'` as any[];
  const [{ flags }] = await sql`SELECT coalesce(sum(jsonb_array_length(flags)),0)::int flags FROM item` as any[];
  const [{ pinned }] = await sql`SELECT count(*)::int pinned FROM item_state WHERE pinned` as any[];
  const cat = await sql`SELECT category, count(*)::int value FROM item GROUP BY category ORDER BY value DESC` as any[];
  const recent = await listItems({ sort: 'recent', limit: 8 });
  const pinnedItems = await listItems({ pinned: true, limit: 6 });
  return {
    total, thisWeek: week, openFlags: flags, pinned,
    byCategory: cat.map(c => ({ label: c.category ?? '—', value: c.value })),
    recent, pinnedItems,
  };
}
```

- [ ] **Step 2: Write `src/components/ExecOverview.tsx`** (uses `KpiTile`, `GlassCard`, `Donut`, dept colors, links to reader)

```tsx
import Link from 'next/link';
import { GlassCard } from './GlassCard';
import { KpiTile } from './KpiTile';
import { Donut } from './charts/Donut';
import { deptColor, deptLabel, categoryLabel } from '@/lib/format';
import type { DashboardData } from '@/lib/dashboard';

export function ExecOverview({ d }: { d: DashboardData }) {
  return (
    <div style={{ padding: '16px 18px', display: 'grid', gap: 12 }}>
      <div style={{ fontSize: 10, letterSpacing: 1.5, color: 'var(--violet)' }}>EXECUTIVE OVERVIEW</div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 10 }}>
        <KpiTile label="Total briefs" value={d.total} />
        <KpiTile label="This week" value={`+${d.thisWeek}`} color="var(--mint)" />
        <KpiTile label="Open flags" value={d.openFlags} color="var(--amber)" />
        <KpiTile label="Pinned" value={d.pinned} />
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1.6fr 1fr', gap: 12 }}>
        <GlassCard>
          <h3 style={{ marginTop: 0, fontSize: 14 }}>Recent briefs</h3>
          <div style={{ display: 'grid', gap: 8 }}>
            {d.recent.map(it => (
              <Link key={it.id} href={`/library/${it.id}`} style={{ display: 'flex', gap: 8, alignItems: 'center', textDecoration: 'none', color: 'var(--ink)', fontSize: 13 }}>
                <span style={{ width: 6, height: 6, borderRadius: 9, background: deptColor(it.dept) }} />
                <span>{deptLabel(it.dept)} · {categoryLabel(it.category)} — {it.highlight || it.summary.slice(0, 60)}</span>
                <span style={{ marginLeft: 'auto', color: '#889', fontSize: 11 }}>{it.sourceDate}</span>
              </Link>
            ))}
            {d.recent.length === 0 && <p style={{ color: '#889' }}>No briefs yet — run a sync from Import/Export.</p>}
          </div>
        </GlassCard>
        <GlassCard>
          <h3 style={{ marginTop: 0, fontSize: 14 }}>By category</h3>
          <Donut a={{ kind: 'donut', title: '', series: d.byCategory.map(c => ({ label: categoryLabel(c.label), value: c.value })) }} />
        </GlassCard>
      </div>
    </div>
  );
}
```

- [ ] **Step 3: Write `src/app/dashboard/page.tsx`** (gated server page)

```tsx
import { requireSession } from '@/lib/session';
import { NavBar } from '@/components/NavBar';
import { ExecOverview } from '@/components/ExecOverview';
import { getDashboard } from '@/lib/dashboard';

export const dynamic = 'force-dynamic';

export default async function DashboardPage() {
  await requireSession();
  const d = await getDashboard();
  return <><NavBar /><ExecOverview d={d} /></>;
}
```

- [ ] **Step 4: Verify + commit** — Run: `npm run build`.

```bash
git add -A && git commit -m "feat: executive glass dashboard

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 13: Library browse `/library` + FilterBar + ItemCard

**Files:**
- Create: `src/app/library/page.tsx`, `src/components/FilterBar.tsx`, `src/components/ItemCard.tsx`

- [ ] **Step 1: Write `src/components/ItemCard.tsx`**

```tsx
import Link from 'next/link';
import { deptColor, deptLabel, categoryLabel } from '@/lib/format';
import type { Item } from '@/lib/types';

export function ItemCard({ it }: { it: Item }) {
  return (
    <Link href={`/library/${it.id}`} className="glass" style={{ padding: 14, textDecoration: 'none', color: 'var(--ink)', display: 'block' }}>
      <div style={{ display: 'flex', gap: 8, alignItems: 'center', fontSize: 11, color: '#aab' }}>
        <span style={{ width: 7, height: 7, borderRadius: 9, background: deptColor(it.dept) }} />
        {deptLabel(it.dept)} · {categoryLabel(it.category)}
        <span style={{ marginLeft: 'auto' }}>{it.sourceDate}</span>
      </div>
      <div style={{ fontWeight: 600, marginTop: 6 }}>{it.highlight || it.summary.slice(0, 80)}</div>
      <p style={{ color: '#bcc', fontSize: 13, margin: '6px 0 0' }}>{it.summary.slice(0, 140)}</p>
      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginTop: 8 }}>
        {(it.tags ?? []).slice(0, 5).map(t => <span key={t} style={{ fontSize: 11, color: '#a9b' }}>#{t}</span>)}
      </div>
    </Link>
  );
}
```

- [ ] **Step 2: Write `src/components/FilterBar.tsx`** (client; updates URL query params)

```tsx
'use client';
import { useRouter, useSearchParams } from 'next/navigation';
import { ALL_DEPTS, ALL_CATEGORIES, deptLabel, categoryLabel } from '@/lib/format';

export function FilterBar() {
  const router = useRouter(); const sp = useSearchParams();
  function set(key: string, val: string) {
    const next = new URLSearchParams(sp.toString());
    if (val) next.set(key, val); else next.delete(key);
    router.push(`/library?${next.toString()}`);
  }
  return (
    <div style={{ display: 'flex', gap: 8, padding: '10px 18px', flexWrap: 'wrap' }}>
      <input defaultValue={sp.get('q') ?? ''} placeholder="Search…" onKeyDown={e => { if (e.key === 'Enter') set('q', (e.target as HTMLInputElement).value); }} />
      <select value={sp.get('dept') ?? ''} onChange={e => set('dept', e.target.value)}>
        <option value="">All depts</option>
        {ALL_DEPTS.map(d => <option key={d} value={d}>{deptLabel(d)}</option>)}
      </select>
      <select value={sp.get('category') ?? ''} onChange={e => set('category', e.target.value)}>
        <option value="">All categories</option>
        {ALL_CATEGORIES.map(c => <option key={c} value={c}>{categoryLabel(c)}</option>)}
      </select>
      <select value={sp.get('sort') ?? 'recent'} onChange={e => set('sort', e.target.value)}>
        <option value="recent">Newest</option><option value="oldest">Oldest</option>
      </select>
    </div>
  );
}
```

- [ ] **Step 3: Write `src/app/library/page.tsx`** (gated; reads filters from `searchParams`)

```tsx
import { requireSession } from '@/lib/session';
import { NavBar } from '@/components/NavBar';
import { FilterBar } from '@/components/FilterBar';
import { ItemCard } from '@/components/ItemCard';
import { listItems } from '@/lib/items';

export const dynamic = 'force-dynamic';

export default async function LibraryPage({ searchParams }: { searchParams: Promise<Record<string, string>> }) {
  await requireSession();
  const sp = await searchParams;
  const items = await listItems({
    dept: sp.dept, category: sp.category, q: sp.q,
    sort: (sp.sort as 'recent' | 'oldest') ?? 'recent', limit: 60,
  });
  return (
    <>
      <NavBar /><FilterBar />
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill,minmax(280px,1fr))', gap: 12, padding: '4px 18px 24px' }}>
        {items.map(it => <ItemCard key={it.id} it={it} />)}
        {items.length === 0 && <p style={{ color: '#889' }}>No matching briefs.</p>}
      </div>
    </>
  );
}
```

- [ ] **Step 4: Verify + commit** — Run: `npm run build`.

```bash
git add -A && git commit -m "feat: library browse with filters

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 14: Reader `/library/[id]` (Notion-style) + state actions

**Files:**
- Create: `src/app/library/[id]/page.tsx`, `src/components/BriefReader.tsx`, `src/components/StateActions.tsx`

- [ ] **Step 1: Write `src/components/StateActions.tsx`** (client; pin/save/archive buttons → `/api/state`)

```tsx
'use client';
import { useState } from 'react';
import type { ItemState } from '@/lib/types';

export function StateActions({ itemId, initial }: { itemId: string; initial: ItemState }) {
  const [s, setS] = useState(initial);
  async function toggle(field: keyof ItemState) {
    const res = await fetch('/api/state', { method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ itemId, field, value: !s[field] }) });
    if (res.ok) setS((await res.json()).state);
  }
  const btn = (field: keyof ItemState, on: string, off: string) =>
    <button onClick={() => toggle(field)} style={{ fontSize: 12, opacity: s[field] ? 1 : .6 }}>{s[field] ? on : off}</button>;
  return <div style={{ display: 'flex', gap: 8 }}>{btn('pinned', '★ Pinned', '☆ Pin')}{btn('saved', '✓ Saved', '+ Save')}{btn('archived', '🗀 Archived', 'Archive')}</div>;
}
```

- [ ] **Step 2: Write `src/components/BriefReader.tsx`** (Notion two-pane: content + sticky right rail)

```tsx
import { Markdown } from './Markdown';
import { ArtifactRenderer } from './charts/ArtifactRenderer';
import { StateActions } from './StateActions';
import { GlassCard } from './GlassCard';
import { deptLabel, categoryLabel, deptColor } from '@/lib/format';
import type { Item } from '@/lib/types';
import { EMPTY_STATE } from '@/lib/types';

export function BriefReader({ it }: { it: Item }) {
  return (
    <div style={{ display: 'grid', gridTemplateColumns: 'minmax(0,1fr) 280px', gap: 20, padding: '18px 22px', maxWidth: 1100, margin: '0 auto' }}>
      <article>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, color: '#aab', fontSize: 12 }}>
          <span style={{ width: 8, height: 8, borderRadius: 9, background: deptColor(it.dept) }} />
          {deptLabel(it.dept)} · {categoryLabel(it.category)} · {it.sourceDate}
        </div>
        <h1 style={{ fontSize: 26, margin: '8px 0' }}>{it.highlight || it.summary.slice(0, 80)}</h1>
        <p style={{ color: '#cbd5ff', fontSize: 16 }}>{it.summary}</p>
        {it.artifacts.length > 0 && (
          <div style={{ display: 'grid', gap: 14, margin: '18px 0' }}>
            {it.artifacts.map((a, i) => <GlassCard key={i}><ArtifactRenderer artifact={a} /></GlassCard>)}
          </div>
        )}
        <div style={{ marginTop: 18 }}><Markdown>{it.bodyMd}</Markdown></div>
      </article>
      <aside style={{ position: 'sticky', top: 70, alignSelf: 'start', display: 'grid', gap: 12 }}>
        <GlassCard><StateActions itemId={it.id} initial={it.state ?? EMPTY_STATE} /></GlassCard>
        {it.flags.length > 0 && <GlassCard><h4 style={{ margin: '0 0 6px' }}>Flags</h4>{it.flags.map((f, i) => <div key={i} style={{ fontSize: 13, color: 'var(--amber)' }}>⚑ {f}</div>)}</GlassCard>}
        {(it.tags ?? []).length > 0 && <GlassCard><h4 style={{ margin: '0 0 6px' }}>Tags</h4><div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>{it.tags!.map(t => <span key={t} style={{ fontSize: 12, color: '#a9b' }}>#{t}</span>)}</div></GlassCard>}
      </aside>
    </div>
  );
}
```

- [ ] **Step 3: Write `src/app/library/[id]/page.tsx`**

```tsx
import { notFound } from 'next/navigation';
import { requireSession } from '@/lib/session';
import { NavBar } from '@/components/NavBar';
import { BriefReader } from '@/components/BriefReader';
import { getItem } from '@/lib/items';

export const dynamic = 'force-dynamic';

export default async function ReaderPage({ params }: { params: Promise<{ id: string }> }) {
  await requireSession();
  const { id } = await params;
  const it = await getItem(id);
  if (!it) notFound();
  return <><NavBar /><BriefReader it={it} /></>;
}
```

- [ ] **Step 4: Verify + commit** — Run: `npm run build`.

```bash
git add -A && git commit -m "feat: Notion-style brief reader with pin/save/archive

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 15: Collections, Tags, Archive pages

**Files:**
- Create: `src/app/collections/page.tsx`, `src/app/collections/[slug]/page.tsx`,
  `src/app/tags/page.tsx`, `src/app/tags/[slug]/page.tsx`, `src/app/archive/page.tsx`

- [ ] **Step 1: `src/app/collections/page.tsx`** (list collections as glass cards)

```tsx
import Link from 'next/link';
import { requireSession } from '@/lib/session';
import { NavBar } from '@/components/NavBar';
import { GlassCard } from '@/components/GlassCard';
import { listCollections } from '@/lib/collections';
export const dynamic = 'force-dynamic';

export default async function CollectionsPage() {
  await requireSession();
  const cols = await listCollections();
  return (
    <>
      <NavBar />
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill,minmax(220px,1fr))', gap: 12, padding: 18 }}>
        {cols.map(c => (
          <Link key={c.id} href={`/collections/${c.slug}`} style={{ textDecoration: 'none' }}>
            <GlassCard style={{ borderLeft: `3px solid ${c.color}` }}>
              <div style={{ fontSize: 20 }}>{c.icon}</div>
              <div style={{ fontWeight: 600, color: 'var(--ink)' }}>{c.name}</div>
              <div style={{ color: '#889', fontSize: 12 }}>{c.itemCount ?? 0} items</div>
            </GlassCard>
          </Link>
        ))}
        {cols.length === 0 && <p style={{ color: '#889' }}>No collections yet.</p>}
      </div>
    </>
  );
}
```

- [ ] **Step 2: `src/app/collections/[slug]/page.tsx`** (items in a collection — reuse ItemCard)

```tsx
import { requireSession } from '@/lib/session';
import { NavBar } from '@/components/NavBar';
import { ItemCard } from '@/components/ItemCard';
import { listItems } from '@/lib/items';
export const dynamic = 'force-dynamic';

export default async function CollectionPage({ params }: { params: Promise<{ slug: string }> }) {
  await requireSession();
  const { slug } = await params;
  const items = await listItems({ collection: slug, limit: 100 });
  return (
    <>
      <NavBar />
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill,minmax(280px,1fr))', gap: 12, padding: 18 }}>
        {items.map(it => <ItemCard key={it.id} it={it} />)}
        {items.length === 0 && <p style={{ color: '#889' }}>Empty collection.</p>}
      </div>
    </>
  );
}
```

- [ ] **Step 3: `src/app/tags/page.tsx`** (tag cloud linking to `/tags/[slug]`)

```tsx
import Link from 'next/link';
import { requireSession } from '@/lib/session';
import { NavBar } from '@/components/NavBar';
import { listTags } from '@/lib/tags';
export const dynamic = 'force-dynamic';

export default async function TagsPage() {
  await requireSession();
  const tags = await listTags();
  return (
    <>
      <NavBar />
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10, padding: 18 }}>
        {tags.map(t => (
          <Link key={t.id} href={`/tags/${t.slug}`} className="glass" style={{ padding: '6px 12px', textDecoration: 'none', color: 'var(--ink)', fontSize: 13 + Math.min((t.count ?? 1), 8) }}>
            #{t.label} <span style={{ color: '#889' }}>{t.count}</span>
          </Link>
        ))}
        {tags.length === 0 && <p style={{ color: '#889' }}>No tags yet.</p>}
      </div>
    </>
  );
}
```

- [ ] **Step 4: `src/app/tags/[slug]/page.tsx`** (items for a tag — reuse ItemCard, same body as collection page but `{ tag: slug }`)

```tsx
import { requireSession } from '@/lib/session';
import { NavBar } from '@/components/NavBar';
import { ItemCard } from '@/components/ItemCard';
import { listItems } from '@/lib/items';
export const dynamic = 'force-dynamic';

export default async function TagPage({ params }: { params: Promise<{ slug: string }> }) {
  await requireSession();
  const { slug } = await params;
  const items = await listItems({ tag: slug, limit: 100 });
  return (
    <>
      <NavBar />
      <div style={{ padding: '8px 18px', color: '#aab' }}>#{slug}</div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill,minmax(280px,1fr))', gap: 12, padding: '0 18px 24px' }}>
        {items.map(it => <ItemCard key={it.id} it={it} />)}
        {items.length === 0 && <p style={{ color: '#889' }}>No briefs with this tag.</p>}
      </div>
    </>
  );
}
```

- [ ] **Step 5: `src/app/archive/page.tsx`** (archived items)

```tsx
import { requireSession } from '@/lib/session';
import { NavBar } from '@/components/NavBar';
import { ItemCard } from '@/components/ItemCard';
import { listItems } from '@/lib/items';
export const dynamic = 'force-dynamic';

export default async function ArchivePage() {
  await requireSession();
  const items = await listItems({ archived: true, limit: 100 });
  return (
    <>
      <NavBar />
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill,minmax(280px,1fr))', gap: 12, padding: 18 }}>
        {items.map(it => <ItemCard key={it.id} it={it} />)}
        {items.length === 0 && <p style={{ color: '#889' }}>Archive is empty.</p>}
      </div>
    </>
  );
}
```

- [ ] **Step 6: Verify + commit** — Run: `npm run build`.

```bash
git add -A && git commit -m "feat: collections, tags, and archive pages

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 16: Import/Export page + sync panel

**Files:**
- Create: `src/app/import/page.tsx`, `src/components/SyncPanel.tsx`, `src/lib/syncLog.ts`

- [ ] **Step 1: Write `src/lib/syncLog.ts`** (read recent sync history)

```ts
import { getSql } from './db';
import type { SyncLog } from './types';

export async function recentSyncs(limit = 10): Promise<SyncLog[]> {
  const sql = getSql();
  const rows = await sql`SELECT id, started_at, finished_at, fetched_count, upserted_count, status, error
    FROM sync_log ORDER BY started_at DESC LIMIT ${limit}` as any[];
  return rows.map(r => ({ id: r.id, startedAt: r.started_at, finishedAt: r.finished_at,
    fetchedCount: r.fetched_count, upsertedCount: r.upserted_count, status: r.status, error: r.error }));
}
```

- [ ] **Step 2: Write `src/components/SyncPanel.tsx`** (client; Sync button → POST `/api/sync`, export links)

```tsx
'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';

export function SyncPanel() {
  const router = useRouter(); const [busy, setBusy] = useState(false); const [msg, setMsg] = useState('');
  async function sync() {
    setBusy(true); setMsg('');
    const res = await fetch('/api/sync', { method: 'POST' });
    const j = await res.json().catch(() => ({}));
    setBusy(false);
    setMsg(res.ok ? `Synced: ${j.log?.upsertedCount ?? 0} items` : 'Sync failed');
    router.refresh();
  }
  return (
    <div style={{ display: 'grid', gap: 12 }}>
      <button onClick={sync} disabled={busy}>{busy ? 'Syncing…' : '⟳ Sync from company KB'}</button>
      {msg && <span style={{ fontSize: 13, color: '#9fb' }}>{msg}</span>}
      <div style={{ display: 'flex', gap: 10 }}>
        <a href="/api/export?format=md" className="glass" style={{ padding: '6px 12px', textDecoration: 'none', color: 'var(--ink)' }}>Export Markdown</a>
        <a href="/api/export?format=json" className="glass" style={{ padding: '6px 12px', textDecoration: 'none', color: 'var(--ink)' }}>Export JSON</a>
        <a href="/api/export?format=pdf" target="_blank" className="glass" style={{ padding: '6px 12px', textDecoration: 'none', color: 'var(--ink)' }}>Export PDF (print)</a>
      </div>
    </div>
  );
}
```

- [ ] **Step 3: Write `src/app/import/page.tsx`**

```tsx
import { requireSession } from '@/lib/session';
import { NavBar } from '@/components/NavBar';
import { GlassCard } from '@/components/GlassCard';
import { SyncPanel } from '@/components/SyncPanel';
import { recentSyncs } from '@/lib/syncLog';
export const dynamic = 'force-dynamic';

export default async function ImportPage() {
  await requireSession();
  const logs = await recentSyncs();
  return (
    <>
      <NavBar />
      <div style={{ padding: 18, display: 'grid', gap: 14, maxWidth: 760 }}>
        <GlassCard><h3 style={{ marginTop: 0 }}>Import & Export</h3><SyncPanel /></GlassCard>
        <GlassCard>
          <h4 style={{ marginTop: 0 }}>Recent syncs</h4>
          {logs.map(l => (
            <div key={l.id} style={{ display: 'flex', gap: 10, fontSize: 13, padding: '4px 0', color: l.status === 'error' ? '#ff8080' : '#cbd5ff' }}>
              <span>{new Date(l.startedAt).toLocaleString()}</span>
              <span style={{ marginLeft: 'auto' }}>{l.status} · {l.upsertedCount} upserted</span>
            </div>
          ))}
          {logs.length === 0 && <p style={{ color: '#889' }}>No syncs yet.</p>}
        </GlassCard>
      </div>
    </>
  );
}
```

- [ ] **Step 4: Verify + commit** — Run: `npm run build`.

```bash
git add -A && git commit -m "feat: import/export page with sync panel and history

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 17: Cmd-K global search

**Files:**
- Create: `src/components/CommandSearch.tsx`, `src/components/AppChrome.tsx`
- Modify: dashboard/library/etc. to render `<AppChrome>` instead of `<NavBar>` (wraps NavBar + search modal)

- [ ] **Step 1: Write `src/components/CommandSearch.tsx`** (client; debounced fetch `/api/items?q=`)

```tsx
'use client';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import type { Item } from '@/lib/types';

export function CommandSearch({ open, onClose }: { open: boolean; onClose: () => void }) {
  const router = useRouter(); const [q, setQ] = useState(''); const [items, setItems] = useState<Item[]>([]);
  useEffect(() => {
    if (!open || !q.trim()) { setItems([]); return; }
    const t = setTimeout(async () => {
      const res = await fetch(`/api/items?q=${encodeURIComponent(q)}&limit=8`);
      if (res.ok) setItems((await res.json()).items);
    }, 180);
    return () => clearTimeout(t);
  }, [q, open]);
  if (!open) return null;
  return (
    <div onClick={onClose} style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,.5)', display: 'grid', placeItems: 'start center', paddingTop: '12vh', zIndex: 50 }}>
      <div onClick={e => e.stopPropagation()} className="glass" style={{ width: 'min(620px,92vw)', padding: 14 }}>
        <input autoFocus placeholder="Search the library…" value={q} onChange={e => setQ(e.target.value)} style={{ width: '100%' }} />
        <div style={{ marginTop: 10, display: 'grid', gap: 4 }}>
          {items.map(it => (
            <button key={it.id} onClick={() => { onClose(); router.push(`/library/${it.id}`); }}
              style={{ textAlign: 'left', fontSize: 13, padding: 8 }}>
              {it.highlight || it.summary.slice(0, 70)}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Write `src/components/AppChrome.tsx`** (client; owns search-open state + ⌘K listener, renders NavBar + modal)

```tsx
'use client';
import { useEffect, useState } from 'react';
import { NavBar } from './NavBar';
import { CommandSearch } from './CommandSearch';

export function AppChrome() {
  const [open, setOpen] = useState(false);
  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') { e.preventDefault(); setOpen(o => !o); }
      if (e.key === 'Escape') setOpen(false);
    }
    window.addEventListener('keydown', onKey); return () => window.removeEventListener('keydown', onKey);
  }, []);
  return <><NavBar onOpenSearch={() => setOpen(true)} /><CommandSearch open={open} onClose={() => setOpen(false)} /></>;
}
```

- [ ] **Step 3: Swap `<NavBar />` → `<AppChrome />`** in `dashboard/page.tsx`, `library/page.tsx`, `library/[id]/page.tsx`, `collections/page.tsx`, `collections/[slug]/page.tsx`, `tags/page.tsx`, `tags/[slug]/page.tsx`, `archive/page.tsx`, `import/page.tsx`. (Update each import line and tag.)

- [ ] **Step 4: Verify + commit** — Run: `npm run build`.

```bash
git add -A && git commit -m "feat: Cmd-K global search

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 18: Provision, verify end-to-end, and deploy v0.1

**Files:**
- Create: `CLAUDE.md` (project guide), `README.md`

- [ ] **Step 1: Full local verification gate**

Run: `npm run test && npx tsc --noEmit && npm run lint && npm run build`
Expected: tests pass, no type errors, lint clean, build succeeds.

- [ ] **Step 2: Provision Neon (free tier) + apply schema**

- Create a Neon project via the Vercel dashboard (Storage → Postgres/Neon → **Free**), or `vercel` Marketplace. Copy `POSTGRES_URL`.
- Run: `POSTGRES_URL=... npm run db:migrate` → Expected: `applied N statements`.

- [ ] **Step 3: Create the Vercel project + env vars**

- New Vercel project linked to `khantee8/kb.nanoteofficial.me`.
- Set env (Production + Preview): `KB_ADMIN_USER`, `KB_ADMIN_PASSWORD`, `COMPANY_KB_URL=https://company.nanoteofficial.me/api/kb`, `POSTGRES_URL`, `SYNC_SECRET`, `CRON_SECRET`.

- [ ] **Step 4: First deploy + seed data**

- Push to `main` (auto-deploy), or `vercel --prod`.
- Trigger the first sync: `curl -X POST https://kb.nanoteofficial.me/api/sync -H "authorization: Bearer $SYNC_SECRET"`.
- Expected JSON: `{ "ok": true, "log": { "status": "ok", "upsertedCount": >0 } }`.

- [ ] **Step 5: Browser smoke test (Playwright/manual)**

- `/` landing renders; "Sign in" → `/login`.
- Wrong creds → error; correct creds → `/dashboard` with KPIs + recent + donut populated.
- `/library` filters by dept/category; search returns results; open a brief → reader shows summary, charts, markdown, flags; Pin toggles and persists on refresh.
- `/collections`, `/tags`, `/archive` load; `/import` shows the sync log; Export MD/JSON download, PDF opens printable view.
- Capture screenshots of `/dashboard` and a reader page.

- [ ] **Step 6: Add the `kb` CNAME**

- In Namecheap, add `kb` CNAME → Vercel (per the other `*.nanoteofficial.me` projects). Add the domain in Vercel. Verify `https://kb.nanoteofficial.me` resolves and is gated.

- [ ] **Step 7: Write `CLAUDE.md` + `README.md`** documenting: stack, the pull+cache sync model, the unified `item` schema, env vars, and the "no LLM / free-tier" constraints (mirror spec §13). Commit.

- [ ] **Step 8: Tag v0.1 via base-deployment**

Use the **base-deployment** skill to run the release: verify → version bump (already `0.1.0`) → commit → confirm Vercel production push. Then:
```bash
git tag v0.1.0 && git push origin v0.1.0
```

- [ ] **Step 9: Final commit**

```bash
git add -A && git commit -m "docs: project CLAUDE.md + README for v0.1

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review notes (author check)

- **Spec coverage:** Auth (T4–5), pull+cache sync + daily cron (T6), unified `item` schema (T2–3),
  items/search (T7), collections/tags/state (T8), export MD/JSON/PDF (T9), glass dashboard (T12),
  library + reader (T13–14), collections/tags/archive pages (T15), import/export UI (T16), Cmd-K (T17),
  landing (T11), deploy + Neon free tier + CNAME + v0.1 tag (T18), $0 cost (vercel.json daily cron,
  no Anthropic dep). All spec sections map to a task.
- **No LLM:** confirmed — no `@anthropic-ai/sdk` in `package.json`, no model calls anywhere.
- **Type consistency:** `Item`/`ItemState`/`Collection`/`Tag`/`SyncLog` defined in T2 and consumed
  unchanged; `buildItemsWhere`/`listItems`/`getItem`/`rowToItem` names stable across T7→T12–15;
  `setState` field allowlist matches `ItemState` keys; `ArtifactRenderer` prop is `artifact` (matches
  ported source).
- **Placeholder scan:** no TBD/TODO; every code step shows complete code; ported files give exact
  source path + the precise edits to make.

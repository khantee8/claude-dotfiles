# kb.nanoteofficial.me — NaNote Library v0.1 — Design

**Date:** 2026-06-03
**Status:** Approved (brainstorm) → ready for implementation plan
**Repo (to create):** `khantee8/kb.nanoteofficial.me` under `/project/src/`
**Live target:** https://kb.nanoteofficial.me (Vercel Hobby, auto-deploy from `main`, `kb` CNAME in Namecheap)

---

## 1. Summary

kb.nanoteofficial.me is the **NaNote Library** — a login-gated knowledge base with a glassmorphism
**executive dashboard** up front and a calm, Notion-style **reader** for individual entries.

v0.1 is scoped as a **reader/dashboard over the company KB feed**: it ingests the AI company's
**published** briefs from `company.nanoteofficial.me/api/kb` and presents them with browse, search,
collections, tags, archive, and export. It is built on a data model that already accommodates
**personal notes / Obsidian import** (v0.2) with near-zero rework.

### Scope decisions (locked during brainstorm)

| Question | Decision |
|---|---|
| v0.1 scope | Company-KB **reader first**; architect the data layer for the broader Library |
| Login | **Username + password**, HMAC-signed session cookie (port company `/admin` `auth.ts`) |
| Company data access | **Fetch public `/api/kb` over HTTPS** and cache (no shared DB creds) |
| Own database | **Vercel Postgres (Neon)** — relational schema |
| Dashboard / landing look | **NaNote Glass** (evolves company `/dashboard` glassmorphism) |
| Reader look | **Notion-clean** (content column + right meta/TOC rail) |
| Search | **Postgres full-text** (tsvector), Cmd-K global |

### Non-goals (v0.2+, architected but NOT built)

- Personal notes (create/edit markdown in-app)
- Obsidian vault file import (`.md` upload / folder)
- Graph view / backlinks
- Multi-user & roles
- Live webhook push from company (v0.1 is pull/cron)

---

## 2. Stack & conventions

- **Next.js 16 (App Router), React 19, TypeScript, Tailwind v4** — matches every other
  nanoteofficial project. Next.js 16 APIs differ from training data: consult `context7` MCP or
  `node_modules/next/dist/docs/` before writing Next-specific code.
- **Vitest** for unit tests (house pattern).
- **Vercel Hobby**, auto-deploy from `main`; `kb.nanoteofficial.me` CNAME → Vercel.
- No `dangerouslySetInnerHTML` — port the company `Markdown` safe renderer.

---

## 3. Authentication

Port the company `/admin` pattern verbatim where possible:

- Env: `KB_ADMIN_USER`, `KB_ADMIN_PASSWORD`.
- Stateless **HMAC-signed session cookie** (`src/lib/auth.ts`), secret = `KB_ADMIN_PASSWORD`. Fails closed.
- **No middleware.** Each gated page checks the cookie server-side via `cookies()`; each gated API
  route re-checks. (Same model the company app uses — keeps edge config simple.)
- **Public routes:** `/` (landing) and `/login` (+ its `/api/auth/login`). Everything else is gated.

---

## 4. Data flow — pull + cache

```
company.nanoteofficial.me/api/kb  ──HTTPS pull──▶  POST /api/sync  ──upsert──▶  Neon Postgres
                                                                                     │
   UI: dashboard · library · reader · search · collections · export  ◀── reads ─────┘
```

- The UI **never** calls the company API directly. It reads Postgres → search/filter/FTS are fast,
  and the company site being down never breaks reads (last good cache stays served).
- **Sync** (`POST /api/sync`, guarded by `SYNC_SECRET`) fetches `COMPANY_KB_URL` (default
  `https://company.nanoteofficial.me/api/kb?limit=200`), maps each `KbEntry` → `item` row, and
  **upserts** on `external_id`. Records a `sync_log` row.
- Triggered by (a) a manual **Sync** button on `/import` (primary, on-demand) and (b) **one daily
  Vercel Cron** in `vercel.json`. Daily is the maximum schedule frequency on the **Vercel Hobby free
  tier** — and it's plenty, since the company agents post on a daily cadence. No sub-daily cron, so no
  Pro plan is required.
- The company feed is **published-only** by design (draft→publish gate lives in the company `/admin`),
  so the Library only ever sees curated entries.

### Upstream contract consumed (from company.nanoteofficial.me)

`GET /api/kb?dept=&category=&q=&from=&to=&limit=` → `{ entries: KbEntry[], count, generatedAt }`, where:

```ts
interface KbEntry {
  id: string; dept: 'ceo'|'cyb'|'mkt'|'rnd'|'ops'|'fin';
  date: string; ts: string;
  category: 'market-brief'|'threat-intel'|'research'|'content-plan'|'ops-status'|'exec-brief';
  tags: string[]; status: 'draft'|'published'|'archived'; pinned?: boolean;
  summary: string; highlight: string; flags: string[];
  artifacts: Artifact[];   // typed chart union (bars|divergingBars|donut|line|sparkline|table|scorecard|heatmap|tags|checklist)
  markdown: string;
}
```

Departments: `ceo` NaNote CEO · `fin` Finance · `cyb` CyberX · `mkt` Marketing & Social Media ·
`rnd` AI R&D · `ops` Operations. Category is 1:1 with department.

---

## 5. Database schema (Neon Postgres) — unified `item` model

Company briefs and future notes are both **items** (`kind` discriminator), so collections, tags,
search, and archive work for both from day one. This is the central architecture-for-later choice.

```sql
-- one row per knowledge artifact (company brief now; personal note in v0.2)
CREATE TABLE item (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kind         text NOT NULL CHECK (kind IN ('company_brief','note')),
  external_id  text UNIQUE,                 -- company KbEntry.id (null for notes)
  dept         text,                        -- company DeptId (null for notes)
  category     text,                        -- company KbCategory or user category (null ok)
  summary      text NOT NULL DEFAULT '',
  highlight    text NOT NULL DEFAULT '',
  body_md      text NOT NULL DEFAULT '',    -- KbEntry.markdown / note body
  flags        jsonb NOT NULL DEFAULT '[]',
  artifacts    jsonb NOT NULL DEFAULT '[]', -- KbEntry.artifacts (rendered by ported chart primitives)
  source_date  date,                        -- KbEntry.date
  source_ts    timestamptz,                 -- KbEntry.ts
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  search       tsvector                     -- generated/maintained from summary+highlight+body_md+tags
);
CREATE INDEX item_search_idx   ON item USING gin (search);
CREATE INDEX item_dept_idx     ON item (dept);
CREATE INDEX item_category_idx ON item (category);
CREATE INDEX item_date_idx     ON item (source_date DESC);

-- user groupings ("category manager")
CREATE TABLE collection (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL,
  slug        text UNIQUE NOT NULL,
  description text NOT NULL DEFAULT '',
  color       text NOT NULL DEFAULT '#a78bfa',
  icon        text NOT NULL DEFAULT '◆',
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE collection_item (
  collection_id uuid REFERENCES collection(id) ON DELETE CASCADE,
  item_id       uuid REFERENCES item(id)       ON DELETE CASCADE,
  added_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (collection_id, item_id)
);

-- canonical tags (company tags seeded; user can add more)
CREATE TABLE tag (
  id    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  label text NOT NULL,
  slug  text UNIQUE NOT NULL
);
CREATE TABLE item_tag (
  item_id uuid REFERENCES item(id) ON DELETE CASCADE,
  tag_id  uuid REFERENCES tag(id)  ON DELETE CASCADE,
  source  text NOT NULL DEFAULT 'company' CHECK (source IN ('company','user')),
  PRIMARY KEY (item_id, tag_id)
);

-- per-item user state (single user in v0.1; user_id reserved for multi-user later)
CREATE TABLE item_state (
  item_id   uuid PRIMARY KEY REFERENCES item(id) ON DELETE CASCADE,
  user_id   text NOT NULL DEFAULT 'owner',
  pinned    boolean NOT NULL DEFAULT false,
  archived  boolean NOT NULL DEFAULT false,
  saved     boolean NOT NULL DEFAULT false,
  read      boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- import audit
CREATE TABLE sync_log (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  started_at    timestamptz NOT NULL DEFAULT now(),
  finished_at   timestamptz,
  fetched_count int NOT NULL DEFAULT 0,
  upserted_count int NOT NULL DEFAULT 0,
  status        text NOT NULL DEFAULT 'running' CHECK (status IN ('running','ok','error')),
  error         text
);
```

**Sync upsert rule:** map `KbEntry` → `item` (`kind='company_brief'`, `external_id=KbEntry.id`),
`ON CONFLICT (external_id) DO UPDATE` the mutable fields and `updated_at`. Seed `tag`/`item_tag`
(`source='company'`) from `KbEntry.tags`. Never delete on sync (archive instead). `item_state` rows
are created lazily on first pin/archive/save.

---

## 6. Pages / routes

| Route | Gate | Purpose |
|---|---|---|
| `/` | public | **Landing** — hero, what the NaNote Library is, login CTA |
| `/login` | public | Username + password form |
| `/dashboard` | gated | **Glass executive overview** — KPI strip, recent feed, by-category donut, flags, pinned |
| `/library` | gated | Browse all items; filter dept · category · date; sort; list/grid |
| `/library/[id]` | gated | **Notion-style reader** — summary, artifacts/charts, markdown, right rail (meta, tags, flags, on-this-page) |
| `/collections` · `/collections/[slug]` | gated | Manage groupings; view a collection's items |
| `/tags` · `/tags/[slug]` | gated | Tag explorer; rename/merge; view a tag's items |
| `/archive` | gated | Archived items, restore |
| `/import` | gated | Sync trigger + `sync_log` history + export tools |

**API routes**

| Route | Purpose |
|---|---|
| `/api/auth/login` · `/api/auth/logout` | set/clear HMAC session cookie |
| `/api/sync` | `SYNC_SECRET`-guarded; pull `COMPANY_KB_URL`, upsert items, write `sync_log` |
| `/api/items` | list/filter/search (`?dept=&category=&tag=&collection=&q=&archived=&pinned=&sort=&limit=`) |
| `/api/items/[id]` | single item (for reader) |
| `/api/collections` | CRUD + add/remove item |
| `/api/tags` | list / rename / merge |
| `/api/state` | toggle pinned/archived/saved/read on an item |
| `/api/export` | item or collection → Markdown / JSON / PDF |

---

## 7. Components & design system

- **NavBar** — `Dashboard · Library · Collections · Tags · Archive` + global Cmd-K search trigger +
  Import/Export menu + account. Responsive (collapses to a drawer on mobile).
- **Glass primitives** — `GlassCard`, `KpiTile`, deep-gradient `AppBackground`.
- **Charts** — port the company's **zero-dep, SSR-safe SVG primitives** (`Bars/Donut/Line/DataTable/
  Scorecard/Heatmap/TagCloud/Checklist`) behind an `ArtifactRenderer` switching on `Artifact.kind`,
  so cached `artifacts[]` render in both dashboard and reader.
- **Dashboard** — `ExecOverview` (KPI strip, recent briefs, by-category donut, open-flags feed,
  pinned shelf).
- **Reader** — `BriefReader` (Notion-clean two-pane: content + sticky right rail).
- **Browse** — `FilterBar`, `ItemCard`, `ItemList`.
- **Search** — `CommandSearch` (Cmd-K modal over Postgres FTS).
- **Markdown** — ported safe renderer (no `dangerouslySetInnerHTML`).
- Built with the **frontend-design** and **ui-ux-pro-max** skills during implementation.

---

## 8. Search

Postgres `tsvector` (`item.search`) over `summary + highlight + body_md + tags`, combined with
structured filters (dept, category, tag, collection, archived/pinned). Ranked with `ts_rank`.
Surfaced globally via Cmd-K and inline on `/library`.

---

## 9. Import / Export

- **Import v0.1** = company sync (button on `/import` + one daily cron). `.md`/Obsidian file import is
  designed into the `item` model (`kind='note'`) but **not built** in v0.1.
- **Export** = single item or whole collection → **Markdown** (bundle) · **JSON** · **PDF**. Port the
  company export utility (PDF built from `textContent` only — no raw HTML injection).

---

## 10. Env vars (Vercel)

`KB_ADMIN_USER`, `KB_ADMIN_PASSWORD`, `COMPANY_KB_URL`
(`https://company.nanoteofficial.me/api/kb`), `POSTGRES_URL` (Neon), `SYNC_SECRET`, `CRON_SECRET`.

---

## 11. Testing & verification

- **Vitest** pure units: sync mapper (`KbEntry → item`), search/filter query builder, export
  serializers (MD/JSON), tag-normalize/merge, auth cookie sign/verify.
- **No visual unit tests** — verify dashboard/reader with the dev server + Playwright screenshots.
- `npx tsc --noEmit` + `npm run lint` clean before deploy.

---

## 12. Deployment (v0.1)

Ship via the **base-deployment** workflow: vibe-code → verify (`build`, `tsc`, `lint`, tests) →
commit with version bump → confirm Vercel production push. Create the Neon database and set env vars,
add the `kb` CNAME, tag **v0.1**.

---

## 13. Cost — free-tier guarantee (no incremental spend)

v0.1 runs entirely on free tiers already in use across the nanoteofficial family. Nothing here
requires a paid upgrade.

| Item | Plan | Cost |
|---|---|---|
| Hosting / functions | **Vercel Hobby** (same account as the other projects) | $0 |
| Cron | **1 daily** Vercel Cron — within Hobby limits (daily is the Hobby max) | $0 |
| Database | **Neon free tier** (via Vercel Postgres / Neon marketplace) — ~0.5 GB; our data is a few MB of text/JSON | $0 |
| Domain | `kb` **CNAME** on the existing `nanoteofficial.me` (Namecheap) | $0 |
| Company data | Pull from our own `company.nanoteofficial.me/api/kb` | $0 |
| **AI / LLM** | **None.** The Library only *displays* company briefs — it makes **zero** Anthropic/LLM calls. No `ANTHROPIC_API_KEY`, no token spend. | $0 |

**Cost guardrails baked into the design:**

- **No LLM at runtime** — all intelligence already happened upstream in the company agents; kb is a
  pure reader. (If a "summarize/ask" feature is ever wanted, it's a deliberate, separately-approved
  v0.2+ addition — never silent.)
- **No sub-daily cron** — avoids the Vercel Pro requirement; manual Sync button covers on-demand needs.
- **Cache-and-read** — the UI reads Postgres, not the company API per request, keeping function
  invocations and egress minimal.
- **Bounded sync** — `limit=200` per pull; upsert-only (no unbounded growth); data stays tiny.

If any future feature would introduce a recurring cost (a paid DB tier, a sub-daily cron, an LLM
call, a third-party API), it must be called out and approved before implementation — v0.1 ships at $0.

---

## 14. Module boundaries (for the implementation plan)

Each unit has one purpose and a clear interface:

- `lib/auth.ts` — sign/verify session cookie; `requireSession()` helper. (no deps)
- `lib/db.ts` — Neon client + typed query helpers. (depends: POSTGRES_URL)
- `lib/sync.ts` — `mapEntryToItem()` (pure, tested) + `runSync()` (fetch + upsert + log). (depends: db, COMPANY_KB_URL)
- `lib/items.ts` — list/filter/search/get query builders (pure builder + thin db call). (depends: db)
- `lib/collections.ts`, `lib/tags.ts`, `lib/state.ts` — CRUD seams. (depends: db)
- `lib/export.ts` — `toMarkdown()/toJson()/toPdfDoc()` serializers (pure, tested). (no db)
- `lib/artifacts.ts` + `components/charts/*` — ported typed `Artifact` union + SVG renderers. (no deps)
- UI components consume the above through props; pages are thin servers that gate + fetch + render.

This isolation keeps each file focused, testable, and safe to change without breaking consumers.
```

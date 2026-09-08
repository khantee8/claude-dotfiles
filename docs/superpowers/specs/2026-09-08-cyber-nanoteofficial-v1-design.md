# cyber.nanoteofficial.me v1.0 — Design Spec

**Status:** Drafted autonomously from the owner's brief of 2026-09-08; assumptions listed in §15 for review
**Date:** 2026-09-08
**Author:** NaNote + Claude (Fable 5.1)
**Builds on:** the `cyber` preview shell in `nanoteofficial.me` (static page, no repo, no deployment)
**Reference systems:** `marc-shade/world-intel-mcp` (Threat Intel ops-center), `Sushegaad/MCP-Server-for-ISO27001` (ISO 27001 ISMS), `rocklambros/nist-csf-2-mcp-server` (CSF 2.0, later)

---

## 1. Overview

`cyber.nanoteofficial.me` becomes a real product: a cybersecurity SaaS platform
with several modules behind one landing page and one login. The brief names four
modules — **Threat Intel**, **GRC**, **AI Red Teaming**, **Training / Consult** —
and asks for two of them in v1:

1. **Threat Intel** — the "big win / quick win". A live, map-first intelligence
   view in the spirit of world-intel-mcp's ops-center, shown *publicly* on the
   front page so a visitor is drawn in and goes looking for the rest.
2. **GRC / ISO 27001** — the module the owner expects to use for real work. A
   stateful ISMS workspace modelled on the ISO 27001 MCP server: control
   registry, gap assessment, risk register, Statement of Applicability.

AI Red Teaming, Training / Consult and the CSF 2.0 / CRAF assessments are
represented on the landing page and get honest "in design" pages; they are not
built in v1.

The visual bar is set by real vendor sites (Cymulate, Group-IB): dark, dense,
data-forward, and clearly made by people. §5 spells out what that means in
practice, including the rules for *not* looking machine-generated.

## 2. Goals / non-goals

**Goals**

- One landing page that sells the platform and routes to each module.
- Basic login: magic link by email, invite-only, same pattern as `exam` and `plan`.
- Threat Intel that shows *real* data from free sources, updates itself, and
  degrades gracefully (a source failing must never blank the page).
- An ISO 27001 workspace with persistence, usable for an actual gap assessment
  and risk register from day one.
- Own repo, own Vercel project, `cyber.nanoteofficial.me` bound to it, tagged
  release `v1.0.0`.
- Every layer multi-module from day one, so CSF 2.0 slots in as a sibling of
  ISO 27001 rather than a rewrite.

**Non-goals for v1**

- No LLM calls (no AI summaries, no chat). The platform must cost nothing to
  idle. An `anthropic` dependency is a v1.1+ decision.
- No MCP server of our own. The reference repos are *models for the UX and the
  data model*, not dependencies; nothing is installed from them.
- No multi-user organisations, roles beyond `admin | member`, or billing.
- No evidence uploads (file storage), audits, management review, or policy
  generation. Those are the ISO 27001 v1.1 backlog (§16).
- No changes to the portfolio repo. Once the domain moves, its `/cyber` shell
  is simply no longer what visitors see.

## 3. Stack and repository

Identical to the two most recent projects, so the owner and future contributors
(Opus, Sonnet) work in one idiom:

| Layer | Choice |
|---|---|
| Framework | Next.js 16 App Router, React 19, TypeScript strict |
| Styling | Tailwind v4 + CSS tokens in `globals.css`; no component library |
| Auth | Auth.js v5, Resend magic link, database sessions, `ALLOWED_EMAILS` bootstrap |
| Database | Neon Postgres + Drizzle (eager `db` for the adapter, `getDb()` for app code) |
| Tests | Vitest for pure logic (feed parsers, scoring, SoA builder, map projection helpers) |
| Map | `d3-geo` + `world-atlas` (110m TopoJSON) + `topojson-client`, rendered as inline SVG — no tile server, no external requests from the browser |
| Deploy | Vercel Hobby, auto-deploy from `main`, `cyber.nanoteofficial.me` on Vercel DNS |

Repository: `khantee8/cyber.nanoteofficial.me`, **public** (§15, A1). Working
copy at `/project/src/cyber.nanoteofficial.me`.

Gate before any release: `npx tsc --noEmit && npm run lint && npm test && npm run build`,
and the build must pass with `DATABASE_URL` unset.

## 4. Information architecture

```
/                       landing (public)
/intel                  Threat Intel ops view (public, full page)
/grc                    GRC hub: ISO 27001 live, CSF 2.0 + CRAF "in design" (gated)
/grc/iso27001           ISMS dashboard (gated)
/grc/iso27001/controls  control registry + gap assessment (gated)
/grc/iso27001/controls/[id]   one control: status, justification, evidence links (gated)
/grc/iso27001/risks     risk register + heat map (gated)
/grc/iso27001/risks/new, /risks/[id]   create / edit a risk (gated)
/grc/iso27001/soa       Statement of Applicability + export (gated)
/grc/iso27001/settings  organisation profile + reset (gated)
/redteam                module page, "in design" (public)
/training               module page, "in design" (public)
/signin, /pending       auth pages
/admin                  approve access requests (admin)
/api/auth/[...nextauth] Auth.js
/api/intel              JSON snapshot of the Threat Intel data (public, cached)
/api/grc/iso27001/soa.csv   SoA export (gated)
```

The gate is `src/app/(app)/layout.tsx`, exactly as in `exam` — **no middleware
and no `proxy.ts`**. Public routes live outside `(app)`.

## 5. Visual system

### 5.1 Direction

Dark, editorial, instrument-like. The reference is a security operations
vendor, not a startup template. Concretely:

- **Palette.** Near-black blue ground (`#070B14`), raised surfaces (`#0D1320`,
  `#121A2B`), hairline borders at 8–12% white. One accent, a cold signal green
  (`#3DDC97`) used only for live/OK states and primary actions. Severity uses a
  fixed scale: critical `#FF4D6D`, high `#FF9F43`, medium `#FFD166`, low
  `#4CC9F0`. No purple-to-pink gradients anywhere.
- **Type.** `Geist` for UI, `Geist Mono` for data (IDs, timestamps, counts).
  Headlines are set tight and large, body at 15/1.6. Numbers in tables are
  tabular-figure mono.
- **Surfaces.** Flat panels with 1px borders and 6px radius. No glassmorphic
  blur, no drop shadows heavier than 1px, no glow except a 2px pulse on the
  live indicator.
- **Motion.** One idea: things that are live tick. The HUD counters count up on
  first paint, the map dots pulse, the feed list slides in new rows. Everything
  gated on `prefers-reduced-motion`.
- **Light mode** is not offered in v1. The product is dark by design, like the
  references; the landing page and the app share one theme.

### 5.2 Rules for not looking generated

These are enforced in review, not just intended:

1. No emoji in UI copy. Icons are a small inline SVG set (12 glyphs) drawn once.
2. No "Unlock", "Empower", "Seamless", "Revolutionize", "Next-gen" in copy.
   Headlines state a fact or a capability: *"Exploited in the wild, mapped
   within the hour."*
3. Every number on the landing page is real and computed at render time (KEV
   entries added this week, ransomware claims this week, ISC infocon). If a
   source is down the tile shows the cached value with its age, never a
   placeholder.
4. No fake logo wall, no fake testimonials, no fake team.
5. Asymmetric layout on the landing page: a 7/5 split hero, a full-bleed map
   band, a modules grid with one wide card (Threat Intel) and three narrow ones.
6. Copy is written in a specific voice (short, declarative, second person used
   sparingly). Thai is a full translation, not a machine gloss — the same
   `LStr` discipline as the portfolio.
7. Real product footers: version, data-source attribution, last-refresh time.

### 5.3 i18n

TH/EN, cookie-based, server-side, same `lang.ts` / `i18n.ts` split as `plan`
and `exam`. Every user-facing string goes through `t()` or an `LStr`.
Threat data itself (CVE titles, victim names) stays in its source language.

## 6. Landing page

Sections, top to bottom:

1. **Nav** — wordmark `NaNote Cyber`, links: Threat Intel · GRC · Red Team ·
   Training · Sign in. Language toggle.
2. **Hero (7/5)** — left: headline, one paragraph, two buttons (*Open Threat
   Intel* → `/intel`, *Request access* → `#access`). Right: the live HUD — four
   tiles fed by §7 (KEV added 7d, ransomware claims 7d, active C2 servers,
   ISC infocon) with a "live · refreshed 4m ago" line.
3. **Map band (full bleed)** — the same `WorldMap` component as `/intel`, in a
   fixed 420px-tall band, ransomware layer on, animated. A caption row below
   lists the sources.
4. **Modules** — 2×2 bento: Threat Intel (wide, "live" chip), GRC (ISO 27001
   "available", CSF 2.0 and CRAF "in design"), AI Red Teaming ("in design"),
   Training / Consult ("in design"). Each card: name, one sentence, three
   bullet capabilities, link.
5. **How it fits** — a three-column strip: *Observe* (Threat Intel) → *Govern*
   (GRC) → *Test & train* (Red Team, Training). Short copy, no chart.
6. **Access** — the request-access form (email + message), same server action
   pattern as `exam`. Sign-in link for existing members.
7. **Footer** — version, sources credit, link to the portfolio.

## 7. Threat Intel module

### 7.1 Sources (all free, no key, verified reachable 2026-09-08)

| Source | Endpoint | Used for | Refresh |
|---|---|---|---|
| CISA KEV | `known_exploited_vulnerabilities.json` (1.7 MB) | exploited CVE list, "added this week" count, vendor breakdown | 30 min |
| FIRST EPSS | `api.first.org/data/v1/epss?cve=…` (batched, ≤100 per call) | exploit probability for the newest 30 KEV entries | 30 min |
| ransomware.live | `api.ransomware.live/v2/recentvictims` | victim claims with `country`, `group`, `activity`, `attackdate` → map layer + leaderboard | 15 min |
| abuse.ch Feodo Tracker | `feodotracker.abuse.ch/downloads/ipblocklist.json` | active botnet C2 with `country`, `malware`, `as_name` → map layer | 15 min |
| SANS ISC | `isc.sans.edu/api/infocon?json`, `/api/topports/records/10?json` | infocon status, top attacked ports | 15 min |
| News | The Hacker News RSS, BleepingComputer RSS | headline ticker (title + link only) | 15 min |

Deliberately excluded: URLhaus API (now requires an auth key), URLhaus CSV
(3.8 MB per pull, too heavy for a request path), NVD (rate-limited without a key;
KEV + EPSS covers the need), Cloudflare Radar (403 without a key).

### 7.2 Fetch, cache, degrade

- `src/lib/intel/sources/<name>.ts` — one file per source, pure
  `parse*`/`select*` functions (fixture-tested) and a `fetch*` that returns
  `null` on any failure. Same shape as `company`'s `sources/`.
- `src/lib/intel/aggregate.ts` — `buildIntelSnapshot()` runs all fetches with
  `Promise.allSettled`, an 8 s timeout each, and returns an `IntelSnapshot`
  with a per-source `health: { status: 'ok' | 'stale' | 'down', fetchedAt, ms }`.
- Caching uses Next's `"use cache"` + `cacheLife` (15 min) on the aggregate.
  Both `/` and `/intel` and `/api/intel` read the same cached snapshot, so a
  burst of visitors costs one upstream round-trip per source per window.
- **Fallback snapshot.** `src/lib/intel/fallback.json` is a committed snapshot
  captured by `npm run intel:snapshot`. When a source is down, its section
  comes from the fallback and is labelled *stale* with the capture date. The
  build and the test suite never touch the network.
- `/api/intel` returns the snapshot as JSON with `Cache-Control: public, s-maxage=900`.
  This is the seed of a later MCP/REST surface.

### 7.3 Map

`WorldMap` (client component): `d3-geo` `geoNaturalEarth1` projection over
`world-atlas` 110m countries, drawn as one SVG `<path>` per country. Layers:

- **Ransomware claims** — one dot per victim country in the window, size by
  count, colour by recency.
- **Botnet C2** — dots from Feodo, colour by malware family.
- **Country choropleth** — combined intensity, faint.

Countries are placed by centroid (`d3-geo` `geoCentroid` over the TopoJSON
feature), keyed by ISO-3166 alpha-2, using a small alpha-2 → numeric map in
`src/lib/intel/geo/iso.ts`. Hover shows a tooltip; click filters the side
panels to that country. Layer toggles sit in a compact HUD at the top-left of
the map. Everything is inline SVG; the browser makes zero network requests for
the map.

### 7.4 `/intel` layout

Three columns on desktop (map 7 / panels 5), stacked on mobile:

- **HUD bar** — the four counters, infocon, source health dots, refresh age.
- **Map** with layer toggles.
- **Panels** (tabbed on mobile): *Exploited* (KEV newest 30 with EPSS bar,
  vendor, added date, link to CISA), *Ransomware* (top groups 7d, latest
  claims with sector + country), *Infrastructure* (Feodo C2 table, ISC top
  ports as a bar list), *Headlines* (news list).

Every panel row links out to its source. Every panel header carries the source
name and its fetched-at time.

## 8. GRC — ISO 27001 module

### 8.1 Model (mirrors the reference server's tables, trimmed to v1)

- **Organisation** — one per user in v1 (`organisations.ownerId` unique). Name,
  scope statement, industry, size band, ISMS lead. Created on first visit to
  `/grc/iso27001` with a short form.
- **Control catalogue** — static, in code: all **93 ISO/IEC 27001:2022 Annex A
  controls** across the four themes (Organisational 5.1–5.37, People 6.1–6.8,
  Physical 7.1–7.14, Technological 8.1–8.34). Each has `id`, `title`, `theme`,
  and a one-line **paraphrase** written for this product (not the standard's
  text — the standard is copyrighted; titles and numbering are public), plus
  the 2022 attribute tags (control type, CIA properties, cybersecurity concept).
  Bilingual titles.
- **Control status** — per organisation per control: `status`
  (`not_started | partial | implemented | not_applicable`), `justification`,
  `owner`, `evidenceUrl[]` (links only), `updatedAt`.
- **Risk** — `ref` (`RISK-001`…), `title`, `description`, `asset`, `threat`,
  `vulnerability`, `likelihood` 1–5, `impact` 1–5, `score` = product,
  `band` derived, `treatment` (`mitigate | accept | transfer | avoid`),
  `treatmentPlan`, `owner`, `status` (`open | in_treatment | closed`),
  `linkedControlIds[]`, `residualLikelihood`, `residualImpact`.
- **Risk methodology** — per organisation: the 5×5 band thresholds
  (`low ≤ 4`, `medium ≤ 9`, `high ≤ 15`, `critical > 15`) and the acceptance
  threshold. Editable in settings; defaults follow the reference server.

### 8.2 Pages

- **Dashboard** — compliance gauge (implemented ÷ applicable), per-theme bars,
  risk heat map (5×5), top open risks, controls with no owner, last activity.
- **Controls** — table of 93, filter by theme / status / attribute, inline
  status change (server action), search. Progress header per theme.
- **Control detail** — status, justification, owner, evidence links, linked
  risks, the paraphrase and attributes.
- **Risks** — register table sorted by score, heat map, new / edit forms.
  Creating a risk suggests linked controls by matching the 2022 attributes
  (simple keyword map, no LLM).
- **SoA** — one row per control: applicable?, justification for inclusion /
  exclusion, implementation status. Export as CSV (`/api/grc/iso27001/soa.csv`)
  and as a printable page (`?print=1`, plain layout, `@media print`).
- **Settings** — organisation profile, risk methodology, "reset workspace"
  (destructive, confirm by typing the org name).

### 8.3 Scoring (pure, tested)

`src/lib/grc/iso27001/score.ts`:
- `compliance(statuses)` → `{ applicable, implemented, partial, notStarted, pct }`
  where `pct = (implemented + 0.5 × partial) / applicable`.
- `riskBand(score, methodology)`, `heatmap(risks)` → 5×5 counts.
- `buildSoa(catalogue, statuses)` → rows, with the not-applicable justification
  required for export (export fails loudly listing the missing rows).

### 8.4 Multi-framework seam

`src/lib/grc/frameworks.ts` exports a `Framework` registry
(`{ slug, name, catalogue, routes }`). ISO 27001 is the only entry in v1; the
`/grc` hub renders the registry plus the "in design" placeholders for
`nist-csf-2` and `craf`. Tables carry a `framework` column so a second
framework needs no migration of the status/risk tables.

## 9. Auth and access

Copied from `exam` with the product name changed: Resend provider with the
multipart bilingual email, `ALLOWED_EMAILS` bootstrap → `admin`, access
requests approved on `/admin`, approval re-read from the DB on every gated
request. `AUTH_RESEND_FROM = "NaNote Cyber <cyber@nanoteofficial.me>"`.

## 10. Security

- Headers in `next.config.ts`: CSP `default-src 'self'`, `script-src 'self'
  'unsafe-inline'`, `style-src 'self' 'unsafe-inline'`, `img-src 'self' data:`,
  `font-src 'self'`, `connect-src 'self'`, `frame-ancestors 'none'`; HSTS,
  `X-Content-Type-Options`, `Referrer-Policy: strict-origin-when-cross-origin`,
  `Permissions-Policy` denying camera/mic/geolocation; `poweredByHeader: false`.
  The map and fonts are self-hosted so the CSP has no third-party hosts.
- All upstream fetches are server-side; the browser never calls a feed.
- Server actions validate with hand-written guards (no `zod` in v1 — one
  `src/lib/validate.ts` with `str(max)`, `int(min,max)`, `oneOf`).
- Access-request form: length limits, per-IP throttle (in-memory, best effort),
  honeypot field.
- Threat data is rendered as text only. Victim names and news titles come from
  third parties and are escaped by React; no `dangerouslySetInnerHTML` anywhere.
- Ransomware victim records are displayed as the source publishes them (org
  name, sector, country). No individual's name is ever shown.

## 11. Data model (Drizzle)

Auth.js tables as in `exam` (`user`, `account`, `session`, `verificationToken`),
`access_request`, then:

```
organisation        id, ownerId (unique → user), name, scope, industry, sizeBand,
                    ismsLead, createdAt
risk_methodology    organisationId (pk), lowMax, mediumMax, highMax, acceptMax
control_status      organisationId, framework, controlId, status, justification,
                    owner, evidenceUrls jsonb, updatedAt   — pk (org, framework, controlId)
risk                id, organisationId, framework, ref, title, description, asset,
                    threat, vulnerability, likelihood, impact, treatment,
                    treatmentPlan, owner, status, linkedControlIds jsonb,
                    residualLikelihood, residualImpact, createdAt, updatedAt
```

## 12. Testing

Vitest over pure code only, as in the sibling projects:

- each feed parser against a committed fixture (`src/lib/intel/sources/__fixtures__/`)
- `aggregate` with mocked fetchers: one source failing yields `stale` from
  fallback, never a throw
- `iso.ts` alpha-2 → numeric coverage for every country in the 110m atlas
- `score.ts`: compliance, bands, heat map, SoA export failure on missing
  justification
- the ISO catalogue: exactly 93 entries, unique ids, four themes with the
  correct counts, every entry bilingual

UI is verified with Playwright screenshots at 390 / 768 / 1280 before release,
not with automated tests.

## 13. Deployment and release

1. `gh repo create khantee8/cyber.nanoteofficial.me --public`, push `main`.
2. `vercel link` → new project `cyber-nanoteofficial-me`; `vercel git connect`.
3. Env: `AUTH_SECRET`, `AUTH_RESEND_KEY` (same Resend account as `exam`),
   `AUTH_RESEND_FROM`, `ALLOWED_EMAILS`, `DATABASE_URL` (Neon, §15 A3).
4. `DATABASE_URL=… npx drizzle-kit push`.
5. `vercel domains add cyber.nanoteofficial.me` on the new project. The
   portfolio keeps its wildcard; the explicit assignment wins.
6. Tag `v1.0.0`, push, then verify: `curl` the production URL for 200, confirm
   the HUD shows live (not stale) values, sign in with the allow-listed email.

Release convention follows the portfolio: bump `package.json` and both
`package-lock.json` version fields together; annotated tag; confirm production
serves the change.

## 14. Repository layout

```
src/app/                   routes (§4); (app)/ is the gated group
src/components/intel/      HudBar, WorldMap, LayerToggles, panels
src/components/grc/        ControlTable, StatusPill, RiskForm, HeatMap, SoaTable
src/components/site/       Nav, Footer, LangToggle, Wordmark, Icon
src/lib/intel/             sources/, aggregate.ts, fallback.json, geo/
src/lib/grc/               frameworks.ts, iso27001/{catalogue.ts,score.ts,suggest.ts}
src/lib/{lang,i18n,validate}.ts
src/server/actions/        access.ts, admin.ts, grc.ts, prefs.ts
src/db/                    schema.ts, index.ts
scripts/                   intel-snapshot.ts
```

## 15. Assumptions made without the owner (please confirm or overrule)

- **A1 Public repo.** Nothing in this product is licensed content, and the brief
  says "release it", so the repo is public like `company` and the portfolio.
  Flip with `gh repo edit --visibility private` at any time.
- **A2 Login is invite-only**, same as `exam` and `plan`. "Basic login" read as
  magic-link, not username/password. Visitors see Threat Intel without an
  account; GRC needs one.
- **A3 Database.** A fresh Neon database is provisioned through the Vercel
  Neon integration if the CLI allows it non-interactively; otherwise a new
  *database* is created inside an existing Neon project and this is flagged
  in the hand-off so the owner can move it later.
- **A4 No LLM in v1.** The brief lists "advanced tools"; the free-feed
  visualisation and a working ISMS are the v1 substance, and an AI layer
  (summaries, control-mapping suggestions) is the natural Opus/Sonnet
  contribution in v1.1 once the structure exists.
- **A5 One organisation per user.** Enough for the owner's own use; team
  membership is a schema addition (`organisation_member`), not a redesign.
- **A6 Dark-only theme.** Matches the references; a light theme is a later
  token pass, the tokens are already CSS variables.
- **A7 "CRAF"** in the brief is read as a cyber-resilience assessment framework
  and shown as a planned GRC entry next to CSF 2.0; nothing is built for it.

## 16. Backlog after v1.0

- ISO 27001 v1.1: evidence records (not just links), internal audit findings
  and corrective actions, management review inputs, policy templates.
- NIST CSF 2.0 assessment (from `nist-csf-2-mcp-server`'s question bank idea,
  our own questions), then CRAF.
- Threat Intel v1.1: country drill-down page, sector filter, an
  `/api/intel/mcp` MCP surface so Claude can query the snapshot, optional
  Anthropic-generated daily brief.
- AI Red Teaming and Training / Consult module designs.
- Team membership and roles inside an organisation.

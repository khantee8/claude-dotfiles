# cyber.nanoteofficial.me v1.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `cyber.nanoteofficial.me` v1.0.0 — a public landing page with live Threat Intel, magic-link login, and a persisted ISO 27001 GRC workspace — in its own repo and Vercel project.

**Architecture:** Next.js 16 App Router app in the same idiom as `exam`/`plan`: public routes at the root, gated routes under `src/app/(app)/` guarded by that group's layout (no middleware). Threat Intel is server-fetched from free feeds, cached 15 min, and falls back to a committed snapshot; the map is inline SVG from `d3-geo` + `world-atlas`. GRC state lives in Neon via Drizzle; the ISO 27001 catalogue and all scoring are pure code with Vitest coverage.

**Tech Stack:** Next.js 16.3, React 19, TypeScript strict, Tailwind v4, Auth.js v5 beta (Resend), Neon + Drizzle, Vitest, d3-geo, topojson-client, world-atlas, geist fonts.

**Spec:** `/project/docs/superpowers/specs/2026-09-08-cyber-nanoteofficial-v1-design.md`

## Global Constraints

- Working copy: `/project/src/cyber.nanoteofficial.me`; every command below runs from there unless stated.
- Next.js 16 APIs differ from training data — read `node_modules/next/dist/docs/` before using `"use cache"`, `cacheLife`, `proxy`, or route-handler signatures.
- `npm run build` must pass with `DATABASE_URL` unset. App code uses `getDb()`; only the Auth.js adapter uses the eager `db`.
- No middleware, no `proxy.ts`. The only gate is `src/app/(app)/layout.tsx`.
- No LLM dependency, no `dangerouslySetInnerHTML`, no emoji in UI, no third-party hosts in the CSP.
- Every user-facing string is bilingual (TH/EN) through `t()` or an `LStr`.
- Palette and type from spec §5: ground `#070B14`, surfaces `#0D1320`/`#121A2B`, accent `#3DDC97`, severity `#FF4D6D` / `#FF9F43` / `#FFD166` / `#4CC9F0`; Geist + Geist Mono. Dark-only.
- Commit after every task with a conventional prefix (`feat:`, `test:`, `chore:`, `docs:`).
- Release gate: `npx tsc --noEmit && npm run lint && npm test && npm run build`.

---

### Task 1: Scaffold, design tokens, site chrome, i18n

**Files:**
- Create: `package.json`, `tsconfig.json`, `next.config.ts`, `eslint.config.mjs`, `postcss.config.mjs`, `vitest.config.ts`, `.gitignore`, `.env.example`, `README.md`
- Create: `src/app/layout.tsx`, `src/app/globals.css`, `src/app/page.tsx` (placeholder, replaced in Task 7), `src/app/icon.svg`
- Create: `src/lib/lang.ts`, `src/lib/lang-action.ts`, `src/lib/i18n.ts`
- Create: `src/components/site/Nav.tsx`, `Footer.tsx`, `LangToggle.tsx`, `Wordmark.tsx`, `Icon.tsx`

**Interfaces:**
- Produces: `type Lang = 'en' | 'th'`; `getLang(): Promise<Lang>` (reads `lang` cookie, default `en`); `setLang(lang)` server action; `t(lang, key: UiKey): string`; `type LStr = Record<Lang, string>`; `pick(l: LStr, lang)`; `<Icon name={IconName} className?>` with `IconName = 'shield'|'globe'|'radar'|'clipboard'|'flask'|'graduation'|'arrow'|'check'|'alert'|'external'|'pulse'|'menu'`; `<Nav lang />`, `<Footer lang version sources? />`.

- [ ] **Step 1: Initialise the project from the exam project's config files**

```bash
mkdir -p /project/src/cyber.nanoteofficial.me && cd /project/src/cyber.nanoteofficial.me && git init -b main
cp /project/src/exam.nanoteofficial.me/{tsconfig.json,eslint.config.mjs,postcss.config.mjs,vitest.config.ts,.gitignore} .
```
Write `package.json` with name `cyber.nanoteofficial.me`, version `0.1.0`, scripts `dev/build/start/lint/test` as in exam plus `"intel:snapshot": "tsx scripts/intel-snapshot.ts"`, dependencies: `next@16.3.4 react@19.2.8 react-dom@19.2.8 next-auth@5.0.0-beta.32 @auth/drizzle-adapter @neondatabase/serverless drizzle-orm d3-geo topojson-client world-atlas geist`, dev: `@tailwindcss/postcss tailwindcss typescript @types/node @types/react @types/react-dom @types/d3-geo @types/topojson-client @types/geojson drizzle-kit eslint eslint-config-next@16.3.4 tsx vitest`. Run `npm install`.

- [ ] **Step 2: Write `globals.css` tokens**

```css
@import "tailwindcss";
:root {
  --bg: #070B14; --surface: #0D1320; --surface-2: #121A2B;
  --line: rgba(255,255,255,0.09); --line-strong: rgba(255,255,255,0.16);
  --fg: #E6EAF2; --muted: #8B94A7; --muted-soft: #5C6478;
  --accent: #3DDC97; --accent-ink: #052616;
  --sev-critical: #FF4D6D; --sev-high: #FF9F43; --sev-medium: #FFD166; --sev-low: #4CC9F0;
  --font-sans: var(--font-geist-sans); --font-mono: var(--font-geist-mono);
}
@theme inline { --color-bg: var(--bg); /* … one per token … */ }
html { color-scheme: dark; background: var(--bg); }
body { background: var(--bg); color: var(--fg); font-family: var(--font-sans); font-size: 15px; line-height: 1.6; }
.mono { font-family: var(--font-mono); font-variant-numeric: tabular-nums; }
.panel { background: var(--surface); border: 1px solid var(--line); border-radius: 6px; }
@keyframes pulse-dot { 0%,100% { opacity: .55; transform: scale(1);} 50% { opacity: 1; transform: scale(1.35);} }
.live-dot { animation: pulse-dot 1.8s ease-in-out infinite; }
@media (prefers-reduced-motion: reduce) { .live-dot, .animate-in { animation: none !important; } }
```

- [ ] **Step 3: Write `layout.tsx` with Geist fonts, `lang` attribute from `getLang()`, `<Nav>` and `<Footer>`; write `i18n.ts` with a typed `UiKey` union (`nav.intel`, `nav.grc`, `nav.redteam`, `nav.training`, `nav.signin`, `nav.signout`, `nav.admin`, `footer.sources`, `footer.refreshed`, `common.live`, `common.stale`, `common.down`, … add keys as tasks need them) and a `dict` object; `lang.ts`/`lang-action.ts` copied from exam.**

- [ ] **Step 4: Write the 12-glyph `Icon.tsx` (inline `<svg viewBox="0 0 24 24" stroke="currentColor" fill="none" strokeWidth={1.6}>` paths in a `Record<IconName, ReactNode>`), `Wordmark.tsx` ("NaNote" in sans + "Cyber" in mono accent), `Nav.tsx` (sticky, hairline bottom border, links from §6, mobile disclosure using `<details>` so it works without JS), `Footer.tsx`, `LangToggle.tsx` (form posting to `setLang`).**

- [ ] **Step 5: Verify and commit**

Run: `npx tsc --noEmit && npm run lint && npm run build`
Expected: all pass; build lists `/` as static.
```bash
git add -A && git commit -m "chore: scaffold cyber.nanoteofficial.me — tokens, chrome, i18n"
```

---

### Task 2: Database, auth, access requests, admin

**Files:**
- Create: `src/db/schema.ts`, `src/db/index.ts`, `drizzle.config.ts`, `src/auth.ts`, `src/types/next-auth.d.ts`
- Create: `src/app/api/auth/[...nextauth]/route.ts`, `src/app/signin/page.tsx`, `src/app/pending/page.tsx`, `src/app/(app)/layout.tsx`, `src/app/(app)/admin/page.tsx`
- Create: `src/server/actions/access.ts`, `src/server/actions/admin.ts`, `src/components/site/RequestAccessForm.tsx`, `src/components/site/AdminDecideButtons.tsx`

**Interfaces:**
- Produces: `auth()`, `signIn`, `signOut`, `handlers`; `getDb()`; tables `users, accounts, sessions, verificationTokens, accessRequests`; `requestAccess(prev, formData)` server action returning `{ ok: true } | { error: string }`; `decideAccess(id, 'approved'|'rejected')`.
- Gate contract for later tasks: any page under `src/app/(app)/` can assume `auth()` returns a session whose email has `approvedAt` set; the layout also exposes nothing else — pages re-query what they need.

- [ ] **Step 1: Copy the auth/db skeleton from exam and rename**

Copy `src/auth.ts`, `src/db/index.ts`, `src/types/next-auth.d.ts`, the auth route, `signin`, `pending`, `(app)/layout.tsx`, `admin/page.tsx`, `server/actions/{access,admin}.ts`, `components/{RequestAccessForm,AdminDecideButtons}.tsx` from `/project/src/exam.nanoteofficial.me`. Replace every "ExamPrep" with "NaNote Cyber", `exam.nanoteofficial.me` with `cyber.nanoteofficial.me`, the email button colour `#0f766e` with `#3DDC97` on `#052616` text, and the `(app)` layout nav with links GRC · Admin · Sign out. Schema: keep the four Auth.js tables + `access_request`; drop the exam tables.

- [ ] **Step 2: Write `.env.example`**

```
DATABASE_URL=
AUTH_SECRET=            # npx auth secret
AUTH_RESEND_KEY=
AUTH_RESEND_FROM="NaNote Cyber <cyber@nanoteofficial.me>"
ALLOWED_EMAILS=khantee9@gmail.com
```

- [ ] **Step 3: Add a throttle + honeypot to `requestAccess`**

In `access.ts`: read `formData.get('website')` — if non-empty return `{ ok: true }` silently (bot). Keep a module-level `Map<string, number[]>` of timestamps per IP (from `headers().get('x-forwarded-for')`), reject with `{ error: 'rate' }` when more than 3 requests in 10 minutes. Validate email with a simple regex and length ≤ 254, message ≤ 1000 chars.

- [ ] **Step 4: Verify without a database**

Run: `npx tsc --noEmit && npm run lint && npm run build` with `DATABASE_URL` unset.
Expected: pass. `/signin` renders; `/admin` redirects to `/signin` when signed out.
```bash
git add -A && git commit -m "feat: auth.js magic-link login, access requests, admin approval"
```

---

### Task 3: Threat Intel sources (pure parsers, fixture-tested)

**Files:**
- Create: `src/lib/intel/types.ts`, `src/lib/intel/sources/{kev,epss,ransomware,feodo,isc,news}.ts`, matching `*.test.ts`, `src/lib/intel/sources/__fixtures__/{kev.json,epss.json,ransomware.json,feodo.json,isc-infocon.json,isc-topports.json,thn.xml}`

**Interfaces (types.ts):**
```ts
export type SourceId = 'kev' | 'epss' | 'ransomware' | 'feodo' | 'isc' | 'news';
export interface KevEntry { cveId: string; vendor: string; product: string; name: string; dateAdded: string; dueDate: string; ransomwareUse: boolean; description: string; url: string; epss?: number }
export interface RansomVictim { victim: string; group: string; country: string | null; sector: string | null; attackDate: string; discovered: string; url: string }
export interface C2Server { ip: string; port: number; country: string | null; malware: string; asName: string | null; status: 'online' | 'offline'; lastOnline: string }
export interface IscStatus { infocon: 'green' | 'yellow' | 'orange' | 'red' | 'unknown'; topPorts: { port: number; records: number; sources: number }[] }
export interface Headline { title: string; url: string; source: 'thn' | 'bleeping'; publishedAt: string | null }
```
Each source exports `parseX(raw: unknown | string): T` (pure, throws on shape mismatch) and `fetchX(signal?: AbortSignal): Promise<T | null>` (never throws; returns `null` on any failure). `selectRecentKev(entries, days, now)` filters by `dateAdded`.

- [ ] **Step 1: Capture fixtures** — `curl` each endpoint (URLs in spec §7.1) into `__fixtures__/`, trimming KEV to its 40 newest and ransomware to 50 entries with a small `tsx` one-liner so fixtures stay under 100 KB.
- [ ] **Step 2: Write failing tests** — for each parser: correct count, first record's fields, `parseX({})` throws; `selectRecentKev` with `now = fixture max date` and `days = 7` returns only entries within the window; `parseRss` handles CDATA titles; `parseEpss` returns `Map<string, number>`.
- [ ] **Step 3: Run `npm test` — expect failures ("Cannot find module").**
- [ ] **Step 4: Implement each parser and fetcher** (fetch with `{ signal, headers: { accept }, next: { revalidate: 0 } }`, 8 s `AbortSignal.timeout` when no signal given).
- [ ] **Step 5: `npm test` green; commit `feat(intel): feed parsers for KEV, EPSS, ransomware.live, Feodo, ISC, news`.**

---

### Task 4: Aggregate snapshot, fallback, `/api/intel`

**Files:**
- Create: `src/lib/intel/aggregate.ts`, `src/lib/intel/aggregate.test.ts`, `src/lib/intel/fallback.json`, `src/lib/intel/snapshot.ts`, `scripts/intel-snapshot.ts`, `src/app/api/intel/route.ts`

**Interfaces:**
```ts
export interface SourceHealth { status: 'ok' | 'stale' | 'down'; fetchedAt: string; ms: number }
export interface IntelSnapshot {
  generatedAt: string;
  kev: KevEntry[]; ransomware: RansomVictim[]; c2: C2Server[]; isc: IscStatus; headlines: Headline[];
  health: Record<SourceId, SourceHealth>;
  stats: { kevAdded7d: number; ransomware7d: number; c2Online: number; infocon: IscStatus['infocon']; topGroups7d: { group: string; count: number }[]; byCountry: Record<string, { ransomware: number; c2: number }> };
}
export async function buildIntelSnapshot(deps?: Partial<Fetchers>, fallback?: IntelSnapshot, now?: Date): Promise<IntelSnapshot>
export async function getIntelSnapshot(): Promise<IntelSnapshot>   // "use cache", cacheLife 15 min
```

- [ ] **Step 1: Tests** — with all fetchers stubbed to return fixture data, every health is `ok` and stats are computed (assert exact `kevAdded7d`, `topGroups7d[0]`, `byCountry.US`); with `ransomware` stubbed to `null`, `health.ransomware.status === 'stale'` and `ransomware` equals the fallback's list; with a fetcher that rejects, no throw.
- [ ] **Step 2: Implement `buildIntelSnapshot`** using `Promise.allSettled`, per-source timing, EPSS looked up only for the 30 newest KEV entries and merged into `epss`.
- [ ] **Step 3: `snapshot.ts`** — `getIntelSnapshot` wrapped in `"use cache"` + `cacheLife('minutes')` (check `node_modules/next/dist/docs/` for the exact profile API in 16.3, and whether `cacheComponents` must be enabled in `next.config.ts`; if the directive is unavailable, use `unstable_cache` with `revalidate: 900`). Imports `fallback.json`.
- [ ] **Step 4: `scripts/intel-snapshot.ts`** — runs `buildIntelSnapshot()` live and writes `fallback.json` (pretty JSON, ransomware trimmed to 100, KEV to 60). Run it once to create the initial fallback; commit the file.
- [ ] **Step 5: `/api/intel` route** — `GET` returns the snapshot with `Cache-Control: public, s-maxage=900, stale-while-revalidate=300`.
- [ ] **Step 6: Gate + commit `feat(intel): cached aggregate snapshot with fallback and /api/intel`.**

---

### Task 5: Geo helpers and `WorldMap`

**Files:**
- Create: `src/lib/intel/geo/iso.ts`, `iso.test.ts`, `src/lib/intel/geo/atlas.ts`, `src/components/intel/WorldMap.tsx`, `src/components/intel/LayerToggles.tsx`

**Interfaces:**
```ts
// iso.ts
export const ALPHA2_TO_NUMERIC: Record<string, string>   // 'US' → '840'
export function numericFor(alpha2: string): string | null
// atlas.ts (server-safe, no DOM)
export interface CountryShape { id: string; path: string; centroid: [number, number]; name: string }
export function buildAtlas(width: number, height: number): { countries: CountryShape[]; project: (lonLat: [number, number]) => [number, number] | null }
// WorldMap.tsx ("use client")
export interface MapPoint { id: string; alpha2: string; kind: 'ransomware' | 'c2'; weight: number; label: string; sub?: string }
export function WorldMap(props: { points: MapPoint[]; heat: Record<string, number>; layers?: ('ransomware'|'c2'|'heat')[]; height?: number; interactive?: boolean; onSelectCountry?: (alpha2: string | null) => void; lang: Lang })
```

- [ ] **Step 1: Tests** — `numericFor('US') === '840'`, `'TH' → '764'`, unknown → `null`; `buildAtlas(960, 500).countries.length > 150`, every country has a finite centroid, and every `ALPHA2_TO_NUMERIC` value appears in the atlas ids **or** is in an explicit `NOT_IN_110M` allow-list (small states).
- [ ] **Step 2: Write `iso.ts`** — the full ISO 3166-1 alpha-2 → numeric table (249 entries) as a literal object.
- [ ] **Step 3: Write `atlas.ts`** — `import land from 'world-atlas/countries-110m.json'`, `feature()` from topojson-client, `geoNaturalEarth1().fitSize([w,h], collection)`, `geoPath` for `d` strings, `geoCentroid` projected; country name from the atlas `properties.name`.
- [ ] **Step 4: Write `WorldMap`** — SVG with `viewBox`, countries as `<path>` (fill `var(--surface-2)`, stroke `var(--line)`), heat as fill-opacity, points as `<circle>` with `r = 3 + 2*log2(weight)`, class `live-dot` on the newest 10, `<title>` tooltips, click → `onSelectCountry`. Rendered on the server for the paths; only hover/click state is client. `LayerToggles` is three small toggle buttons.
- [ ] **Step 5: Gate + commit `feat(intel): SVG world map from world-atlas with ransomware and C2 layers`.**

---

### Task 6: Threat Intel page and panels

**Files:**
- Create: `src/app/intel/page.tsx`, `src/components/intel/{HudBar,SourceHealthDots,ExploitedPanel,RansomwarePanel,InfraPanel,HeadlinesPanel,IntelWorkspace}.tsx`, `src/lib/intel/format.ts` (`ago(iso, now, lang)`, `pct(n)`)

**Interfaces:**
- `IntelWorkspace` ("use client") takes `{ snapshot: IntelSnapshot; lang: Lang }`, owns `selectedCountry` and `layers`, renders map + tabbed panels; each panel takes its slice + `selectedCountry` and filters.
- `HudBar` takes `{ stats, health, generatedAt, lang }`; counters animate from 0 with `requestAnimationFrame`, disabled under reduced motion.

- [ ] **Step 1: Build the panels** per spec §7.4 (KEV rows: CVE id mono, vendor/product, EPSS bar `width = epss*100%` coloured by severity band ≥0.7 critical / ≥0.4 high / ≥0.1 medium / else low, "added" date, external link; Ransomware: top-groups bar list + latest claims with sector/country; Infra: C2 table + ISC top ports bar list; Headlines: list with source tag).
- [ ] **Step 2: `page.tsx`** — `const snap = await getIntelSnapshot()`, `generateMetadata` bilingual, render `IntelWorkspace`. Add `revalidate`/dynamic settings as the cache API requires.
- [ ] **Step 3: Screenshot at 390/768/1280 with Playwright (`npm run dev` then `browser_take_screenshot`); fix overflow (`overflow-x-auto` on tables). Commit `feat(intel): ops view — HUD, map, exploited/ransomware/infra/headline panels`.**

---

### Task 7: Landing page

**Files:**
- Modify: `src/app/page.tsx`; Create: `src/components/landing/{Hero,MapBand,Modules,Flow,AccessSection}.tsx`, `src/lib/modules.ts`

**Interfaces:**
```ts
// modules.ts
export interface ModuleDef { slug: 'intel'|'grc'|'redteam'|'training'; name: LStr; blurb: LStr; bullets: LStr[]; status: 'live'|'available'|'design'; href: string; icon: IconName; wide?: boolean }
export const modules: ModuleDef[]
```

- [ ] **Step 1: Write copy** (EN + TH) for every section per spec §6 and the §5.2 word ban; headline EN: "Exploited in the wild, mapped within the hour." Sub: one sentence on what the platform is for.
- [ ] **Step 2: Build sections** — `Hero` (7/5 grid, HUD tiles from `snapshot.stats`), `MapBand` (`WorldMap` at 420 px, non-interactive, ransomware layer), `Modules` (bento with `wide` on intel), `Flow` (Observe → Govern → Test & train), `AccessSection` (`RequestAccessForm` + sign-in link). `page.tsx` awaits `getIntelSnapshot()` and passes slices down.
- [ ] **Step 3: Screenshots at three widths; check the §5.2 list line by line. Commit `feat: landing page with live HUD and map band`.**

---

### Task 8: ISO 27001 catalogue and framework registry

**Files:**
- Create: `src/lib/grc/types.ts`, `src/lib/grc/iso27001/catalogue.ts`, `catalogue.test.ts`, `src/lib/grc/frameworks.ts`

**Interfaces:**
```ts
export type Theme = 'organisational' | 'people' | 'physical' | 'technological';
export interface Control { id: string; theme: Theme; title: LStr; summary: LStr; type: ('preventive'|'detective'|'corrective')[]; cia: ('C'|'I'|'A')[]; concept: ('identify'|'protect'|'detect'|'respond'|'recover')[]; domains: string[] }
export const ISO27001_CONTROLS: Control[]            // exactly 93
export const THEMES: { key: Theme; label: LStr; range: string }[]
export interface Framework { slug: 'iso27001'; name: LStr; version: string; catalogue: Control[]; status: 'available' }
export const frameworks: Framework[]; export const plannedFrameworks: { slug: string; name: LStr; blurb: LStr }[]   // nist-csf-2, craf
```

- [ ] **Step 1: Tests** — length 93; ids unique; theme counts 37/8/14/34; ids match `/^[5-8]\.\d{1,2}$/`; every `title.th` and `summary.th` non-empty; every control has ≥1 `type`, ≥1 `cia`, ≥1 `concept`.
- [ ] **Step 2: Write the catalogue** — all 93 controls with the official titles, product-written one-line summaries in EN and TH (not the standard's text), and attribute tags. Write it as data, four arrays concatenated.
- [ ] **Step 3: `npm test` green; commit `feat(grc): ISO 27001:2022 Annex A catalogue (93 controls) and framework registry`.**

---

### Task 9: GRC scoring

**Files:**
- Create: `src/lib/grc/iso27001/score.ts`, `score.test.ts`, `src/lib/grc/iso27001/suggest.ts`, `suggest.test.ts`

**Interfaces:**
```ts
export type ControlStatusValue = 'not_started' | 'partial' | 'implemented' | 'not_applicable';
export interface StatusRow { controlId: string; status: ControlStatusValue; justification: string | null; owner: string | null }
export interface Methodology { lowMax: number; mediumMax: number; highMax: number; acceptMax: number }   // defaults 4, 9, 15, 4
export function compliance(rows: StatusRow[], catalogue: Control[]): { applicable: number; implemented: number; partial: number; notStarted: number; notApplicable: number; pct: number }
export function complianceByTheme(rows, catalogue): Record<Theme, ReturnType<typeof compliance>>
export type Band = 'low' | 'medium' | 'high' | 'critical';
export function riskBand(score: number, m: Methodology): Band
export function heatmap(risks: { likelihood: number; impact: number }[]): number[][]   // [impact-1][likelihood-1]
export interface SoaRow { controlId: string; applicable: boolean; status: ControlStatusValue; justification: string }
export function buildSoa(catalogue: Control[], rows: StatusRow[]): { rows: SoaRow[]; missingJustification: string[] }
export function soaCsv(rows: SoaRow[], catalogue: Control[], lang: Lang): string
export function suggestControls(text: string): string[]   // keyword → control ids, max 5
```

- [ ] **Step 1: Tests** — `compliance` on an empty set: all 93 `notStarted`, `pct 0`; 93 implemented → `pct 1`; 1 implemented + 1 partial + 1 N/A of 93 → `applicable 92`, `pct = 1.5/92`; `riskBand(4)=low, (5)=medium, (9)=medium, (10)=high, (16)=critical`; heatmap 5×5 sums to input length; `buildSoa` lists a N/A control without justification in `missingJustification`; `soaCsv` quotes commas; `suggestControls('phishing email password')` includes `'8.5'` (secure auth) and `'6.3'` (awareness).
- [ ] **Step 2: Implement; `npm test` green; commit `feat(grc): compliance, risk bands, heat map, SoA builder, control suggestions`.**

---

### Task 10: GRC schema and server actions

**Files:**
- Modify: `src/db/schema.ts`; Create: `src/server/actions/grc.ts`, `src/lib/validate.ts`, `src/lib/grc/queries.ts`

**Interfaces:**
```ts
// queries.ts (server only)
export async function getOrgForUser(userId): Promise<Organisation | null>
export async function getStatuses(orgId, framework): Promise<StatusRow[]>
export async function getRisks(orgId, framework): Promise<Risk[]>
export async function getMethodology(orgId): Promise<Methodology>
// grc.ts (server actions; all call auth(), resolve org by ownerId, and 403 on mismatch)
export async function createOrganisation(prev, fd): Promise<ActionResult>
export async function updateOrganisation(prev, fd)
export async function setControlStatus(input: { controlId: string; status: ControlStatusValue; justification?: string; owner?: string; evidenceUrls?: string[] })
export async function saveRisk(prev, fd)        // create or update by `id`
export async function deleteRisk(id: string)
export async function updateMethodology(prev, fd)
export async function resetWorkspace(confirmName: string)
// validate.ts
export const str = (v: unknown, max: number, opts?: { required?: boolean }) => string | null | never
export const int = (v: unknown, min: number, max: number) => number
export const oneOf = <T extends string>(v: unknown, allowed: readonly T[]) => T
```

- [ ] **Step 1: Add the four tables from spec §11 to `schema.ts`** (`organisation` with `ownerId` unique FK → user; `risk_methodology`; `control_status` composite pk; `risk` with `ref` unique per org). `ref` is assigned as `RISK-${String(n).padStart(3,'0')}` where `n = count(*)+1` inside the insert.
- [ ] **Step 2: Write `validate.ts` and the actions**; every action ends with `revalidatePath('/grc/iso27001', 'layout')`. `resetWorkspace` deletes `control_status` and `risk` rows for the org only when `confirmName === org.name`.
- [ ] **Step 3: `npx tsc --noEmit`; commit `feat(grc): organisation, control status, risk register schema and actions`.**

---

### Task 11: GRC hub, dashboard, controls

**Files:**
- Create: `src/app/(app)/grc/page.tsx`, `src/app/(app)/grc/iso27001/layout.tsx` (sub-nav + org guard: no org → render `OrgSetupForm`), `page.tsx` (dashboard), `controls/page.tsx`, `controls/[id]/page.tsx`
- Create: `src/components/grc/{OrgSetupForm,SubNav,Gauge,ThemeBars,HeatMap,StatusPill,StatusSelect,ControlTable,ControlDetailForm}.tsx`

- [ ] **Step 1: Hub** — cards for each `frameworks` entry ("Open") and `plannedFrameworks` ("In design").
- [ ] **Step 2: Dashboard** — `Gauge` (SVG arc of `compliance().pct`), `ThemeBars`, `HeatMap` (5×5 grid coloured by `riskBand`), top 5 open risks by score, controls with no owner count, last `updatedAt`.
- [ ] **Step 3: Controls** — `ControlTable` with theme progress header, `?theme=&status=&q=` filters via search params, `StatusSelect` (client, calls `setControlStatus` on change, optimistic). Detail page: `ControlDetailForm` for status/justification/owner/evidence URLs (one per line), linked risks list.
- [ ] **Step 4: Screenshots at three widths; commit `feat(grc): ISO 27001 hub, dashboard, control registry`.**

---

### Task 12: Risks, SoA export, settings

**Files:**
- Create: `src/app/(app)/grc/iso27001/risks/page.tsx`, `risks/new/page.tsx`, `risks/[id]/page.tsx`, `soa/page.tsx`, `settings/page.tsx`, `src/app/api/grc/iso27001/soa.csv/route.ts`
- Create: `src/components/grc/{RiskTable,RiskForm,SoaTable,MethodologyForm,ResetWorkspace}.tsx`

- [ ] **Step 1: Risk register** — table sorted by score desc with band pill, `HeatMap` above; `RiskForm` with likelihood/impact 1–5 radios, live score + band, treatment select, linked controls multi-select seeded by `suggestControls(title + description)` (client, debounced).
- [ ] **Step 2: SoA** — `SoaTable` from `buildSoa`; a banner listing `missingJustification` controls with links; export button → `/api/grc/iso27001/soa.csv` (route calls `auth()`, resolves org, returns 409 with the missing list as JSON when justification is incomplete, else `text/csv` attachment). `?print=1` renders the plain table under `@media print`.
- [ ] **Step 3: Settings** — organisation form, `MethodologyForm` (four ints with ordering validated `lowMax < mediumMax < highMax`), `ResetWorkspace` (type the org name).
- [ ] **Step 4: Screenshots; commit `feat(grc): risk register, Statement of Applicability export, settings`.**

---

### Task 13: Module pages, security headers, docs

**Files:**
- Create: `src/app/redteam/page.tsx`, `src/app/training/page.tsx`, `src/components/site/ModulePage.tsx`; Modify: `next.config.ts`; Create: `CLAUDE.md`, `AGENTS.md`, update `README.md`

- [ ] **Step 1: `ModulePage`** — shared layout for "in design" modules: name, what it will do (3 paragraphs, bilingual), planned capabilities list, "Request a briefing" → `/#access`. No fake screenshots.
- [ ] **Step 2: Headers** in `next.config.ts` exactly as spec §10; `poweredByHeader: false`. Verify with `curl -sI localhost:3000 | grep -i content-security`.
- [ ] **Step 3: Docs** — `CLAUDE.md` (commands, gate location, cache rule, source list, the eager-`db` rule, catalogue-not-standard-text rule, release steps); `AGENTS.md` pointer; `README.md` public description with attribution to the three reference repos and all data sources.
- [ ] **Step 4: Gate; commit `feat: module pages, security headers, docs`.**

---

### Task 14: Release — repo, Vercel, Neon, domain, v1.0.0

- [ ] **Step 1: Full gate** — `npx tsc --noEmit && npm run lint && npm test && npm run build` (with `DATABASE_URL` unset).
- [ ] **Step 2: Repo** — `gh repo create khantee8/cyber.nanoteofficial.me --public --source=. --push`.
- [ ] **Step 3: Vercel** — `vercel link --yes --project cyber-nanoteofficial-me`, `vercel git connect`. Confirm the project appears in `vercel project ls`.
- [ ] **Step 4: Database** — try `vercel integration add neon`; if it needs interaction, fall back to `psql` against an existing Neon project: `CREATE DATABASE cyber` and derive `DATABASE_URL` from `exam`'s `.env.local` with the database name swapped; record which path was used in the hand-off. Then `DATABASE_URL=… npx drizzle-kit push`.
- [ ] **Step 5: Env** — `vercel env add` for `AUTH_SECRET` (`openssl rand -base64 32`), `AUTH_RESEND_KEY` (pull from exam: `vercel env pull` in the exam directory, read the value), `AUTH_RESEND_FROM`, `ALLOWED_EMAILS`, `DATABASE_URL` — production + preview.
- [ ] **Step 6: Version** — set `package.json` and both `package-lock.json` version fields to `1.0.0`; commit `feat: v1.0.0 — Threat Intel ops view, ISO 27001 workspace, landing and login`; `git tag -a v1.0.0 -m "v1.0.0"`; push main and tag; `gh release create v1.0.0 --generate-notes`.
- [ ] **Step 7: Domain** — `vercel domains add cyber.nanoteofficial.me` in the new project; wait for the deploy; `curl -s -o /dev/null -w '%{http_code}' https://cyber.nanoteofficial.me` → 200; `curl -s https://cyber.nanoteofficial.me/api/intel | jq .health` → every source `ok`.
- [ ] **Step 8: Memory + dotfiles** — write `/root/.claude/projects/-project/memory/project_cyber_deployment.md`, add the index line, add the project section to `/project/CLAUDE.md`, commit the dotfiles repo.

---

## Self-review

- Spec §4 routes: `/`, `/intel` (T6/T7), `/grc*` (T11/T12), `/redteam`, `/training` (T13), auth (T2), `/api/intel` (T4), `/api/grc/iso27001/soa.csv` (T12) — covered.
- Spec §7.1 six sources — T3; §7.2 caching/fallback — T4; §7.3 map — T5; §7.4 panels — T6.
- Spec §8 model/pages/scoring/seam — T8–T12; §9 auth — T2; §10 security — T2 (throttle), T13 (headers); §12 tests — T3, T4, T5, T8, T9; §13 deploy — T14.
- Names are consistent: `getIntelSnapshot`, `IntelSnapshot.stats.byCountry`, `WorldMap` props, `StatusRow`, `Methodology`, `buildSoa`, `suggestControls` used identically across tasks.

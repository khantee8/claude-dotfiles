# cyber.nanoteofficial.me v1.1 — NIST CSF 2.0 Profile Workspace — Design Spec

**Date:** 2026-09-23 · **Repo:** `khantee8/cyber.nanoteofficial.me` · **Target release:** `v1.1.0`
**Builds on:** `2026-09-08-cyber-nanoteofficial-v1-design.md` (§8.4 multi-framework seam, §16 backlog)

## 1. Overview

A second GRC framework beside ISO 27001: a NIST Cybersecurity Framework 2.0
**Organisational Profile** workspace. For each of the 106 CSF Subcategories the
organisation records a **Current** and a **Target** score (0–4); the product is
the gap between them, by Function and Category, plus organisation-level Tiers.

It reuses the ISO workspace's organisation, auth gate, layout and risk register,
and links to ISO 27001 through NIST's CSF-to-ISO mapping so an existing ISO gap
assessment can suggest CSF Current scores.

## 2. Decisions (confirmed with the owner, 2026-09-23)

| # | Question | Decision |
|---|---|---|
| D1 | How is a Subcategory assessed? | Current vs Target maturity, 0–4 each (not ISO-style status, not a questionnaire) |
| D2 | Link to ISO 27001? | Show mapped ISO controls with live status **and** suggest a Current score; never written without the user accepting |
| D3 | Risk register? | One shared register; a risk links to ISO controls and CSF Subcategories |
| D4 | Storage | New dedicated `csf_score` table (not extra columns on `control_status`, not a JSON blob) |

## 3. Goals / non-goals

**Goals**
- A full CSF 2.0 Profile for an organisation: Current, Target, gap, coverage, Tiers.
- Gap views that read at a glance: per-Function bars, per-Category heatmap, ranked gaps.
- CSV export of the Profile.
- ISO↔CSF cross-reference with suggestions and a bulk "prefill from ISO".
- A BankX demo profile consistent with the existing BankX ISO assessment.
- Purely additive migration; ISO 27001 behaviour unchanged.

**Non-goals (v1.1)**
- Questionnaire / guided mode (a later layer that would write the same scores).
- Community or sector profiles, profile history or comparisons over time.
- CSF-specific policy templates, CRAF, any LLM feature.
- Changes to the portfolio or tools repos (no new external connection).

## 4. Catalogue

`src/lib/grc/nist-csf-2/catalogue.ts` — static data, no DB.

- **Structure:** 6 Functions → 22 Categories → 106 Subcategories.

  | Function | Categories | Subcategories |
  |---|---|---|
  | GV Govern | GV.OC, GV.RM, GV.RR, GV.PO, GV.OV, GV.SC | 31 |
  | ID Identify | ID.AM, ID.RA, ID.IM | 21 |
  | PR Protect | PR.AA, PR.AT, PR.DS, PR.PS, PR.IR | 22 |
  | DE Detect | DE.CM, DE.AE | 11 |
  | RS Respond | RS.MA, RS.AN, RS.CO, RS.MI | 13 |
  | RC Recover | RC.RP, RC.CO | 8 |

- **Text:** CSF 2.0 is a US Government work (public domain), so English
  Function/Category/Subcategory text is NIST's official wording. Thai is our own
  translation. This differs deliberately from the ISO catalogue rule ("our own
  words"), which exists because ISO text is copyrighted; a comment in the file
  states why.
- **Types** (`src/lib/grc/nist-csf-2/types.ts`):
  ```ts
  type CsfFunctionId = 'GV' | 'ID' | 'PR' | 'DE' | 'RS' | 'RC';
  interface CsfFunction    { id: CsfFunctionId; name: LStr; }
  interface CsfCategory    { id: string; fn: CsfFunctionId; name: LStr; }      // "GV.RM"
  interface CsfSubcategory { id: string; category: string; fn: CsfFunctionId;  // "GV.RM-01"
                             text: LStr; iso27001: string[]; }                 // ["5.1", "6.1.2"?]
  ```
  `iso27001` holds **Annex A control IDs present in the ISO catalogue** only
  (clause-level references such as 6.1.2 are omitted, because the ISO workspace
  does not track clauses).
- **Mapping source:** NIST's published CSF 2.0 Informative Reference for
  ISO/IEC 27001:2022 (NIST CPRT / OLIR). See assumption A1.

## 5. Data model (Drizzle, additive)

```ts
csf_score (
  organisationId  text  → organisation.id, cascade
  subcategoryId   text                       -- "GV.RM-01"
  current         integer null               -- 0..4, null = not scored
  target          integer null               -- 0..4, null = not scored
  inScope         boolean not null default true
  owner           text null
  notes           text null
  evidenceUrls    jsonb string[] not null default []
  updatedAt       timestamp not null default now()
  PK (organisationId, subcategoryId)
)

csf_profile (
  organisationId  text PK → organisation.id, cascade
  scope           text null
  currentTier     integer null   -- 1..4
  targetTier      integer null   -- 1..4
  updatedAt       timestamp not null default now()
)

risk.linkedCsfIds  jsonb string[] not null default []   -- new column
```

**Risk sharing:** `risk.framework` keeps its meaning of "workspace the risk was
created in". Risk listings become org-wide: `getRisks(orgId)` drops the
framework filter for both workspaces. The ISO risk form gains a CSF Subcategory
picker; the CSF pages list risks where `linkedCsfIds` is non-empty (dashboard)
or contains the Subcategory (detail), linking through to the ISO risk page to edit.

## 6. Scales

**Subcategory score (0–4)** — labelled "Maturity" in the UI, never "Tier":

| Score | Label (EN) | Meaning |
|---|---|---|
| 0 | Not performed | Outcome not achieved |
| 1 | Initial | Ad hoc, person-dependent |
| 2 | Defined | Documented, partially applied |
| 3 | Managed | Consistently applied, owned, checked |
| 4 | Optimised | Measured and continuously improved |

**Tier (1–4, organisation-wide, CSF's own):** 1 Partial, 2 Risk Informed,
3 Repeatable, 4 Adaptive. One Current and one Target Tier per profile.

## 7. Scoring (`src/lib/grc/nist-csf-2/score.ts`, pure, tested)

- `gap(row) = max(0, target − current)`, defined only when both are set.
- **Assessed** = in scope **and** both scores set.
- `summary(rows, subset)` → `{ inScope, assessed, coverage = assessed / inScope,
  avgCurrent, avgTarget, avgGap }`, averages over assessed rows only; all
  averages `null` when `assessed = 0`. Used per Function, per Category and overall.
- `topGaps(rows, n)` → assessed rows sorted by gap desc, then ID asc; gap 0 excluded.
- **ISO suggestion** `suggestCurrent(sub, isoStatuses)`:
  implemented = 3, partial = 1.5, not_started = 0, not_applicable skipped, and a
  control with no status row counts as not assessed (skipped). Mean of the rest,
  rounded half-up to an integer. Returns `null` if nothing remains. Also returns
  the per-control breakdown for the UI.
- Missing rows are treated as `{ current: null, target: null, inScope: true }`.

## 8. Pages (`src/app/(app)/grc/nist-csf-2/`)

Shared `layout.tsx` with tab bar, mirroring the ISO layout. A user with no
organisation is redirected to `/grc/iso27001/setup?next=/grc/nist-csf-2`; setup
honours `next` (validated to start with `/grc/`).

| Route | Content |
|---|---|
| `/` | Dashboard: Current vs Target bars for 6 Functions, coverage, Tier current → target, top 10 gaps, linked risks |
| `/profile` | All 106 grouped by Function → Category; inline 0–4 pickers for Current/Target; filters: function, unscored, gap ≥ 2, out of scope; per-Category bulk "set Target to N" |
| `/profile/[id]` | Official text + Thai, scores, in-scope toggle, owner, notes, evidence URLs; mapped ISO controls with live status and links; suggestion with Accept; linked risks. 404 for unknown IDs |
| `/gaps` | 22-row Category heatmap by avg gap; ranked Subcategory gaps; CSV export link |
| `/settings` | Scope text, Current/Target Tier, "Prefill Current from ISO" with a preview count before applying |

`/api/grc/nist-csf-2/profile.csv` — gated like the SoA CSV; columns: `id,
function, category, current, target, gap, in_scope, owner, notes`; RFC 4180
quoting; filename `csf-profile-<org>-<date>.csv`. No 409 condition (a partial
profile is a valid export).

Charts are hand-rolled SVG, like the ISO dashboard. Heatmap colour steps use
existing CSS tokens; each cell also prints its number (colour is never the only signal).

**Hub:** `frameworks.ts` — `Framework` becomes
`{ slug, name, version, blurb, href, count }` (the hub only needs a count);
CSF moves from `plannedFrameworks` to `frameworks`; `FrameworkSlug` gains
`'nist-csf-2'`. Nothing reads `framework.catalogue` today, so dropping it
touches only `frameworks.ts` and the hub page.

## 9. Server actions (`src/server/actions/csf.ts`)

Same rules as `grc.ts`: resolve the organisation from the session on every call,
validate with `src/lib/validate.ts` (no zod), `revalidatePath` the affected routes.

| Action | Input | Effect |
|---|---|---|
| `saveCsfScore` | id, partial of current/target/inScope/owner/notes/evidenceUrls | upsert one `csf_score` row |
| `bulkSetTarget` | categoryId, target | upsert target for every Subcategory in the Category |
| `acceptSuggestion` | id | recompute suggestion server-side, write `current` (refuse if null) |
| `prefillFromIso` | — | for every Subcategory with `current = null` and a non-null suggestion, write it; return count |
| `saveCsfProfile` | scope, currentTier, targetTier | upsert `csf_profile` |
| `saveRisk` (existing) | + `linkedCsfIds` | validated against the CSF catalogue |

Validation: scores are integers 0–4 or null; Tiers 1–4 or null; IDs must exist
in the catalogue; evidence URLs reuse the existing URL validator.

## 10. BankX demo

`src/lib/grc/nist-csf-2/demo/bankx.ts`: all 106 Subcategories with current,
target, owner, note. Targets mostly 3; 4 for PR.AA, DE.CM, GV.SC (the areas BOT
supervision presses hardest). Current values are chosen so they agree with the
ISO-derived suggestion within ±1 wherever a suggestion exists. Profile: Tier 2 →
3, scope matching the ISO scope. 4–5 of the existing 12 BankX risks gain
`linkedCsfIds`. `scripts/seed-demo.ts` emits the CSF rows inside the same
transaction, still keyed by organisation name and re-runnable (upserts).

## 11. i18n and UI rules

Every new string EN + TH in `i18n.ts` typed keys; data uses `LStr`. No emoji, no
`dangerouslySetInnerHTML`, copy avoids "unlock / empower / seamless / next-gen".
CSP unchanged (no new hosts).

## 12. Testing

Vitest, pure logic only (as in v1):
- `catalogue.test.ts` — 6 / 22 / 106, per-Function counts from §4, unique IDs,
  IDs well-formed and consistent with parent Category/Function, EN + TH non-empty,
  every `iso27001` ID exists in `ISO27001_CONTROLS`.
- `score.test.ts` — gap, summary per Function/Category, coverage with
  unscored/out-of-scope rows, `null` averages, topGaps ordering, suggestion
  (all implemented → 3; mixed rounding half-up; all N/A → null; no statuses → null).
- `validate` cases for scores, Tiers and unknown IDs.
- `demo/bankx.test.ts` — all 106 present, scores in range, suggestion
  agreement ±1, linked risk IDs valid.

Gate: `npx tsc --noEmit && npm run lint && npm test && npm run build` with
`DATABASE_URL` unset. Manual pass against the local Postgres + Neon-proxy recipe
with BankX seeded: every route, both languages, 390 px width.

## 13. Release

1. `drizzle-kit push` against production Neon (additive: 2 tables, 1 defaulted column) **before** pushing code.
2. Bump to `1.1.0` in `package.json` + both `package-lock.json` fields; gate; commit `feat: v1.1.0 — NIST CSF 2.0 profile workspace`; tag; push main + tag.
3. Confirm production serves `/grc` with CSF listed and `/api/intel` reports every source `ok`.
4. Docs: repo `CLAUDE.md` + README; `/project/CLAUDE.md` cyber entry.

## 14. Assumptions (please confirm or overrule)

- **A1 Mapping source.** NIST publishes a CSF 2.0 → ISO/IEC 27001:2022
  Informative Reference via CPRT/OLIR. If, during implementation, it is not
  available in a usable form, we build the mapping ourselves, label it in the UI
  as "NaNote mapping, not NIST's", and record that in the catalogue header.
- **A2 Suggestion weights** (3 / 1.5 / 0) are ours, shown in the UI next to the
  suggestion so it is never mistaken for an official conversion.
- **A3 Thai translation** of CSF text is machine-assisted and reviewed in-session;
  it is labelled as an unofficial translation.
- **A4 Shared risk listing** — ISO's risk page now shows all org risks, including
  any created from CSF context in the future. Today every risk is created in the
  ISO workspace, so nothing visible changes.

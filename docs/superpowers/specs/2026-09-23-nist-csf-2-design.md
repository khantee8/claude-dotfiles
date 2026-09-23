# cyber.nanoteofficial.me v1.1 — NIST CSF 2.0 Profile Workspace — Design Spec

**Date:** 2026-09-23 · **Repo:** `khantee8/cyber.nanoteofficial.me` · **Target release:** `v1.1.0`
**Builds on:** `2026-09-08-cyber-nanoteofficial-v1-design.md` (§8.4 multi-framework seam, §16 backlog)

## 1. Overview

A second GRC framework beside ISO 27001: a NIST Cybersecurity Framework 2.0
**Organisational Profile** workspace. For each of the 106 CSF Subcategories the
organisation records a **Current** and a **Target** score on a 0–10 scale plus
fieldwork details (testing status, methods, observation date); the product is the
gap between them, by Function and Category, a rating per Function, and
organisation-level Tiers.

It reuses the ISO workspace's organisation, auth gate, layout and risk register,
and links to ISO 27001 through NIST's official mapping so an existing ISO gap
assessment can suggest CSF Current scores.

## 2. Decisions (confirmed with the owner, 2026-09-23)

| # | Question | Decision |
|---|---|---|
| D1 | How is a Subcategory assessed? | Current vs Target score per Subcategory (not ISO-style status, not a questionnaire) |
| D2 | Link to ISO 27001? | Show mapped ISO controls with live status **and** suggest a Current score; never written without the user accepting |
| D3 | Risk register? | One shared register; a risk links to ISO controls and CSF Subcategories |
| D4 | Storage | New dedicated `csf_score` table |
| D5 | Scale | **0–10 in 0.5 steps**, 5 = minimum acceptable, 8+ = excessive — the method used by csf_profile (§3) |
| D6 | Reference projects | Model the workflow on csf_profile; take no code or question content from either project; build the catalogue from NIST's own published data |

## 3. Reference projects

Both are MIT-licensed. They are **models**, not dependencies: nothing is
installed or vendored, and no source code is copied. Both are credited in the README.

**[CPAtoCybersecurity/csf_profile](https://github.com/CPAtoCybersecurity/csf_profile)** —
a self-hosted CSF 2.0 profile assessment tool (React). Adopted:
- the 0–10 Current/Target scale with a pass line at 5 and a deliberate
  "excessive" band (proportionate security, not maximum security) — anchors
  rewritten in our own words, because csf_profile credits the band scheme to the
  AKYLADE *Mastering Cyber Resilience* textbook;
- fieldwork fields per Subcategory: testing status and Examine / Interview / Test methods, observation date;
- the per-Function rating: Satisfactory (average ≥ target), Needs Improvement
  (≥ 70 % of target), Unsatisfactory (below);
- a radar chart of Current vs Target by Function on the dashboard.

Not adopted: its category-level ISO mapping (`src/data/csfMappings.js`, e.g. GV.RM
→ A.5.1, A.5.2 only — too coarse; we use NIST's Subcategory-level mapping), the
Alma Security case study and test procedures (written for that fictional company),
multi-assessment/quarterly history, findings and remediation tables (our shared
risk register covers treatment), the AI assistant, and encrypted exports.

**[rocklambros/nist-csf-2-mcp-server](https://github.com/rocklambros/nist-csf-2-mcp-server)** —
an MCP server with 40+ CSF tools. Adopted:
- the idea of ranking gaps by risk as well as size — our tie-break (§7);
- confirmation that NIST's CPRT JSON export is the practical source for the
  catalogue and the 363 Implementation Examples (its `data/csf-2.0-framework.json`
  is that export; we fetch it from NIST, not from the repo).

Not adopted: the question bank — 424 questions (not the 740 the README claims),
4 per Subcategory, only 88 distinct wordings, mostly templated; profile
compare/clone and maturity trends (backlog); cost estimates, policy templates.
An MCP surface of our own stays in the backlog next to `/api/intel/mcp`.

## 4. Goals / non-goals

**Goals**
- A full CSF 2.0 Profile: Current, Target, gap, coverage, Function ratings, Tiers.
- Fieldwork recording per Subcategory: owner, testing status, methods, observation date, notes, evidence links.
- Gap views: radar and paired bars by Function, Category heatmap, ranked gaps.
- CSV export of the Profile.
- ISO↔CSF cross-reference with suggestions and a bulk "prefill from ISO".
- NIST Implementation Examples on every Subcategory page.
- A BankX demo profile consistent with the existing BankX ISO assessment.
- Purely additive migration; ISO 27001 behaviour unchanged.

**Non-goals (v1.1)**
- Questionnaire / guided mode; multiple assessments or quarterly history; profile comparison.
- Findings / remediation-plan tables, policy templates, CRAF, any LLM feature.
- Changes to the portfolio or tools repos (no new external connection at runtime).

## 5. Catalogue

Generated, committed, static — no DB and no network at build or test time.

- **Source:** NIST CPRT JSON export of CSF 2.0 (functions, categories,
  subcategories, implementation examples; public domain) and NIST OLIR
  informative reference **"ISO/IEC-27001:2022-to-Cybersecurity-Framework-v2.0"**
  (catalogue referenceId 154, Final v1.0.0, 2026-07-09).
- **Import script:** `npm run csf:import` (`scripts/import-csf.ts`) downloads
  both, keeps only active elements (the export also carries 202 withdrawn CSF 1.1
  items), and writes `src/lib/grc/nist-csf-2/catalogue.data.json`. Same pattern as
  `intel:snapshot`: the only code that touches the network, refuses to write on
  any shape mismatch.
- **Thai:** `src/lib/grc/nist-csf-2/catalogue.th.json` — our translation of every
  Function, Category, Subcategory and Implementation Example, keyed by element ID,
  labelled in the UI as an unofficial translation. `catalogue.ts` merges the two
  into `LStr` values.
- **Structure:** 6 Functions → 22 Categories → 106 Subcategories → 363 Implementation Examples.

  | Function | Categories | Subcategories |
  |---|---|---|
  | GV Govern | GV.OC, GV.RM, GV.RR, GV.PO, GV.OV, GV.SC | 31 |
  | ID Identify | ID.AM, ID.RA, ID.IM | 21 |
  | PR Protect | PR.AA, PR.AT, PR.DS, PR.PS, PR.IR | 22 |
  | DE Detect | DE.CM, DE.AE | 11 |
  | RS Respond | RS.MA, RS.AN, RS.CO, RS.MI | 13 |
  | RC Recover | RC.RP, RC.CO | 8 |

- **Types** (`src/lib/grc/nist-csf-2/types.ts`):
  ```ts
  type CsfFunctionId = 'GV' | 'ID' | 'PR' | 'DE' | 'RS' | 'RC';
  interface CsfFunction    { id: CsfFunctionId; name: LStr; }
  interface CsfCategory    { id: string; fn: CsfFunctionId; name: LStr; }      // "GV.RM"
  interface CsfSubcategory { id: string; category: string; fn: CsfFunctionId;  // "GV.RM-01"
                             text: LStr; examples: LStr[]; iso27001: string[]; }
  ```
- **ISO text rule is unchanged.** CSF text is public domain, so it is shown
  verbatim; the mapping only carries ISO **identifiers**. `iso27001` keeps Annex A
  control IDs that exist in `ISO27001_CONTROLS`, normalised ("A.5.1" → "5.1");
  clause-level references (4–10) are dropped because the ISO workspace does not track clauses.

## 6. Data model (Drizzle, additive)

```ts
csf_score (
  organisationId  text  → organisation.id, cascade
  subcategoryId   text                         -- "GV.RM-01"
  current         real null                    -- 0..10, multiples of 0.5; null = not scored
  target          real null                    -- same
  inScope         boolean not null default true
  owner           text null
  testingStatus   text enum('not_started','in_progress','complete') not null default 'not_started'
  examined        boolean not null default false
  interviewed     boolean not null default false
  tested          boolean not null default false
  observedAt      date null
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

`real` is exact for multiples of 0.5, so no rounding drift; the validator rejects anything else.

**Risk sharing:** `risk.framework` keeps its meaning of "workspace the risk was
created in". `getRisks(orgId)` drops the framework filter so both workspaces
list all organisation risks. The ISO risk form gains a CSF Subcategory picker;
CSF pages list risks whose `linkedCsfIds` is non-empty (dashboard) or contains
the Subcategory (detail), linking to the ISO risk page to edit.

## 7. Scales and scoring

**Score anchors (0–10, 0.5 steps)** — our wording:

| Score | Anchor |
|---|---|
| 0 | Nothing exists: no policy, no process, no sign it is done |
| 1 | Written down somewhere, not actually done |
| 2 | Done occasionally, by individual initiative |
| 3 | A process is defined but runs unreliably — missed cycles, gaps |
| 4 | Runs regularly with material weaknesses — partial coverage, untreated exceptions |
| 5 | Runs consistently across the full scope, minor flaws, evidence for the period — **minimum acceptable** |
| 6 | As 5, plus defined measures the owner reviews and acts on |
| 7 | Measured and demonstrably improving over several periods |
| 8 | Highly effective and proportionate to the risk, sustained |
| 9 | Investment exceeds what the risk justifies |
| 10 | So heavy it gets in the way of the business |

**Bands:** 0–1.5 Insecure · 2–4.5 Some security · 5–5.5 Minimally acceptable ·
6–6.5 Effective · 7–7.5 Optimised · 8–10 Excessive. A score belongs to the band
that starts at or below it. The UI explains that 8+ is a finding, not an achievement.

**Tier (1–4, organisation-wide, CSF's own):** Partial, Risk Informed, Repeatable, Adaptive.

**Pure functions** (`src/lib/grc/nist-csf-2/score.ts`, tested):
- `gap(row) = max(0, target − current)`, defined only when both are set.
- **Assessed** = in scope **and** both scores set.
- `summary(rows, subset)` → `{ inScope, assessed, coverage, avgCurrent,
  avgTarget, avgGap }` over assessed rows; averages `null` when `assessed = 0`.
  Used per Function, per Category and overall.
- `functionRating(summary)` → `satisfactory` if avgCurrent ≥ avgTarget,
  `needs_improvement` if ≥ 0.7 × avgTarget, else `unsatisfactory`; `null` when not assessed.
- `band(score)` → band key.
- `rankGaps(rows, risks, methodology)` → assessed rows with gap > 0, sorted by
  gap desc, then highest inherent score (likelihood × impact) among linked risks
  desc, then ID asc.
- `suggestCurrent(sub, isoStatuses)` — implemented = 5, partial = 3,
  not_started = 0; not_applicable and missing status rows are skipped; mean of
  the rest rounded to the nearest 0.5 (half up); `null` if nothing remains.
  Returns the per-control breakdown for the UI, which states the weights are ours.
- Missing rows are treated as `{ current: null, target: null, inScope: true }`.

## 8. Pages (`src/app/(app)/grc/nist-csf-2/`)

Shared `layout.tsx` with tab bar, mirroring the ISO layout. A user with no
organisation is redirected to `/grc/iso27001/setup?next=/grc/nist-csf-2`; setup
honours `next` only when it starts with `/grc/`.

| Route | Content |
|---|---|
| `/` | Dashboard: radar (Current vs Target by Function), per-Function paired bars with rating badge, coverage, Tier current → target, top 10 gaps, linked risks |
| `/profile` | All 106 grouped by Function → Category; inline Current/Target pickers (0–10, 0.5 steps) with band colour; filters: function, unscored, gap ≥ 2, testing status, out of scope; per-Category bulk "set Target to N" |
| `/profile/[id]` | Official text + Thai; Implementation Examples; scores with band and anchor text; fieldwork (testing status, methods, observation date, owner, notes, evidence URLs); in-scope toggle; mapped ISO controls with live status and links; suggestion with Accept; linked risks. 404 for unknown IDs |
| `/gaps` | 22-row Category heatmap by average gap; ranked gaps (§7); CSV export link |
| `/settings` | Scope text, Current/Target Tier, "Prefill Current from ISO" with a preview count before applying |

`/api/grc/nist-csf-2/profile.csv` — gated like the SoA CSV; columns `id,
function, category, current, target, gap, band, in_scope, testing_status,
examined, interviewed, tested, observed_at, owner, notes`; RFC 4180 quoting;
filename `csf-profile-<org>-<date>.csv`. Always exportable (a partial profile is valid).

Charts are hand-rolled SVG, like the ISO dashboard. Colour is never the only
signal: heatmap cells and bars print their numbers.

**Hub:** `Framework` in `frameworks.ts` becomes `{ slug, name, version, blurb,
href, count }`; CSF moves from `plannedFrameworks` to `frameworks`;
`FrameworkSlug` gains `'nist-csf-2'`. Nothing reads `framework.catalogue`
today, so the change touches only `frameworks.ts` and the hub page.

## 9. Server actions (`src/server/actions/csf.ts`)

Same rules as `grc.ts`: resolve the organisation from the session on every
call, validate with `src/lib/validate.ts` (no zod), `revalidatePath` affected routes.

| Action | Input | Effect |
|---|---|---|
| `saveCsfScore` | id + partial of the `csf_score` fields | upsert one row |
| `bulkSetTarget` | categoryId, target | upsert target for every Subcategory in the Category |
| `acceptSuggestion` | id | recompute server-side, write `current` (refuse if null) |
| `prefillFromIso` | — | for every Subcategory with `current = null` and a suggestion, write it; return count |
| `saveCsfProfile` | scope, currentTier, targetTier | upsert `csf_profile` |
| `saveRisk` (existing) | + `linkedCsfIds` | validated against the CSF catalogue |

Validation: scores are null or a multiple of 0.5 in 0–10; Tiers 1–4 or null;
testing status in its enum; `observedAt` a real date not in the future; IDs must
exist in the catalogue; evidence URLs reuse the existing URL validator.

## 10. BankX demo

`src/lib/grc/nist-csf-2/demo/bankx.ts`: all 106 Subcategories with current,
target, owner, testing status, methods, observation date and a short note.
Targets mostly 6; 7 for PR.AA, DE.CM, GV.SC (the areas BOT supervision presses
hardest); none at 8+. Current values agree with the ISO-derived suggestion
within ±1 wherever one exists. Profile: Tier 2 → 3, scope matching the ISO scope.
4–5 of the existing 12 BankX risks gain `linkedCsfIds`. `scripts/seed-demo.ts`
emits the CSF rows inside the same transaction, still keyed by organisation name
and re-runnable (upserts).

## 11. i18n, UI and attribution

Every new string EN + TH in `i18n.ts` typed keys; data uses `LStr`. No emoji,
no `dangerouslySetInnerHTML`, copy avoids "unlock / empower / seamless /
next-gen". CSP unchanged. README gains a "Reference projects" section crediting
both repos (MIT) and NIST as the source of the catalogue and mapping; the
Subcategory page footer cites NIST CSF 2.0 and the OLIR reference.

## 12. Testing

Vitest, pure logic only:
- `catalogue.test.ts` — 6 / 22 / 106 / 363, per-Function counts from §5, unique
  well-formed IDs consistent with parents, EN + TH non-empty for every element,
  every `iso27001` ID exists in `ISO27001_CONTROLS`, at least 90 of 106
  Subcategories carry an ISO mapping (guards against a broken import).
- `score.test.ts` — gap, summary, coverage with unscored/out-of-scope rows, `null`
  averages, Function rating boundaries (exactly target, exactly 70 %), band
  boundaries (4.5 / 5 / 7.5 / 8), rankGaps tie-break, suggestion (all
  implemented → 5; mixed rounding to 0.5; all N/A → null; no statuses → null).
- `import-csf` parser tests against small fixtures (active-only filter,
  withdrawn elements dropped, `A.` prefix normalisation, clause refs dropped).
- `validate` cases for scores (4.25 rejected, 10.5 rejected), Tiers, dates, unknown IDs.
- `demo/bankx.test.ts` — all 106 present, scores valid, suggestion agreement ±1, risk links valid.

Gate: `npx tsc --noEmit && npm run lint && npm test && npm run build` with
`DATABASE_URL` unset. Manual pass against the local Postgres + Neon-proxy recipe
with BankX seeded: every route, both languages, 390 px width.

## 13. Release

1. `drizzle-kit push` against production Neon (additive: 2 tables, 1 defaulted column) **before** pushing code.
2. Bump to `1.1.0` in `package.json` + both `package-lock.json` fields; gate; commit `feat: v1.1.0 — NIST CSF 2.0 profile workspace`; tag; push main + tag.
3. Confirm production serves `/grc` with CSF listed and `/api/intel` reports every source `ok`.
4. Docs: repo `CLAUDE.md` + README (incl. reference projects); `/project/CLAUDE.md` cyber entry.

## 14. Assumptions (please confirm or overrule)

- **A1 Mapping source — confirmed.** NIST OLIR referenceId 154 is Final (v1.0.0,
  2026-07-09). Its exact download format is resolved in the import script; if a
  relationship type such as "intersects with" appears, every relationship except
  "not related" counts as a mapping.
- **A2 Suggestion weights** (5 / 3 / 0) are ours and shown next to the suggestion.
- **A3 Thai translation** of CSF text and all 363 Implementation Examples is
  machine-assisted, reviewed in-session, and labelled unofficial.
- **A4 Shared risk listing** — ISO's risk page now shows all organisation risks;
  today every risk is created in ISO, so nothing visible changes.
- **A5 No csf_profile import/export compatibility.** csf_profile scores
  *control implementations* (`GV.RM-01 Ex1`) per quarter; we score
  Subcategories once. Column names follow its vocabulary, but files are not
  interchangeable.

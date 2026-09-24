# cyber.nanoteofficial.me v1.3 — GRC customers, folders and assessment history (B1) — Design Spec

**Date:** 2026-09-24 · **Repo:** `khantee8/cyber.nanoteofficial.me` · **Target:** v1.3.0 · **Status:** approved in chat (§1–§3), 2026-09-24
**Follows:** v1.1 CSF spec (`2026-09-23-nist-csf-2-design.md`). **Precedes:** B2 framework builder (separate spec).

## 1. Problem and goal

Today each login owns exactly one organisation, and each organisation has exactly one ISO 27001 and one NIST CSF 2.0 record. The owner's practice serves many customers and re-assesses every fiscal year. Goal: many customers, a free folder tree per customer, many assessments per framework (one per fiscal year or per unit), each new year starting from the previous one, and a year-over-year comparison. B2 will add a framework builder (CRAF and the owner's research framework); B1 must leave the seam for it.

## 2. Decisions (owner, 2026-09-24)

| # | Decision |
|---|---|
| D1 | Only the owner's team signs in; every approved user sees and edits every customer. Customers never log in. |
| D2 | Free folders at any depth under each customer (capped at 8 levels). |
| D3 | New assessments can start from a previous one of the same framework (default) or blank. |
| D4 | New frameworks will come from an in-app builder (B2). |
| D5 | Approach 1: ISO and CSF stay code-defined with their dedicated pages, scoped to an `assessment`; B2 adds a generic engine for builder-made frameworks. |
| D6 | Risk register is per customer, shared across all its assessments and years. |
| D7 | Customers are archived, not deleted, in B1. |

## 3. Data model

New:
```ts
customer (
  id text PK, name text not null, industry text, sizeBand enum('1-10','11-50','51-250','251-1000','1000+'),
  notes text, createdBy text → user.id (set null), createdAt timestamp default now, archivedAt timestamp null
)
folder (
  id text PK, customerId → customer.id cascade, parentId → folder.id cascade null,
  name text not null, sortOrder integer default 0, createdAt timestamp default now
)
assessment (
  id text PK, customerId → customer.id cascade, folderId → folder.id set null,
  framework text not null            -- 'iso27001' | 'nist-csf-2' now; builder frameworks in B2
  title text not null, fiscalYear integer null, periodStart date null, periodEnd date null,
  status enum('draft','in_progress','complete','archived') default 'draft',
  scope text null, lead text null, basedOnId → assessment.id set null,
  createdBy text → user.id set null, createdAt, updatedAt
)
```
Changed (scores move from organisation to assessment; risks to customer):
- `control_status`: PK (assessmentId, controlId); drop `organisationId`; keep `framework` column only if needed for existing queries (else drop).
- `csf_score`: PK (assessmentId, subcategoryId). `csf_profile`: PK assessmentId.
- `risk`: `organisationId` → `customerId`; unique (customerId, ref).
- `risk_methodology`: PK customerId.
- `organisation`: removed after migration (its fields split: name/industry/sizeBand → customer; scope/ismsLead → each assessment's scope/lead).
- Indexes: assessment(customerId, folderId), folder(customerId, parentId).

## 4. Pages and URLs

| Route | Content |
|---|---|
| `/grc` | Customers list (search, name, industry, assessment count, last activity), New customer, archived filter |
| `/grc/c/[customerId]` | Folder tree (create, rename, move via "move to…", delete when empty) + assessments in the selected folder (framework badge, fiscal year, status, key score, updated); New assessment; Compare |
| `/grc/c/[customerId]/risks` (+ `/new`, `/[riskId]`) | Customer risk register (today's ISO risk pages, moved) |
| `/grc/c/[customerId]/settings` | Customer details, risk methodology, archive |
| `/grc/a/[assessmentId]/…` | ISO: dashboard, controls, controls/[id], soa (+ `soa.csv`). CSF: dashboard, profile, profile/[id], gaps (+ `profile.csv`), settings. Header: breadcrumb Customer / folders / assessment, fiscal year, status picker |
| `/grc/c/[customerId]/compare?a=&b=` | Year over year for two assessments of the same framework and customer |

- New assessment dialog: framework, title, fiscal year, folder, Start = Blank | From [previous assessment of that framework; default most recent].
- Old routes `/grc/iso27001/*`, `/grc/nist-csf-2/*` and their CSV routes redirect (308) to `/grc`.
- The org setup screen is replaced by "New customer".

## 5. Copy from previous

One server action, one transaction:
- ISO: status, justification, owner, evidenceUrls for every control.
- CSF: current, target, inScope, owner, notes, evidenceUrls for every subcategory; **reset** testingStatus → 'not_started', examined/interviewed/tested → false, observedAt → null; copy csf_profile (scope, tiers).
- New assessment: `basedOnId` = source; status 'draft'. Pure helpers `planIsoCopy(rows)` / `planCsfCopy(rows)` define exactly what's copied and reset (tested).

## 6. Comparison

Pure, tested:
- `compareIso(aRows, bRows)` → compliance % each, per-theme deltas, per-control transitions (from → to), counts improved/regressed/unchanged.
- `compareCsf(aRows, bRows)` → per-Function avg Current and avg gap each, subcategories with gap closed / opened / changed, radar pairs.
- Server refuses different frameworks or customers (400).

## 7. Rules

- Every action/route: approved-session check (v1.1 `getApprovedViewer`), then load the target by id; no per-customer ACL (D1).
- Folder move rejects cycles and depth > 8; folder delete only when it has no sub-folders and no assessments.
- Assessment delete requires typing its title; cascades its scores and profile.
- Customer archive hides it from `/grc` (filter to show); no delete in B1.
- EN + TH for every new string; no emoji; `getDb()` only; validation in `src/lib/validate.ts`.

## 8. Migration (production, v1.3.0)

1. **Backup:** create a Neon branch of production (`pre-v1.3.0`), free, instant restore.
2. One SQL transaction:
   - create customer / folder / assessment;
   - for each organisation: customer (same id, name, industry, sizeBand, createdBy = ownerId), folder "FY2026", assessment ISO "ISO 27001 — FY2026" (scope/lead from the organisation) if it has any control_status rows, assessment CSF "NIST CSF 2.0 — FY2026" if it has csf_score or csf_profile rows;
   - add assessmentId / customerId columns, backfill, switch PKs/FKs, drop old columns and `organisation`;
   - assert counts before COMMIT (production today: 1 organisation, 93 control_status, 106 csf_score, 1 csf_profile, 12 risks, 1 risk_methodology); `RAISE EXCEPTION` on any mismatch.
3. The SQL is generated from a script (`scripts/migrate-v1.3.sql`, committed) and tested first against the local Docker Postgres with the BankX demo seeded.
4. Deploy; verify BankX → FY2026 → both assessments show the same numbers as before (ISO compliance %, CSF averages, 12 risks).

## 9. Testing

Vitest, no DB: folder tree build + cycle/depth checks; copy plans; compareIso / compareCsf; validators for new inputs. Migration SQL tested on local Postgres (counts and a spot check of values). Browser pass on the local stack (EN/TH, 390/1280 px): create customer → folder → assessment → copy to FY2027 → edit → compare.

## 10. Docs and connected repos

Update cyber CLAUDE.md/README, `/project/CLAUDE.md`, and the tools + portfolio models' cyber GRC description (routes/nodes) in lockstep.

## 11. Out of scope

Framework builder, CRAF and the owner's framework (B2); customer logins; per-customer permissions; drag-and-drop; customer deletion; assessment sign-off workflow.

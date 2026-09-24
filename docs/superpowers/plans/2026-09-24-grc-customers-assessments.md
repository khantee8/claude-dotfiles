# GRC Customers, Folders and Assessment History (B1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace "one organisation per user" with customers → free folder tree → many ISO 27001 / NIST CSF 2.0 assessments (one per fiscal year), with copy-from-previous and year-over-year comparison, migrating production data without loss. Release cyber v1.3.0.

**Architecture:** New `customer`, `folder`, `assessment` tables; ISO/CSF score tables re-keyed by `assessmentId`; risks and risk methodology re-keyed by `customerId`. Pure units (tree, copy plans, comparisons) are tested without a DB. Existing ISO and CSF pages move under `/grc/a/[assessmentId]/…` unchanged in behaviour; a customer workspace at `/grc/c/[customerId]` holds the folder tree, assessments, risks and settings. A committed SQL script migrates production in one transaction with count assertions, after a Neon branch backup.

**Tech Stack:** Next.js 16 App Router, React 19, Drizzle + Neon, Vitest, Tailwind v4.

**Spec:** `/project/docs/superpowers/specs/2026-09-24-grc-customers-assessments-design.md`

**Repo:** `/project/src/cyber.nanoteofficial.me` (worktree created by the controller). Read `CLAUDE.md` first.

## Global Constraints

- Every approved user sees and edits every customer (no per-customer ACL). Every server action and route handler starts with the approved-session check (`getApprovedViewer()` / `requireApproved()`), then loads its target by id and 404s/401s if missing.
- Frameworks in B1: `'iso27001' | 'nist-csf-2'`. `assessment.framework` is `text` so B2 can add more.
- Folder depth ≤ 8; folder moves must not create cycles; folders delete only when empty; customers archive, never delete; assessment delete requires typing its title.
- Copy-from-previous: ISO copies status, justification, owner, evidenceUrls. CSF copies current, target, inScope, owner, notes, evidenceUrls, and csf_profile; it resets testingStatus → 'not_started', examined/interviewed/tested → false, observedAt → null.
- Production migration: Neon branch backup first; one transaction; asserts counts before COMMIT (production today: 1 organisation, 93 control_status, 106 csf_score, 1 csf_profile, 12 risks, 1 risk_methodology).
- Existing behaviour of every ISO and CSF page is unchanged apart from scoping and URLs.
- EN + TH for every new UI string (`src/lib/i18n.ts`). No emoji, no `dangerouslySetInnerHTML`. App code uses `getDb()`. Validation via `src/lib/validate.ts` (no zod).
- Client components never import runtime values from `src/lib/grc/nist-csf-2/catalogue.ts` or `score.ts` (use `scale.ts`, or props from the server).
- Gate: `DATABASE_URL="" sh -c 'npm run build && npx tsc --noEmit && npm run lint && npm test'` (build first: it generates `PageProps` types). The main checkout's `.env.local` holds the real Neon URL; worktrees have none. Never use a production URL except in the release task.
- Local DB: Docker `cyber-pg` (postgres/pg, db `cyber`, port 55432) + `cyber-neon-proxy` (4444). Dev: `DATABASE_URL=postgres://postgres:pg@cyber-pg:5432/cyber NEON_LOCAL_PROXY=http://localhost:4444/sql AUTH_SECRET=dev ALLOWED_EMAILS=<email> npm run dev -- -p <port>`.
- Commits: `feat(grc): …` / `fix(grc): …`, ending with `Co-Authored-By: <authoring model> <noreply@anthropic.com>`.

---

### Task 1: Pure logic — folder tree, copy plans, comparisons

**Files:**
- Create: `src/lib/grc/tree.ts`, `src/lib/grc/tree.test.ts`
- Create: `src/lib/grc/copy.ts`, `src/lib/grc/copy.test.ts`
- Create: `src/lib/grc/compare.ts`, `src/lib/grc/compare.test.ts`

**Interfaces (produces):**
```ts
// tree.ts
export const MAX_FOLDER_DEPTH = 8;
export interface FolderRow { id: string; parentId: string | null; name: string; sortOrder: number }
export interface FolderNode extends FolderRow { children: FolderNode[]; depth: number }  // depth 1 = top level
export function buildTree(rows: FolderRow[]): FolderNode[];                 // sorted by sortOrder, then name; orphans (unknown parent) become top level
export function ancestorsOf(rows: FolderRow[], id: string): FolderRow[];     // root-first path excluding the folder itself
export function canMove(rows: FolderRow[], id: string, newParentId: string | null): { ok: true } | { ok: false; reason: 'cycle' | 'depth' | 'missing' };
// copy.ts
export interface IsoStatusCopy { controlId: string; status: ControlStatusValue; justification: string | null; owner: string | null; evidenceUrls: string[] }
export interface CsfScoreCopy { subcategoryId: string; current: number | null; target: number | null; inScope: boolean; owner: string | null; notes: string | null; evidenceUrls: string[];
  testingStatus: TestingStatus; examined: boolean; interviewed: boolean; tested: boolean; observedAt: string | null }
export function planIsoCopy(rows: IsoStatusCopy[]): IsoStatusCopy[];        // identity copy (new arrays)
export function planCsfCopy(rows: CsfScoreCopy[]): CsfScoreCopy[];           // copies, resetting fieldwork fields
// compare.ts
export interface IsoCompare { a: Compliance; b: Compliance; byTheme: Record<Theme, { a: number; b: number; delta: number }>;
  transitions: { controlId: string; from: ControlStatusValue; to: ControlStatusValue; direction: 'improved' | 'regressed' | 'changed' }[];
  counts: { improved: number; regressed: number; unchanged: number } }
export function compareIso(a: StatusRow[], b: StatusRow[]): IsoCompare;
export interface CsfCompare { byFunction: { fn: CsfFunctionId; a: CsfSummary; b: CsfSummary }[];
  changes: { id: string; aGap: number | null; bGap: number | null; kind: 'closed' | 'opened' | 'changed' }[] }
export function compareCsf(a: CsfScoreRow[], b: CsfScoreRow[]): CsfCompare;
```
Consumes: `Compliance`, `StatusRow`, `compliance`, `complianceByTheme` from `src/lib/grc/iso27001/score.ts`; `ISO27001_CONTROLS` from its catalogue; `ControlStatusValue`, `Theme` from `src/lib/grc/types.ts`; `summary`, `gap`, `CsfSummary` from `src/lib/grc/nist-csf-2/score.ts`; `CSF_FUNCTIONS`, `CSF_SUBCATEGORIES`; `CsfFunctionId`, `CsfScoreRow`, `TestingStatus` from nist-csf-2/types.

Status order for ISO direction (`not_applicable` is excluded from direction: moving to/from N/A is `changed`): `not_started` < `partial` < `implemented`.

CSF change kinds (only subcategories in scope in both): `closed` = aGap > 0 and bGap === 0; `opened` = (aGap === 0 or null) and bGap > 0; `changed` = both > 0 and different. Unchanged ones are omitted.

- [ ] **Step 1: Write the failing tests**

`tree.test.ts`:
```ts
import { describe, expect, it } from 'vitest';
import { ancestorsOf, buildTree, canMove, MAX_FOLDER_DEPTH, type FolderRow } from './tree';

const f = (id: string, parentId: string | null, name = id, sortOrder = 0): FolderRow => ({ id, parentId, name, sortOrder });

describe('buildTree', () => {
  it('nests children, sorts by sortOrder then name, and sets depth', () => {
    const t = buildTree([f('b', null, 'FY2027', 0), f('a', null, 'FY2026', 0), f('c', 'a', 'Head office'), f('d', 'c', 'IT')]);
    expect(t.map((n) => n.name)).toEqual(['FY2026', 'FY2027']);
    expect(t[0].children[0].name).toBe('Head office');
    expect(t[0].children[0].children[0].depth).toBe(3);
  });
  it('treats folders with an unknown parent as top level', () => {
    expect(buildTree([f('x', 'gone')]).map((n) => n.id)).toEqual(['x']);
  });
});

describe('ancestorsOf', () => {
  it('returns the root-first path excluding the folder', () => {
    const rows = [f('a', null), f('b', 'a'), f('c', 'b')];
    expect(ancestorsOf(rows, 'c').map((r) => r.id)).toEqual(['a', 'b']);
    expect(ancestorsOf(rows, 'a')).toEqual([]);
  });
});

describe('canMove', () => {
  const rows = [f('a', null), f('b', 'a'), f('c', 'b')];
  it('allows moving to root or to an unrelated folder', () => {
    expect(canMove(rows, 'c', null)).toEqual({ ok: true });
    expect(canMove([...rows, f('z', null)], 'b', 'z')).toEqual({ ok: true });
  });
  it('rejects moving a folder into itself or its descendant', () => {
    expect(canMove(rows, 'a', 'a')).toEqual({ ok: false, reason: 'cycle' });
    expect(canMove(rows, 'a', 'c')).toEqual({ ok: false, reason: 'cycle' });
  });
  it('rejects unknown ids', () => {
    expect(canMove(rows, 'nope', null)).toEqual({ ok: false, reason: 'missing' });
    expect(canMove(rows, 'a', 'nope')).toEqual({ ok: false, reason: 'missing' });
  });
  it('rejects a move that makes the subtree deeper than the limit', () => {
    const chain: FolderRow[] = Array.from({ length: MAX_FOLDER_DEPTH }, (_, i) => f(`n${i}`, i ? `n${i - 1}` : null));
    const sub = [f('s0', null), f('s1', 's0')];              // a 2-level subtree
    expect(canMove([...chain, ...sub], 's0', `n${MAX_FOLDER_DEPTH - 2}`)).toEqual({ ok: false, reason: 'depth' });
    expect(canMove([...chain, ...sub], 's0', `n${MAX_FOLDER_DEPTH - 3}`)).toEqual({ ok: true });
  });
});
```

`copy.test.ts`:
```ts
import { describe, expect, it } from 'vitest';
import { planCsfCopy, planIsoCopy } from './copy';

describe('planIsoCopy', () => {
  it('copies every field into new objects', () => {
    const src = [{ controlId: '5.1', status: 'partial' as const, justification: 'j', owner: 'CISO', evidenceUrls: ['https://x'] }];
    const out = planIsoCopy(src);
    expect(out).toEqual(src);
    expect(out[0]).not.toBe(src[0]);
    expect(out[0].evidenceUrls).not.toBe(src[0].evidenceUrls);
  });
});

describe('planCsfCopy', () => {
  it('keeps scores, scope, owner, notes and evidence; resets fieldwork', () => {
    const [r] = planCsfCopy([{ subcategoryId: 'GV.OC-01', current: 4, target: 6, inScope: false, owner: 'CISO', notes: 'n', evidenceUrls: ['https://e'],
      testingStatus: 'complete', examined: true, interviewed: true, tested: true, observedAt: '2026-08-01' }]);
    expect(r).toEqual({ subcategoryId: 'GV.OC-01', current: 4, target: 6, inScope: false, owner: 'CISO', notes: 'n', evidenceUrls: ['https://e'],
      testingStatus: 'not_started', examined: false, interviewed: false, tested: false, observedAt: null });
  });
});
```

`compare.test.ts`:
```ts
import { describe, expect, it } from 'vitest';
import { compareCsf, compareIso } from './compare';
import type { StatusRow } from './iso27001/score';

const s = (controlId: string, status: StatusRow['status']): StatusRow => ({ controlId, status, justification: null, owner: null });

describe('compareIso', () => {
  it('classifies transitions and computes compliance for both sides', () => {
    const r = compareIso([s('5.1', 'partial'), s('5.2', 'implemented'), s('5.3', 'not_started'), s('5.4', 'implemented')],
                         [s('5.1', 'implemented'), s('5.2', 'partial'), s('5.3', 'not_applicable'), s('5.4', 'implemented')]);
    expect(r.transitions).toEqual([
      { controlId: '5.1', from: 'partial', to: 'implemented', direction: 'improved' },
      { controlId: '5.2', from: 'implemented', to: 'partial', direction: 'regressed' },
      { controlId: '5.3', from: 'not_started', to: 'not_applicable', direction: 'changed' },
    ]);
    expect(r.counts).toEqual({ improved: 1, regressed: 1, unchanged: 90 });
    expect(r.b.notApplicable).toBe(1);
    expect(r.byTheme.organisational.delta).toBeCloseTo(r.byTheme.organisational.b - r.byTheme.organisational.a);
  });
  it('treats a missing row as not_started', () => {
    const r = compareIso([], [s('8.1', 'implemented')]);
    expect(r.transitions[0]).toEqual({ controlId: '8.1', from: 'not_started', to: 'implemented', direction: 'improved' });
  });
});

describe('compareCsf', () => {
  const row = (subcategoryId: string, current: number | null, target: number | null, inScope = true) => ({ subcategoryId, current, target, inScope });
  it('finds closed, opened and changed gaps; skips unchanged and out-of-scope', () => {
    const r = compareCsf(
      [row('GV.OC-01', 3, 6), row('GV.OC-02', 6, 6), row('GV.OC-03', 2, 6), row('GV.OC-04', 4, 6), row('GV.OC-05', 1, 6, false)],
      [row('GV.OC-01', 6, 6), row('GV.OC-02', 5, 6), row('GV.OC-03', 4, 6), row('GV.OC-04', 4, 6), row('GV.OC-05', 1, 6, false)],
    );
    expect(r.changes).toEqual([
      { id: 'GV.OC-01', aGap: 3, bGap: 0, kind: 'closed' },
      { id: 'GV.OC-02', aGap: 0, bGap: 1, kind: 'opened' },
      { id: 'GV.OC-03', aGap: 4, bGap: 2, kind: 'changed' },
    ]);
    expect(r.byFunction.map((x) => x.fn)).toEqual(['GV', 'ID', 'PR', 'DE', 'RS', 'RC']);
    expect(r.byFunction[0].b.avgCurrent).not.toBeNull();
  });
});
```

- [ ] **Step 2:** Run `npx vitest run src/lib/grc/tree.test.ts src/lib/grc/copy.test.ts src/lib/grc/compare.test.ts` → FAIL (modules missing).

- [ ] **Step 3: Implement**

`tree.ts`:
```ts
export const MAX_FOLDER_DEPTH = 8;
export interface FolderRow { id: string; parentId: string | null; name: string; sortOrder: number }
export interface FolderNode extends FolderRow { children: FolderNode[]; depth: number }

const byOrder = (a: FolderRow, b: FolderRow) => a.sortOrder - b.sortOrder || a.name.localeCompare(b.name);

export function buildTree(rows: FolderRow[]): FolderNode[] {
  const ids = new Set(rows.map((r) => r.id));
  const kids = new Map<string | null, FolderRow[]>();
  for (const r of rows) {
    const p = r.parentId && ids.has(r.parentId) ? r.parentId : null;
    kids.set(p, [...(kids.get(p) ?? []), r]);
  }
  const make = (parent: string | null, depth: number): FolderNode[] =>
    (kids.get(parent) ?? []).sort(byOrder).map((r) => ({ ...r, depth, children: make(r.id, depth + 1) }));
  return make(null, 1);
}

export function ancestorsOf(rows: FolderRow[], id: string): FolderRow[] {
  const byId = new Map(rows.map((r) => [r.id, r]));
  const out: FolderRow[] = [];
  let cur = byId.get(id)?.parentId ?? null;
  const seen = new Set<string>();
  while (cur && byId.has(cur) && !seen.has(cur)) {
    seen.add(cur);
    out.unshift(byId.get(cur)!);
    cur = byId.get(cur)!.parentId;
  }
  return out;
}

function subtreeHeight(rows: FolderRow[], id: string): number {
  const children = rows.filter((r) => r.parentId === id);
  return 1 + Math.max(0, ...children.map((c) => subtreeHeight(rows, c.id)));
}

export function canMove(rows: FolderRow[], id: string, newParentId: string | null): { ok: true } | { ok: false; reason: 'cycle' | 'depth' | 'missing' } {
  const ids = new Set(rows.map((r) => r.id));
  if (!ids.has(id) || (newParentId !== null && !ids.has(newParentId))) return { ok: false, reason: 'missing' };
  if (newParentId === id || (newParentId !== null && ancestorsOf(rows, newParentId).some((a) => a.id === id))) return { ok: false, reason: 'cycle' };
  const parentDepth = newParentId === null ? 0 : ancestorsOf(rows, newParentId).length + 1;
  if (parentDepth + subtreeHeight(rows, id) > MAX_FOLDER_DEPTH) return { ok: false, reason: 'depth' };
  return { ok: true };
}
```

`copy.ts`:
```ts
import type { ControlStatusValue } from './types';
import type { TestingStatus } from './nist-csf-2/types';

export interface IsoStatusCopy { controlId: string; status: ControlStatusValue; justification: string | null; owner: string | null; evidenceUrls: string[] }
export interface CsfScoreCopy {
  subcategoryId: string; current: number | null; target: number | null; inScope: boolean; owner: string | null; notes: string | null; evidenceUrls: string[];
  testingStatus: TestingStatus; examined: boolean; interviewed: boolean; tested: boolean; observedAt: string | null;
}

/** ISO carries over as the new year's baseline, unchanged. */
export function planIsoCopy(rows: IsoStatusCopy[]): IsoStatusCopy[] {
  return rows.map((r) => ({ ...r, evidenceUrls: [...r.evidenceUrls] }));
}

/** CSF carries over scores and context; fieldwork belongs to the new year and is reset. */
export function planCsfCopy(rows: CsfScoreCopy[]): CsfScoreCopy[] {
  return rows.map((r) => ({
    ...r, evidenceUrls: [...r.evidenceUrls],
    testingStatus: 'not_started', examined: false, interviewed: false, tested: false, observedAt: null,
  }));
}
```

`compare.ts`:
```ts
import { ISO27001_CONTROLS } from './iso27001/catalogue';
import { compliance, complianceByTheme, type Compliance, type StatusRow } from './iso27001/score';
import type { ControlStatusValue, Theme } from './types';
import { CSF_FUNCTIONS, CSF_SUBCATEGORIES } from './nist-csf-2/catalogue';
import { gap, summary, type CsfSummary } from './nist-csf-2/score';
import type { CsfFunctionId, CsfScoreRow } from './nist-csf-2/types';

const RANK: Record<Exclude<ControlStatusValue, 'not_applicable'>, number> = { not_started: 0, partial: 1, implemented: 2 };

export interface IsoCompare {
  a: Compliance; b: Compliance;
  byTheme: Record<Theme, { a: number; b: number; delta: number }>;
  transitions: { controlId: string; from: ControlStatusValue; to: ControlStatusValue; direction: 'improved' | 'regressed' | 'changed' }[];
  counts: { improved: number; regressed: number; unchanged: number };
}

export function compareIso(a: StatusRow[], b: StatusRow[]): IsoCompare {
  const am = new Map(a.map((r) => [r.controlId, r.status]));
  const bm = new Map(b.map((r) => [r.controlId, r.status]));
  const transitions: IsoCompare['transitions'] = [];
  let unchanged = 0;
  for (const c of ISO27001_CONTROLS) {
    const from = am.get(c.id) ?? 'not_started';
    const to = bm.get(c.id) ?? 'not_started';
    if (from === to) { unchanged++; continue; }
    const direction = from === 'not_applicable' || to === 'not_applicable' ? 'changed' : RANK[to] > RANK[from] ? 'improved' : 'regressed';
    transitions.push({ controlId: c.id, from, to, direction });
  }
  const ta = complianceByTheme(a, ISO27001_CONTROLS);
  const tb = complianceByTheme(b, ISO27001_CONTROLS);
  const byTheme = Object.fromEntries((Object.keys(ta) as Theme[]).map((t) => [t, { a: ta[t].pct, b: tb[t].pct, delta: tb[t].pct - ta[t].pct }])) as IsoCompare['byTheme'];
  return {
    a: compliance(a, ISO27001_CONTROLS), b: compliance(b, ISO27001_CONTROLS), byTheme, transitions,
    counts: { improved: transitions.filter((t) => t.direction === 'improved').length, regressed: transitions.filter((t) => t.direction === 'regressed').length, unchanged },
  };
}

export interface CsfCompare {
  byFunction: { fn: CsfFunctionId; a: CsfSummary; b: CsfSummary }[];
  changes: { id: string; aGap: number | null; bGap: number | null; kind: 'closed' | 'opened' | 'changed' }[];
}

export function compareCsf(a: CsfScoreRow[], b: CsfScoreRow[]): CsfCompare {
  const byFunction = CSF_FUNCTIONS.map((f) => {
    const ids = CSF_SUBCATEGORIES.filter((s) => s.fn === f.id).map((s) => s.id);
    return { fn: f.id, a: summary(a, ids), b: summary(b, ids) };
  });
  const am = new Map(a.map((r) => [r.subcategoryId, r]));
  const bm = new Map(b.map((r) => [r.subcategoryId, r]));
  const changes: CsfCompare['changes'] = [];
  for (const s of CSF_SUBCATEGORIES) {
    const ra = am.get(s.id); const rb = bm.get(s.id);
    if (ra?.inScope === false || rb?.inScope === false) continue;
    const aGap = ra ? gap(ra) : null; const bGap = rb ? gap(rb) : null;
    if (aGap !== null && aGap > 0 && bGap === 0) changes.push({ id: s.id, aGap, bGap, kind: 'closed' });
    else if ((aGap === 0 || aGap === null) && bGap !== null && bGap > 0) changes.push({ id: s.id, aGap, bGap, kind: 'opened' });
    else if (aGap !== null && bGap !== null && aGap > 0 && bGap > 0 && aGap !== bGap) changes.push({ id: s.id, aGap, bGap, kind: 'changed' });
  }
  return { byFunction, changes };
}
```

- [ ] **Step 4:** Run the three test files → PASS; `npx vitest run` → all pass; `npx tsc --noEmit` clean (run `DATABASE_URL="" npm run build` first if PageProps types are missing).
- [ ] **Step 5:** Commit `feat(grc): pure folder tree, copy plans and year-over-year comparison`.

---

### Task 2: Schema and the data migration (tested locally)

**Files:**
- Modify: `src/db/schema.ts` (GRC section)
- Create: `scripts/migrate-v1.3.sql`
- Create: `scripts/verify-migration-v1.3.sh`

**Interfaces (produces):**
```ts
export const customers;   // 'customer'
export const folders;     // 'folder'
export const assessments; // 'assessment'
export type Customer = typeof customers.$inferSelect;
export type Folder = typeof folders.$inferSelect;
export type Assessment = typeof assessments.$inferSelect;
export const FRAMEWORK_IDS = ['iso27001', 'nist-csf-2'] as const; export type FrameworkId = (typeof FRAMEWORK_IDS)[number];
export const ASSESSMENT_STATUSES = ['draft', 'in_progress', 'complete', 'archived'] as const;
// changed: controlStatuses (assessmentId, controlId PK; no organisationId, no framework)
//          csfScores (assessmentId, subcategoryId PK), csfProfiles (assessmentId PK)
//          risks (customerId; unique customerId+ref), riskMethodologies (customerId PK)
// removed: organisations, type Organisation
```

- [ ] **Step 1: Schema.** In `src/db/schema.ts` replace the GRC section with:

```ts
// ── GRC ─────────────────────────────────────────────────────
export const FRAMEWORK_IDS = ['iso27001', 'nist-csf-2'] as const;
export type FrameworkId = (typeof FRAMEWORK_IDS)[number];
export const ASSESSMENT_STATUSES = ['draft', 'in_progress', 'complete', 'archived'] as const;
export const SIZE_BANDS = ['1-10', '11-50', '51-250', '251-1000', '1000+'] as const;

export const customers = pgTable('customer', {
  id: text('id').primaryKey().$defaultFn(() => crypto.randomUUID()),
  name: text('name').notNull(),
  industry: text('industry'),
  sizeBand: text('sizeBand', { enum: SIZE_BANDS }),
  notes: text('notes'),
  createdBy: text('createdBy').references(() => users.id, { onDelete: 'set null' }),
  createdAt: timestamp('createdAt', { mode: 'date' }).notNull().defaultNow(),
  archivedAt: timestamp('archivedAt', { mode: 'date' }),
});

export const folders = pgTable('folder', {
  id: text('id').primaryKey().$defaultFn(() => crypto.randomUUID()),
  customerId: text('customerId').notNull().references(() => customers.id, { onDelete: 'cascade' }),
  parentId: text('parentId').references((): AnyPgColumn => folders.id, { onDelete: 'cascade' }),
  name: text('name').notNull(),
  sortOrder: integer('sortOrder').notNull().default(0),
  createdAt: timestamp('createdAt', { mode: 'date' }).notNull().defaultNow(),
}, (t) => [index('folder_customer_parent').on(t.customerId, t.parentId)]);

export const assessments = pgTable('assessment', {
  id: text('id').primaryKey().$defaultFn(() => crypto.randomUUID()),
  customerId: text('customerId').notNull().references(() => customers.id, { onDelete: 'cascade' }),
  folderId: text('folderId').references(() => folders.id, { onDelete: 'set null' }),
  framework: text('framework').notNull(),
  title: text('title').notNull(),
  fiscalYear: integer('fiscalYear'),
  periodStart: date('periodStart', { mode: 'string' }),
  periodEnd: date('periodEnd', { mode: 'string' }),
  status: text('status', { enum: ASSESSMENT_STATUSES }).notNull().default('draft'),
  scope: text('scope'),
  lead: text('lead'),
  basedOnId: text('basedOnId').references((): AnyPgColumn => assessments.id, { onDelete: 'set null' }),
  createdBy: text('createdBy').references(() => users.id, { onDelete: 'set null' }),
  createdAt: timestamp('createdAt', { mode: 'date' }).notNull().defaultNow(),
  updatedAt: timestamp('updatedAt', { mode: 'date' }).notNull().defaultNow(),
}, (t) => [index('assessment_customer_folder').on(t.customerId, t.folderId)]);

export const riskMethodologies = pgTable('risk_methodology', {
  customerId: text('customerId').primaryKey().references(() => customers.id, { onDelete: 'cascade' }),
  lowMax: integer('lowMax').notNull().default(4),
  mediumMax: integer('mediumMax').notNull().default(9),
  highMax: integer('highMax').notNull().default(15),
  acceptMax: integer('acceptMax').notNull().default(4),
});

export const controlStatuses = pgTable('control_status', {
  assessmentId: text('assessmentId').notNull().references(() => assessments.id, { onDelete: 'cascade' }),
  controlId: text('controlId').notNull(),
  status: text('status', { enum: ['not_started', 'partial', 'implemented', 'not_applicable'] }).notNull().default('not_started'),
  justification: text('justification'),
  owner: text('owner'),
  evidenceUrls: jsonb('evidenceUrls').$type<string[]>().notNull().default([]),
  updatedAt: timestamp('updatedAt', { mode: 'date' }).notNull().defaultNow(),
}, (t) => [primaryKey({ columns: [t.assessmentId, t.controlId] })]);
```
`risks`: replace `organisationId` with `customerId: text('customerId').notNull().references(() => customers.id, { onDelete: 'cascade' })`, keep `framework` (where the risk was created), and change the index to `uniqueIndex('risk_customer_ref').on(t.customerId, t.ref)`.
`csfScores`: replace `organisationId` with `assessmentId` (references `assessments.id`, cascade); PK `[t.assessmentId, t.subcategoryId]`.
`csfProfiles`: `assessmentId: text('assessmentId').primaryKey().references(() => assessments.id, { onDelete: 'cascade' })`.
Delete `organisations` and `type Organisation`; add the three new `export type`s. Import `index` and `type AnyPgColumn` from `drizzle-orm/pg-core`.

The app will not compile until Task 3 updates callers; that is expected — commit Task 2 and 3 together only if the reviewer prefers, otherwise commit Task 2 with `// @ts-expect-error`-free code by running only the migration verification (not the app gate) in this task.

- [ ] **Step 2: Migration SQL** — `scripts/migrate-v1.3.sql` (one transaction; idempotence not required; run exactly once per database):

```sql
-- cyber v1.3.0: organisation → customer / folder / assessment. One transaction; aborts on any count mismatch.
BEGIN;

CREATE TEMP TABLE _before AS SELECT
  (SELECT count(*) FROM organisation) AS orgs,
  (SELECT count(*) FROM control_status) AS statuses,
  (SELECT count(*) FROM csf_score) AS scores,
  (SELECT count(*) FROM csf_profile) AS profiles,
  (SELECT count(*) FROM risk) AS risks,
  (SELECT count(*) FROM risk_methodology) AS methods;

CREATE TABLE customer (
  "id" text PRIMARY KEY NOT NULL, "name" text NOT NULL, "industry" text, "sizeBand" text, "notes" text,
  "createdBy" text REFERENCES "user"("id") ON DELETE SET NULL,
  "createdAt" timestamp DEFAULT now() NOT NULL, "archivedAt" timestamp
);
CREATE TABLE folder (
  "id" text PRIMARY KEY NOT NULL, "customerId" text NOT NULL REFERENCES customer("id") ON DELETE CASCADE,
  "parentId" text REFERENCES folder("id") ON DELETE CASCADE, "name" text NOT NULL,
  "sortOrder" integer DEFAULT 0 NOT NULL, "createdAt" timestamp DEFAULT now() NOT NULL
);
CREATE INDEX folder_customer_parent ON folder ("customerId", "parentId");
CREATE TABLE assessment (
  "id" text PRIMARY KEY NOT NULL, "customerId" text NOT NULL REFERENCES customer("id") ON DELETE CASCADE,
  "folderId" text REFERENCES folder("id") ON DELETE SET NULL, "framework" text NOT NULL, "title" text NOT NULL,
  "fiscalYear" integer, "periodStart" date, "periodEnd" date, "status" text DEFAULT 'draft' NOT NULL,
  "scope" text, "lead" text, "basedOnId" text REFERENCES assessment("id") ON DELETE SET NULL,
  "createdBy" text REFERENCES "user"("id") ON DELETE SET NULL,
  "createdAt" timestamp DEFAULT now() NOT NULL, "updatedAt" timestamp DEFAULT now() NOT NULL
);
CREATE INDEX assessment_customer_folder ON assessment ("customerId", "folderId");

-- 1. organisations become customers (same id), each with a FY2026 folder
INSERT INTO customer ("id", "name", "industry", "sizeBand", "createdBy", "createdAt")
  SELECT "id", "name", "industry", "sizeBand", "ownerId", "createdAt" FROM organisation;
INSERT INTO folder ("id", "customerId", "name") SELECT gen_random_uuid()::text, "id", 'FY2026' FROM organisation;

-- 2. one ISO and/or one CSF assessment per organisation that has data
INSERT INTO assessment ("id", "customerId", "folderId", "framework", "title", "fiscalYear", "status", "scope", "lead", "createdBy")
  SELECT gen_random_uuid()::text, o."id", f."id", 'iso27001', 'ISO 27001 — FY2026', 2026, 'in_progress', o."scope", o."ismsLead", o."ownerId"
  FROM organisation o JOIN folder f ON f."customerId" = o."id"
  WHERE EXISTS (SELECT 1 FROM control_status cs WHERE cs."organisationId" = o."id");
INSERT INTO assessment ("id", "customerId", "folderId", "framework", "title", "fiscalYear", "status", "scope", "lead", "createdBy")
  SELECT gen_random_uuid()::text, o."id", f."id", 'nist-csf-2', 'NIST CSF 2.0 — FY2026', 2026, 'in_progress',
         coalesce((SELECT p."scope" FROM csf_profile p WHERE p."organisationId" = o."id"), o."scope"), o."ismsLead", o."ownerId"
  FROM organisation o JOIN folder f ON f."customerId" = o."id"
  WHERE EXISTS (SELECT 1 FROM csf_score s WHERE s."organisationId" = o."id") OR EXISTS (SELECT 1 FROM csf_profile p WHERE p."organisationId" = o."id");

-- 3. control_status → assessment
ALTER TABLE control_status ADD COLUMN "assessmentId" text;
UPDATE control_status cs SET "assessmentId" = a."id" FROM assessment a WHERE a."customerId" = cs."organisationId" AND a."framework" = 'iso27001';
ALTER TABLE control_status DROP CONSTRAINT control_status_organisationId_framework_controlId_pk;
ALTER TABLE control_status DROP CONSTRAINT control_status_organisationId_organisation_id_fk;
ALTER TABLE control_status DROP COLUMN "organisationId", DROP COLUMN "framework";
ALTER TABLE control_status ALTER COLUMN "assessmentId" SET NOT NULL;
ALTER TABLE control_status ADD CONSTRAINT control_status_assessmentId_controlId_pk PRIMARY KEY ("assessmentId", "controlId");
ALTER TABLE control_status ADD CONSTRAINT control_status_assessmentId_assessment_id_fk FOREIGN KEY ("assessmentId") REFERENCES assessment("id") ON DELETE CASCADE;

-- 4. csf_score / csf_profile → assessment
ALTER TABLE csf_score ADD COLUMN "assessmentId" text;
UPDATE csf_score s SET "assessmentId" = a."id" FROM assessment a WHERE a."customerId" = s."organisationId" AND a."framework" = 'nist-csf-2';
ALTER TABLE csf_score DROP CONSTRAINT csf_score_organisationId_subcategoryId_pk;
ALTER TABLE csf_score DROP CONSTRAINT csf_score_organisationId_organisation_id_fk;
ALTER TABLE csf_score DROP COLUMN "organisationId";
ALTER TABLE csf_score ALTER COLUMN "assessmentId" SET NOT NULL;
ALTER TABLE csf_score ADD CONSTRAINT csf_score_assessmentId_subcategoryId_pk PRIMARY KEY ("assessmentId", "subcategoryId");
ALTER TABLE csf_score ADD CONSTRAINT csf_score_assessmentId_assessment_id_fk FOREIGN KEY ("assessmentId") REFERENCES assessment("id") ON DELETE CASCADE;

ALTER TABLE csf_profile ADD COLUMN "assessmentId" text;
UPDATE csf_profile p SET "assessmentId" = a."id" FROM assessment a WHERE a."customerId" = p."organisationId" AND a."framework" = 'nist-csf-2';
ALTER TABLE csf_profile DROP CONSTRAINT csf_profile_pkey;
ALTER TABLE csf_profile DROP CONSTRAINT csf_profile_organisationId_organisation_id_fk;
ALTER TABLE csf_profile DROP COLUMN "organisationId";
ALTER TABLE csf_profile ALTER COLUMN "assessmentId" SET NOT NULL;
ALTER TABLE csf_profile ADD PRIMARY KEY ("assessmentId");
ALTER TABLE csf_profile ADD CONSTRAINT csf_profile_assessmentId_assessment_id_fk FOREIGN KEY ("assessmentId") REFERENCES assessment("id") ON DELETE CASCADE;

-- 5. risk / risk_methodology → customer (customer ids equal organisation ids)
ALTER TABLE risk RENAME COLUMN "organisationId" TO "customerId";
ALTER TABLE risk DROP CONSTRAINT risk_organisationId_organisation_id_fk;
DROP INDEX risk_org_ref;
ALTER TABLE risk ADD CONSTRAINT risk_customerId_customer_id_fk FOREIGN KEY ("customerId") REFERENCES customer("id") ON DELETE CASCADE;
CREATE UNIQUE INDEX risk_customer_ref ON risk ("customerId", "ref");

ALTER TABLE risk_methodology RENAME COLUMN "organisationId" TO "customerId";
ALTER TABLE risk_methodology DROP CONSTRAINT risk_methodology_organisationId_organisation_id_fk;
ALTER TABLE risk_methodology ADD CONSTRAINT risk_methodology_customerId_customer_id_fk FOREIGN KEY ("customerId") REFERENCES customer("id") ON DELETE CASCADE;

-- 6. drop organisation
DROP TABLE organisation;

-- 7. assert nothing was lost
DO $$
DECLARE b _before%ROWTYPE;
BEGIN
  SELECT * INTO b FROM _before;
  IF (SELECT count(*) FROM customer) <> b.orgs THEN RAISE EXCEPTION 'customer count % <> %', (SELECT count(*) FROM customer), b.orgs; END IF;
  IF (SELECT count(*) FROM control_status) <> b.statuses THEN RAISE EXCEPTION 'control_status count changed'; END IF;
  IF (SELECT count(*) FROM csf_score) <> b.scores THEN RAISE EXCEPTION 'csf_score count changed'; END IF;
  IF (SELECT count(*) FROM csf_profile) <> b.profiles THEN RAISE EXCEPTION 'csf_profile count changed'; END IF;
  IF (SELECT count(*) FROM risk) <> b.risks THEN RAISE EXCEPTION 'risk count changed'; END IF;
  IF (SELECT count(*) FROM risk_methodology) <> b.methods THEN RAISE EXCEPTION 'risk_methodology count changed'; END IF;
  IF EXISTS (SELECT 1 FROM control_status WHERE "assessmentId" IS NULL) OR EXISTS (SELECT 1 FROM csf_score WHERE "assessmentId" IS NULL) THEN
    RAISE EXCEPTION 'unmapped score rows'; END IF;
END $$;

COMMIT;
```

The constraint names above are Drizzle's defaults. Before trusting them, check them on the local DB (`docker exec cyber-pg psql -U postgres -d cyber -c '\d control_status'` etc.) and adjust the script to the real names if any differ — the production DB was created by the same Drizzle version, so local names match production.

- [ ] **Step 3: Verification script** — `scripts/verify-migration-v1.3.sh` (local only; refuses unless the URL points at localhost/cyber-pg):

```bash
#!/usr/bin/env bash
# Local-only check of scripts/migrate-v1.3.sql: build a DB with the OLD schema + BankX demo, migrate it,
# compare row counts and values, and compare its structure with a DB built from the NEW schema.
set -euo pipefail
PG="docker exec -i cyber-pg psql -U postgres -v ON_ERROR_STOP=1 -q"
OLD_REF=${OLD_REF:-main}
TMP=$(mktemp -d)
for db in mig_old mig_new; do $PG -d postgres -c "DROP DATABASE IF EXISTS $db" -c "CREATE DATABASE $db"; done

# old schema + demo data
git show "$OLD_REF:src/db/schema.ts" > "$TMP/schema.ts"
( cd "$TMP" && ln -s "$OLDPWD/node_modules" node_modules )
npx drizzle-kit generate --schema "$TMP/schema.ts" --dialect postgresql --out "$TMP/old" --name old >/dev/null
sed 's/--> statement-breakpoint//' "$TMP"/old/*.sql | $PG -d mig_old
$PG -d mig_old -c "INSERT INTO \"user\" (id, email, \"approvedAt\") VALUES ('u1','owner@example.com', now()); INSERT INTO organisation (id, \"ownerId\", name) VALUES ('o1','u1','BankX');"
git show "$OLD_REF:scripts/seed-demo.ts" > "$TMP/seed-demo.ts"
npx tsx "$TMP/seed-demo.ts" --org BankX | $PG -d mig_old
$PG -d mig_old -At -c "select count(*) from control_status; select count(*) from csf_score; select count(*) from risk" > "$TMP/before.txt"
$PG -d mig_old -At -c "select \"controlId\"||':'||status from control_status order by 1" > "$TMP/iso_before.txt"
$PG -d mig_old -At -c "select \"subcategoryId\"||':'||coalesce(current::text,'')||':'||coalesce(target::text,'') from csf_score order by 1" > "$TMP/csf_before.txt"

# migrate
$PG -d mig_old < scripts/migrate-v1.3.sql
$PG -d mig_old -At -c "select count(*) from control_status; select count(*) from csf_score; select count(*) from risk" > "$TMP/after.txt"
diff "$TMP/before.txt" "$TMP/after.txt"
$PG -d mig_old -At -c "select \"controlId\"||':'||status from control_status order by 1" | diff "$TMP/iso_before.txt" -
$PG -d mig_old -At -c "select \"subcategoryId\"||':'||coalesce(current::text,'')||':'||coalesce(target::text,'') from csf_score order by 1" | diff "$TMP/csf_before.txt" -
$PG -d mig_old -At -c "select c.name, f.name, a.framework, a.title from customer c join folder f on f.\"customerId\"=c.id join assessment a on a.\"folderId\"=f.id order by a.framework"

# structure must equal a DB built from the NEW schema
npx drizzle-kit generate --schema src/db/schema.ts --dialect postgresql --out "$TMP/new" --name new >/dev/null
sed 's/--> statement-breakpoint//' "$TMP"/new/*.sql | $PG -d mig_new
dump() { docker exec cyber-pg pg_dump -U postgres --schema-only --no-owner --no-privileges "$1" | grep -vE '^(--|SET |SELECT pg_catalog)' | sed '/^$/d' | sort; }
diff <(dump mig_old) <(dump mig_new) && echo "STRUCTURE MATCHES"
echo "MIGRATION OK"
```
(If sorted line diffs flag only column *order* differences — e.g. `assessmentId` added last vs first — normalise by comparing `information_schema.columns` (table, column, type, nullable, default) and constraint definitions instead; the requirement is identical columns, types, nullability, defaults, PKs, FKs and indexes.)

- [ ] **Step 4: Run it**: `bash scripts/verify-migration-v1.3.sh` → `STRUCTURE MATCHES` and `MIGRATION OK`; paste the output. Fix the SQL until it passes. Drop `mig_old`/`mig_new` afterwards.
- [ ] **Step 5: Commit** `feat(grc): customer/folder/assessment schema and v1.3 data migration` (schema + both scripts). The app does not compile until Task 3; say so in the commit body.

---

### Task 3: i18n keys

**Files:** Modify `src/lib/i18n.ts` (add before `} as const;`; keep existing `grc.org.*` keys — they are reused for customer fields).

- [ ] **Step 1:** Add:

```ts
  // GRC customers, folders, assessments
  'grc.customers.title':     { en: 'Customers', th: 'ลูกค้า' },
  'grc.customers.lede':      { en: 'Every customer you assess, with its folders and assessments by fiscal year.', th: 'ลูกค้าทุกรายที่ประเมิน พร้อมโฟลเดอร์และการประเมินตามปีงบประมาณ' },
  'grc.customers.new':       { en: 'New customer', th: 'เพิ่มลูกค้า' },
  'grc.customers.search':    { en: 'Search customers', th: 'ค้นหาลูกค้า' },
  'grc.customers.none':      { en: 'No customers yet. Add the first one to start an assessment.', th: 'ยังไม่มีลูกค้า เพิ่มรายแรกเพื่อเริ่มการประเมิน' },
  'grc.customers.assessments': { en: '{n} assessments', th: '{n} การประเมิน' },
  'grc.customers.showArchived': { en: 'Show archived', th: 'แสดงที่เก็บถาวร' },
  'grc.customers.archived':  { en: 'Archived', th: 'เก็บถาวร' },
  'grc.customer.notes':      { en: 'Notes', th: 'บันทึก' },
  'grc.customer.archive':    { en: 'Archive customer', th: 'เก็บลูกค้าถาวร' },
  'grc.customer.unarchive':  { en: 'Restore customer', th: 'กู้คืนลูกค้า' },
  'grc.customer.archiveLede': { en: 'Archived customers are hidden from the list. Nothing is deleted.', th: 'ลูกค้าที่เก็บถาวรจะถูกซ่อนจากรายการ โดยไม่มีข้อมูลใดถูกลบ' },
  'grc.nav.workspace':       { en: 'Assessments', th: 'การประเมิน' },
  'grc.nav.compare':         { en: 'Compare', th: 'เปรียบเทียบ' },
  'grc.folders.title':       { en: 'Folders', th: 'โฟลเดอร์' },
  'grc.folders.all':         { en: 'All assessments', th: 'การประเมินทั้งหมด' },
  'grc.folders.root':        { en: 'Top level', th: 'ระดับบนสุด' },
  'grc.folders.new':         { en: 'New folder', th: 'โฟลเดอร์ใหม่' },
  'grc.folders.newSub':      { en: 'New sub-folder', th: 'โฟลเดอร์ย่อยใหม่' },
  'grc.folders.rename':      { en: 'Rename', th: 'เปลี่ยนชื่อ' },
  'grc.folders.move':        { en: 'Move to…', th: 'ย้ายไป…' },
  'grc.folders.delete':      { en: 'Delete folder', th: 'ลบโฟลเดอร์' },
  'grc.folders.notEmpty':    { en: 'Only empty folders can be deleted.', th: 'ลบได้เฉพาะโฟลเดอร์ที่ว่าง' },
  'grc.folders.cycle':       { en: 'A folder cannot move into itself or its own sub-folder.', th: 'ไม่สามารถย้ายโฟลเดอร์เข้าไปในตัวเองหรือโฟลเดอร์ย่อยของตัวเอง' },
  'grc.folders.depth':       { en: 'Folders can nest at most 8 levels deep.', th: 'โฟลเดอร์ซ้อนกันได้สูงสุด 8 ระดับ' },
  'grc.folders.name':        { en: 'Folder name', th: 'ชื่อโฟลเดอร์' },
  'grc.assessments.none':    { en: 'No assessments in this folder.', th: 'ไม่มีการประเมินในโฟลเดอร์นี้' },
  'grc.assessments.new':     { en: 'New assessment', th: 'การประเมินใหม่' },
  'grc.assessment.framework': { en: 'Framework', th: 'กรอบมาตรฐาน' },
  'grc.assessment.title':    { en: 'Title', th: 'ชื่อการประเมิน' },
  'grc.assessment.fiscalYear': { en: 'Fiscal year', th: 'ปีงบประมาณ' },
  'grc.assessment.period':   { en: 'Period', th: 'ช่วงเวลา' },
  'grc.assessment.folder':   { en: 'Folder', th: 'โฟลเดอร์' },
  'grc.assessment.status':   { en: 'Status', th: 'สถานะ' },
  'grc.assessment.status.draft':       { en: 'Draft', th: 'ร่าง' },
  'grc.assessment.status.in_progress': { en: 'In progress', th: 'กำลังดำเนินการ' },
  'grc.assessment.status.complete':    { en: 'Complete', th: 'เสร็จสิ้น' },
  'grc.assessment.status.archived':    { en: 'Archived', th: 'เก็บถาวร' },
  'grc.assessment.scope':    { en: 'Scope', th: 'ขอบเขต' },
  'grc.assessment.lead':     { en: 'Lead', th: 'ผู้รับผิดชอบหลัก' },
  'grc.assessment.start':    { en: 'Start', th: 'เริ่มจาก' },
  'grc.assessment.blank':    { en: 'Blank', th: 'ว่างเปล่า' },
  'grc.assessment.from':     { en: 'From {title}', th: 'จาก {title}' },
  'grc.assessment.basedOn':  { en: 'Started from {title}', th: 'เริ่มจาก {title}' },
  'grc.assessment.create':   { en: 'Create assessment', th: 'สร้างการประเมิน' },
  'grc.assessment.details':  { en: 'Assessment details', th: 'รายละเอียดการประเมิน' },
  'grc.assessment.delete':   { en: 'Delete assessment', th: 'ลบการประเมิน' },
  'grc.assessment.deleteLede': { en: 'Deletes this assessment and all its scores. Type its title to confirm.', th: 'ลบการประเมินนี้และคะแนนทั้งหมด พิมพ์ชื่อการประเมินเพื่อยืนยัน' },
  'grc.assessment.keyScore': { en: 'Score', th: 'คะแนน' },
  'grc.assessment.updated':  { en: 'Updated', th: 'อัปเดต' },
  'grc.compare.title':       { en: 'Compare assessments', th: 'เปรียบเทียบการประเมิน' },
  'grc.compare.lede':        { en: 'Two assessments of the same framework, side by side.', th: 'การประเมินสองชุดในกรอบมาตรฐานเดียวกัน แบบเทียบกัน' },
  'grc.compare.pickA':       { en: 'Earlier', th: 'ก่อนหน้า' },
  'grc.compare.pickB':       { en: 'Later', th: 'ล่าสุด' },
  'grc.compare.go':          { en: 'Compare', th: 'เปรียบเทียบ' },
  'grc.compare.sameFramework': { en: 'Choose two assessments of the same framework.', th: 'เลือกการประเมินสองชุดในกรอบมาตรฐานเดียวกัน' },
  'grc.compare.improved':    { en: 'Improved', th: 'ดีขึ้น' },
  'grc.compare.regressed':   { en: 'Regressed', th: 'แย่ลง' },
  'grc.compare.changed':     { en: 'Changed', th: 'เปลี่ยนแปลง' },
  'grc.compare.unchanged':   { en: 'Unchanged', th: 'ไม่เปลี่ยนแปลง' },
  'grc.compare.closed':      { en: 'Gap closed', th: 'ปิดช่องว่างแล้ว' },
  'grc.compare.opened':      { en: 'Gap opened', th: 'เกิดช่องว่างใหม่' },
  'grc.compare.gapChanged':  { en: 'Gap changed', th: 'ช่องว่างเปลี่ยนแปลง' },
  'grc.compare.none':        { en: 'No differences.', th: 'ไม่มีความแตกต่าง' },
```

- [ ] **Step 2:** `npx tsc --noEmit` passes for i18n.ts in isolation (the rest of the app may not compile until Task 5 — acceptable). Commit `feat(grc): EN/TH strings for customers, folders, assessments and compare`.

---

### Task 4: Queries and page loaders

**Files:**
- Modify: `src/lib/grc/queries.ts`
- Replace: `src/lib/grc/workspace.ts` (delete) and `src/lib/grc/nist-csf-2/workspace.ts` (delete) → create `src/lib/grc/context.ts`
- Modify: `src/server/actions/shared.ts`

**Interfaces (produces):**
```ts
// queries.ts (server-only). getViewer / getApprovedViewer / lookupUser unchanged. getOrgForUser removed.
export interface CustomerSummary extends Customer { assessmentCount: number; lastActivity: Date | null }
export async function listCustomers(opts?: { includeArchived?: boolean; q?: string }): Promise<CustomerSummary[]>;
export async function getCustomer(id: string): Promise<Customer | null>;
export async function getFolders(customerId: string): Promise<Folder[]>;
export async function listAssessments(customerId: string): Promise<Assessment[]>;          // newest updatedAt first
export async function getAssessment(id: string): Promise<Assessment | null>;
export async function getStatuses(assessmentId: string): Promise<StatusRow[]>;
export async function getStatusRows(assessmentId: string): Promise<ControlStatusRow[]>;
export async function getStatusRow(assessmentId: string, controlId: string): Promise<ControlStatusRow | null>;
export async function getRisks(customerId: string): Promise<Risk[]>;
export async function getRisk(customerId: string, id: string): Promise<Risk | null>;
export async function getMethodology(customerId: string): Promise<Methodology>;
export async function getCsfScores(assessmentId: string): Promise<CsfScore[]>;
export async function getCsfScore(assessmentId: string, subcategoryId: string): Promise<CsfScore | null>;
export async function getCsfProfile(assessmentId: string): Promise<CsfProfile | null>;
export function toScoreRows(rows: CsfScore[]): CsfScoreRow[];                              // unchanged
// context.ts (server-only) — page loaders
export const customerBase = (id: string) => `/grc/c/${id}`;
export const assessmentBase = (id: string) => `/grc/a/${id}`;
export async function loadViewer(): Promise<{ lang: Lang; viewer: Viewer }>;              // redirect('/signin') if no session, '/pending' if unapproved
export async function loadCustomer(customerId: string): Promise<{ lang: Lang; viewer: Viewer; customer: Customer; methodology: Methodology; base: string }>;  // notFound() if missing
export async function loadAssessment(assessmentId: string, framework?: FrameworkId): Promise<{ lang: Lang; viewer: Viewer; assessment: Assessment; customer: Customer; methodology: Methodology; folders: Folder[]; base: string; customerBase: string }>;  // notFound() if missing or framework mismatch
// shared.ts (server-only; for actions)
export async function requireApproved(): Promise<Viewer>;                                   // throws Error('Unauthorized')
export async function requireCustomer(customerId: unknown): Promise<{ viewer: Viewer; customer: Customer }>;          // ValidationError('customer not found')
export async function requireAssessment(assessmentId: unknown, framework?: FrameworkId): Promise<{ viewer: Viewer; customer: Customer; assessment: Assessment }>;
export function fail(err: unknown): ActionResult;                                           // unchanged
```

- [ ] **Step 1: queries.ts** — rewrite every function keyed by `orgId` to the new keys. `listCustomers` does one query: customers left-joined to a grouped subquery on assessment (`count(*)`, `max("updatedAt")`), filtered by `archivedAt IS NULL` unless `includeArchived`, and by `name ILIKE '%' || q || '%'` when `q` is non-empty (bind as a parameter — never interpolate), ordered by `lastActivity desc nulls last, name`.
- [ ] **Step 2: context.ts**

```ts
import 'server-only';
import { notFound, redirect } from 'next/navigation';
import { auth } from '@/auth';
import { getLang } from '@/lib/lang';
import type { FrameworkId } from '@/db/schema';
import { getApprovedViewer, getAssessment, getCustomer, getFolders, getMethodology } from './queries';

export const customerBase = (id: string) => `/grc/c/${id}`;
export const assessmentBase = (id: string) => `/grc/a/${id}`;

/** Mirrors (app)/layout.tsx: no session → /signin, signed in but not approved → /pending. */
export async function loadViewer() {
  const [lang, session, viewer] = await Promise.all([getLang(), auth(), getApprovedViewer()]);
  if (!session?.user?.email) redirect('/signin');
  if (!viewer) redirect('/pending');
  return { lang, viewer };
}

export async function loadCustomer(customerId: string) {
  const { lang, viewer } = await loadViewer();
  const customer = await getCustomer(customerId);
  if (!customer) notFound();
  const methodology = await getMethodology(customer.id);
  return { lang, viewer, customer, methodology, base: customerBase(customer.id) };
}

export async function loadAssessment(assessmentId: string, framework?: FrameworkId) {
  const { lang, viewer } = await loadViewer();
  const assessment = await getAssessment(assessmentId);
  if (!assessment || (framework && assessment.framework !== framework)) notFound();
  const [customer, folders] = await Promise.all([getCustomer(assessment.customerId), getFolders(assessment.customerId)]);
  if (!customer) notFound();
  const methodology = await getMethodology(customer.id);
  return { lang, viewer, assessment, customer, methodology, folders, base: assessmentBase(assessment.id), customerBase: customerBase(customer.id) };
}
```

- [ ] **Step 3: shared.ts** — replace `requireOrg` with `requireApproved`, `requireCustomer`, `requireAssessment` (each validates the id is a non-empty string ≤ 64 chars, loads the row, throws `ValidationError('… not found')` when missing; `requireAssessment` also throws when `framework` is given and differs).
- [ ] **Step 4:** `npx tsc --noEmit` on these three files only is not possible in isolation; proceed to Task 5 in the same worktree before running the full gate. Commit `feat(grc): customer/assessment queries and page loaders` (commit body: app compiles again after Task 6).

---

### Task 5: Server actions and the components that call them

**Files:**
- Modify: `src/server/actions/grc.ts`, `src/server/actions/csf.ts`
- Modify components: `StatusSelect.tsx`, `ControlDetailForm.tsx`, `RiskForm.tsx`, `DeleteRiskButton.tsx`, `MethodologyForm.tsx` (all in `src/components/grc/`), and `csf/ScorePicker.tsx`, `csf/BulkTarget.tsx`, `csf/CsfScoreForm.tsx`, `csf/SuggestionPanel.tsx`, `csf/PrefillButton.tsx`, `csf/CsfProfileForm.tsx`
- Delete: `src/components/grc/OrgForm.tsx`, `src/components/grc/ResetWorkspace.tsx` (replaced in Task 7)

**Interfaces (produces)** — every action starts with `requireApproved`/`requireCustomer`/`requireAssessment`, validates with `src/lib/validate.ts`, then `revalidatePath('/grc', 'layout')`:
```ts
// grc.ts ('use server')
export async function createCustomer(prev, fd): Promise<ActionResult>;                 // fd: name, industry, sizeBand, notes → redirect(`/grc/c/${id}`)
export async function updateCustomer(prev, fd): Promise<ActionResult>;                 // fd: customerId + same fields
export async function setCustomerArchived(customerId: string, archived: boolean): Promise<ActionResult>;
export async function createFolder(customerId: string, parentId: string | null, name: string): Promise<ActionResult & { id?: string }>;  // canMove-style depth check for the new position
export async function renameFolder(folderId: string, name: string): Promise<ActionResult>;
export async function moveFolder(folderId: string, newParentId: string | null): Promise<ActionResult>;   // uses canMove; messages 'cycle' | 'depth'
export async function deleteFolder(folderId: string): Promise<ActionResult>;                            // refuses when it has sub-folders or assessments
export async function createAssessment(prev, fd): Promise<ActionResult>;               // fd: customerId, framework, title, fiscalYear?, folderId?, basedOnId?, scope?, lead? → one transaction; redirect(`/grc/a/${id}`)
export async function updateAssessment(prev, fd): Promise<ActionResult>;               // fd: assessmentId, title, fiscalYear, periodStart, periodEnd, status, scope, lead, folderId
export async function deleteAssessment(assessmentId: string, confirmTitle: string): Promise<ActionResult>;  // exact title match → delete → redirect(`/grc/c/${customerId}`)
export interface ControlStatusInput { assessmentId: string; controlId: string; status: string; justification?: string | null; owner?: string | null; evidenceUrls?: string }
export async function setControlStatus(input: ControlStatusInput): Promise<ActionResult>;
export async function saveRisk(prev, fd): Promise<ActionResult>;                       // fd adds customerId; redirect(`/grc/c/${customerId}/risks/${id}`)
export async function deleteRisk(customerId: string, id: string): Promise<ActionResult>;   // redirect(`/grc/c/${customerId}/risks`)
export async function updateMethodology(prev, fd): Promise<ActionResult>;              // fd adds customerId
// removed: createOrganisation, updateOrganisation, resetWorkspace
// csf.ts ('use server') — assessmentId added, framework 'nist-csf-2' enforced
export interface CsfScoreInput { assessmentId: string; subcategoryId: string; /* rest unchanged */ }
export async function saveCsfScore(input: CsfScoreInput): Promise<ActionResult>;
export async function bulkSetTarget(assessmentId: string, categoryId: string, target: string): Promise<ActionResult>;
export async function acceptSuggestion(assessmentId: string, subcategoryId: string): Promise<ActionResult>;   // ISO statuses come from the customer's most recent iso27001 assessment (same fiscal year preferred, else most recent); none → error
export async function prefillFromIso(assessmentId: string): Promise<ActionResult & { count?: number }>;      // same ISO source rule
export async function saveCsfProfile(prev, fd): Promise<ActionResult>;                 // fd adds assessmentId
```
Also export a pure helper for the ISO-source rule and test it (`src/lib/grc/isoSource.ts` + test):
```ts
export function pickIsoSource(assessments: Pick<Assessment, 'id' | 'framework' | 'fiscalYear' | 'updatedAt'>[], fiscalYear: number | null): string | null;
// iso27001 only; prefer same fiscalYear (most recent updatedAt among them), else most recent updatedAt overall; null when none
```

`createAssessment` with `basedOnId`: load the source (same customer and framework, else ValidationError), then in `getDb().transaction(async (tx) => …)` insert the assessment and the copied rows from `planIsoCopy` / `planCsfCopy` (+ csf_profile copy for CSF), with `basedOnId` set. The Neon HTTP driver does not support interactive transactions — if `transaction` is unavailable, use `getDb().batch([...])` (atomic on neon-http) with the new id generated up front via `crypto.randomUUID()`. Verify which the installed drizzle/neon version supports and note it in the report.

Component changes: each component that calls an action takes the new id(s) as props (`assessmentId` for ISO status/CSF components, `customerId` for risk and methodology components) and passes them through; components that build links take a `base` prop instead of importing `BASE`/`CSF_BASE`. No other behaviour change.

- [ ] **Step 1:** Write `isoSource.test.ts` (same-year preference, fallback to newest, ignores CSF, null when none) → FAIL → implement → PASS.
- [ ] **Step 2:** Rewrite `grc.ts` and `csf.ts` per the interfaces.
- [ ] **Step 3:** Update the components (props only).
- [ ] **Step 4:** Commit `feat(grc): actions scoped to customers and assessments; copy-from-previous` (app compiles again after Task 6).

---

### Task 6: Assessment routes

**Files:**
- Move ISO pages from `src/app/(app)/grc/iso27001/{page,controls/page,controls/[id]/page,soa/page}.tsx` → `src/app/(app)/grc/a/[assessmentId]/iso/{page,controls/page,controls/[id]/page,soa/page}.tsx`
- Move CSF pages from `src/app/(app)/grc/nist-csf-2/{page,profile/page,profile/[id]/page,gaps/page,settings/page}.tsx` → `src/app/(app)/grc/a/[assessmentId]/csf/{…same}`
- Create: `src/app/(app)/grc/a/[assessmentId]/layout.tsx`, `src/app/(app)/grc/a/[assessmentId]/page.tsx` (redirects to `iso` or `csf` by framework), `src/app/(app)/grc/a/[assessmentId]/details/page.tsx`
- Create: `src/components/grc/AssessmentHeader.tsx`, `src/components/grc/AssessmentDetailsForm.tsx`, `src/components/grc/DeleteAssessment.tsx`
- Move CSV routes → `src/app/api/grc/a/[assessmentId]/soa.csv/route.ts` and `…/profile.csv/route.ts` (approved-viewer check, then `getAssessment` with the right framework → 404 otherwise)
- Delete: `src/app/(app)/grc/iso27001/**` and `src/app/(app)/grc/nist-csf-2/**` (incl. their layouts, setup, risks, settings — risks/settings move to the customer in Task 7)
- Modify: `next.config.ts` — redirects (permanent) `/grc/iso27001/:path*` → `/grc`, `/grc/nist-csf-2/:path*` → `/grc`, `/api/grc/iso27001/:path*` → `/grc`, `/api/grc/nist-csf-2/:path*` → `/grc`
- Modify: `src/lib/grc/frameworks.ts` — `href` removed (frameworks are no longer standalone workspaces); keep `slug`, `name`, `version`, `blurb`, `status`

**Behaviour:**
- `layout.tsx` calls `loadAssessment(assessmentId)` and renders `AssessmentHeader`: breadcrumb `GRC / {customer} / {folder path via ancestorsOf} / {title}`, framework badge, fiscal year, status (`AssessmentDetailsForm` has the editable status; header shows it read-only with a link to Details), "Started from {title}" link when `basedOnId` resolves; SubNav per framework — ISO: Dashboard (`iso`), Controls, SoA, Details; CSF: Dashboard (`csf`), Profile, Gaps, Settings, Details. Risks link → `/grc/c/{customerId}/risks`.
- Each moved page replaces `loadWorkspace()`/`loadCsfWorkspace()` with `loadAssessment(params.assessmentId, 'iso27001' | 'nist-csf-2')` and passes `assessment.id` / `customer.id` / `base` to components; data calls use `assessment.id` (scores) and `customer.id` (risks, methodology). Everything else in each page stays as it is.
- ISO settings (organisation form, methodology, reset) no longer lives here: organisation fields → customer settings (Task 7); ISO scope/lead → Details page; reset → Delete assessment on Details.
- `details/page.tsx`: `AssessmentDetailsForm` (title, fiscal year, period start/end, status select, folder select from `getFolders`, scope, lead) + `DeleteAssessment` (type the title).

- [ ] **Step 1:** Moves + edits; `git mv` so history follows.
- [ ] **Step 2:** Full gate: `DATABASE_URL="" sh -c 'npm run build && npx tsc --noEmit && npm run lint && npm test'` — the app must compile from here on.
- [ ] **Step 3:** Local check (after running `scripts/migrate-v1.3.sql` against a local DB seeded with the old schema, or a fresh DB built from the new schema plus Task 9's seed — whichever is available now; if neither, curl only for 200/404 on a fresh DB with a manually inserted customer + two assessments): each ISO and CSF page renders for the right framework and 404s for the wrong one; CSVs download; old URLs 308 to `/grc`.
- [ ] **Step 4:** Commit `feat(grc): ISO and CSF pages scoped to an assessment under /grc/a/[id]`.

---

### Task 7: Customer pages — list, workspace with folder tree, risks, settings

**Files:**
- Replace: `src/app/(app)/grc/page.tsx` (customers list + archived filter + search `?q=` + `?archived=1`)
- Create: `src/app/(app)/grc/new/page.tsx` + `src/components/grc/CustomerForm.tsx` (create/update; reuses `grc.org.*` labels for name/industry/size; notes)
- Create: `src/app/(app)/grc/c/[customerId]/layout.tsx` (loadCustomer; header with customer name, industry; SubNav: Assessments, Risks, Compare, Settings)
- Create: `src/app/(app)/grc/c/[customerId]/page.tsx` (workspace), `src/components/grc/FolderTree.tsx` (client), `src/components/grc/AssessmentList.tsx`, `src/components/grc/NewAssessmentForm.tsx` (client)
- Move: `src/app/(app)/grc/iso27001/risks/{page,new/page,[id]/page}.tsx` (from git history of Task 6's deletion — use `git show <task-5-head>:path`) → `src/app/(app)/grc/c/[customerId]/risks/{page,new/page,[riskId]/page}.tsx`, now using `loadCustomer` and `customer.id`
- Create: `src/app/(app)/grc/c/[customerId]/settings/page.tsx` (CustomerForm in update mode, MethodologyForm, archive/restore)

**Workspace behaviour (`/grc/c/[customerId]?folder=<id>`):**
- Left: `FolderTree` built with `buildTree(getFolders(customer.id))`. Each node links to `?folder=<id>`; "All assessments" shows everything; "Top level" shows assessments with `folderId = null`. Per-node menu (a `<details>` element — no custom popover library): New sub-folder, Rename (inline input), Move to… (a `<select>` of valid targets: all folders except itself and its descendants, plus Top level), Delete (disabled with the `grc.folders.notEmpty` hint when it has children or assessments). Actions from Task 5; errors shown inline (`cycle`, `depth`, `notEmpty` messages).
- Right: `AssessmentList` for the selected folder: title (link to `/grc/a/<id>`), framework badge (ISO 27001 / NIST CSF 2.0), fiscal year, status pill (the four statuses, i18n), key score (ISO: compliance % via `compliance(getStatuses(id))`; CSF: `avgCurrent / avgTarget` via `summary(toScoreRows(getCsfScores(id)), all ids)` — compute server-side in one pass per assessment), updated (use `ago` from `src/lib/intel/format.ts`).
- "New assessment" (`NewAssessmentForm`): framework select (from `frameworks` in `frameworks.ts`), title (prefilled `"{framework name} — FY{year}"` on change of framework/year, editable), fiscal year (number, default current year), folder (select, default the selected folder), Start (radio: Blank, or "From {title}" for each existing assessment of the chosen framework for this customer, newest first; default the newest when one exists), scope, lead. Submits `createAssessment`.
- Empty states: no folders → only "Top level"/"All" and a "New folder" button; no assessments → `grc.assessments.none` + New assessment.
- Mobile (390 px): tree collapses above the list (`<details open>` on ≥ 768 px via CSS only, collapsed below); no horizontal scroll — every grid has a base `grid-cols-1`.

- [ ] **Step 1:** Implement; client components import only types from server modules and scale helpers per the Global Constraints.
- [ ] **Step 2:** Gate; local browser pass (Python Playwright with `--no-sandbox`, as in earlier releases): create a customer, two nested folders, an ISO assessment, a CSF assessment; move a folder (and see the cycle error when moving into its own child); delete an empty folder; see the non-empty refusal; archive + restore the customer; EN and TH; 390 and 1280 px. Screenshots into the task directory.
- [ ] **Step 3:** Commit `feat(grc): customers list, customer workspace with folder tree, risks and settings`.

---

### Task 8: Year-over-year comparison page

**Files:**
- Create: `src/app/(app)/grc/c/[customerId]/compare/page.tsx`, `src/components/grc/CompareIso.tsx`, `src/components/grc/CompareCsf.tsx`

**Behaviour:**
- Pickers (GET form): Earlier (`a`) and Later (`b`) — selects listing the customer's assessments grouped by framework. Default when the page opens without params: the two most recent assessments of the framework with the most assessments (if at least two exist).
- If `a` and `b` are of different frameworks or customers → show `grc.compare.sameFramework` (no 400 page; the route handler isn't involved).
- ISO: two compliance gauges side by side (reuse `Gauge`), per-theme table with a, b and delta (signed, coloured with a text sign), counts (improved / regressed / unchanged), and a list of transitions grouped by direction with control id + title + from → to (status pills).
- CSF: `Radar` with both profiles — extend `Radar` with an optional second series (`points2`) drawn as a dashed outline in `--sev-low`, legend labels from the picker titles; per-Function table (a avgCurrent, b avgCurrent, a avgGap, b avgGap); change lists grouped by closed / opened / changed with subcategory id + text + gaps.
- Uses `compareIso` / `compareCsf` from Task 1.

- [ ] **Step 1:** Implement; gate; local check with the Task 7 data (copy the ISO assessment to FY2027 via Start = From…, change three statuses, compare); screenshot EN + TH.
- [ ] **Step 2:** Commit `feat(grc): compare two assessments year over year`.

---

### Task 9: Demo seed, docs, connected repos

**Files:**
- Modify: `scripts/seed-demo.ts` — args `--customer "BankX" [--folder "FY2026"] [--year 2026]`: find the customer by name (abort if missing), find or create the folder, upsert one ISO and one CSF assessment titled `"ISO 27001 — FY{year}"` / `"NIST CSF 2.0 — FY{year}"` in it (matched by customer + framework + title), then upsert statuses/scores/profile keyed by those assessment ids and replace the customer's risks — one transaction, re-runnable.
- Modify: cyber `CLAUDE.md` (GRC architecture: customers/folders/assessments, routes, copy + compare, migration script, seed args), `README.md`.
- Modify (lockstep, both repos): the cyber GRC description in `/project/src/nanoteofficial.me/src/lib/profile.ts` and `/project/src/tools.nanoteofficial.me/src/data/systems.ts` (+ `systems.private.ts` routes) — replace per-framework workspace routes with `/grc` (customers), `/grc/c/[id]` (workspace, risks, compare, settings), `/grc/a/[id]/…` (assessment); node labels/notes mention customers → folders → assessments. Same ids and EN/TH labels in both repos; tools `model.test.ts` must pass. Work in worktrees of those repos created by the controller.

- [ ] **Step 1:** Seed script + a local run twice (idempotent: same counts).
- [ ] **Step 2:** Docs in cyber.
- [ ] **Step 3:** Portfolio + tools model edits; each repo's gate.
- [ ] **Step 4:** Commits: cyber `feat(grc): seed demo into a customer's folder`, `docs(grc): customers, folders and assessments`; portfolio `fix: cyber GRC is multi-customer on the Tools map`; tools `fix: cyber GRC routes are customer- and assessment-scoped`.

---

### Task 10: Release v1.3.0 (controller)

- [ ] **Step 1: Backup** — create a Neon branch of the production database named `pre-v1-3-0` (Neon console, `neonctl branches create --name pre-v1-3-0`, or the Neon MCP/API — whichever is authorised). Confirm it exists before continuing.
- [ ] **Step 2: Rehearse** — restore nothing; instead run `scripts/verify-migration-v1.3.sh` once more on the final code.
- [ ] **Step 3: Migrate production** — `vercel env pull` → `psql "$DATABASE_URL_UNPOOLED" -v ON_ERROR_STOP=1 -f scripts/migrate-v1.3.sql` → confirm counts (93 / 106 / 1 / 12 / 1) and the BankX → FY2026 → two assessments rows → delete the env file. The live v1.2.0 code breaks against the new schema from this moment, so Step 4 follows immediately.
- [ ] **Step 4: Deploy** — merge the branch into main (fast-forward); `npm version 1.3.0 --no-git-tag-version`; gate with `DATABASE_URL=""`; commit `feat: v1.3.0 — customers, folders and assessment history`; tag; push main + tag; wait for Ready.
- [ ] **Step 5: Verify** — sign in is not possible from the controller; instead check with SQL that BankX's ISO compliance % and CSF averages match the pre-migration values recorded in Step 3 (compute with the same formulas from the same rows), `/grc` returns the sign-in redirect, old URLs 308, `/api/intel` still `ok`. Ask the owner to open `/grc` and confirm BankX → FY2026 → both assessments.
- [ ] **Step 6:** Push the portfolio and tools commits (patch releases, tags); update `/project/CLAUDE.md`; commit.
- [ ] **Rollback plan:** if Step 3 or 5 fails, restore production from the `pre-v1-3-0` branch (Neon "restore branch") and redeploy v1.2.0 (`vercel rollback` to the previous production deployment).

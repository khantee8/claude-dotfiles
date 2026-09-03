# exam.nanoteofficial.me v1.2.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a session configurable — a third `study` mode with answers revealed on demand, six size presets, in-order or shuffled questions, an optionally shuffled choice order that never breaks a lettered explanation, bookmarks, and retry-the-ones-I-missed.

**Architecture:** `buildQuestionOrder` gains an options object and a per-question `letterSafe` flag; everything else follows from it. The flag is *derived* by `validate:content` scanning explanations for letter references, stored on `questions`, and honoured by the engine — so choice shuffling can never contradict an explanation. Session options live in the existing `config` jsonb (no migration), and a new `bookmark` table backs the bookmark and retry-wrong pools.

**Tech Stack:** unchanged — Next.js 16, React 19, TypeScript, Tailwind v4, Auth.js v5, Neon + Drizzle, Vitest.

**Spec:** `docs/superpowers/specs/2026-09-03-exam-nanoteofficial-v1.2-design.md` — read it; §6 carries the constraint that shapes half this plan.

## Global Constraints

- Repo `/project/src/exam.nanoteofficial.me` on `main`, currently at `v1.1.1`, deployed and live. All paths are relative to it.
- Gate for every task: `npx tsc --noEmit`, `npm run lint`, `npm test`, `npm run validate:content`, `env -u DATABASE_URL npm run build`. The build must pass with `DATABASE_URL` unset.
- Never `git add -A`; add by path, quoting paths containing parentheses or brackets. Commit messages end with a blank line then `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.
- **Client components never import `@/lib/i18n`** — they receive a `labels` object built on the server. Adding a user-facing string means adding a key to `src/lib/i18n.ts` with both `en` and `th`.
- **Never `text-white` on a `bg-teal`/`bg-good`/`bg-amber`/`bg-bad` fill** — use `text-on-teal` / `text-on-good` / `text-on-amber` / `text-on-bad`.
- The exam runner gets **no mascot and no bookmark control**. Nothing in a timed attempt may hint at the answer or invite reflection.
- Local Neon DNS is flaky (~70% failure). Any script touching the database needs a retry wrapper; load env with `set -a; . ./.env.local; set +a`.
- Old `exam_session` rows predate the new config keys. Readers must default `order` to `'shuffled'` (those sessions *were* shuffled), `choiceOrder` to `'fixed'`, `source` to `'all'`.

---

## Existing code this plan builds on

`src/lib/exam/shuffle.ts`:
```ts
export interface PoolQuestion { id: string; number: number; scenarioId: string | null; choiceKeys: string[] }
export interface OrderedQuestionRef { questionId: string; choiceOrder: string[] }
export function mulberry32(seed: number): () => number
export function shuffleInPlace<T>(arr: T[], rng: () => number): T[]
export function buildQuestionOrder(pool: PoolQuestion[], seed: number, count: number): OrderedQuestionRef[]
```
It groups by scenario (`sc:<id>` / `solo:<id>`), sorts each group ascending by `number`, shuffles the groups, greedily takes whole groups that fit, and currently returns `choiceOrder: [...q.choiceKeys].sort()` with a comment explaining why choices are not shuffled.

`src/db/schema.ts`: `questions` (…, `explanation`, `explanationTh`), `examSessions` (`mode: text({enum:['practice','exam']})`, `config: jsonb<SessionConfig>`, `questionOrder: jsonb<OrderedQuestionRef[]>`), `sessionAnswers` (composite PK `(sessionId, questionId)`, `givenKey`, `isCorrect`, `flagged`).

`src/server/actions/sessions.ts`: `startSession(formData)` reads `subject`, `mode`, `questionCount`, `minutes`; `answerQuestion`, `toggleFlag`, `submitSession`, `deleteSession`. Module-private `requireUser()` and `requireOwnedSession()`.

`src/app/(app)/app/[subject]/page.tsx` renders the two start forms.

---

### Task 1: Detect lettered explanations

Derives the flag that makes choice shuffling safe. No UI yet.

**Files:**
- Create: `src/lib/content/letters.ts`, `src/lib/content/letters.test.ts`
- Modify: `scripts/validate-content.ts`

**Interfaces:**
- Produces: `namesAnOptionByLetter(explanation: string | null): boolean` — true when the text refers to an option by letter in English or Thai.

- [ ] **Step 1: Write the failing test** — `src/lib/content/letters.test.ts`

```ts
import { describe, expect, it } from 'vitest';
import { namesAnOptionByLetter } from './letters';

describe('namesAnOptionByLetter', () => {
  it('detects English option references', () => {
    for (const s of [
      'Option B is tempting but wrong.',
      'that makes statement B the incorrect one',
      'so A is wrong even though the community voted for it',
      'The answer C describes monitoring, not analysis.',
      'choice (B) refers to availability',
    ]) expect(namesAnOptionByLetter(s)).toBe(true);
  });

  it('detects Thai option references', () => {
    expect(namesAnOptionByLetter('ตัวเลือก B เป็นตัวลวงที่น่าสนใจ')).toBe(true);
  });

  it('does not fire on clause or control identifiers', () => {
    for (const s of [
      'ISO/IEC 27001:2022 clause 6.1.3 requires a comparison.',
      'Annex A control A.5.15 covers access control.',
      'The ISMS scope must be documented.',
      'มาตรการควบคุม A.8.24 ว่าด้วยการเข้ารหัสลับ',
    ]) expect(namesAnOptionByLetter(s)).toBe(false);
  });

  it('treats null as safe', () => {
    expect(namesAnOptionByLetter(null)).toBe(false);
  });
});
```

- [ ] **Step 2: Run `npm test`** — expect FAIL, module not found.

- [ ] **Step 3: Implement** — `src/lib/content/letters.ts`

```ts
/**
 * True when an explanation refers to an answer option by its letter.
 *
 * Such an explanation cannot survive a shuffled choice order: "option B is
 * tempting" points at whatever now sits at B. The session engine uses this to
 * leave those questions' choices in canonical order.
 *
 * Deliberately narrow. `A.5.15` (an Annex A control) and `6.1.3` (a clause) must
 * NOT match, so a bare letter only counts when an option word introduces it and
 * no dot follows.
 */
const EN = /\b(?:option|statement|choice|answer)s?\s+\(?([A-F])\)?(?![.\w])/i;
const TH = /ตัวเลือก\s*\(?([A-F])\)?(?![.\w])/;
const EN_BARE = /\b([A-F])\s+is\s+(?:the\s+)?(?:correct|incorrect|right|wrong|better|closer)\b/;

export function namesAnOptionByLetter(explanation: string | null): boolean {
  if (!explanation) return false;
  return EN.test(explanation) || TH.test(explanation) || EN_BARE.test(explanation);
}
```

- [ ] **Step 4: Run `npm test`** — all pass.

- [ ] **Step 5: Report the count from the validator.** In `scripts/validate-content.ts`, import the helper and count questions whose English *or* Thai explanation matches, then append to the success line so the number is visible on every run:

```ts
import { namesAnOptionByLetter } from '../src/lib/content/letters';
// …inside the per-question loop:
if (namesAnOptionByLetter(q.explanation) || namesAnOptionByLetter(q.explanationTh)) lettered.push(q.number);
```
with `const lettered: number[] = [];` beside `errors`, and in the final `console.log` add:
`` `, ${lettered.length} still name an option by letter` ``

This is a report, not an error — the count is expected to be non-zero until Task 8.

- [ ] **Step 6: Run `npm run validate:content`** — passes, and prints a non-zero lettered count. Record the number; Task 3 asserts against it.

- [ ] **Step 7: Commit**

```bash
git add src/lib/content/letters.ts src/lib/content/letters.test.ts scripts/validate-content.ts
git commit -m "feat(content): detect explanations that name an option by letter

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: Schema — flag, study mode, bookmarks

**Files:**
- Modify: `src/db/schema.ts`, `scripts/seed.ts`

**Interfaces:**
- Produces: `questions.lettersInExplanation` (boolean, not null, default false); `examSessions.mode` accepting `'study'`; `SessionConfig` with `order`/`choiceOrder`/`source`; table `bookmarks` exported from `@/db/schema`.

- [ ] **Step 1: Extend `SessionConfig` and the mode enum** in `src/db/schema.ts`

```ts
export type SessionOrder = 'sequential' | 'shuffled';
export type ChoiceOrder = 'fixed' | 'shuffled';
export type SessionSource = 'all' | 'bookmarks' | 'wrong';

export interface SessionConfig {
  questionCount: number;
  minutes: number | null;
  seed: number;
  /** Absent on rows written before v1.2 — readers must default these. */
  order?: SessionOrder;
  choiceOrder?: ChoiceOrder;
  source?: SessionSource;
}
```
and change the mode column to `text('mode', { enum: ['study', 'practice', 'exam'] })`.

- [ ] **Step 2: Add the question flag**, immediately after `explanationTh`:

```ts
  /** Derived by validate:content — see src/lib/content/letters.ts. */
  lettersInExplanation: boolean('lettersInExplanation').notNull().default(false),
```

- [ ] **Step 3: Add the bookmark table** at the end of the file:

```ts
export const bookmarks = pgTable('bookmark', {
  userId: text('userId').notNull().references(() => users.id, { onDelete: 'cascade' }),
  questionId: text('questionId').notNull().references(() => questions.id, { onDelete: 'cascade' }),
  createdAt: timestamp('createdAt', { mode: 'date' }).notNull().defaultNow(),
}, (t) => [primaryKey({ columns: [t.userId, t.questionId] })]);
```

- [ ] **Step 4: Seed the flag.** In `scripts/seed.ts`, import `namesAnOptionByLetter` from `../src/lib/content/letters` and add to the per-question `values` object:

```ts
      lettersInExplanation:
        namesAnOptionByLetter(q.explanation) || namesAnOptionByLetter(q.explanationTh),
```

- [ ] **Step 5: Verify** — `npx tsc --noEmit`, `npm run lint`, `env -u DATABASE_URL npm run build`. Then generate SQL without a database to confirm the shape:

```bash
npx drizzle-kit generate --dialect postgresql --schema ./src/db/schema.ts --out /tmp/v12-probe
grep -E "lettersInExplanation|CREATE TABLE \"bookmark\"" /tmp/v12-probe/*.sql
rm -rf /tmp/v12-probe
```
Expect the new column and the bookmark table.

- [ ] **Step 6: Apply to the database and reseed**

```bash
set -a; . ./.env.local; set +a
npx drizzle-kit push --force
for i in $(seq 1 12); do npm run seed 2>&1 | grep -q "✓ seeded" && break; sleep 8; done
npm run seed 2>&1 | tail -1
```
Retry loops are required — see Global Constraints. Then confirm the flag landed:

```bash
npx tsx -e "
import { neon } from '@neondatabase/serverless';
const sql=neon(process.env.DATABASE_URL);
sql\`select count(*) filter (where \"lettersInExplanation\") lettered, count(*) total from question\`.then(r=>console.log(r[0]));
"
```
`lettered` must equal the count Task 1 reported.

- [ ] **Step 7: Commit**

```bash
git add src/db/schema.ts scripts/seed.ts
git commit -m "feat(db): lettersInExplanation flag, study mode, bookmark table

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Session engine — order and safe choice shuffling

**Files:**
- Modify: `src/lib/exam/shuffle.ts`, `src/lib/exam/shuffle.test.ts`

**Interfaces:**
- Consumes: nothing new.
- Produces: `PoolQuestion` gains `letterSafe: boolean`; `buildQuestionOrder(pool, seed, count, options: OrderOptions)` where `interface OrderOptions { order: 'sequential' | 'shuffled'; choiceOrder: 'fixed' | 'shuffled' }`.

- [ ] **Step 1: Write the failing tests** — append inside the existing `describe('buildQuestionOrder', …)` in `src/lib/exam/shuffle.test.ts`. The existing `POOL` helper builds questions with `choiceKeys: ['A','B','C']`; extend the local `q()` helper to take a `letterSafe` argument defaulting to `true`.

```ts
  const OPTS = { order: 'shuffled', choiceOrder: 'fixed' } as const;

  it('sequential order yields ascending question numbers', () => {
    const order = buildQuestionOrder(POOL, 7, POOL.length, { ...OPTS, order: 'sequential' });
    const nums = order.map((o) => Number(o.questionId.replace('q', '')));
    expect(nums).toEqual([...nums].sort((a, b) => a - b));
  });

  it('sequential order is the same for every seed', () => {
    const a = buildQuestionOrder(POOL, 1, 10, { ...OPTS, order: 'sequential' }).map((o) => o.questionId);
    const b = buildQuestionOrder(POOL, 999, 10, { ...OPTS, order: 'sequential' }).map((o) => o.questionId);
    expect(a).toEqual(b);
  });

  it('sequential order still keeps scenario blocks contiguous', () => {
    const ids = buildQuestionOrder(POOL, 3, POOL.length, { ...OPTS, order: 'sequential' }).map((o) => o.questionId);
    const i1 = ids.indexOf('q1');
    expect(ids.slice(i1, i1 + 3)).toEqual(['q1', 'q2', 'q3']);
  });

  it('leaves choices canonical when choiceOrder is fixed', () => {
    for (const o of buildQuestionOrder(POOL, 3, 10, OPTS)) {
      expect(o.choiceOrder).toEqual(['A', 'B', 'C']);
    }
  });

  it('shuffles choices only for letter-safe questions', () => {
    const mixed = [
      { id: 'safe1', number: 1, scenarioId: null, choiceKeys: ['A', 'B', 'C'], letterSafe: true },
      { id: 'safe2', number: 2, scenarioId: null, choiceKeys: ['A', 'B', 'C'], letterSafe: true },
      { id: 'safe3', number: 3, scenarioId: null, choiceKeys: ['A', 'B', 'C'], letterSafe: true },
      { id: 'unsafe', number: 4, scenarioId: null, choiceKeys: ['A', 'B', 'C'], letterSafe: false },
    ];
    const order = buildQuestionOrder(mixed, 5, 4, { order: 'sequential', choiceOrder: 'shuffled' });
    const unsafe = order.find((o) => o.questionId === 'unsafe')!;
    expect(unsafe.choiceOrder).toEqual(['A', 'B', 'C']);
    for (const o of order) expect([...o.choiceOrder].sort()).toEqual(['A', 'B', 'C']);
  });

  it('actually shuffles some safe question across seeds', () => {
    const safe = Array.from({ length: 12 }, (_, i) => ({
      id: `s${i}`, number: i + 1, scenarioId: null,
      choiceKeys: ['A', 'B', 'C'], letterSafe: true,
    }));
    const seen = new Set<string>();
    for (const seed of [1, 2, 3, 4, 5]) {
      for (const o of buildQuestionOrder(safe, seed, 12, { order: 'sequential', choiceOrder: 'shuffled' })) {
        seen.add(o.choiceOrder.join(''));
      }
    }
    expect(seen.size).toBeGreaterThan(1);
  });
```

- [ ] **Step 2: Run `npm test`** — the new tests FAIL (the 4th argument is not accepted yet).

- [ ] **Step 3: Implement.** In `src/lib/exam/shuffle.ts` add `letterSafe: boolean;` to `PoolQuestion`, add the options interface, and change the signature and the two behavioural lines:

```ts
export interface OrderOptions {
  order: 'sequential' | 'shuffled';
  choiceOrder: 'fixed' | 'shuffled';
}

export function buildQuestionOrder(
  pool: PoolQuestion[],
  seed: number,
  count: number,
  options: OrderOptions,
): OrderedQuestionRef[] {
```
Replace `shuffleInPlace(units, rng);` with:
```ts
  // Sequential order walks the bank as printed; scenario blocks are already
  // contiguous because each group is sorted by number, so ordering the groups by
  // their first question preserves that.
  if (options.order === 'sequential') {
    units.sort((a, b) => a[0].number - b[0].number);
  } else {
    shuffleInPlace(units, rng);
  }
```
and replace the `choiceOrder` line in the returned map with:
```ts
    // A question whose explanation names an option by letter must keep its
    // canonical order, or the explanation points at the wrong text.
    choiceOrder:
      options.choiceOrder === 'shuffled' && q.letterSafe
        ? shuffleInPlace([...q.choiceKeys], rng)
        : [...q.choiceKeys].sort(),
```
Delete the now-outdated comment block that said choices are never shuffled.

- [ ] **Step 4: Fix the existing call sites in the test file** — every pre-existing `buildQuestionOrder(POOL, seed, n)` call needs the 4th argument `OPTS`, and the `q()` helper needs `letterSafe: true`. Run `npm test`; all tests pass (the previous "keeps choices in canonical order" test now expresses the `fixed` path).

- [ ] **Step 5: Verify** — `npx tsc --noEmit` will now fail in `src/server/actions/sessions.ts` because its call lacks the 4th argument. That is expected and is fixed in Task 4; note it and proceed.

- [ ] **Step 6: Commit**

```bash
git add src/lib/exam/shuffle.ts src/lib/exam/shuffle.test.ts
git commit -m "feat(exam): sequential order and letter-safe choice shuffling

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: startSession — new options and pool sources

**Files:**
- Modify: `src/server/actions/sessions.ts`

**Interfaces:**
- Consumes: `buildQuestionOrder(pool, seed, count, options)` and `PoolQuestion.letterSafe` from Task 3; `bookmarks`, `SessionOrder`, `ChoiceOrder`, `SessionSource` from Task 2.
- Produces: `startSession(formData)` additionally reading `order`, `choiceOrder`, `source`; exported `deleteSession` unchanged.

- [ ] **Step 1: Parse and validate the new fields.** In `startSession`, after the existing `mode` validation, add:

```ts
  const order: SessionOrder = formData.get('order') === 'sequential' ? 'sequential' : 'shuffled';
  const choiceOrder: ChoiceOrder = formData.get('choiceOrder') === 'shuffled' ? 'shuffled' : 'fixed';
  const rawSource = String(formData.get('source') ?? 'all');
  const source: SessionSource =
    rawSource === 'bookmarks' || rawSource === 'wrong' ? rawSource : 'all';
```
and widen the mode check to `if (mode !== 'study' && mode !== 'practice' && mode !== 'exam')`. Type `mode` as `'study' | 'practice' | 'exam'` where it is used.

Minutes are exam-only; leave that branch as it is (`mode === 'exam'`).

- [ ] **Step 2: Build the pool from the chosen source.** Replace the single `pool` query with:

```ts
  const base = {
    where: eq(questions.subjectSlug, subjectSlug),
    columns: { id: true, number: true, scenarioId: true, choices: true, lettersInExplanation: true },
  } as const;

  let pool = await db.query.questions.findMany(base);

  if (source === 'bookmarks') {
    const marked = await db.select({ questionId: bookmarks.questionId })
      .from(bookmarks).where(eq(bookmarks.userId, userId));
    const ids = new Set(marked.map((m) => m.questionId));
    pool = pool.filter((q) => ids.has(q.id));
  } else if (source === 'wrong') {
    // Only this user's own finished sessions, so one learner's mistakes never
    // leak into another's pool.
    const missed = await db.selectDistinct({ questionId: sessionAnswers.questionId })
      .from(sessionAnswers)
      .innerJoin(examSessions, eq(sessionAnswers.sessionId, examSessions.id))
      .where(and(
        eq(examSessions.userId, userId),
        eq(sessionAnswers.isCorrect, false),
      ));
    const ids = new Set(missed.map((m) => m.questionId));
    pool = pool.filter((q) => ids.has(q.id));
  }

  if (pool.length === 0) throw new Error('No questions available for this selection');
```
Add `bookmarks` to the schema import.

- [ ] **Step 3: Pass the flag and options through**

```ts
  const orderRefs = buildQuestionOrder(
    pool.map((q) => ({
      id: q.id,
      number: q.number,
      scenarioId: q.scenarioId,
      choiceKeys: q.choices.map((c) => c.key),
      letterSafe: !q.lettersInExplanation,
    })),
    seed,
    questionCount,
    { order, choiceOrder },
  );
```
and persist the options in `config`:
```ts
    config: {
      questionCount: orderRefs.length,
      minutes: mode === 'exam' ? minutes : null,
      seed,
      order,
      choiceOrder,
      source,
    },
```
Rename the local variable consistently (`order` is now taken by the option, so the refs variable must be `orderRefs`) and update the `console.warn` under-fill check and the `questionOrder:` field to use it.

- [ ] **Step 4: Route study mode.** The redirect at the end of `startSession` builds `/app/${subjectSlug}/${mode}/${row.id}`. `study` sessions render in the practice runner, so redirect study to the practice route:

```ts
  const route = mode === 'exam' ? 'exam' : 'practice';
  redirect(`/app/${subjectSlug}/${route}/${row.id}`);
```

- [ ] **Step 5: Verify** — `npx tsc --noEmit` clean, `npm run lint` clean, `env -u DATABASE_URL npm run build` succeeds, `npm test` passes.

- [ ] **Step 6: Commit**

```bash
git add src/server/actions/sessions.ts
git commit -m "feat(sessions): order, choice-order and pool-source options

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: Study mode — reveal on demand

**Files:**
- Modify: `src/server/actions/sessions.ts`, `src/components/PracticeRunner.tsx`, `src/app/(app)/app/[subject]/practice/[sessionId]/page.tsx`, `src/lib/i18n.ts`

**Interfaces:**
- Consumes: `AnswerResult` from `sessions.ts`.
- Produces: `revealAnswer(sessionId: string, questionId: string): Promise<AnswerResult>`; `PracticeRunner` gains props `mode: 'study' | 'practice'` and `labels.showAnswer`, `labels.reviewed`.

- [ ] **Step 1: Add the reveal action** to `src/server/actions/sessions.ts`:

```ts
/**
 * Study mode only: return the answer without requiring a guess. Records the
 * question as reviewed (givenKey stays null) so history can show coverage.
 * Refuses in practice and exam mode — those must be earned.
 */
export async function revealAnswer(sessionId: string, questionId: string): Promise<AnswerResult> {
  const userId = await requireUser();
  const db = getDb();
  const sess = await requireOwnedSession(sessionId, userId);
  if (sess.mode !== 'study') throw new Error('Reveal is only available in study mode');
  if (sess.finishedAt) throw new Error('Session already finished');
  if (!sess.questionOrder.some((o) => o.questionId === questionId)) {
    throw new Error('Question is not part of this session');
  }

  const [q] = await db.select().from(questions).where(eq(questions.id, questionId)).limit(1);
  if (!q) throw new Error('Question not found');

  await db.insert(sessionAnswers)
    .values({ sessionId, questionId, answeredAt: new Date() })
    .onConflictDoNothing();

  return {
    correctKey: q.correctKey,
    explanation: q.explanation,
    explanationTh: q.explanationTh,
    votes: q.votes,
  };
}
```
Note `isCorrect` stays null, which is what makes the results screen show coverage rather than a score.

- [ ] **Step 2: Pass the mode into the runner.** In the practice page, read `sess.mode` and pass `mode={sess.mode === 'study' ? 'study' : 'practice'}`; keep the existing `notFound()` guard but accept both modes:

```ts
  if (!sess || (sess.mode !== 'practice' && sess.mode !== 'study')) notFound();
```

- [ ] **Step 3: Add the dictionary keys** to `src/lib/i18n.ts`:

```ts
  'q.showAnswer':   { en: 'Show answer',  th: 'ดูเฉลย' },
  'q.reviewed':     { en: 'Reviewed',     th: 'ทบทวนแล้ว' },
  'results.reviewedOf': { en: 'reviewed {n} of {total}', th: 'ทบทวนแล้ว {n} จาก {total}' },
```

- [ ] **Step 4: Render the reveal control.** In `PracticeRunner`, when `mode === 'study'` and the current question has no result, render a quiet button below the choices:

```tsx
{mode === 'study' && !result && (
  <button
    type="button"
    disabled={pending}
    onClick={() => startTransition(async () => {
      const r = await revealAnswer(sessionId, question.questionId);
      setResults((prev) => ({ ...prev, [current]: { ...r, givenKey: '' } }));
    })}
    className="mt-4 rounded-lg border border-line px-4 py-2 text-sm text-muted transition-colors hover:text-ink"
  >
    {labels.showAnswer}
  </button>
)}
```
Choices stay enabled in study mode until a result exists, so the learner may still answer first. The existing feedback panel renders unchanged; when `givenKey` is `''` it shows the explanation without a correct/incorrect verdict — guard the verdict line with `result.isCorrect !== undefined`.

- [ ] **Step 5: Question-map colours in study mode.** A reviewed question is neither right nor wrong, so give it the neutral "answered" tone rather than green/red: in the map's tone logic, treat `r && r.isCorrect === undefined` as `bg-line text-ink`.

- [ ] **Step 6: Verify** — full gate, then `npm run dev` and confirm TypeScript is happy. Behavioural verification happens against production in Task 9.

- [ ] **Step 7: Commit**

```bash
git add src/server/actions/sessions.ts src/components/PracticeRunner.tsx "src/app/(app)/app/[subject]/practice/[sessionId]/page.tsx" src/lib/i18n.ts
git commit -m "feat(study): reveal the answer on demand without guessing

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: Bookmarks

**Files:**
- Create: `src/server/actions/bookmarks.ts`, `src/components/BookmarkButton.tsx`
- Modify: `src/components/PracticeRunner.tsx`, `src/app/(app)/app/[subject]/practice/[sessionId]/page.tsx`, `src/lib/i18n.ts`

**Interfaces:**
- Produces: `toggleBookmark(questionId: string, on: boolean): Promise<void>`; `BookmarkButton` with props `{ questionId: string; initial: boolean; labels: { add: string; remove: string } }`.

- [ ] **Step 1: Write the action** — `src/server/actions/bookmarks.ts`

```ts
'use server';

import { and, eq } from 'drizzle-orm';
import { redirect } from 'next/navigation';
import { auth } from '@/auth';
import { getDb } from '@/db';
import { bookmarks, questions } from '@/db/schema';

async function requireUser(): Promise<string> {
  const session = await auth();
  if (!session?.user?.id) redirect('/signin');
  return session.user.id;
}

/** Star or unstar a question for the signed-in user. */
export async function toggleBookmark(questionId: string, on: boolean) {
  const userId = await requireUser();
  const db = getDb();

  // Reject ids that are not real questions, so the table cannot be filled with junk.
  const [q] = await db.select({ id: questions.id })
    .from(questions).where(eq(questions.id, questionId)).limit(1);
  if (!q) throw new Error('Unknown question');

  if (on) {
    await db.insert(bookmarks).values({ userId, questionId }).onConflictDoNothing();
  } else {
    await db.delete(bookmarks)
      .where(and(eq(bookmarks.userId, userId), eq(bookmarks.questionId, questionId)));
  }
}
```

- [ ] **Step 2: Write the component** — `src/components/BookmarkButton.tsx`

```tsx
'use client';

import { useState, useTransition } from 'react';
import { toggleBookmark } from '@/server/actions/bookmarks';

export default function BookmarkButton({
  questionId,
  initial,
  labels,
}: {
  questionId: string;
  initial: boolean;
  labels: { add: string; remove: string };
}) {
  const [on, setOn] = useState(initial);
  const [pending, start] = useTransition();

  return (
    <button
      type="button"
      disabled={pending}
      aria-pressed={on}
      aria-label={on ? labels.remove : labels.add}
      title={on ? labels.remove : labels.add}
      onClick={() => {
        const next = !on;
        setOn(next);
        start(async () => {
          try {
            await toggleBookmark(questionId, next);
          } catch {
            setOn(!next); // put the star back if the write failed
          }
        });
      }}
      className={`min-h-11 min-w-11 rounded-lg text-lg transition-colors sm:min-h-0 sm:min-w-0 ${
        on ? 'text-amber' : 'text-faint hover:text-ink'
      }`}
    >
      {on ? '★' : '☆'}
    </button>
  );
}
```
Note the optimistic flip is reverted on failure — a star that lies about being saved is worse than a slow one.

- [ ] **Step 3: Dictionary keys**

```ts
  'q.bookmarkAdd':    { en: 'Bookmark this question', th: 'บันทึกข้อนี้ไว้' },
  'q.bookmarkRemove': { en: 'Remove bookmark',        th: 'เอาออกจากที่บันทึกไว้' },
```

- [ ] **Step 4: Load the learner's bookmarks in the practice page** and pass them down:

```ts
  const marked = await db.select({ questionId: bookmarks.questionId })
    .from(bookmarks).where(eq(bookmarks.userId, user!.id));
  const bookmarked = new Set(marked.map((m) => m.questionId));
```
then include `bookmarked: bookmarked.has(q.id)` on each `PracticeQuestion`, and render `<BookmarkButton>` in the runner beside the "Question N of M" line. **Do not add it to `ExamRunner`.**

- [ ] **Step 5: Verify** — full gate.

- [ ] **Step 6: Commit**

```bash
git add src/server/actions/bookmarks.ts src/components/BookmarkButton.tsx src/components/PracticeRunner.tsx "src/app/(app)/app/[subject]/practice/[sessionId]/page.tsx" src/lib/i18n.ts
git commit -m "feat: bookmark questions in study and practice

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: Start screen and retry-wrong

**Files:**
- Modify: `src/app/(app)/app/[subject]/page.tsx`, `src/app/(app)/app/[subject]/results/[sessionId]/page.tsx`, `src/app/(app)/app/results/page.tsx`, `src/lib/i18n.ts`
- Create: `src/components/SessionSetup.tsx`

**Interfaces:**
- Consumes: `startSession` from Task 4.
- Produces: `SessionSetup` client component with props `{ subject: string; total: number; bookmarkCount: number; wrongCount: number; defaultExamMinutes: number; labels: Record<string, string> }`.

- [ ] **Step 1: Build `SessionSetup`** — a client component implementing approved layout A: three mode cards, then one shared control block. It holds the selected mode in state and submits a single `<form action={startSession}>` carrying hidden `subject` and `mode` plus the visible controls.

Requirements, all of which the spec fixes:
- Sizes 10, 20, 25, 50, 100, All — **render only presets `<= total`**, plus All.
- Question order: In order / Shuffled. Default `sequential` for study, `shuffled` for practice and exam.
- Choice order: Fixed / Shuffled, default `fixed`. Render a one-line note under it explaining that questions whose explanation names an option keep their original order.
- Draw from: Whole bank / Bookmarks ({bookmarkCount}) / Questions I got wrong ({wrongCount}). Disable a source whose count is 0 rather than letting it start an empty session.
- Minutes select, rendered only when mode is `exam`.
- Segmented controls: `min-h-11` on touch widths, `sm:min-h-0` above, matching v1.1.
- Never `text-white` on a coloured fill — use the `text-on-*` tokens.

- [ ] **Step 2: Add the dictionary keys** for every string in the component — modes, control labels, the choice-order note, and the source options — each with `en` and `th`.

- [ ] **Step 3: Wire the subject page.** Replace the two existing forms with `<SessionSetup>`, computing the counts server-side:

```ts
  const [{ bookmarkCount }] = await db
    .select({ bookmarkCount: sql<number>`count(*)::int` })
    .from(bookmarks)
    .innerJoin(questions, eq(bookmarks.questionId, questions.id))
    .where(and(eq(bookmarks.userId, user!.id), eq(questions.subjectSlug, subject)));

  const [{ wrongCount }] = await db
    .select({ wrongCount: sql<number>`count(distinct ${sessionAnswers.questionId})::int` })
    .from(sessionAnswers)
    .innerJoin(examSessions, eq(sessionAnswers.sessionId, examSessions.id))
    .where(and(eq(examSessions.userId, user!.id), eq(sessionAnswers.isCorrect, false)));
```

- [ ] **Step 4: Retry-wrong on the result page.** Count the misses in that session; when non-zero render a form posting to `startSession` with `mode=practice`, `source=wrong`, `questionCount` equal to the miss count, and label it with a new key `results.retryMissed` (`en: 'Retry the {n} you missed'`, `th: 'ลองใหม่ {n} ข้อที่ตอบผิด'`).

- [ ] **Step 5: Show study sessions correctly in history.** `/app/results` currently prints `{score}/{count}`. For `mode === 'study'`, `score` is 0 and meaningless — print `t(lang, 'results.reviewedOf', { n: answeredCount, total })` instead. Fetch the reviewed count per session with a grouped query rather than per row.

- [ ] **Step 6: Verify** — full gate, then `npm run dev` and screenshot the subject page at 390px and 1280px in both languages and themes with Playwright (`chromium.launch({ chromiumSandbox: false })`; package at `/root/.npm/_npx/705bc6b22212b352/node_modules/playwright/index.mjs`). Confirm no horizontal overflow and that every control is reachable on a phone. Look at the screenshots before claiming done.

- [ ] **Step 7: Commit**

```bash
git add src/components/SessionSetup.tsx "src/app/(app)/app/[subject]/page.tsx" "src/app/(app)/app/[subject]/results/[sessionId]/page.tsx" "src/app/(app)/app/results/page.tsx" src/lib/i18n.ts
git commit -m "feat(ui): mode-first session setup, retry-wrong, study coverage in history

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 8: Rewrite the lettered explanations

Removes the last constraint on choice shuffling. Judgement-heavy content work — dispatch one subagent per batch, and do not let an agent change an answer key.

**Files:**
- Modify: `content/iso-27001-li/bank.md` (via the per-range extract and Thai files), `content/iso-27001-li/subject.json` if the version changes

- [ ] **Step 1: List the affected questions**

```bash
cd /project/src/exam.nanoteofficial.me
npx tsx -e "
import {readFileSync} from 'node:fs';
import {parseBank} from './src/lib/content/parse';
import {namesAnOptionByLetter} from './src/lib/content/letters';
const b=parseBank(readFileSync('content/iso-27001-li/bank.md','utf8'));
const hit=b.questions.filter(q=>namesAnOptionByLetter(q.explanation)||namesAnOptionByLetter(q.explanationTh));
console.log(hit.length, hit.map(q=>q.number).join(' '));
"
```

- [ ] **Step 2: Rewrite, in batches of ~20 questions.** For each affected question, reword **both** the English and Thai explanation so it identifies the option by its content, not its letter: "option B is tempting" becomes "the option about risk retention is tempting". Rules for whoever does this:
  - Do not change the meaning, the recommended answer, or any clause number.
  - Keep the sentence that flags a marked-answer-vs-community disagreement.
  - Keep the two languages saying the same thing.
  - Edit `content/iso-27001-li/extract/*.md` for English and `content/iso-27001-li/th/*.md` for Thai, then re-merge — never hand-edit `bank.md`, which is generated.

- [ ] **Step 3: Re-merge and re-validate**

```bash
npm run merge:th
npm run derive:questions-only
npm run validate:content
```
The lettered count in the validator output must now be **0**.

- [ ] **Step 4: Bump the bank version** to `1.2.0` in `content/iso-27001-li/bank.md` frontmatter, then reseed with the retry loop from Task 2 Step 6 and confirm `lettersInExplanation` is false for all 285.

- [ ] **Step 5: Commit**

```bash
git add content/iso-27001-li/
git commit -m "content: reword explanations to name options by content, not letter (bank v1.2.0)

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 9: Live verification and release

- [ ] **Step 1: Full gate**

```bash
npm test && npx tsc --noEmit && npm run lint && npm run validate:content && env -u DATABASE_URL npm run build
```

- [ ] **Step 2: Deploy**

```bash
git push origin main
timeout 500 vercel deploy --prod --yes
```
Confirm it aliases `https://exam.nanoteofficial.me`.

- [ ] **Step 3: Verify against the live site.** Mint a temporary admin session by inserting a `session` row and setting the `__Secure-authjs.session-token` cookie (domain `exam.nanoteofficial.me`, `secure: true`, `httpOnly: true`); **delete the row afterwards**. Note that `EN`/`TH` header buttons also carry `aria-pressed`, so scope choice selectors to `article button[aria-pressed]`. Check:
  1. A study session started **in order** begins at Q1 and ascends.
  2. **Show answer** reveals the explanation without answering, and the question map shows a neutral state, not green or red.
  3. History shows "reviewed N of M" for that study session, not a percentage.
  4. A practice session with **shuffled choices** leaves a flagged question canonical — pick one from the Task 8 Step 1 list if any remain, otherwise confirm all questions shuffle.
  5. Bookmark two questions, then start a session with **Draw from: Bookmarks** and confirm it contains exactly those.
  6. Finish a practice session with at least one miss, then use **Retry the N you missed** and confirm the count matches.
  7. Sizes 10 and 100 both start; presets above the pool are absent.
  8. 390 / 768 / 1280 in EN and TH, light and dark: no horizontal overflow.
  9. The exam runner still has **no bookmark star and no mascot**.
  Then delete every test session, answer and bookmark you created.

- [ ] **Step 4: Update documentation.** In the repo `CLAUDE.md`, add a v1.2 section covering: the three modes, `lettersInExplanation` being derived by `validate:content` and honoured by the engine, the `bookmark` table, and the rule that old `config` rows default to `order: 'shuffled'`. Update the `exam.nanoteofficial.me` section of `/project/CLAUDE.md` to mention study mode, session options and bookmarks.

- [ ] **Step 5: Tag**

```bash
git tag -a v1.2.0 -m "v1.2.0 — study mode, session options, bookmarks, retry-wrong"
git push origin v1.2.0
```

---

## Self-Review Notes (performed at write time)

1. **Spec coverage:** three modes (Tasks 5, 4, 7 ✓); sizes (7 ✓); question order (3, 4, 7 ✓); choice order incl. the safety rule (1, 2, 3, 4, 7 ✓); bookmarks and retry-wrong (2, 6, 7 ✓); start screen layout A (7 ✓); data model incl. the old-row default (2, 7 ✓); session engine (3 ✓); security (4, 6 ✓); verification and release (9 ✓); the 83 rewrite (8 ✓).
2. **Placeholder scan:** no TBDs. Task 7 Step 1 and Task 8 Step 2 describe requirements rather than literal code because they are layout and prose work; both carry explicit, checkable acceptance rules.
3. **Type consistency:** `OrderOptions`, `SessionOrder`, `ChoiceOrder`, `SessionSource`, `PoolQuestion.letterSafe`, `questions.lettersInExplanation` and `namesAnOptionByLetter` are each defined once and referenced identically thereafter. Task 3 renames the local `order` variable to `orderRefs` in `startSession` because `order` becomes an option name — Task 4 Step 3 carries that through.
4. **Deliberate ordering:** Task 3 knowingly leaves `tsc` failing until Task 4 compiles the new call site. Stated in the task so an executor does not treat it as a defect.
5. **Carried constraints:** no mascot or bookmark in the exam runner; client components take `labels`; `text-on-*` on coloured fills; retry loops for local Neon.

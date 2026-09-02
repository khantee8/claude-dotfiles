# exam.nanoteofficial.me v1.1.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship v1.1.0 — Thai translations for all 285 explanations behind a TH/EN toggle, dark mode, a Shield Keeper mascot, interface animation, a genuine responsive pass, and the ability to delete a saved result.

**Architecture:** The bank grammar gains an optional `> **ทำไม:**` block parsed into `explanationTh`, seeded into a new nullable column. Language is a server-readable cookie so the first paint is already correct; theme is a `dark` class on `<html>` applied by a pre-paint inline script. The mascot and all motion are CSS/SVG only — no new runtime dependencies.

**Tech Stack:** unchanged — Next.js 16, React 19, TS, Tailwind v4, Auth.js v5, Neon + Drizzle, Vitest.

**Spec:** `docs/superpowers/specs/2026-09-02-exam-nanoteofficial-v1.1-design.md` (read it — especially §3.2, which carries the translation glossary).

**Repo:** `/project/src/exam.nanoteofficial.me` on `main`, currently at `v1.0.0`, deployed and live. All paths below are relative to it. Never `git add -A`; add by path (quote paths containing parentheses/brackets).

**Verification gate for every task:** `npx tsc --noEmit`, `npm run lint`, `npm test`, `env -u DATABASE_URL npm run build`. Content tasks additionally run `npm run validate:content`.

**Local DB caveat:** this container's DNS to `api.<region>.aws.neon.tech` fails intermittently (~70%). Any script touching Neon needs a retry wrapper. Load env with `set -a; . ./.env.local; set +a`.

---

## Existing code you must match

- `src/lib/content/parse.ts` — `parseBank(md): ParsedBank`. Relevant constants:
  `WHY_START = /^> \*\*Why:\*\* (.*)$/`, `WHY_CONT = /^>(?: (.*))?$/`,
  `ANSWER_LINE`, `HEADING_LIKE = /^##/`. Throws `Q<n> (line N): …` on malformation
  and throws on any unrecognised `###`/`##` heading.
- `src/lib/content/types.ts` — `ParsedQuestion { number, topic, scenario, text, choices, correctKey, votes, explanation }`.
- `src/db/schema.ts` — `questions` table; `users`; `examSessions`; `sessionAnswers`.
- `src/db/index.ts` — `getDb()` (app code), eager `db` (Auth.js adapter only), `schema`.
- `src/app/globals.css` — Tailwind v4 `@theme` tokens (`--color-paper`, `--color-ink`,
  `--color-muted`, `--color-faint`, `--color-line`, `--color-card`, `--color-teal`,
  `--color-teal-soft`, `--color-teal-line`, `--color-amber`, `--color-good`,
  `--color-bad`, plus `--color-hall*`, `--color-sky`, `--color-timer`) and
  `@theme inline` mapping `--font-display`/`--font-sans`.
- Components: `SiteHeader` (default export, `{ right?: ReactNode }`), `SiteFooter`,
  `QuestionCard` (default, exports `ClientChoice`), `VoteBar` (default,
  `{ votes, dark? }`), `PracticeRunner`, `ExamRunner`, `RequestAccessForm`,
  `AdminDecideButtons`.
- Server actions: `src/server/actions/{sessions,admin,access}.ts`.
- `src/lib/exam/shuffle.ts` — `choiceOrder` is canonical (NOT shuffled) because 83
  explanations name options by letter. **Do not re-enable the shuffle in this
  release** — the Thai translations keep those same letter references.

---

## Phase A — Thai content pipeline

### Task 1: Parser support for the Thai block (TDD)

**Files:** Modify `src/lib/content/types.ts`, `src/lib/content/parse.ts`; Test `src/lib/content/parse.test.ts`

- [ ] **Step 1: Add the field to `types.ts`** — in `ParsedQuestion`, after `explanation`:

```ts
  explanation: string;
  /** Thai translation of `explanation`; null until the bank is translated. */
  explanationTh: string | null;
```

- [ ] **Step 2: Write the failing tests** (append inside the existing `describe('parseBank', …)`):

```ts
  it('parses a Thai explanation block after the English one', () => {
    const withTh = FIXTURE.replace(
      '> **Why:** Because it is.',
      '> **Why:** Because it is.\n> **ทำไม:** เพราะว่ามันเป็นเช่นนั้น\n> บรรทัดที่สอง',
    );
    const q2 = parseBank(withTh).questions[1];
    expect(q2.explanation).toBe('Because it is.');
    expect(q2.explanationTh).toBe('เพราะว่ามันเป็นเช่นนั้น\nบรรทัดที่สอง');
  });

  it('leaves explanationTh null when there is no Thai block', () => {
    expect(parseBank(FIXTURE).questions[0].explanationTh).toBeNull();
  });

  it('does not absorb the Thai block into the English explanation', () => {
    const withTh = FIXTURE.replace(
      '> **Why:** Confidentiality means no unauthorized disclosure.\n> Privacy invasion is a disclosure failure.',
      '> **Why:** Confidentiality means no unauthorized disclosure.\n> Privacy invasion is a disclosure failure.\n> **ทำไม:** การรักษาความลับ',
    );
    const q1 = parseBank(withTh).questions[0];
    expect(q1.explanation).toBe(
      'Confidentiality means no unauthorized disclosure.\nPrivacy invasion is a disclosure failure.',
    );
    expect(q1.explanationTh).toBe('การรักษาความลับ');
  });

  it('still throws when the English Why block is missing but Thai is present', () => {
    const broken = FIXTURE.replace('> **Why:** Because it is.', '> **ทำไม:** เพราะว่า');
    expect(() => parseBank(broken)).toThrow(/Q2/);
  });
```

- [ ] **Step 3: Run `npm test`** — the four new tests must FAIL before you implement.

- [ ] **Step 4: Implement in `parse.ts`.** Add the constant beside `WHY_START`:

```ts
const WHY_TH_START = /^> \*\*ทำไม:\*\* (.*)$/;
```

Then, in the question branch, the English continuation loop must stop at the Thai
heading, and a Thai block is collected the same way. Replace the existing Why block
with:

```ts
      const why: string[] = [];
      const wm = i < lines.length ? lines[i].match(WHY_START) : null;
      if (wm) {
        why.push(wm[1]);
        i++;
        while (i < lines.length) {
          const cm = lines[i].match(WHY_CONT);
          if (
            !cm ||
            WHY_START.test(lines[i]) ||
            WHY_TH_START.test(lines[i]) ||
            ANSWER_LINE.test(lines[i])
          ) break;
          why.push(cm[1] ?? '');
          i++;
        }
      }

      const whyTh: string[] = [];
      const tm = i < lines.length ? lines[i].match(WHY_TH_START) : null;
      if (tm) {
        whyTh.push(tm[1]);
        i++;
        while (i < lines.length) {
          const cm = lines[i].match(WHY_CONT);
          if (
            !cm ||
            WHY_START.test(lines[i]) ||
            WHY_TH_START.test(lines[i]) ||
            ANSWER_LINE.test(lines[i])
          ) break;
          whyTh.push(cm[1] ?? '');
          i++;
        }
      }
```

and extend the pushed object:

```ts
        explanation: why.join('\n').trim(),
        explanationTh: whyTh.length ? whyTh.join('\n').trim() : null,
```

The `if (why.length === 0) throw …` guard stays exactly as it is — a Thai-only
question is still an error.

- [ ] **Step 5: Run `npm test`** — all tests pass (33 existing + 4 new = 37).

- [ ] **Step 6: Commit**

```bash
git add src/lib/content/types.ts src/lib/content/parse.ts src/lib/content/parse.test.ts
git commit -m "feat(parser): parse the Thai explanation block

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 2: Schema column, seed and validator

**Files:** Modify `src/db/schema.ts`, `scripts/seed.ts`, `scripts/validate-content.ts`

- [ ] **Step 1: Add the column** in `src/db/schema.ts`, in the `questions` table right after `explanation`:

```ts
  explanation: text('explanation').notNull(),
  explanationTh: text('explanationTh'),
```

Nullable on purpose: the column ships before the translations do.

- [ ] **Step 2: Seed it.** In `scripts/seed.ts`, add `explanationTh: q.explanationTh,`
to the `values` object built for each question (it is used by both the INSERT and the
UPDATE path, so one addition covers both).

- [ ] **Step 3: Validate it.** In `scripts/validate-content.ts`, inside the per-question
loop, add — but make it a *warning* for now so the gate stays green until Task 9 lands:

```ts
  if (!q.explanationTh) missingThai.push(q.number);
```

with `const missingThai: number[] = [];` declared beside `errors`, and after the loop:

```ts
if (missingThai.length > 0) {
  console.warn(
    `⚠ ${missingThai.length} question(s) still have no Thai explanation ` +
      `(first few: ${missingThai.slice(0, 5).join(', ')})`,
  );
}
```

Task 9 promotes this to a hard error.

- [ ] **Step 4: Verify** — `npx tsc --noEmit && npm run lint && npm test && env -u DATABASE_URL npm run build && npm run validate:content`. The validator should now print the ⚠ line reporting 285 missing.

- [ ] **Step 5: Apply the column to the database**

```bash
set -a; . ./.env.local; set +a
npx drizzle-kit push --force
```

Expect an additive `ALTER TABLE "question" ADD COLUMN "explanationTh" text;`. Retry on a Neon DNS failure.

- [ ] **Step 6: Commit**

```bash
git add src/db/schema.ts scripts/seed.ts scripts/validate-content.ts
git commit -m "feat(db): add explanationTh column, seed and validate it

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Translation tasks (3–8) — shared instructions

Tasks 3–8 are identical in shape, one per question range. **Read this block once; it
applies to all six.** These are judgement-heavy language tasks, not coding tasks —
dispatch one subagent each.

**Input:** `content/iso-27001-li/bank.md` (read only your range's questions).
**Output:** `content/iso-27001-li/th/th-<range>.md` — a fragment file containing ONLY
the Thai blocks, keyed by question number, in this exact shape:

```markdown
### Q1
> **ทำไม:** การรักษาความลับหมายถึงข้อมูลจะไม่ถูกเปิดเผยต่อผู้ที่ไม่ได้รับอนุญาต
> การเข้าถึงข้อมูลผู้ป่วยโดยไม่ได้รับอนุญาตจึงเป็นการละเมิดความเป็นส่วนตัว

### Q2
> **ทำไม:** …
```

Do NOT edit `bank.md` — Task 9 merges these fragments. Do NOT commit.

**Translation requirements** (spec §3.2):
1. Translate meaning for a Thai IT professional sitting an English-language exam.
   Natural Thai, not word-for-word.
2. **Keep in English, never transliterate:** clause numbers (`6.1.3`), Annex A
   identifiers (`A.5.15`), standard names (`ISO/IEC 27001:2022`, `ISO 9001`),
   and any option letter the text names (`option B` → `ตัวเลือก B`).
3. **Use this glossary consistently** — every batch must agree:

   | English | Thai |
   |---|---|
   | information security | ความมั่นคงปลอดภัยสารสนเทศ |
   | confidentiality | การรักษาความลับ |
   | integrity | ความถูกต้องสมบูรณ์ |
   | availability | ความพร้อมใช้งาน |
   | asset | สินทรัพย์ |
   | threat | ภัยคุกคาม |
   | vulnerability | ช่องโหว่ |
   | risk assessment | การประเมินความเสี่ยง |
   | risk treatment | การจัดการความเสี่ยง |
   | control | มาตรการควบคุม |
   | nonconformity | ความไม่สอดคล้อง |
   | corrective action | การปฏิบัติการแก้ไข |
   | internal audit | การตรวจประเมินภายใน |
   | management review | การทบทวนของฝ่ายบริหาร |
   | ISMS | ระบบบริหารจัดการความมั่นคงปลอดภัยสารสนเทศ (ISMS) |
   | Statement of Applicability | เอกสารแสดงการบังคับใช้ (SoA) |
   | certification body | หน่วยรับรอง |
   | preventive / detective / corrective control | มาตรการเชิงป้องกัน / เชิงตรวจจับ / เชิงแก้ไข |

4. Where the English flags a marked-answer-vs-community disagreement, keep that
   sentence in the Thai.
5. Target length within ±40% of the English. Much longer usually means you added
   commentary — don't.
6. Never a bare `>` line inside a block (the parser treats `>` alone as an empty
   continuation line, which is fine, but avoid it for tidiness). No `**` other than
   the opening `**ทำไม:**`.

**Completion check before reporting:**

```bash
cd /project/src/exam.nanoteofficial.me
f=content/iso-27001-li/th/th-<range>.md
grep -c '^### Q' $f          # must equal the range size
grep -c '^> \*\*ทำไม:\*\*' $f  # must equal the range size
grep -o '^### Q[0-9]*' $f | sed 's/### Q//' | sort -n | awk 'NR==1{print "first",$1} END{print "last",$1}'
```

**Report:** status, the three counts, any question whose English you found ambiguous
or whose meaning you were unsure how to render, and any term you had to translate
that is not in the glossary (so the controller can keep the batches consistent).

### Task 3: Translate Q1–Q50
- [ ] Follow the shared instructions for questions 1–50 → `content/iso-27001-li/th/th-001-050.md`. Counts must be 50.

### Task 4: Translate Q51–Q100
- [ ] Same, questions 51–100 → `th-051-100.md`. Counts must be 50.

### Task 5: Translate Q101–Q150
- [ ] Same, questions 101–150 → `th-101-150.md`. Counts must be 50.

### Task 6: Translate Q151–Q200
- [ ] Same, questions 151–200 → `th-151-200.md`. Counts must be 50.

### Task 7: Translate Q201–Q250
- [ ] Same, questions 201–250 → `th-201-250.md`. Counts must be 50.

### Task 8: Translate Q251–Q285
- [ ] Same, questions 251–285 → `th-251-285.md`. Counts must be **35**.

---

### Task 9: Merge translations into bank.md and enforce

**Files:** Create `scripts/merge-th.ts`; modify `content/iso-27001-li/bank.md`, `scripts/validate-content.ts`

- [ ] **Step 1: Write the merge script** — it inserts each Thai block immediately after
that question's English Why block. Doing this with a script rather than by hand keeps
the 285 insertions exact and repeatable.

```ts
// scripts/merge-th.ts — splice content/iso-27001-li/th/*.md into bank.md
import { readFileSync, writeFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

const dir = join(process.cwd(), 'content', 'iso-27001-li');
const thDir = join(dir, 'th');

// number -> thai block lines (already '> '-prefixed)
const th = new Map<number, string[]>();
for (const file of readdirSync(thDir).sort()) {
  if (!file.endsWith('.md')) continue;
  let current: number | null = null;
  for (const line of readFileSync(join(thDir, file), 'utf8').split(/\r?\n/)) {
    const h = line.match(/^### Q(\d+)\s*$/);
    if (h) { current = Number(h[1]); th.set(current, []); continue; }
    if (current !== null && line.startsWith('>')) th.get(current)!.push(line);
  }
}
console.log(`loaded ${th.size} Thai blocks`);

const lines = readFileSync(join(dir, 'bank.md'), 'utf8').split(/\r?\n/);
const out: string[] = [];
let q: number | null = null;
let inWhy = false;

const flush = () => {
  if (q !== null && inWhy) {
    const block = th.get(q);
    if (block?.length) out.push(...block);
    inWhy = false;
  }
};

for (const line of lines) {
  const h = line.match(/^### Q(\d+)\b/);
  if (h) { flush(); q = Number(h[1]); out.push(line); continue; }
  if (/^> \*\*ทำไม:\*\*/.test(line)) continue;         // drop any previous merge
  if (/^> \*\*Why:\*\*/.test(line)) { inWhy = true; out.push(line); continue; }
  if (inWhy && !line.startsWith('>')) { flush(); }
  out.push(line);
}
flush();

writeFileSync(join(dir, 'bank.md'), out.join('\n'));
console.log('✓ merged Thai blocks into bank.md');
```

Note it is **idempotent** — it strips any existing `ทำไม` lines first, so it can be
re-run after fixing a translation.

- [ ] **Step 2: Add the npm script** to `package.json`: `"merge:th": "tsx scripts/merge-th.ts"`.

- [ ] **Step 3: Bump the bank version** — in `content/iso-27001-li/bank.md` frontmatter, `version: 1.1.0`.

- [ ] **Step 4: Run the merge and check**

```bash
npm run merge:th
grep -c '^> \*\*Why:\*\*' content/iso-27001-li/bank.md      # 285
grep -c '^> \*\*ทำไม:\*\*' content/iso-27001-li/bank.md      # 285
npm run derive:questions-only                                # regenerate; must still strip all '>' lines
grep -c '^>' content/iso-27001-li/questions-only.md          # 0
```

- [ ] **Step 5: Promote the validator warning to an error.** In `scripts/validate-content.ts`
replace the `missingThai` warning block with:

```ts
for (const n of missingThai) errors.push(`Q${n}: missing Thai explanation`);
```

and extend the success line to mention Thai coverage. Then `npm run validate:content`
must print ✓ with 285 questions.

- [ ] **Step 6: Full gate + reseed**

```bash
npx tsc --noEmit && npm run lint && npm test && env -u DATABASE_URL npm run build && npm run validate:content
set -a; . ./.env.local; set +a
npm run seed        # expect "0 inserted, 285 updated"; retry on Neon DNS failure
```

- [ ] **Step 7: Commit**

```bash
git add scripts/merge-th.ts package.json content/iso-27001-li/ scripts/validate-content.ts
git commit -m "content: Thai explanations for all 285 questions (bank v1.1.0)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

## Phase B — UI foundations

### Task 10: Language cookie, dictionary and Thai font

**Files:** Create `src/lib/lang.ts`, `src/lib/i18n.ts`, `src/components/LangToggle.tsx`, `src/server/actions/prefs.ts`; modify `src/app/layout.tsx`

- [ ] **Step 1: `src/lib/lang.ts`** — server-side cookie read, so the first paint is correct.

```ts
import { cookies } from 'next/headers';

export const LANGS = ['en', 'th'] as const;
export type Lang = (typeof LANGS)[number];
export const LANG_COOKIE = 'lang';

function isLang(v: string | undefined): v is Lang {
  return v === 'en' || v === 'th';
}

/** The visitor's language, defaulting to English. Server components only. */
export async function getLang(): Promise<Lang> {
  const v = (await cookies()).get(LANG_COOKIE)?.value;
  return isLang(v) ? v : 'en';
}
```

- [ ] **Step 2: `src/server/actions/prefs.ts`**

```ts
'use server';

import { cookies } from 'next/headers';
import { revalidatePath } from 'next/cache';
import { LANG_COOKIE, type Lang } from '@/lib/lang';

const ONE_YEAR = 60 * 60 * 24 * 365;

export async function setLang(lang: Lang) {
  if (lang !== 'en' && lang !== 'th') throw new Error('Invalid language');
  (await cookies()).set(LANG_COOKIE, lang, {
    maxAge: ONE_YEAR, path: '/', sameSite: 'lax',
  });
  revalidatePath('/', 'layout');
}
```

- [ ] **Step 3: `src/lib/i18n.ts`** — one flat dictionary. Include every user-visible
string in the app; the list below is the required minimum, add any you find while
doing Task 15.

```ts
import type { Lang } from './lang';

const dict = {
  // nav / chrome
  'nav.subjects':    { en: 'Subjects',        th: 'วิชา' },
  'nav.results':     { en: 'My results',      th: 'ผลของฉัน' },
  'nav.admin':       { en: 'Admin',           th: 'ผู้ดูแล' },
  'nav.signOut':     { en: 'Sign out',        th: 'ออกจากระบบ' },
  'nav.signIn':      { en: 'Sign in',         th: 'เข้าสู่ระบบ' },
  // subject / start
  'subject.pick':        { en: 'Pick a subject',      th: 'เลือกวิชา' },
  'subject.questions':   { en: 'questions',           th: 'ข้อ' },
  'practice.title':      { en: 'Practice',            th: 'ฝึกทำข้อสอบ' },
  'practice.blurb':      { en: 'Instant feedback with an explanation after every answer.',
                           th: 'ดูเฉลยพร้อมคำอธิบายทันทีหลังตอบทุกข้อ' },
  'practice.start':      { en: 'Start',               th: 'เริ่ม' },
  'exam.title':          { en: 'Exam simulation',     th: 'จำลองการสอบ' },
  'exam.blurb':          { en: 'Timed, with no feedback until you submit.',
                           th: 'จับเวลา ไม่แสดงเฉลยจนกว่าจะส่งข้อสอบ' },
  'exam.begin':          { en: 'Begin',               th: 'เริ่มสอบ' },
  'exam.minutes':        { en: 'min',                 th: 'นาที' },
  // runner
  'q.of':            { en: 'Question {n} of {total}', th: 'ข้อ {n} จาก {total}' },
  'q.scenario':      { en: 'Scenario',        th: 'สถานการณ์' },
  'q.correct':       { en: '✓ Correct',       th: '✓ ถูกต้อง' },
  'q.wrong':         { en: '✗ Not quite — the correct answer is highlighted above',
                       th: '✗ ยังไม่ถูก — คำตอบที่ถูกต้องถูกไฮไลต์ไว้ด้านบน' },
  'q.community':     { en: 'Community',       th: 'ผลโหวตจากผู้เรียน' },
  'q.previous':      { en: '← Previous',      th: '← ก่อนหน้า' },
  'q.next':          { en: 'Next →',          th: 'ถัดไป →' },
  'q.finish':        { en: 'Finish session',  th: 'จบการฝึก' },
  'q.answered':      { en: 'Answered',        th: 'ตอบแล้ว' },
  'q.showEnglish':   { en: 'Show English',    th: 'ดูต้นฉบับภาษาอังกฤษ' },
  'q.showThai':      { en: 'ดูภาษาไทย',       th: 'ดูภาษาไทย' },
  // exam runner
  'exam.flag':       { en: 'Flag for review', th: 'ทำเครื่องหมายไว้ทบทวน' },
  'exam.flagged':    { en: 'Flagged',         th: 'ทำเครื่องหมายแล้ว' },
  'exam.submit':     { en: 'Submit exam',     th: 'ส่งข้อสอบ' },
  'exam.keepWorking':{ en: 'Keep working',    th: 'ทำต่อ' },
  'exam.confirm':    { en: 'Submit exam?',    th: 'ยืนยันส่งข้อสอบ?' },
  'exam.cannotUndo': { en: 'This cannot be undone.', th: 'การส่งข้อสอบไม่สามารถย้อนกลับได้' },
  // results
  'results.title':   { en: 'My results',      th: 'ผลของฉัน' },
  'results.correct': { en: 'correct',         th: 'ข้อที่ถูก' },
  'results.review':  { en: 'Review',          th: 'ทบทวน' },
  'results.empty':   { en: 'No sessions yet — go practice!', th: 'ยังไม่มีประวัติ — เริ่มฝึกได้เลย' },
  'results.inProgress': { en: 'in progress — resume →', th: 'ยังไม่จบ — ทำต่อ →' },
  'results.why':     { en: 'Why',             th: 'ทำไม' },
  'results.notAnswered': { en: 'Not answered.', th: 'ไม่ได้ตอบ' },
  'results.delete':  { en: 'Delete',          th: 'ลบ' },
  'results.deleteConfirm': { en: 'Delete this result permanently?', th: 'ลบผลนี้ถาวรหรือไม่?' },
  'results.deleteCancel':  { en: 'Cancel',    th: 'ยกเลิก' },
  // misc
  'common.loading':  { en: 'Loading…',        th: 'กำลังโหลด…' },
} as const;

export type Key = keyof typeof dict;

/** Translate. `vars` fills {placeholders}. */
export function t(lang: Lang, key: Key, vars?: Record<string, string | number>): string {
  let s: string = dict[key][lang];
  if (vars) for (const [k, v] of Object.entries(vars)) s = s.replaceAll(`{${k}}`, String(v));
  return s;
}
```

- [ ] **Step 4: `src/components/LangToggle.tsx`** — client component, two small buttons.

```tsx
'use client';

import { useTransition } from 'react';
import { setLang } from '@/server/actions/prefs';
import type { Lang } from '@/lib/lang';

export default function LangToggle({ lang }: { lang: Lang }) {
  const [pending, start] = useTransition();
  return (
    <div className="flex items-center rounded-lg border border-line text-xs" role="group" aria-label="Language">
      {(['en', 'th'] as const).map((l) => (
        <button
          key={l}
          type="button"
          disabled={pending}
          aria-pressed={lang === l}
          onClick={() => start(() => { void setLang(l); })}
          className={`px-2.5 py-1 uppercase transition-colors first:rounded-l-md last:rounded-r-md disabled:opacity-50 ${
            lang === l ? 'bg-teal text-white' : 'text-muted hover:text-ink'
          }`}
        >
          {l}
        </button>
      ))}
    </div>
  );
}
```

- [ ] **Step 5: Thai font** — in `src/app/layout.tsx` add alongside the existing fonts:

```tsx
import { Noto_Sans_Thai } from 'next/font/google';
const notoThai = Noto_Sans_Thai({ subsets: ['thai'], variable: '--font-thai' });
```

put `notoThai.variable` on `<html>`, and in `globals.css` extend the sans stack so
Thai glyphs resolve:

```css
@theme inline {
  --font-display: var(--font-fraunces);
  --font-sans: var(--font-inter), var(--font-thai), ui-sans-serif, system-ui, sans-serif;
}
```

Also set `<html lang={lang}>` from `getLang()` (makes `layout.tsx` async).

- [ ] **Step 6: Verify + commit**

```bash
npx tsc --noEmit && npm run lint && env -u DATABASE_URL npm run build
git add src/lib/lang.ts src/lib/i18n.ts src/components/LangToggle.tsx src/server/actions/prefs.ts src/app/layout.tsx src/app/globals.css
git commit -m "feat(i18n): language cookie, dictionary, TH/EN toggle and Thai font

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 11: Dark mode

**Files:** Create `src/components/ThemeToggle.tsx`; modify `src/app/globals.css`, `src/app/layout.tsx`

- [ ] **Step 1: Dark tokens in `globals.css`.** Tailwind v4 needs the variant declared,
then the tokens overridden under `.dark`. Add after the existing `@theme` block:

```css
/* Class-based dark mode: the toggle writes `.dark` on <html>. */
@custom-variant dark (&:where(.dark, .dark *));

.dark {
  --color-paper: #17161a;
  --color-ink: #f5f3ef;
  --color-muted: #a8a29e;
  --color-faint: #78716c;
  --color-line: #33313a;
  --color-card: #201f24;
  --color-teal: #2dd4bf;
  --color-teal-soft: #10302c;
  --color-teal-line: #1c554d;
  --color-amber: #fbbf24;
  --color-good: #2dd4bf;
  --color-bad: #f87171;
}
```

The `--color-hall*`, `--color-sky` and `--color-timer` tokens are **not** overridden —
the exam simulator keeps its fixed palette in both modes, by design.

- [ ] **Step 2: Pre-paint script** in `src/app/layout.tsx`, inside `<head>`, so there is
no white flash before React hydrates:

```tsx
<script
  dangerouslySetInnerHTML={{
    __html: `(function(){try{var t=localStorage.getItem('theme');var d=t==='dark'||(!t&&matchMedia('(prefers-color-scheme:dark)').matches);document.documentElement.classList.toggle('dark',d)}catch(e){}})()`,
  }}
/>
```

This is the one sanctioned use of `dangerouslySetInnerHTML` in the project: the string
is a hard-coded literal with no interpolation and no user input. Add a comment saying
so, because the project rule is otherwise "never".

- [ ] **Step 3: `src/components/ThemeToggle.tsx`**

```tsx
'use client';

import { useEffect, useState } from 'react';

type Mode = 'light' | 'dark' | 'system';

function apply(mode: Mode) {
  const dark = mode === 'dark'
    || (mode === 'system' && window.matchMedia('(prefers-color-scheme: dark)').matches);
  document.documentElement.classList.toggle('dark', dark);
  if (mode === 'system') localStorage.removeItem('theme');
  else localStorage.setItem('theme', mode);
}

export default function ThemeToggle() {
  const [mode, setMode] = useState<Mode>('system');

  useEffect(() => {
    const stored = localStorage.getItem('theme');
    setMode(stored === 'dark' || stored === 'light' ? stored : 'system');
  }, []);

  // Follow the OS while in system mode.
  useEffect(() => {
    if (mode !== 'system') return;
    const mq = window.matchMedia('(prefers-color-scheme: dark)');
    const onChange = () => apply('system');
    mq.addEventListener('change', onChange);
    return () => mq.removeEventListener('change', onChange);
  }, [mode]);

  const cycle = () => {
    const next: Mode = mode === 'system' ? 'light' : mode === 'light' ? 'dark' : 'system';
    setMode(next);
    apply(next);
  };

  const label = mode === 'system' ? 'Theme: system' : mode === 'light' ? 'Theme: light' : 'Theme: dark';
  return (
    <button
      type="button" onClick={cycle} title={label} aria-label={label}
      className="rounded-lg border border-line px-2.5 py-1 text-xs text-muted transition-colors hover:text-ink"
    >
      {mode === 'system' ? '◐' : mode === 'light' ? '☀' : '☾'}
    </button>
  );
}
```

Renders `◐` until mounted, so there is no hydration mismatch (server has no
`localStorage`).

- [ ] **Step 4: Audit contrast.** Every screen in dark mode must keep body text at
≥ 4.5:1 against its background. Check especially: `text-muted` on `bg-paper`,
`text-faint` on `bg-card`, the amber explanation panel, and the ✓/✗ markers.
Fix by lightening the token, not by special-casing components.

- [ ] **Step 5: Verify + commit**

```bash
npx tsc --noEmit && npm run lint && env -u DATABASE_URL npm run build
git add src/app/globals.css src/app/layout.tsx src/components/ThemeToggle.tsx
git commit -m "feat(theme): dark mode following the OS with a manual override

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 12: Shield Keeper mascot

**Files:** Create `src/components/Mascot.tsx`

- [ ] **Step 1: Write the component.** Inline SVG, `currentColor`-friendly, four states.

```tsx
export type MascotState = 'idle' | 'thinking' | 'correct' | 'wrong';

/**
 * The Shield Keeper. Inline SVG so it inherits the theme and needs no assets.
 * Deliberately never rendered inside the exam simulator: a reacting character
 * would both break the testing-room tone and hint at correctness.
 */
export default function Mascot({
  state = 'idle',
  size = 64,
  className = '',
}: {
  state?: MascotState;
  size?: number;
  className?: string;
}) {
  const body = state === 'wrong' ? 'fill-faint' : 'fill-teal';
  const face = state === 'wrong' ? 'fill-card' : 'fill-teal-soft';
  const anim =
    state === 'correct' ? 'mascot-nod'
    : state === 'thinking' ? 'mascot-think'
    : state === 'wrong' ? 'mascot-squash'
    : 'mascot-bob';

  return (
    <svg
      width={size} height={size * 1.13} viewBox="0 0 76 86"
      className={`${anim} ${className}`} role="img"
      aria-label={
        state === 'correct' ? 'Correct' :
        state === 'wrong' ? 'Not quite' :
        state === 'thinking' ? 'Checking your answer' : 'Shield Keeper'
      }
    >
      <path d="M38 6 L68 18 V44 C68 62 54 74 38 80 C22 74 8 62 8 44 V18 Z" className={body} />
      <path d="M38 14 L60 23 V44 C60 57 50 66 38 71 C26 66 16 57 16 44 V23 Z" className={face} />
      {state === 'correct' ? (
        <>
          <path d="M25 39 Q30 34 35 39" className="stroke-ink" strokeWidth="2.6" fill="none" strokeLinecap="round" />
          <path d="M41 39 Q46 34 51 39" className="stroke-ink" strokeWidth="2.6" fill="none" strokeLinecap="round" />
          <path d="M30 49 Q38 58 46 49" className="stroke-ink" strokeWidth="2.8" fill="none" strokeLinecap="round" />
        </>
      ) : state === 'wrong' ? (
        <>
          <line x1="27" y1="37" x2="33" y2="43" className="stroke-ink" strokeWidth="2.6" strokeLinecap="round" />
          <line x1="33" y1="37" x2="27" y2="43" className="stroke-ink" strokeWidth="2.6" strokeLinecap="round" />
          <circle cx="46" cy="40" r="3.4" className="fill-ink" />
          <path d="M31 54 Q38 49 45 54" className="stroke-ink" strokeWidth="2.6" fill="none" strokeLinecap="round" />
        </>
      ) : (
        <>
          <circle cx="30" cy="40" r="3.4" className="fill-ink mascot-blink" />
          <circle cx="46" cy="40" r="3.4" className="fill-ink mascot-blink" />
          <path d="M31 50 Q38 55 45 50" className="stroke-ink" strokeWidth="2.6" fill="none" strokeLinecap="round" />
        </>
      )}
    </svg>
  );
}
```

- [ ] **Step 2: Keyframes** go in `globals.css` as part of Task 13 (`mascot-bob`,
`mascot-nod`, `mascot-think`, `mascot-squash`, `mascot-blink`). Until Task 13 lands the
component renders correctly but still.

- [ ] **Step 3: Verify + commit**

```bash
npx tsc --noEmit && npm run lint && env -u DATABASE_URL npm run build
git add src/components/Mascot.tsx
git commit -m "feat: Shield Keeper mascot component

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 13: Animation layer

**Files:** Modify `src/app/globals.css`

- [ ] **Step 1: Add the keyframes and utilities**, all gated on reduced-motion.

```css
@media (prefers-reduced-motion: no-preference) {
  @keyframes rise-in   { from { opacity: 0; transform: translateY(8px) } to { opacity: 1; transform: none } }
  @keyframes fade-in   { from { opacity: 0 } to { opacity: 1 } }
  @keyframes ring-once { from { box-shadow: 0 0 0 0 color-mix(in srgb, var(--color-good) 45%, transparent) }
                         to   { box-shadow: 0 0 0 12px transparent } }
  @keyframes mascot-bob    { 0%,100% { transform: translateY(0) } 50% { transform: translateY(-5px) } }
  @keyframes mascot-nod    { 0%,100% { transform: rotate(0) } 30% { transform: rotate(-9deg) } 60% { transform: rotate(6deg) } }
  @keyframes mascot-think  { 0%,100% { transform: rotate(-3deg) } 50% { transform: rotate(3deg) } }
  @keyframes mascot-squash { 0%,100% { transform: scaleY(1) } 50% { transform: scaleY(.93) } }
  @keyframes mascot-blink  { 0%,92%,100% { transform: scaleY(1) } 96% { transform: scaleY(.1) } }

  .animate-rise   { animation: rise-in .28s ease-out both }
  .animate-fade   { animation: fade-in .25s ease-out both }
  .animate-ring   { animation: ring-once .9s ease-out 1 }
  .mascot-bob     { animation: mascot-bob 3s ease-in-out infinite }
  .mascot-nod     { animation: mascot-nod .9s ease-in-out 2; transform-origin: 50% 90% }
  .mascot-think   { animation: mascot-think 1.1s ease-in-out infinite; transform-origin: 50% 90% }
  .mascot-squash  { animation: mascot-squash 1.4s ease-in-out 2; transform-origin: 50% 100% }
  .mascot-blink   { animation: mascot-blink 4s infinite; transform-origin: center }
}

/* Colour/size transitions are cheap and safe; still skipped under reduced motion. */
@media (prefers-reduced-motion: no-preference) {
  .transition-cell { transition: background-color .2s ease, color .2s ease, transform .2s ease }
  .transition-bar  { transition: width .35s cubic-bezier(.4,0,.2,1) }
}
```

- [ ] **Step 2: Apply them** (this is the only step that touches other files, and it is
deliberately small — the wiring happens in Task 15 where those files are edited anyway):
`animate-rise` on the practice explanation panel, `animate-ring` on the revealed
correct choice, `transition-cell` on question-map buttons, `transition-bar` on the
progress bar, `animate-fade` on page-level content wrappers.

- [ ] **Step 3: Verify + commit**

```bash
env -u DATABASE_URL npm run build && npm run lint
git add src/app/globals.css
git commit -m "feat(motion): animation utilities, all gated on prefers-reduced-motion

Co-Authored-By: Claude <noreply@anthropic.com>"
```

## Phase C — Feature, wiring and polish

### Task 14: Delete a saved result

**Files:** Modify `src/server/actions/sessions.ts`; create `src/components/DeleteSessionButton.tsx`; modify `src/app/(app)/app/results/page.tsx` and `src/app/(app)/app/[subject]/results/[sessionId]/page.tsx`

- [ ] **Step 1: The action.** Append to `src/server/actions/sessions.ts`:

```ts
export async function deleteSession(sessionId: string) {
  const userId = await requireUser();
  const db = getDb();
  // Ownership is enforced in the WHERE clause itself, so a forged id belonging to
  // another user deletes nothing rather than erroring in a way that confirms it exists.
  await db.delete(examSessions)
    .where(and(eq(examSessions.id, sessionId), eq(examSessions.userId, userId)));
  // session_answer rows follow via ON DELETE CASCADE.
  revalidatePath('/app/results');
}
```

Add `revalidatePath` to the `next/cache` imports at the top of the file.

- [ ] **Step 2: `src/components/DeleteSessionButton.tsx`** — two-step, no `window.confirm`
(it is inconsistent across browsers and untranslatable):

```tsx
'use client';

import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { deleteSession } from '@/server/actions/sessions';

export default function DeleteSessionButton({
  sessionId, labels, redirectTo,
}: {
  sessionId: string;
  labels: { delete: string; confirm: string; cancel: string };
  redirectTo?: string;
}) {
  const [armed, setArmed] = useState(false);
  const [pending, start] = useTransition();
  const router = useRouter();

  if (!armed) {
    return (
      <button type="button" onClick={() => setArmed(true)}
        className="rounded-md px-2 py-1 text-xs text-faint transition-colors hover:text-bad">
        {labels.delete}
      </button>
    );
  }

  return (
    <span className="flex items-center gap-2 text-xs">
      <span className="text-muted">{labels.confirm}</span>
      <button type="button" disabled={pending}
        onClick={() => start(async () => {
          await deleteSession(sessionId);
          if (redirectTo) router.push(redirectTo);
        })}
        className="rounded-md bg-bad px-2 py-1 font-medium text-white disabled:opacity-50">
        {labels.delete}
      </button>
      <button type="button" onClick={() => setArmed(false)} className="text-muted hover:text-ink">
        {labels.cancel}
      </button>
    </span>
  );
}
```

- [ ] **Step 3: Use it** — one per row on `/app/results`, and once on the result detail
page with `redirectTo="/app/results"` (the page it deletes would otherwise 404 under
the user). Pass labels from `t(lang, 'results.delete' | 'results.deleteConfirm' | 'results.deleteCancel')`.

- [ ] **Step 4: Verify manually against the live DB later (Task 17).** For now:
`npx tsc --noEmit && npm run lint && env -u DATABASE_URL npm run build`.

- [ ] **Step 5: Commit**

```bash
git add src/server/actions/sessions.ts src/components/DeleteSessionButton.tsx "src/app/(app)/app/results/page.tsx" "src/app/(app)/app/[subject]/results/[sessionId]/page.tsx"
git commit -m "feat: delete a saved result, with a confirm step

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 15: Wire language, mascot and motion through the app

This is the large integration task. Work file by file; run `npx tsc --noEmit` after each.

**Files:** `src/app/(app)/layout.tsx`, `src/app/(app)/app/page.tsx`, `src/app/(app)/app/[subject]/page.tsx`, `src/app/(app)/app/results/page.tsx`, `src/app/(app)/app/[subject]/results/[sessionId]/page.tsx`, `src/app/page.tsx`, `src/app/signin/page.tsx`, `src/app/pending/page.tsx`, `src/components/{SiteHeader,QuestionCard,PracticeRunner,ExamRunner,VoteBar}.tsx`, the two runner pages.

- [ ] **Step 1: Header controls.** `SiteHeader` gains optional `lang` and renders
`<LangToggle lang={lang} />` + `<ThemeToggle />` before the `right` slot, so both
appear on every page including signed-out ones. Pages pass `lang` from `getLang()`.

- [ ] **Step 2: Server components** — replace every hard-coded string with
`t(lang, 'key')`, `lang` coming from `await getLang()`.

- [ ] **Step 3: Client components take strings as props, not a dictionary.** `PracticeRunner`,
`ExamRunner`, `QuestionCard` and `VoteBar` are client components; do **not** import
`i18n` there (it would ship the whole dictionary and read cookies client-side).
Give each a `labels` prop built on the server, e.g.:

```tsx
// in the practice page (server)
<PracticeRunner
  sessionId={sess.id}
  subject={subject}
  questions={questions}
  lang={lang}
  labels={{
    scenario: t(lang, 'q.scenario'),
    questionOf: t(lang, 'q.of'),      // contains {n} and {total}; runner fills them
    correct: t(lang, 'q.correct'),
    wrong: t(lang, 'q.wrong'),
    community: t(lang, 'q.community'),
    previous: t(lang, 'q.previous'),
    next: t(lang, 'q.next'),
    finish: t(lang, 'q.finish'),
    answered: t(lang, 'q.answered'),
    showEnglish: t(lang, 'q.showEnglish'),
  }}
/>
```

- [ ] **Step 4: Bilingual explanation rendering.** `answerQuestion` must return the Thai
too. In `src/server/actions/sessions.ts`, extend `AnswerResult` with
`explanationTh?: string | null` and include `q.explanationTh` in the practice-mode
return. In `PracticeRunner`, when `lang === 'th'` and `explanationTh` is present,
render the Thai and show a small `showEnglish` toggle that reveals the English
underneath; otherwise render the English alone. Apply the same rule on the results
review page (server-side, so no extra prop plumbing).

- [ ] **Step 5: Mascot placement.** `PracticeRunner` sidebar: `idle` normally,
`thinking` while the answer transition is pending, `correct`/`wrong` once a result
exists for the current question. Results summary page: `correct` when the score is
≥ 70%, else `wrong`, `size={80}`. Empty state on `/app/results`: `idle`.
**Do not add it to `ExamRunner`.**

- [ ] **Step 6: Motion classes** — apply the Task 13 utilities as listed there.

- [ ] **Step 7: Verify** — full gate. Then `npm run dev` and click through both
languages in both themes, checking that no English string is left behind in Thai mode
(grep your diff for quoted user-facing strings that are not `t(...)` calls).

- [ ] **Step 8: Commit**

```bash
git add src/app src/components src/server/actions/sessions.ts
git commit -m "feat: wire TH/EN, mascot and motion through the app

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 16: Responsive pass

**Files:** whichever templates need fixing.

- [ ] **Step 1: Capture the current state.** With `npm run dev` running, screenshot every
screen at 390 / 768 / 1280 in both themes using Playwright (launch with
`chromiumSandbox: false` — Chrome cannot sandbox as root here). Screens: `/`,
`/signin`, `/pending`, `/app`, `/app/iso-27001-li`, a practice runner, an exam runner,
a finished result, `/app/results`, `/admin`. Assert
`document.documentElement.scrollWidth === clientWidth` at every width and fail loudly
if not.

- [ ] **Step 2: Fix the three known weak points** (spec §7):
  - **Exam navigator**: below `md`, render the question grid as a horizontally
    scrollable strip above the card (`flex overflow-x-auto` with `shrink-0` cells),
    not a squeezed column.
  - **Results review**: choice rows must let the ✓/✗ marker sit on its own line at
    390px rather than overlapping the text; stack the row instead of shrinking it.
  - **Subject overview**: the two start panels stack below `sm`, and the dark exam
    panel keeps its full padding rather than collapsing.

- [ ] **Step 3: Enforce the acceptance rules** — no horizontal page scroll at any width,
interactive targets ≥ 44px (the question-map cells are the risk: bump them on touch
widths), and no text below 12px.

- [ ] **Step 4: Re-screenshot and eyeball every image yourself** before claiming done.

- [ ] **Step 5: Commit**

```bash
git add src/app src/components
git commit -m "polish: responsive pass at 390/768/1280 in both themes

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 17: Live verification and release

- [ ] **Step 1: Full gate**

```bash
npm test && npx tsc --noEmit && npm run lint && npm run validate:content && env -u DATABASE_URL npm run build
```

`validate:content` must report 285 questions **with Thai coverage** and no errors.

- [ ] **Step 2: Reseed production** (translations changed the bank):

```bash
set -a; . ./.env.local; set +a
npm run seed     # expect "0 inserted, 285 updated"; retry on Neon DNS failure
```

- [ ] **Step 3: Deploy**

```bash
git push origin main
timeout 400 vercel deploy --prod --yes
```

Confirm it aliases `https://exam.nanoteofficial.me`.

- [ ] **Step 4: Verify on the live site** with a scripted browser pass. Mint a temporary
admin session by inserting a `session` row for the admin user and setting the
`__Secure-authjs.session-token` cookie; **delete the row afterwards**. Check:
  1. Landing renders in EN, toggle to TH, reload — still TH (cookie persisted).
  2. Dark toggle cycles system → light → dark and survives reload.
  3. Practice: answer a question in TH — Thai explanation shows, "show English"
     reveals the original, mascot reacts, explanation panel animates in.
  4. Exam: timer runs, **no mascot present**, no answer leakage, flag + resume work.
  5. Submit → results → review shows Thai explanations; delete that result and confirm
     it disappears from `/app/results` and from the database.
  6. Widths 390 / 768 / 1280: no horizontal scroll on any screen.
  7. With `prefers-reduced-motion: reduce` emulated, nothing animates.
  Then clean up every test session and answer row.

- [ ] **Step 5: Documentation** — update `CLAUDE.md` (repo) with: the `ทำไม` grammar
extension, `explanationTh`, the `lib/lang.ts` vs `lib/i18n.ts` split, the client-
components-take-labels-as-props rule, the dark-token rules (and that the hall palette
is intentionally fixed), the sanctioned `dangerouslySetInnerHTML` for the theme script,
and that the mascot is banned from the exam runner. Update `/project/CLAUDE.md`'s
project section to mention v1.1 (TH/EN, dark mode, mascot, delete).

- [ ] **Step 6: Tag**

```bash
git tag -a v1.1.0 -m "v1.1.0 — Thai explanations, dark mode, mascot, motion, responsive pass, delete results"
git push origin v1.1.0
```

---

## Self-Review Notes (performed at write time)

1. **Spec coverage:** bilingual explanations (Tasks 1–9, 15 ✓), TH/EN toggle (10, 15 ✓),
   dark mode (11 ✓), mascot (12, 15 ✓), animation (13, 15 ✓), responsive (16 ✓),
   delete result (14 ✓), verification + release (17 ✓).
2. **Placeholder scan:** no TBDs; every code step carries complete code. The
   translation tasks are inherently judgement work and carry the glossary plus exact
   output grammar and completion checks instead.
3. **Type consistency:** `explanationTh` is `string | null` in `ParsedQuestion`, a
   nullable `text` column, and `explanationTh?: string | null` on `AnswerResult`
   (optional there because exam mode returns `{}`). `Lang`, `MascotState` and the
   `labels` prop shapes are defined once and referenced consistently.
4. **Deliberate constraints carried forward:** choice order stays canonical (the Thai
   explanations inherit the same letter references); the mascot never appears in the
   exam runner; the hall palette is not themed.
5. **Known risk, documented not solved:** the Thai is machine-translated technical
   standards language. The batch reviews catch errors of meaning, and the UI always
   keeps the English one tap away, but a human spot-check is advised before relying
   on it for exam study.



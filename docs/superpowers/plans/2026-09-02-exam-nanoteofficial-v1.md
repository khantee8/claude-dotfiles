# exam.nanoteofficial.me v1.0.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship v1.0.0 of exam.nanoteofficial.me — a private, invite-only exam-practice web app whose first subject is PECB ISO/IEC 27001 Lead Implementer (285 questions extracted from source PDFs into curated, versioned markdown).

**Architecture:** Next.js 16 App Router app in its own repo at `/project/src/exam.nanoteofficial.me`. Question bank lives as markdown in git (`content/iso-27001-li/bank.md`), parsed by a pure TS parser and seeded into Neon Postgres via Drizzle. Auth.js v5 magic-link auth (Resend) with admin approval; the auth gate is a route-group layout — no middleware. Practice mode (light "calm study" UI) and timed exam simulation (dark "exam hall" UI) run off server actions; correct answers never reach the client before they're earned.

**Tech Stack:** Next.js 16, React 19, TypeScript, Tailwind v4, Auth.js v5 + Resend, Neon Postgres + Drizzle, Vitest (pure logic only), tsx for scripts, Vercel Hobby.

**Spec:** `docs/superpowers/specs/2026-09-02-exam-nanoteofficial-design.md` (in the dotfiles repo). One amendment to the spec's "no test runner" line: Vitest is included for the two pure-logic modules (`parse.ts`, `shuffle.ts`) only — they're the correctness-critical core. The release gate remains `npm run build` + `npx tsc --noEmit` + `npm run lint` + `npm run validate:content` (+ `npm test`).

**Reference project:** `/project/src/plan.nanoteofficial.me` uses the same stack (Auth.js v5 + Resend + Neon + Drizzle + Next 16). When any config in this plan disagrees with what actually works there or with `node_modules/next/dist/docs/`, follow the working reference/docs and note the deviation in the commit message.

**Verification gate for every task:** `npx tsc --noEmit` must pass before each commit (once Task 2 is done). Tasks with tests also run `npm test`.

---

## File Structure

```
/project/src/exam.nanoteofficial.me/          ← repo root (its own git repo, PRIVATE on GitHub)
  .gitignore                                  ← ignores /sources/, .env*, node_modules, .next
  sources/ISO27001-Lead-Implementer/*.pdf     ← raw PDFs (NOT committed)
  content/iso-27001-li/
    subject.json                              ← subject metadata + exam defaults
    extract/qa-001-050.md … qa-251-285.md     ← per-range extraction (committed, provenance)
    bank.md                                   ← MASTER curated bank (answers+votes+explanations)
    questions-only.md                         ← generated, no answer key
  scripts/
    validate-content.ts                       ← invariant checks on bank.md (no DB needed)
    derive-questions-only.ts                  ← bank.md → questions-only.md
    seed.ts                                   ← bank.md + subject.json → Postgres upsert
  drizzle.config.ts
  src/db/schema.ts                            ← all tables (Auth.js + app)
  src/db/index.ts                             ← lazy Neon+Drizzle singleton
  src/auth.ts                                 ← Auth.js v5 config (Resend, approval callback)
  src/app/api/auth/[...nextauth]/route.ts
  src/lib/content/types.ts                    ← parser types
  src/lib/content/parse.ts                    ← bank.md parser (pure)
  src/lib/content/parse.test.ts
  src/lib/exam/shuffle.ts                     ← seeded RNG + scenario-aware shuffle (pure)
  src/lib/exam/shuffle.test.ts
  src/server/actions/access.ts                ← requestAccess
  src/server/actions/sessions.ts              ← start/answer/flag/submit
  src/server/actions/admin.ts                 ← approve/reject
  src/app/globals.css                         ← brand tokens (paper/teal + exam-hall dark)
  src/app/layout.tsx                          ← root layout, fonts
  src/app/page.tsx                            ← public landing (subject catalog)
  src/app/signin/page.tsx                     ← magic-link form
  src/app/pending/page.tsx                    ← awaiting-approval page
  src/app/(app)/layout.tsx                    ← AUTH GATE (session + approvedAt)
  src/app/(app)/app/page.tsx                  ← subject picker
  src/app/(app)/app/results/page.tsx          ← history list
  src/app/(app)/app/[subject]/page.tsx        ← subject overview / start screens
  src/app/(app)/app/[subject]/practice/[sessionId]/page.tsx
  src/app/(app)/app/[subject]/exam/[sessionId]/page.tsx
  src/app/(app)/app/[subject]/results/[sessionId]/page.tsx
  src/app/(app)/admin/page.tsx                ← admin console (role check)
  src/components/PracticeRunner.tsx           ← client
  src/components/ExamRunner.tsx               ← client
  src/components/QuestionCard.tsx             ← shared question/choices presenter
  src/components/VoteBar.tsx
  src/components/SiteHeader.tsx
```

Executor context notes:
- **Task 1 and Tasks 3–8 (extraction) are PDF-reading tasks, not coding tasks.** They are token-heavy; dispatch one subagent per range if using subagent-driven-development.
- All paths below are relative to `/project/src/exam.nanoteofficial.me` unless absolute.
- This project's repo is independent of the `/project` dotfiles repo. Never `git add` from `/project` for project code.

---

### Task 1: Repo bootstrap + source quarantine

**Files:**
- Create: `.gitignore`, `README.md`
- Move: `ISO27001-Lead-Implementer/` → `sources/ISO27001-Lead-Implementer/`

- [ ] **Step 1: Init repo and move sources**

```bash
cd /project/src/exam.nanoteofficial.me
git init -b main
mkdir -p sources
mv ISO27001-Lead-Implementer sources/
```

- [ ] **Step 2: Write .gitignore** (before anything else, so PDFs can never be committed)

```gitignore
# raw source material — copyrighted, never commit
/sources/

# deps / build
node_modules/
.next/
out/

# env
.env
.env.*
!.env.example

# misc
.DS_Store
*.tsbuildinfo
.vercel
```

- [ ] **Step 3: Write README.md**

```markdown
# exam.nanoteofficial.me

Private exam-practice web app (invite-only). First subject: PECB ISO/IEC 27001
Lead Implementer.

- Question bank: `content/<subject>/bank.md` (source of truth, versioned) → seeded
  into Neon Postgres with `npm run seed`.
- Raw source PDFs live in `sources/` and are gitignored — this repo must stay
  **private**.
- Stack: Next.js 16, Auth.js v5 (Resend magic link), Neon + Drizzle, Tailwind v4.

## Commands
npm run dev · npm run build · npm run lint · npm test
npm run validate:content · npm run derive:questions-only · npm run seed
```

- [ ] **Step 4: Verify sources are ignored and commit**

```bash
cd /project/src/exam.nanoteofficial.me
git status --porcelain   # must NOT list anything under sources/
git add .gitignore README.md
git commit -m "chore: init repo, quarantine source PDFs"
```

---

### Task 2: Next.js 16 scaffold + dependencies

**Files:**
- Create: full Next.js scaffold (package.json, tsconfig.json, next.config.ts, postcss config, `src/app/*`), `.env.example`, `vitest.config.ts`

- [ ] **Step 1: Scaffold in a temp dir and copy in** (create-next-app refuses non-empty dirs)

```bash
cd /tmp && rm -rf exam-scaffold
npx create-next-app@latest exam-scaffold --typescript --tailwind --eslint --app --src-dir --use-npm --no-import-alias
# then copy everything except .git into the project:
cd /tmp/exam-scaffold
cp -r $(ls -A | grep -v '^\.git$') /project/src/exam.nanoteofficial.me/
```

If create-next-app's prompts differ (Next 16 CLI evolves), consult `node_modules/next/dist/docs/` or the context7 MCP tool — per CLAUDE.md, Next.js 16 APIs differ from training data. Turbopack default is fine.

- [ ] **Step 2: Install runtime + dev deps**

```bash
cd /project/src/exam.nanoteofficial.me
npm i next-auth@beta @auth/drizzle-adapter drizzle-orm @neondatabase/serverless
npm i -D drizzle-kit tsx vitest
```

- [ ] **Step 3: Add scripts to package.json** (merge into the scaffold's `scripts` block)

```json
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "test": "vitest run",
    "validate:content": "tsx scripts/validate-content.ts",
    "derive:questions-only": "tsx scripts/derive-questions-only.ts",
    "seed": "tsx scripts/seed.ts"
  }
}
```

- [ ] **Step 4: Write vitest.config.ts**

```ts
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: { include: ['src/**/*.test.ts'] },
});
```

- [ ] **Step 5: Write .env.example**

```bash
# Neon Postgres (unset is OK for build)
DATABASE_URL=

# Auth.js
AUTH_SECRET=            # npx auth secret
AUTH_RESEND_KEY=        # Resend API key (same account as plan.nanoteofficial.me)
AUTH_RESEND_FROM="ExamPrep <exam@nanoteofficial.me>"

# comma-separated emails that skip approval and get role=admin
ALLOWED_EMAILS=khantee9@gmail.com
```

- [ ] **Step 6: Verify build + commit**

```bash
npm run build && npx tsc --noEmit
git add -A && git commit -m "chore: scaffold Next.js 16 app with deps and scripts"
```

Expected: build succeeds with `DATABASE_URL` unset.

---

## Extraction Tasks (3–8) — shared instructions

Tasks 3–8 are identical in shape, one per question range. **Read this block once; it applies to all six.**

**Input:** `sources/ISO27001-Lead-Implementer/<range>.pdf` (questions) and `<range>-answer.pdf` (same pages + highlighted correct answer + community vote bars).
**Output:** `content/iso-27001-li/extract/qa-<range>.md` in the exact bank grammar below.

**Procedure per range:**
1. Read the *answer* PDF with the Read tool, 3–5 pages at a time, until all pages are consumed. The answer PDF alone contains everything: question text, choices, correct answer ("Correct Answer: X"), and community vote distribution. Use the questions PDF only when an answer page is illegible.
2. Transcribe every question into the grammar below, **in question-number order**. Fix obvious OCR artifacts (ligatures, broken words); do not paraphrase question or choice text.
3. When a question introduces a scenario ("Scenario N: …"), put the scenario text in a `## Scenario N` block *before* the first question that uses it, and strip the scenario prose out of the question body — keep only the actual question sentence(s). Questions saying "Refer to scenario N" get `[scenario: N]` with the reference sentence removed from the body.
4. Record the marked "Correct Answer" as truth. Record vote distribution when visible (e.g. `B 75%, A 25%`); if the bar is unreadable, omit the votes clause entirely.
5. Write a `> **Why:**` explanation for EVERY question: 2–4 sentences, plain language a Thai examinee reading English can follow. Explain why the correct choice is right; when it clarifies, add one line on why the tempting distractor is wrong. Cite ISO/IEC 27001:2022 / 27002 / 27000 clauses **only when confident**; otherwise explain conceptually with no clause number. Never invent clause numbers.
6. If a question has multiple correct answers (rare), write `Answer: B,C` (comma-joined, alphabetical).

**Bank grammar (parser contract — exact):**

```markdown
## Scenario 1
HealthGenic is a pediatric clinic that... (full scenario text, multiple paragraphs allowed)

### Q1 [scenario: 1] [topic: 1]
Which of the following indicates that the confidentiality of information was compromised?
- (A) Service interruptions due to the increased number of users
- (B) Invasion of patients' privacy
- (C) Modification of patients' medical reports
> **Answer: B** — votes: B 100%
> **Why:** Confidentiality means information is not disclosed to unauthorized parties.
> The unauthorized access to patients' sensitive information is a disclosure failure,
> which is exactly an invasion of privacy. Service interruptions affect availability,
> and report modification affects integrity.
```

Rules: heading `### Q<n>` with optional `[scenario: <n>]` then optional `[topic: <n>]`; choices as `- (A) text` (A–F, single line each); answer line `> **Answer: <keys>**` optionally followed by ` — votes: <K> <n>%, <K> <n>%`; explanation starts `> **Why:** ` and may continue on subsequent `> `-prefixed lines. No ✅ markers, no blank `> ` lines inside the Why block. Standalone questions have no `[scenario]` tag. `[topic: <n>]` comes from the "Topic N" banner on the page (default 1).

**Per-range completion check** (before commit):

```bash
grep -c '^### Q' content/iso-27001-li/extract/qa-<range>.md   # must equal range size
grep -c '^> \*\*Answer:' content/iso-27001-li/extract/qa-<range>.md  # must equal range size
grep -c '^> \*\*Why:\*\*' content/iso-27001-li/extract/qa-<range>.md # must equal range size
```

---

### Task 3: Extract questions 1–50

**Files:** Create: `content/iso-27001-li/extract/qa-001-050.md`

- [ ] **Step 1:** Follow the shared extraction procedure for `sources/ISO27001-Lead-Implementer/1-50-answer.pdf` (fallback `1-50.pdf`).
- [ ] **Step 2:** Run the completion check — all three counts must be **50**.
- [ ] **Step 3:** `git add content/iso-27001-li/extract/qa-001-050.md && git commit -m "content: extract ISO 27001 LI questions 1-50"`

### Task 4: Extract questions 51–100

**Files:** Create: `content/iso-27001-li/extract/qa-051-100.md`

- [ ] **Step 1:** Shared procedure on `51-100-answer.pdf`. Scenario numbering continues from Task 3's range (scenarios are global across the bank; re-declare a `## Scenario N` block only when its text first appears in this range).
- [ ] **Step 2:** Completion check — counts must be **50**.
- [ ] **Step 3:** `git add ... && git commit -m "content: extract ISO 27001 LI questions 51-100"`

### Task 5: Extract questions 101–150

**Files:** Create: `content/iso-27001-li/extract/qa-101-150.md`

- [ ] **Step 1:** Shared procedure on `101-150-answer.pdf`.
- [ ] **Step 2:** Completion check — counts must be **50**.
- [ ] **Step 3:** Commit: `"content: extract ISO 27001 LI questions 101-150"`

### Task 6: Extract questions 151–200

**Files:** Create: `content/iso-27001-li/extract/qa-151-200.md`

- [ ] **Step 1:** Shared procedure on `151-200-answer.pdf`.
- [ ] **Step 2:** Completion check — counts must be **50**.
- [ ] **Step 3:** Commit: `"content: extract ISO 27001 LI questions 151-200"`

### Task 7: Extract questions 201–250

**Files:** Create: `content/iso-27001-li/extract/qa-201-250.md`

- [ ] **Step 1:** Shared procedure on `201-250-answer.pdf`.
- [ ] **Step 2:** Completion check — counts must be **50**.
- [ ] **Step 3:** Commit: `"content: extract ISO 27001 LI questions 201-250"`

### Task 8: Extract questions 251–285

**Files:** Create: `content/iso-27001-li/extract/qa-251-285.md`

- [ ] **Step 1:** Shared procedure on `251-285-answer.pdf`.
- [ ] **Step 2:** Completion check — counts must be **35**.
- [ ] **Step 3:** Commit: `"content: extract ISO 27001 LI questions 251-285"`

---

### Task 9: Consolidate bank.md + subject.json

**Files:**
- Create: `content/iso-27001-li/bank.md`, `content/iso-27001-li/subject.json`

- [ ] **Step 1: Write subject.json**

```json
{
  "slug": "iso-27001-li",
  "name": "ISO/IEC 27001 Lead Implementer",
  "certBody": "PECB",
  "isLive": true,
  "defaultExamQuestionCount": 50,
  "defaultExamMinutes": 90
}
```

- [ ] **Step 2: Concatenate extracts into bank.md with frontmatter**

```bash
cd /project/src/exam.nanoteofficial.me/content/iso-27001-li
{
  printf -- '---\nsubject: iso-27001-li\nversion: 1.0.0\ngenerated: 2026-09-02\n---\n\n'
  cat extract/qa-001-050.md extract/qa-051-100.md extract/qa-101-150.md \
      extract/qa-151-200.md extract/qa-201-250.md extract/qa-251-285.md
} > bank.md
```

- [ ] **Step 3: Manual spot-check** — open `bank.md`; verify: frontmatter present, first question is `### Q1`, last is `### Q285`, no duplicated `## Scenario N` headings with *different* text (same number must appear exactly once). Fix duplicates by keeping the first occurrence.

```bash
grep '^## Scenario' bank.md | sort | uniq -d    # expected: empty
grep -c '^### Q' bank.md                        # expected: 285
```

- [ ] **Step 4: Commit**

```bash
git add content/iso-27001-li/bank.md content/iso-27001-li/subject.json
git commit -m "content: consolidate ISO 27001 LI bank v1.0.0 (285 questions)"
```

### Task 10: Bank parser (pure, TDD)

**Files:**
- Create: `src/lib/content/types.ts`, `src/lib/content/parse.ts`
- Test: `src/lib/content/parse.test.ts`

- [ ] **Step 1: Write types.ts**

```ts
// src/lib/content/types.ts
export interface Choice {
  key: string; // 'A'..'F'
  text: string;
}

export type Votes = Record<string, number>; // { B: 75, A: 25 }

export interface ParsedQuestion {
  number: number;
  topic: number;
  scenario: number | null;
  text: string;
  choices: Choice[];
  correctKey: string; // 'B' or 'B,C' (alphabetical, comma-joined)
  votes: Votes | null;
  explanation: string;
}

export interface ParsedScenario {
  number: number;
  text: string;
}

export interface ParsedBank {
  subject: string;
  version: string;
  generated: string;
  scenarios: ParsedScenario[];
  questions: ParsedQuestion[];
}
```

- [ ] **Step 2: Write the failing test**

```ts
// src/lib/content/parse.test.ts
import { describe, expect, it } from 'vitest';
import { parseBank } from './parse';

const FIXTURE = `---
subject: iso-27001-li
version: 1.0.0
generated: 2026-09-02
---

## Scenario 1
HealthGenic is a pediatric clinic.
It uses web-based medical software.

### Q1 [scenario: 1] [topic: 1]
Which principle was compromised?
- (A) Availability
- (B) Confidentiality
- (C) Integrity
> **Answer: B** — votes: B 75%, A 25%
> **Why:** Confidentiality means no unauthorized disclosure.
> Privacy invasion is a disclosure failure.

### Q2 [topic: 2]
Standalone question with a
second line of text?
- (A) Yes
- (B) No
> **Answer: A**
> **Why:** Because it is.
`;

describe('parseBank', () => {
  const bank = parseBank(FIXTURE);

  it('parses frontmatter', () => {
    expect(bank.subject).toBe('iso-27001-li');
    expect(bank.version).toBe('1.0.0');
    expect(bank.generated).toBe('2026-09-02');
  });

  it('parses scenarios with multi-line text', () => {
    expect(bank.scenarios).toHaveLength(1);
    expect(bank.scenarios[0].number).toBe(1);
    expect(bank.scenarios[0].text).toBe(
      'HealthGenic is a pediatric clinic.\nIt uses web-based medical software.'
    );
  });

  it('parses a scenario-linked question fully', () => {
    const q1 = bank.questions[0];
    expect(q1.number).toBe(1);
    expect(q1.scenario).toBe(1);
    expect(q1.topic).toBe(1);
    expect(q1.text).toBe('Which principle was compromised?');
    expect(q1.choices).toEqual([
      { key: 'A', text: 'Availability' },
      { key: 'B', text: 'Confidentiality' },
      { key: 'C', text: 'Integrity' },
    ]);
    expect(q1.correctKey).toBe('B');
    expect(q1.votes).toEqual({ B: 75, A: 25 });
    expect(q1.explanation).toBe(
      'Confidentiality means no unauthorized disclosure.\nPrivacy invasion is a disclosure failure.'
    );
  });

  it('parses a standalone question with no votes', () => {
    const q2 = bank.questions[1];
    expect(q2.number).toBe(2);
    expect(q2.scenario).toBeNull();
    expect(q2.topic).toBe(2);
    expect(q2.text).toBe('Standalone question with a\nsecond line of text?');
    expect(q2.votes).toBeNull();
    expect(q2.correctKey).toBe('A');
  });

  it('throws on a question missing an answer line', () => {
    const broken = FIXTURE.replace('> **Answer: A**\n', '');
    expect(() => parseBank(broken)).toThrow(/Q2/);
  });
});
```

- [ ] **Step 3: Run test to verify it fails**

Run: `npm test`
Expected: FAIL — `parse.ts` does not exist / `parseBank` not exported.

- [ ] **Step 4: Write parse.ts**

```ts
// src/lib/content/parse.ts
import type { Choice, ParsedBank, ParsedQuestion, ParsedScenario, Votes } from './types';

const Q_HEADING = /^### Q(\d+)(?:\s+\[scenario:\s*(\d+)\])?(?:\s+\[topic:\s*(\d+)\])?\s*$/;
const SCENARIO_HEADING = /^## Scenario (\d+)\s*$/;
const CHOICE_LINE = /^- \(([A-F])\) (.*)$/;
const ANSWER_LINE = /^> \*\*Answer: ([A-F](?:,[A-F])*)\*\*(?: — votes: (.*))?\s*$/;
const WHY_START = /^> \*\*Why:\*\* (.*)$/;
const WHY_CONT = /^> (.*)$/;

function parseVotes(raw: string): Votes {
  const votes: Votes = {};
  for (const part of raw.split(',')) {
    const m = part.trim().match(/^([A-F]) (\d+)%$/);
    if (m) votes[m[1]] = Number(m[2]);
  }
  return votes;
}

export function parseBank(markdown: string): ParsedBank {
  const lines = markdown.split('\n');
  let i = 0;

  // frontmatter
  const meta: Record<string, string> = {};
  if (lines[i] === '---') {
    i++;
    while (i < lines.length && lines[i] !== '---') {
      const m = lines[i].match(/^(\w+):\s*(.*)$/);
      if (m) meta[m[1]] = m[2].trim();
      i++;
    }
    i++; // closing ---
  }

  const scenarios: ParsedScenario[] = [];
  const questions: ParsedQuestion[] = [];

  while (i < lines.length) {
    const line = lines[i];

    const sm = line.match(SCENARIO_HEADING);
    if (sm) {
      i++;
      const text: string[] = [];
      while (i < lines.length && !SCENARIO_HEADING.test(lines[i]) && !Q_HEADING.test(lines[i])) {
        text.push(lines[i]);
        i++;
      }
      scenarios.push({ number: Number(sm[1]), text: text.join('\n').trim() });
      continue;
    }

    const qm = line.match(Q_HEADING);
    if (qm) {
      const number = Number(qm[1]);
      const scenario = qm[2] ? Number(qm[2]) : null;
      const topic = qm[3] ? Number(qm[3]) : 1;
      i++;

      const textLines: string[] = [];
      while (i < lines.length && !CHOICE_LINE.test(lines[i])) {
        if (Q_HEADING.test(lines[i]) || SCENARIO_HEADING.test(lines[i]) || ANSWER_LINE.test(lines[i])) break;
        textLines.push(lines[i]);
        i++;
      }

      const choices: Choice[] = [];
      while (i < lines.length) {
        const cm = lines[i].match(CHOICE_LINE);
        if (!cm) break;
        choices.push({ key: cm[1], text: cm[2].trim() });
        i++;
      }

      let correctKey = '';
      let votes: Votes | null = null;
      const am = i < lines.length ? lines[i].match(ANSWER_LINE) : null;
      if (am) {
        correctKey = am[1];
        votes = am[2] ? parseVotes(am[2]) : null;
        i++;
      }

      const why: string[] = [];
      const wm = i < lines.length ? lines[i].match(WHY_START) : null;
      if (wm) {
        why.push(wm[1]);
        i++;
        while (i < lines.length) {
          const cm = lines[i].match(WHY_CONT);
          if (!cm || WHY_START.test(lines[i]) || ANSWER_LINE.test(lines[i])) break;
          why.push(cm[1]);
          i++;
        }
      }

      if (!correctKey) throw new Error(`Q${number}: missing answer line`);
      if (choices.length < 2) throw new Error(`Q${number}: fewer than 2 choices`);
      if (why.length === 0) throw new Error(`Q${number}: missing Why explanation`);

      questions.push({
        number, topic, scenario,
        text: textLines.join('\n').trim(),
        choices, correctKey, votes,
        explanation: why.join('\n').trim(),
      });
      continue;
    }

    i++;
  }

  return {
    subject: meta.subject ?? '',
    version: meta.version ?? '',
    generated: meta.generated ?? '',
    scenarios,
    questions,
  };
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `npm test` — Expected: all `parseBank` tests PASS.

- [ ] **Step 6: Commit**

```bash
git add src/lib/content/ vitest.config.ts
git commit -m "feat: bank.md parser with tests"
```

---

### Task 11: Content validator script

**Files:**
- Create: `scripts/validate-content.ts`

- [ ] **Step 1: Write validate-content.ts**

```ts
// scripts/validate-content.ts — invariant checks on the real bank. No DB needed.
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { parseBank } from '../src/lib/content/parse';

const dir = join(process.cwd(), 'content', 'iso-27001-li');
const bank = parseBank(readFileSync(join(dir, 'bank.md'), 'utf8'));
const subject = JSON.parse(readFileSync(join(dir, 'subject.json'), 'utf8'));

const errors: string[] = [];
const expectTotal = 285;

if (bank.subject !== subject.slug) errors.push(`subject mismatch: ${bank.subject} vs ${subject.slug}`);
if (bank.questions.length !== expectTotal) errors.push(`expected ${expectTotal} questions, got ${bank.questions.length}`);

// contiguous numbering 1..285, no duplicates
const numbers = bank.questions.map((q) => q.number).sort((a, b) => a - b);
numbers.forEach((n, idx) => {
  if (n !== idx + 1) errors.push(`numbering gap/dup at Q${idx + 1} (found ${n})`);
});

const scenarioNums = new Set(bank.scenarios.map((s) => s.number));
if (scenarioNums.size !== bank.scenarios.length) errors.push('duplicate scenario numbers');

for (const q of bank.questions) {
  const keys = q.choices.map((c) => c.key);
  if (new Set(keys).size !== keys.length) errors.push(`Q${q.number}: duplicate choice keys`);
  for (const k of q.correctKey.split(',')) {
    if (!keys.includes(k)) errors.push(`Q${q.number}: correct key ${k} not in choices`);
  }
  if (q.scenario !== null && !scenarioNums.has(q.scenario)) {
    errors.push(`Q${q.number}: references missing scenario ${q.scenario}`);
  }
  if (q.explanation.length < 40) errors.push(`Q${q.number}: explanation too short`);
  if (q.votes) {
    for (const k of Object.keys(q.votes)) {
      if (!keys.includes(k)) errors.push(`Q${q.number}: vote key ${k} not in choices`);
    }
  }
}

// every scenario is referenced by at least one question
const referenced = new Set(bank.questions.map((q) => q.scenario).filter((s) => s !== null));
for (const s of bank.scenarios) {
  if (!referenced.has(s.number)) errors.push(`Scenario ${s.number} is never referenced`);
}

if (errors.length > 0) {
  console.error(`✗ ${errors.length} content error(s):`);
  for (const e of errors) console.error('  -', e);
  process.exit(1);
}
console.log(`✓ bank.md valid — ${bank.questions.length} questions, ${bank.scenarios.length} scenarios, v${bank.version}`);
```

- [ ] **Step 2: Run against the real bank and fix content until clean**

Run: `npm run validate:content`
Expected: `✓ bank.md valid — 285 questions, ...`. Any reported error is a content bug — fix it **in the extract file AND bank.md** (or regenerate bank.md via the Task 9 concat), not by weakening the validator.

- [ ] **Step 3: Commit**

```bash
git add scripts/validate-content.ts content/
git commit -m "feat: content validator; bank passes 285/285"
```

---

### Task 12: questions-only.md deriver

**Files:**
- Create: `scripts/derive-questions-only.ts`
- Create (generated): `content/iso-27001-li/questions-only.md`

- [ ] **Step 1: Write derive-questions-only.ts**

```ts
// scripts/derive-questions-only.ts — strip answer keys + explanations from bank.md
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const dir = join(process.cwd(), 'content', 'iso-27001-li');
const src = readFileSync(join(dir, 'bank.md'), 'utf8');

const out = src
  .split('\n')
  .filter((line) => !line.startsWith('> '))
  .join('\n')
  .replace(/\n{3,}/g, '\n\n');

const header = '<!-- GENERATED from bank.md by npm run derive:questions-only — do not edit -->\n';
writeFileSync(join(dir, 'questions-only.md'), header + out);
console.log('✓ wrote questions-only.md');
```

- [ ] **Step 2: Run it, spot-check, commit**

```bash
npm run derive:questions-only
grep -c '^### Q' content/iso-27001-li/questions-only.md   # expected: 285
grep -c '^> ' content/iso-27001-li/questions-only.md      # expected: 0
git add scripts/derive-questions-only.ts content/iso-27001-li/questions-only.md
git commit -m "feat: derive questions-only variant"
```

### Task 13: Drizzle schema + lazy DB client

**Files:**
- Create: `src/db/schema.ts`, `src/db/index.ts`, `drizzle.config.ts`

- [ ] **Step 1: Write schema.ts** (Auth.js adapter tables per `@auth/drizzle-adapter` docs + app tables; cross-check the shape against `/project/src/plan.nanoteofficial.me/src/db/schema.ts` and the adapter's current docs — table/column names must match what the adapter expects)

```ts
// src/db/schema.ts
import {
  boolean, integer, jsonb, pgTable, primaryKey, text, timestamp,
} from 'drizzle-orm/pg-core';
import type { AdapterAccountType } from 'next-auth/adapters';

// ── Auth.js tables ──────────────────────────────────────────
export const users = pgTable('user', {
  id: text('id').primaryKey().$defaultFn(() => crypto.randomUUID()),
  name: text('name'),
  email: text('email').notNull().unique(),
  emailVerified: timestamp('emailVerified', { mode: 'date' }),
  image: text('image'),
  role: text('role', { enum: ['admin', 'member'] }).notNull().default('member'),
  approvedAt: timestamp('approvedAt', { mode: 'date' }),
});

export const accounts = pgTable('account', {
  userId: text('userId').notNull().references(() => users.id, { onDelete: 'cascade' }),
  type: text('type').$type<AdapterAccountType>().notNull(),
  provider: text('provider').notNull(),
  providerAccountId: text('providerAccountId').notNull(),
  refresh_token: text('refresh_token'),
  access_token: text('access_token'),
  expires_at: integer('expires_at'),
  token_type: text('token_type'),
  scope: text('scope'),
  id_token: text('id_token'),
  session_state: text('session_state'),
}, (t) => [primaryKey({ columns: [t.provider, t.providerAccountId] })]);

export const sessions = pgTable('session', {
  sessionToken: text('sessionToken').primaryKey(),
  userId: text('userId').notNull().references(() => users.id, { onDelete: 'cascade' }),
  expires: timestamp('expires', { mode: 'date' }).notNull(),
});

export const verificationTokens = pgTable('verificationToken', {
  identifier: text('identifier').notNull(),
  token: text('token').notNull(),
  expires: timestamp('expires', { mode: 'date' }).notNull(),
}, (t) => [primaryKey({ columns: [t.identifier, t.token] })]);

// ── App tables ──────────────────────────────────────────────
export const accessRequests = pgTable('access_request', {
  id: text('id').primaryKey().$defaultFn(() => crypto.randomUUID()),
  email: text('email').notNull(),
  message: text('message'),
  ip: text('ip'),
  status: text('status', { enum: ['pending', 'approved', 'rejected'] }).notNull().default('pending'),
  createdAt: timestamp('createdAt', { mode: 'date' }).notNull().defaultNow(),
  decidedAt: timestamp('decidedAt', { mode: 'date' }),
});

export const subjects = pgTable('subject', {
  slug: text('slug').primaryKey(),
  name: text('name').notNull(),
  certBody: text('certBody').notNull(),
  isLive: boolean('isLive').notNull().default(false),
  defaultExamQuestionCount: integer('defaultExamQuestionCount').notNull(),
  defaultExamMinutes: integer('defaultExamMinutes').notNull(),
  bankVersion: text('bankVersion').notNull(),
});

export const scenarios = pgTable('scenario', {
  id: text('id').primaryKey().$defaultFn(() => crypto.randomUUID()),
  subjectSlug: text('subjectSlug').notNull().references(() => subjects.slug, { onDelete: 'cascade' }),
  number: integer('number').notNull(),
  text: text('text').notNull(),
});

export const questions = pgTable('question', {
  id: text('id').primaryKey().$defaultFn(() => crypto.randomUUID()),
  subjectSlug: text('subjectSlug').notNull().references(() => subjects.slug, { onDelete: 'cascade' }),
  number: integer('number').notNull(),
  topic: integer('topic').notNull().default(1),
  scenarioId: text('scenarioId').references(() => scenarios.id, { onDelete: 'set null' }),
  text: text('text').notNull(),
  choices: jsonb('choices').$type<{ key: string; text: string }[]>().notNull(),
  correctKey: text('correctKey').notNull(),
  explanation: text('explanation').notNull(),
  votes: jsonb('votes').$type<Record<string, number> | null>(),
});

export interface SessionConfig {
  questionCount: number;
  minutes: number | null; // null = untimed (practice)
  seed: number;
}
export interface OrderedQuestionRef {
  questionId: string;
  choiceOrder: string[]; // shuffled canonical keys, e.g. ['C','A','B']
}

export const examSessions = pgTable('exam_session', {
  id: text('id').primaryKey().$defaultFn(() => crypto.randomUUID()),
  userId: text('userId').notNull().references(() => users.id, { onDelete: 'cascade' }),
  subjectSlug: text('subjectSlug').notNull().references(() => subjects.slug),
  mode: text('mode', { enum: ['practice', 'exam'] }).notNull(),
  config: jsonb('config').$type<SessionConfig>().notNull(),
  questionOrder: jsonb('questionOrder').$type<OrderedQuestionRef[]>().notNull(),
  startedAt: timestamp('startedAt', { mode: 'date' }).notNull().defaultNow(),
  finishedAt: timestamp('finishedAt', { mode: 'date' }),
  score: integer('score'),
});

export const sessionAnswers = pgTable('session_answer', {
  sessionId: text('sessionId').notNull().references(() => examSessions.id, { onDelete: 'cascade' }),
  questionId: text('questionId').notNull().references(() => questions.id, { onDelete: 'cascade' }),
  givenKey: text('givenKey'),
  isCorrect: boolean('isCorrect'),
  flagged: boolean('flagged').notNull().default(false),
  answeredAt: timestamp('answeredAt', { mode: 'date' }),
}, (t) => [primaryKey({ columns: [t.sessionId, t.questionId] })]);
```

- [ ] **Step 2: Write src/db/index.ts** (lazy — importing must not throw when `DATABASE_URL` is unset, so `next build` works without env)

```ts
// src/db/index.ts
import { neon } from '@neondatabase/serverless';
import { drizzle, type NeonHttpDatabase } from 'drizzle-orm/neon-http';
import * as schema from './schema';

let _db: NeonHttpDatabase<typeof schema> | null = null;

export function getDb() {
  if (!_db) {
    const url = process.env.DATABASE_URL;
    if (!url) throw new Error('DATABASE_URL is not set');
    _db = drizzle(neon(url), { schema });
  }
  return _db;
}

export { schema };
```

- [ ] **Step 3: Write drizzle.config.ts**

```ts
import { defineConfig } from 'drizzle-kit';

export default defineConfig({
  schema: './src/db/schema.ts',
  dialect: 'postgresql',
  dbCredentials: { url: process.env.DATABASE_URL! },
});
```

- [ ] **Step 4: Verify + commit**

```bash
npx tsc --noEmit && npm run build
git add src/db/ drizzle.config.ts
git commit -m "feat: drizzle schema (auth + bank + sessions), lazy neon client"
```

Note: `drizzle-kit push` runs later (Task 21) once the Neon database exists.

---

### Task 14: Auth.js v5 — magic link + approval gate

**Files:**
- Create: `src/auth.ts`, `src/app/api/auth/[...nextauth]/route.ts`

- [ ] **Step 1: Write src/auth.ts** (mirror the working pattern in `/project/src/plan.nanoteofficial.me/src/auth.ts`; adjust import paths/BUT keep this logic)

```ts
// src/auth.ts
import NextAuth from 'next-auth';
import Resend from 'next-auth/providers/resend';
import { DrizzleAdapter } from '@auth/drizzle-adapter';
import { eq } from 'drizzle-orm';
import { getDb, schema } from '@/db';

function allowedEmails(): string[] {
  return (process.env.ALLOWED_EMAILS ?? '')
    .split(',')
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean);
}

export const { handlers, auth, signIn, signOut } = NextAuth({
  adapter: DrizzleAdapter(getDb(), {
    usersTable: schema.users,
    accountsTable: schema.accounts,
    sessionsTable: schema.sessions,
    verificationTokensTable: schema.verificationTokens,
  }),
  providers: [
    Resend({ from: process.env.AUTH_RESEND_FROM }),
  ],
  pages: {
    signIn: '/signin',
    verifyRequest: '/signin?sent=1',
    error: '/signin?error=1',
  },
  callbacks: {
    // Block the magic link for anyone not approved and not allowlisted.
    async signIn({ user }) {
      const email = user.email?.toLowerCase();
      if (!email) return false;
      if (allowedEmails().includes(email)) return true;
      const db = getDb();
      const existing = await db.query.users.findFirst({
        where: eq(schema.users.email, email),
      });
      if (existing?.approvedAt) return true;
      return '/pending';
    },
  },
  events: {
    // Allowlisted emails become approved admins on first sign-in.
    async signIn({ user }) {
      const email = user.email?.toLowerCase();
      if (!email || !user.id || !allowedEmails().includes(email)) return;
      const db = getDb();
      await db.update(schema.users)
        .set({ role: 'admin', approvedAt: new Date() })
        .where(eq(schema.users.id, user.id));
    },
  },
});
```

If `getDb()` at module scope breaks `next build` without env (NextAuth may eagerly initialize), wrap the adapter in the lazy pattern used by plan.nanoteofficial.me — the reference project has solved exactly this; copy its approach.

- [ ] **Step 2: Write the route handler**

```ts
// src/app/api/auth/[...nextauth]/route.ts
import { handlers } from '@/auth';
export const { GET, POST } = handlers;
```

- [ ] **Step 3: Verify + commit**

```bash
npx tsc --noEmit && npm run build   # must pass with DATABASE_URL unset
git add src/auth.ts src/app/api/
git commit -m "feat: Auth.js v5 magic-link auth with approval + allowlist"
```

---

### Task 15: Seed script

**Files:**
- Create: `scripts/seed.ts`

- [ ] **Step 1: Write seed.ts** (idempotent: wipes and reinserts the subject's content rows; user/session tables untouched)

```ts
// scripts/seed.ts — bank.md + subject.json → Postgres. Usage: DATABASE_URL=... npm run seed
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { eq } from 'drizzle-orm';
import { getDb, schema } from '../src/db';
import { parseBank } from '../src/lib/content/parse';

async function main() {
  const dir = join(process.cwd(), 'content', 'iso-27001-li');
  const bank = parseBank(readFileSync(join(dir, 'bank.md'), 'utf8'));
  const meta = JSON.parse(readFileSync(join(dir, 'subject.json'), 'utf8'));
  const db = getDb();

  await db.insert(schema.subjects).values({
    slug: meta.slug,
    name: meta.name,
    certBody: meta.certBody,
    isLive: meta.isLive,
    defaultExamQuestionCount: meta.defaultExamQuestionCount,
    defaultExamMinutes: meta.defaultExamMinutes,
    bankVersion: bank.version,
  }).onConflictDoUpdate({
    target: schema.subjects.slug,
    set: { name: meta.name, certBody: meta.certBody, isLive: meta.isLive,
      defaultExamQuestionCount: meta.defaultExamQuestionCount,
      defaultExamMinutes: meta.defaultExamMinutes, bankVersion: bank.version },
  });

  // content rows are fully rebuilt each seed (questions cascade-delete session
  // answers only if IDs change — so we UPDATE in place when numbers match)
  const existing = await db.query.questions.findMany({
    where: eq(schema.questions.subjectSlug, meta.slug),
  });
  const byNumber = new Map(existing.map((q) => [q.number, q]));

  await db.delete(schema.scenarios).where(eq(schema.scenarios.subjectSlug, meta.slug));
  const scenarioIds = new Map<number, string>();
  for (const s of bank.scenarios) {
    const [row] = await db.insert(schema.scenarios)
      .values({ subjectSlug: meta.slug, number: s.number, text: s.text })
      .returning({ id: schema.scenarios.id });
    scenarioIds.set(s.number, row.id);
  }

  let inserted = 0, updated = 0;
  for (const q of bank.questions) {
    const values = {
      subjectSlug: meta.slug,
      number: q.number,
      topic: q.topic,
      scenarioId: q.scenario !== null ? scenarioIds.get(q.scenario)! : null,
      text: q.text,
      choices: q.choices,
      correctKey: q.correctKey,
      explanation: q.explanation,
      votes: q.votes,
    };
    const prev = byNumber.get(q.number);
    if (prev) {
      await db.update(schema.questions).set(values).where(eq(schema.questions.id, prev.id));
      updated++;
    } else {
      await db.insert(schema.questions).values(values);
      inserted++;
    }
  }
  console.log(`✓ seeded ${meta.slug} v${bank.version}: ${inserted} inserted, ${updated} updated, ${bank.scenarios.length} scenarios`);
}

main().catch((e) => { console.error(e); process.exit(1); });
```

- [ ] **Step 2: Typecheck + commit** (live run happens in Task 21 when the DB exists)

```bash
npx tsc --noEmit
git add scripts/seed.ts
git commit -m "feat: idempotent seed script (bank.md -> postgres)"
```

---

### Task 16: Shuffle engine (pure, TDD)

**Files:**
- Create: `src/lib/exam/shuffle.ts`
- Test: `src/lib/exam/shuffle.test.ts`

**Behavior contract:** shuffle question order from a numeric seed, keeping scenario groups contiguous (each group internally in ascending question number); shuffle each question's choice order; select `count` questions by taking whole shuffled groups while they fit, then filling the remainder with standalone questions.

- [ ] **Step 1: Write the failing test**

```ts
// src/lib/exam/shuffle.test.ts
import { describe, expect, it } from 'vitest';
import { buildQuestionOrder, mulberry32, shuffleInPlace } from './shuffle';

interface Q { id: string; number: number; scenarioId: string | null; choiceKeys: string[] }
const q = (n: number, scenarioId: string | null): Q =>
  ({ id: `q${n}`, number: n, scenarioId, choiceKeys: ['A', 'B', 'C'] });

// 10 questions: scenario s1 = Q1-3, s2 = Q6-7, standalone = Q4,5,8,9,10
const POOL: Q[] = [
  q(1, 's1'), q(2, 's1'), q(3, 's1'), q(4, null), q(5, null),
  q(6, 's2'), q(7, 's2'), q(8, null), q(9, null), q(10, null),
];

describe('mulberry32', () => {
  it('is deterministic for a seed', () => {
    const a = mulberry32(42), b = mulberry32(42);
    expect([a(), a(), a()]).toEqual([b(), b(), b()]);
  });
});

describe('buildQuestionOrder', () => {
  it('keeps scenario groups contiguous and ascending', () => {
    for (const seed of [1, 2, 3, 99, 12345]) {
      const order = buildQuestionOrder(POOL, seed, POOL.length);
      const ids = order.map((o) => o.questionId);
      const i1 = ids.indexOf('q1');
      expect(ids.slice(i1, i1 + 3)).toEqual(['q1', 'q2', 'q3']);
      const i6 = ids.indexOf('q6');
      expect(ids.slice(i6, i6 + 2)).toEqual(['q6', 'q7']);
    }
  });

  it('is deterministic per seed and varies across seeds', () => {
    const a = buildQuestionOrder(POOL, 7, 10).map((o) => o.questionId);
    const b = buildQuestionOrder(POOL, 7, 10).map((o) => o.questionId);
    expect(a).toEqual(b);
    const variants = new Set(
      [1, 2, 3, 4, 5].map((s) => buildQuestionOrder(POOL, s, 10).map((o) => o.questionId).join(','))
    );
    expect(variants.size).toBeGreaterThan(1);
  });

  it('returns exactly count questions, never splitting a scenario group', () => {
    for (const seed of [1, 5, 11, 400]) {
      const order = buildQuestionOrder(POOL, seed, 4);
      expect(order).toHaveLength(4);
      const ids = new Set(order.map((o) => o.questionId));
      const s1In = ['q1', 'q2', 'q3'].filter((id) => ids.has(id)).length;
      expect([0, 3]).toContain(s1In); // all of s1 or none of it
      const s2In = ['q6', 'q7'].filter((id) => ids.has(id)).length;
      expect([0, 2]).toContain(s2In);
    }
  });

  it('shuffles choice order but keeps the same keys', () => {
    const order = buildQuestionOrder(POOL, 3, 10);
    for (const o of order) {
      expect([...o.choiceOrder].sort()).toEqual(['A', 'B', 'C']);
    }
    const allDefault = order.every((o) => o.choiceOrder.join('') === 'ABC');
    expect(allDefault).toBe(false);
  });

  it('caps count at pool size', () => {
    expect(buildQuestionOrder(POOL, 1, 999)).toHaveLength(10);
  });
});
```

- [ ] **Step 2: Run to verify it fails** — `npm test` → FAIL (module missing).

- [ ] **Step 3: Write shuffle.ts**

```ts
// src/lib/exam/shuffle.ts
export interface PoolQuestion {
  id: string;
  number: number;
  scenarioId: string | null;
  choiceKeys: string[];
}
export interface OrderedQuestionRef {
  questionId: string;
  choiceOrder: string[];
}

/** Deterministic PRNG (mulberry32). */
export function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** Fisher–Yates, in place. */
export function shuffleInPlace<T>(arr: T[], rng: () => number): T[] {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

/**
 * Build a session's question order.
 * - Scenario groups stay contiguous, ascending by question number inside the group.
 * - Groups (scenario blocks + standalone singletons) are shuffled as units.
 * - Selection takes whole groups while they fit in `count`, then fills the
 *   remainder with standalone questions.
 */
export function buildQuestionOrder(
  pool: PoolQuestion[],
  seed: number,
  count: number,
): OrderedQuestionRef[] {
  const rng = mulberry32(seed);
  const target = Math.min(count, pool.length);

  const groups = new Map<string, PoolQuestion[]>();
  for (const q of pool) {
    const key = q.scenarioId ?? `solo:${q.id}`;
    const g = groups.get(key) ?? [];
    g.push(q);
    groups.set(key, g);
  }
  const units = [...groups.values()].map((g) => g.sort((a, b) => a.number - b.number));
  shuffleInPlace(units, rng);

  const picked: PoolQuestion[] = [];
  const skippedSolos: PoolQuestion[] = [];
  for (const unit of units) {
    if (picked.length >= target) break;
    if (picked.length + unit.length <= target) {
      picked.push(...unit);
    } else if (unit.length === 1) {
      skippedSolos.push(unit[0]);
    }
    // an oversized scenario block is skipped whole — never split
  }
  for (const solo of skippedSolos) {
    if (picked.length >= target) break;
    picked.push(solo);
  }

  return picked.map((q) => ({
    questionId: q.id,
    choiceOrder: shuffleInPlace([...q.choiceKeys], rng),
  }));
}
```

- [ ] **Step 4: Run tests** — `npm test` → all PASS.

- [ ] **Step 5: Commit**

```bash
git add src/lib/exam/
git commit -m "feat: seeded scenario-aware shuffle engine with tests"
```

### Task 17: Server actions

**Files:**
- Create: `src/server/actions/access.ts`, `src/server/actions/sessions.ts`, `src/server/actions/admin.ts`

**Security invariants (apply to every action):** every session-scoped action loads the session row and verifies `userId` matches the signed-in user; `correctKey`/`explanation` are returned only by `answerQuestion` in practice mode, or after `finishedAt` is set. No action trusts client-supplied correctness.

- [ ] **Step 1: Write access.ts**

```ts
// src/server/actions/access.ts
'use server';

import { and, eq, gt, sql } from 'drizzle-orm';
import { headers } from 'next/headers';
import { getDb, schema } from '@/db';

export interface RequestAccessState { ok: boolean; message: string }

export async function requestAccess(
  _prev: RequestAccessState | null,
  formData: FormData,
): Promise<RequestAccessState> {
  const email = String(formData.get('email') ?? '').trim().toLowerCase();
  const message = String(formData.get('message') ?? '').trim().slice(0, 500);
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return { ok: false, message: 'Please enter a valid email address.' };
  }
  const db = getDb();
  const hdrs = await headers();
  const ip = (hdrs.get('x-forwarded-for') ?? 'unknown').split(',')[0].trim();

  // rate limit: max 3 requests per IP per hour
  const hourAgo = new Date(Date.now() - 60 * 60 * 1000);
  const [{ count }] = await db
    .select({ count: sql<number>`count(*)::int` })
    .from(schema.accessRequests)
    .where(and(eq(schema.accessRequests.ip, ip), gt(schema.accessRequests.createdAt, hourAgo)));
  if (count >= 3) return { ok: false, message: 'Too many requests — try again later.' };

  const existing = await db.query.accessRequests.findFirst({
    where: and(eq(schema.accessRequests.email, email), eq(schema.accessRequests.status, 'pending')),
  });
  if (!existing) {
    await db.insert(schema.accessRequests).values({ email, message, ip });
  }
  return { ok: true, message: 'Request received. You will get a sign-in link once approved.' };
}
```

- [ ] **Step 2: Write sessions.ts**

```ts
// src/server/actions/sessions.ts
'use server';

import { and, eq } from 'drizzle-orm';
import { redirect } from 'next/navigation';
import { auth } from '@/auth';
import { getDb, schema } from '@/db';
import { buildQuestionOrder } from '@/lib/exam/shuffle';

async function requireUser() {
  const session = await auth();
  if (!session?.user?.id) redirect('/signin');
  return session.user.id!;
}

async function requireOwnedSession(sessionId: string, userId: string) {
  const db = getDb();
  const row = await db.query.examSessions.findFirst({
    where: and(eq(schema.examSessions.id, sessionId), eq(schema.examSessions.userId, userId)),
  });
  if (!row) throw new Error('Session not found');
  return row;
}

export async function startSession(formData: FormData) {
  const userId = await requireUser();
  const subjectSlug = String(formData.get('subject'));
  const mode = String(formData.get('mode')) as 'practice' | 'exam';
  const questionCount = Number(formData.get('questionCount'));
  const minutes = mode === 'exam' ? Number(formData.get('minutes')) : null;
  if (!['practice', 'exam'].includes(mode) || !Number.isFinite(questionCount) || questionCount < 1) {
    throw new Error('Invalid session config');
  }
  const db = getDb();
  const pool = await db.query.questions.findMany({
    where: eq(schema.questions.subjectSlug, subjectSlug),
    columns: { id: true, number: true, scenarioId: true, choices: true },
  });
  if (pool.length === 0) throw new Error('Unknown subject');

  const seed = Math.floor(Math.random() * 2 ** 31);
  const order = buildQuestionOrder(
    pool.map((q) => ({ id: q.id, number: q.number, scenarioId: q.scenarioId, choiceKeys: q.choices.map((c) => c.key) })),
    seed,
    questionCount,
  );
  const [row] = await db.insert(schema.examSessions).values({
    userId, subjectSlug, mode,
    config: { questionCount: order.length, minutes, seed },
    questionOrder: order,
  }).returning({ id: schema.examSessions.id });

  redirect(`/app/${subjectSlug}/${mode}/${row.id}`);
}

export interface AnswerResult {
  isCorrect?: boolean;
  correctKey?: string;
  explanation?: string;
  votes?: Record<string, number> | null;
}

export async function answerQuestion(
  sessionId: string, questionId: string, givenKey: string,
): Promise<AnswerResult> {
  const userId = await requireUser();
  const sess = await requireOwnedSession(sessionId, userId);
  if (sess.finishedAt) throw new Error('Session already finished');
  if (!sess.questionOrder.some((o) => o.questionId === questionId)) throw new Error('Question not in session');

  const db = getDb();
  const q = await db.query.questions.findFirst({ where: eq(schema.questions.id, questionId) });
  if (!q) throw new Error('Question missing');
  const isCorrect = q.correctKey === givenKey;

  await db.insert(schema.sessionAnswers)
    .values({ sessionId, questionId, givenKey, isCorrect, answeredAt: new Date() })
    .onConflictDoUpdate({
      target: [schema.sessionAnswers.sessionId, schema.sessionAnswers.questionId],
      set: { givenKey, isCorrect, answeredAt: new Date() },
    });

  if (sess.mode === 'practice') {
    return { isCorrect, correctKey: q.correctKey, explanation: q.explanation, votes: q.votes };
  }
  return {}; // exam mode: no feedback until submit
}

export async function toggleFlag(sessionId: string, questionId: string, flagged: boolean) {
  const userId = await requireUser();
  await requireOwnedSession(sessionId, userId);
  const db = getDb();
  await db.insert(schema.sessionAnswers)
    .values({ sessionId, questionId, flagged })
    .onConflictDoUpdate({
      target: [schema.sessionAnswers.sessionId, schema.sessionAnswers.questionId],
      set: { flagged },
    });
}

export async function submitSession(sessionId: string) {
  const userId = await requireUser();
  const sess = await requireOwnedSession(sessionId, userId);
  if (sess.finishedAt) redirect(`/app/${sess.subjectSlug}/results/${sess.id}`);

  const db = getDb();
  const answers = await db.query.sessionAnswers.findMany({
    where: eq(schema.sessionAnswers.sessionId, sessionId),
  });
  const score = answers.filter((a) => a.isCorrect).length;
  await db.update(schema.examSessions)
    .set({ finishedAt: new Date(), score })
    .where(eq(schema.examSessions.id, sessionId));

  redirect(`/app/${sess.subjectSlug}/results/${sess.id}`);
}
```

- [ ] **Step 3: Write admin.ts**

```ts
// src/server/actions/admin.ts
'use server';

import { eq } from 'drizzle-orm';
import { revalidatePath } from 'next/cache';
import { auth } from '@/auth';
import { getDb, schema } from '@/db';

async function requireAdmin() {
  const session = await auth();
  const email = session?.user?.email;
  if (!email) throw new Error('Unauthorized');
  const db = getDb();
  const user = await db.query.users.findFirst({ where: eq(schema.users.email, email) });
  if (user?.role !== 'admin') throw new Error('Unauthorized');
  return user;
}

export async function decideAccessRequest(requestId: string, decision: 'approved' | 'rejected') {
  await requireAdmin();
  const db = getDb();
  const req = await db.query.accessRequests.findFirst({
    where: eq(schema.accessRequests.id, requestId),
  });
  if (!req || req.status !== 'pending') return;

  await db.update(schema.accessRequests)
    .set({ status: decision, decidedAt: new Date() })
    .where(eq(schema.accessRequests.id, requestId));

  if (decision === 'approved') {
    const existing = await db.query.users.findFirst({ where: eq(schema.users.email, req.email) });
    if (existing) {
      await db.update(schema.users).set({ approvedAt: new Date() }).where(eq(schema.users.id, existing.id));
    } else {
      await db.insert(schema.users).values({ email: req.email, approvedAt: new Date() });
    }
  }
  revalidatePath('/admin');
}
```

- [ ] **Step 4: Verify + commit**

```bash
npx tsc --noEmit
git add src/server/
git commit -m "feat: access, session, and admin server actions"
```

---

### Task 18: Brand theme + root layout + public pages

**Files:**
- Modify: `src/app/globals.css`, `src/app/layout.tsx`
- Create: `src/app/page.tsx`, `src/app/signin/page.tsx`, `src/app/pending/page.tsx`, `src/components/SiteHeader.tsx`, `src/components/RequestAccessForm.tsx`

**Brand (from approved mockups):** light "calm study" base — paper `#fafaf7`, ink `#1c1917`, muted `#78716c`, line `#eceae4`, card `#ffffff`, teal primary `#0f766e`, teal tint `#f0fdf9`, amber accent `#f59e0b`. Exam-hall dark mode (Task 20 only): slate `#0f172a` / `#1e293b`, line `#334155`, sky `#38bdf8`, amber timer `#fbbf24`. Fonts via `next/font`: **Fraunces** (serif display, headings) + **Inter** (UI). The frontend-design plugin conventions apply — hand-tuned spacing, no generic template look.

- [ ] **Step 1: Replace globals.css** with Tailwind v4 `@theme` tokens

```css
@import "tailwindcss";

@theme {
  --color-paper: #fafaf7;
  --color-ink: #1c1917;
  --color-muted: #78716c;
  --color-faint: #a8a29e;
  --color-line: #eceae4;
  --color-card: #ffffff;
  --color-teal: #0f766e;
  --color-teal-soft: #f0fdf9;
  --color-teal-line: #ccfbef;
  --color-amber: #f59e0b;
  --color-good: #14b8a6;
  --color-bad: #dc2626;
  --color-hall: #0f172a;
  --color-hall-card: #1e293b;
  --color-hall-line: #334155;
  --color-hall-text: #e2e8f0;
  --color-hall-dim: #94a3b8;
  --color-sky: #38bdf8;
  --color-timer: #fbbf24;
  --font-display: var(--font-fraunces);
  --font-sans: var(--font-inter);
}

body { background: var(--color-paper); color: var(--color-ink); }
```

- [ ] **Step 2: Update root layout with fonts + metadata**

```tsx
// src/app/layout.tsx
import type { Metadata } from 'next';
import { Fraunces, Inter } from 'next/font/google';
import './globals.css';

const fraunces = Fraunces({ subsets: ['latin'], variable: '--font-fraunces' });
const inter = Inter({ subsets: ['latin'], variable: '--font-inter' });

export const metadata: Metadata = {
  title: 'ExamPrep — practice IT certification exams',
  description: 'Private exam practice for IT & cybersecurity certifications.',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${fraunces.variable} ${inter.variable}`}>
      <body className="font-sans antialiased">{children}</body>
    </html>
  );
}
```

- [ ] **Step 3: Write SiteHeader.tsx** (used by landing + app pages)

```tsx
// src/components/SiteHeader.tsx
import Link from 'next/link';

export function SiteHeader({ right }: { right?: React.ReactNode }) {
  return (
    <header className="border-b border-line bg-card">
      <div className="mx-auto flex h-14 max-w-5xl items-center justify-between px-4">
        <Link href="/" className="font-display text-lg font-semibold text-teal">
          ◆ ExamPrep
        </Link>
        {right}
      </div>
    </header>
  );
}
```

- [ ] **Step 4: Write RequestAccessForm.tsx** (client, `useActionState` on `requestAccess`)

```tsx
// src/components/RequestAccessForm.tsx
'use client';

import { useActionState } from 'react';
import { requestAccess, type RequestAccessState } from '@/server/actions/access';

export function RequestAccessForm() {
  const [state, formAction, pending] = useActionState<RequestAccessState | null, FormData>(
    requestAccess, null,
  );
  return (
    <form action={formAction} className="mx-auto flex w-full max-w-md flex-col gap-3">
      <input
        type="email" name="email" required placeholder="you@example.com"
        className="rounded-lg border border-line bg-card px-4 py-2.5 text-sm outline-none focus:border-teal"
      />
      <textarea
        name="message" rows={2} maxLength={500}
        placeholder="Who are you? (optional — helps approval)"
        className="rounded-lg border border-line bg-card px-4 py-2.5 text-sm outline-none focus:border-teal"
      />
      <button
        type="submit" disabled={pending}
        className="rounded-lg bg-teal px-4 py-2.5 text-sm font-semibold text-white hover:opacity-90 disabled:opacity-50"
      >
        {pending ? 'Sending…' : 'Request access'}
      </button>
      {state && (
        <p className={`text-sm ${state.ok ? 'text-teal' : 'text-bad'}`}>{state.message}</p>
      )}
    </form>
  );
}
```

- [ ] **Step 5: Write the landing page** (approved layout A: hero → stats → subject catalog → request access; **no bank content anywhere**)

```tsx
// src/app/page.tsx
import Link from 'next/link';
import { SiteHeader } from '@/components/SiteHeader';
import { RequestAccessForm } from '@/components/RequestAccessForm';

const SUBJECTS = [
  { tag: 'LIVE', name: 'ISO/IEC 27001 Lead Implementer', detail: 'PECB · 285 questions · scenario-based', live: true },
  { tag: 'SOON', name: 'CISSP', detail: 'Coming next', live: false },
  { tag: 'SOON', name: 'CompTIA Security+', detail: 'On the roadmap', live: false },
];

export default function LandingPage() {
  return (
    <div className="min-h-screen bg-paper">
      <SiteHeader
        right={
          <Link href="/signin" className="rounded-lg bg-teal px-4 py-1.5 text-sm font-medium text-white">
            Sign in
          </Link>
        }
      />
      <main className="mx-auto max-w-5xl px-4">
        <section className="py-20 text-center">
          <h1 className="font-display text-4xl font-semibold tracking-tight sm:text-5xl">
            Practice IT certification exams, properly.
          </h1>
          <p className="mx-auto mt-4 max-w-xl text-muted">
            Real exam-style questions with clear explanations for every answer —
            not just an answer key. Practice at your pace, or simulate the real
            timed exam.
          </p>
          <div className="mt-8 flex justify-center gap-8 text-sm text-muted">
            <div><span className="block font-display text-2xl text-teal">285</span>questions</div>
            <div><span className="block font-display text-2xl text-teal">1</span>subject live</div>
            <div><span className="block font-display text-2xl text-teal">2</span>modes</div>
          </div>
        </section>

        <section className="grid gap-4 pb-16 sm:grid-cols-3">
          {SUBJECTS.map((s) => (
            <div
              key={s.name}
              className={`rounded-xl border bg-card p-5 ${s.live ? 'border-line' : 'border-dashed border-line opacity-60'}`}
            >
              <span className="rounded-full bg-teal-soft px-2 py-0.5 text-xs font-medium text-teal">{s.tag}</span>
              <h3 className="mt-3 font-display text-lg">{s.name}</h3>
              <p className="mt-1 text-sm text-faint">{s.detail}</p>
            </div>
          ))}
        </section>

        <section className="border-t border-line py-16 text-center">
          <h2 className="font-display text-2xl">Access is private</h2>
          <p className="mx-auto mt-2 mb-8 max-w-md text-sm text-muted">
            Accounts are approved individually. Request access and you’ll receive
            a passwordless sign-in link once approved.
          </p>
          <RequestAccessForm />
        </section>
      </main>
      <footer className="border-t border-line py-8 text-center text-xs text-faint">
        exam.nanoteofficial.me — a NaNote project
      </footer>
    </div>
  );
}
```

- [ ] **Step 6: Write signin page**

```tsx
// src/app/signin/page.tsx
import { SiteHeader } from '@/components/SiteHeader';
import { signIn } from '@/auth';

export default async function SignInPage({
  searchParams,
}: {
  searchParams: Promise<{ sent?: string; error?: string }>;
}) {
  const params = await searchParams;
  return (
    <div className="min-h-screen bg-paper">
      <SiteHeader />
      <main className="mx-auto max-w-md px-4 py-24 text-center">
        <h1 className="font-display text-3xl">Sign in</h1>
        {params.sent ? (
          <p className="mt-6 rounded-lg border border-teal-line bg-teal-soft p-4 text-sm text-teal">
            Check your email — we sent you a sign-in link.
          </p>
        ) : (
          <>
            <p className="mt-2 text-sm text-muted">
              Enter your approved email and we’ll send a magic link. No password.
            </p>
            {params.error && (
              <p className="mt-4 text-sm text-bad">Sign-in failed — is your email approved?</p>
            )}
            <form
              className="mt-8 flex flex-col gap-3"
              action={async (formData: FormData) => {
                'use server';
                await signIn('resend', {
                  email: String(formData.get('email')),
                  redirectTo: '/app',
                });
              }}
            >
              <input
                type="email" name="email" required placeholder="you@example.com"
                className="rounded-lg border border-line bg-card px-4 py-2.5 text-sm outline-none focus:border-teal"
              />
              <button className="rounded-lg bg-teal px-4 py-2.5 text-sm font-semibold text-white">
                Email me a sign-in link
              </button>
            </form>
          </>
        )}
      </main>
    </div>
  );
}
```

- [ ] **Step 7: Write pending page**

```tsx
// src/app/pending/page.tsx
import Link from 'next/link';
import { SiteHeader } from '@/components/SiteHeader';

export default function PendingPage() {
  return (
    <div className="min-h-screen bg-paper">
      <SiteHeader />
      <main className="mx-auto max-w-md px-4 py-24 text-center">
        <h1 className="font-display text-3xl">Almost there</h1>
        <p className="mt-4 text-sm text-muted">
          Your account isn’t approved yet. If you haven’t requested access,
          do that first — otherwise hang tight; approval is manual.
        </p>
        <Link href="/" className="mt-8 inline-block text-sm font-medium text-teal">
          ← Back to home
        </Link>
      </main>
    </div>
  );
}
```

- [ ] **Step 8: Verify + commit**

```bash
npm run build && npx tsc --noEmit && npm run lint
git add src/app/ src/components/
git commit -m "feat: brand theme, landing, signin, pending pages"
```

Visual check: `npm run dev`, open `http://localhost:3000` — landing renders with Fraunces headings, teal accents, subject catalog, working request-access form (submit fails without DB — expected at this stage).

### Task 19: Auth gate + subject pages + results pages

**Files:**
- Create: `src/app/(app)/layout.tsx`, `src/app/(app)/app/page.tsx`, `src/app/(app)/app/[subject]/page.tsx`, `src/app/(app)/app/results/page.tsx`, `src/app/(app)/app/[subject]/results/[sessionId]/page.tsx`

- [ ] **Step 1: Write the gate layout** (the ONLY auth gate — no middleware)

```tsx
// src/app/(app)/layout.tsx
import { redirect } from 'next/navigation';
import Link from 'next/link';
import { eq } from 'drizzle-orm';
import { auth, signOut } from '@/auth';
import { getDb, schema } from '@/db';
import { SiteHeader } from '@/components/SiteHeader';

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const session = await auth();
  if (!session?.user?.email) redirect('/signin');
  const db = getDb();
  const user = await db.query.users.findFirst({
    where: eq(schema.users.email, session.user.email),
  });
  if (!user?.approvedAt) redirect('/pending');

  return (
    <div className="min-h-screen bg-paper">
      <SiteHeader
        right={
          <nav className="flex items-center gap-4 text-sm">
            <Link href="/app" className="text-muted hover:text-ink">Subjects</Link>
            <Link href="/app/results" className="text-muted hover:text-ink">My results</Link>
            {user.role === 'admin' && (
              <Link href="/admin" className="text-muted hover:text-ink">Admin</Link>
            )}
            <form action={async () => { 'use server'; await signOut({ redirectTo: '/' }); }}>
              <button className="text-faint hover:text-ink">Sign out</button>
            </form>
          </nav>
        }
      />
      <main className="mx-auto max-w-5xl px-4 py-8">{children}</main>
    </div>
  );
}
```

- [ ] **Step 2: Subject picker `/app`**

```tsx
// src/app/(app)/app/page.tsx
import Link from 'next/link';
import { eq } from 'drizzle-orm';
import { getDb, schema } from '@/db';

export default async function AppHome() {
  const db = getDb();
  const subjects = await db.query.subjects.findMany({
    where: eq(schema.subjects.isLive, true),
  });
  return (
    <div>
      <h1 className="font-display text-2xl">Pick a subject</h1>
      <div className="mt-6 grid gap-4 sm:grid-cols-2">
        {subjects.map((s) => (
          <Link
            key={s.slug} href={`/app/${s.slug}`}
            className="rounded-xl border border-line bg-card p-5 transition hover:border-teal"
          >
            <span className="rounded-full bg-teal-soft px-2 py-0.5 text-xs font-medium text-teal">{s.certBody}</span>
            <h2 className="mt-3 font-display text-lg">{s.name}</h2>
            <p className="mt-1 text-sm text-faint">bank v{s.bankVersion}</p>
          </Link>
        ))}
      </div>
    </div>
  );
}
```

- [ ] **Step 3: Subject overview `/app/[subject]`** (start forms post to `startSession`; count of questions from DB; recent sessions listed)

```tsx
// src/app/(app)/app/[subject]/page.tsx
import { notFound } from 'next/navigation';
import Link from 'next/link';
import { and, desc, eq, sql } from 'drizzle-orm';
import { auth } from '@/auth';
import { getDb, schema } from '@/db';
import { startSession } from '@/server/actions/sessions';

export default async function SubjectPage({ params }: { params: Promise<{ subject: string }> }) {
  const { subject } = await params;
  const db = getDb();
  const session = await auth();
  const subj = await db.query.subjects.findFirst({ where: eq(schema.subjects.slug, subject) });
  if (!subj || !subj.isLive) notFound();

  const [{ total }] = await db
    .select({ total: sql<number>`count(*)::int` })
    .from(schema.questions)
    .where(eq(schema.questions.subjectSlug, subject));

  const user = await db.query.users.findFirst({
    where: eq(schema.users.email, session!.user!.email!),
  });
  const recent = await db.query.examSessions.findMany({
    where: and(eq(schema.examSessions.userId, user!.id), eq(schema.examSessions.subjectSlug, subject)),
    orderBy: desc(schema.examSessions.startedAt),
    limit: 5,
  });

  return (
    <div>
      <h1 className="font-display text-2xl">{subj.name}</h1>
      <p className="mt-1 text-sm text-muted">{subj.certBody} · {total} questions · bank v{subj.bankVersion}</p>

      <div className="mt-8 grid gap-4 sm:grid-cols-2">
        <div className="rounded-xl border border-line bg-card p-5">
          <h2 className="font-display text-lg">🎯 Practice</h2>
          <p className="mt-1 text-sm text-muted">Instant feedback with explanations after each answer.</p>
          <form action={startSession} className="mt-4 flex items-center gap-3">
            <input type="hidden" name="subject" value={subject} />
            <input type="hidden" name="mode" value="practice" />
            <select name="questionCount" className="rounded-lg border border-line bg-card px-3 py-2 text-sm" defaultValue="25">
              <option value="25">25 questions</option>
              <option value="50">50 questions</option>
              <option value={String(total)}>All {total}</option>
            </select>
            <button className="rounded-lg bg-teal px-4 py-2 text-sm font-semibold text-white">Start</button>
          </form>
        </div>

        <div className="rounded-xl border border-hall-line bg-hall p-5 text-hall-text">
          <h2 className="font-display text-lg">⏱ Exam simulation</h2>
          <p className="mt-1 text-sm text-hall-dim">Timed, no feedback until you submit. Like the real thing.</p>
          <form action={startSession} className="mt-4 flex items-center gap-3">
            <input type="hidden" name="subject" value={subject} />
            <input type="hidden" name="mode" value="exam" />
            <select name="questionCount" className="rounded-lg border border-hall-line bg-hall-card px-3 py-2 text-sm" defaultValue={String(subj.defaultExamQuestionCount)}>
              <option value={String(subj.defaultExamQuestionCount)}>{subj.defaultExamQuestionCount} questions</option>
              <option value={String(total)}>All {total}</option>
            </select>
            <select name="minutes" className="rounded-lg border border-hall-line bg-hall-card px-3 py-2 text-sm" defaultValue={String(subj.defaultExamMinutes)}>
              <option value={String(subj.defaultExamMinutes)}>{subj.defaultExamMinutes} min</option>
              <option value="120">120 min</option>
              <option value="150">150 min</option>
            </select>
            <button className="rounded-lg bg-sky px-4 py-2 text-sm font-bold text-hall">Begin</button>
          </form>
        </div>
      </div>

      {recent.length > 0 && (
        <section className="mt-10">
          <h2 className="font-display text-lg">Recent sessions</h2>
          <ul className="mt-3 divide-y divide-line rounded-xl border border-line bg-card">
            {recent.map((s) => (
              <li key={s.id} className="flex items-center justify-between px-4 py-3 text-sm">
                <span className="capitalize">{s.mode} · {s.config.questionCount} Q</span>
                <span className="text-muted">{s.startedAt.toISOString().slice(0, 10)}</span>
                {s.finishedAt ? (
                  <Link className="font-medium text-teal" href={`/app/${subject}/results/${s.id}`}>
                    {s.score}/{s.config.questionCount} →
                  </Link>
                ) : (
                  <Link className="font-medium text-amber" href={`/app/${subject}/${s.mode}/${s.id}`}>
                    resume →
                  </Link>
                )}
              </li>
            ))}
          </ul>
        </section>
      )}
    </div>
  );
}
```

- [ ] **Step 4: Results history `/app/results`**

```tsx
// src/app/(app)/app/results/page.tsx
import Link from 'next/link';
import { desc, eq } from 'drizzle-orm';
import { auth } from '@/auth';
import { getDb, schema } from '@/db';

export default async function ResultsPage() {
  const session = await auth();
  const db = getDb();
  const user = await db.query.users.findFirst({
    where: eq(schema.users.email, session!.user!.email!),
  });
  const sessions = await db.query.examSessions.findMany({
    where: eq(schema.examSessions.userId, user!.id),
    orderBy: desc(schema.examSessions.startedAt),
    limit: 50,
  });

  return (
    <div>
      <h1 className="font-display text-2xl">My results</h1>
      <ul className="mt-6 divide-y divide-line rounded-xl border border-line bg-card">
        {sessions.length === 0 && (
          <li className="px-4 py-8 text-center text-sm text-faint">No sessions yet — go practice!</li>
        )}
        {sessions.map((s) => {
          const pct = s.finishedAt && s.config.questionCount > 0
            ? Math.round(((s.score ?? 0) / s.config.questionCount) * 100) : null;
          return (
            <li key={s.id} className="flex items-center justify-between gap-4 px-4 py-3 text-sm">
              <div>
                <span className="font-medium capitalize">{s.mode}</span>
                <span className="text-muted"> · {s.subjectSlug} · {s.startedAt.toISOString().slice(0, 16).replace('T', ' ')}</span>
              </div>
              {s.finishedAt ? (
                <Link href={`/app/${s.subjectSlug}/results/${s.id}`} className="font-medium text-teal">
                  {s.score}/{s.config.questionCount} ({pct}%) →
                </Link>
              ) : (
                <Link href={`/app/${s.subjectSlug}/${s.mode}/${s.id}`} className="font-medium text-amber">
                  in progress — resume →
                </Link>
              )}
            </li>
          );
        })}
      </ul>
    </div>
  );
}
```

- [ ] **Step 5: Result detail with per-question review** (only for finished, owned sessions; explanations shown here)

```tsx
// src/app/(app)/app/[subject]/results/[sessionId]/page.tsx
import { notFound, redirect } from 'next/navigation';
import { and, eq, inArray } from 'drizzle-orm';
import { auth } from '@/auth';
import { getDb, schema } from '@/db';
import { VoteBar } from '@/components/VoteBar';

export default async function ResultDetail({
  params,
}: {
  params: Promise<{ subject: string; sessionId: string }>;
}) {
  const { subject, sessionId } = await params;
  const authSession = await auth();
  const db = getDb();
  const user = await db.query.users.findFirst({
    where: eq(schema.users.email, authSession!.user!.email!),
  });
  const sess = await db.query.examSessions.findFirst({
    where: and(eq(schema.examSessions.id, sessionId), eq(schema.examSessions.userId, user!.id)),
  });
  if (!sess) notFound();
  if (!sess.finishedAt) redirect(`/app/${subject}/${sess.mode}/${sess.id}`);

  const qids = sess.questionOrder.map((o) => o.questionId);
  const qs = await db.query.questions.findMany({ where: inArray(schema.questions.id, qids) });
  const answers = await db.query.sessionAnswers.findMany({
    where: eq(schema.sessionAnswers.sessionId, sess.id),
  });
  const qById = new Map(qs.map((q) => [q.id, q]));
  const aById = new Map(answers.map((a) => [a.questionId, a]));
  const total = sess.config.questionCount;
  const pct = Math.round(((sess.score ?? 0) / total) * 100);
  const minutes = Math.round((sess.finishedAt.getTime() - sess.startedAt.getTime()) / 60000);

  return (
    <div>
      <div className="rounded-xl border border-line bg-card p-6 text-center">
        <p className="text-sm uppercase tracking-wide text-faint">{sess.mode} result</p>
        <p className="mt-2 font-display text-5xl">{pct}%</p>
        <p className="mt-1 text-sm text-muted">{sess.score}/{total} correct · {minutes} min</p>
      </div>

      <ol className="mt-8 space-y-4">
        {sess.questionOrder.map((o, idx) => {
          const q = qById.get(o.questionId);
          const a = aById.get(o.questionId);
          if (!q) return null;
          const correct = a?.isCorrect === true;
          return (
            <li key={o.questionId} className="rounded-xl border border-line bg-card p-5">
              <div className="flex items-start justify-between gap-3">
                <p className="text-sm font-medium">
                  <span className="text-faint">Q{idx + 1}.</span> {q.text}
                </p>
                <span className={`shrink-0 text-lg ${correct ? 'text-good' : 'text-bad'}`}>
                  {correct ? '✓' : '✗'}
                </span>
              </div>
              <ul className="mt-3 space-y-1.5 text-sm">
                {o.choiceOrder.map((key) => {
                  const choice = q.choices.find((c) => c.key === key)!;
                  const isCorrectKey = q.correctKey.split(',').includes(key);
                  const isGiven = a?.givenKey === key;
                  return (
                    <li
                      key={key}
                      className={`rounded-lg border px-3 py-1.5 ${
                        isCorrectKey ? 'border-good bg-teal-soft'
                        : isGiven ? 'border-bad bg-red-50' : 'border-line'
                      }`}
                    >
                      <b className="mr-1">{key}.</b>{choice.text}
                      {isGiven && !isCorrectKey && <span className="ml-2 text-xs text-bad">your answer</span>}
                    </li>
                  );
                })}
              </ul>
              <div className="mt-3 rounded-lg border border-amber/30 bg-amber/5 p-3 text-sm text-muted">
                <b className="text-ink">Why:</b> {q.explanation}
              </div>
              {q.votes && <VoteBar votes={q.votes} />}
            </li>
          );
        })}
      </ol>
    </div>
  );
}
```

- [ ] **Step 6: Verify + commit**

```bash
npm run build && npx tsc --noEmit
git add src/app/
git commit -m "feat: auth gate, subject pages, results history and review"
```

(`VoteBar` arrives in Task 20 — if building this task in isolation, create it from the Task 20 code block first.)

---

### Task 20: Shared question components + Practice mode

**Files:**
- Create: `src/components/VoteBar.tsx`, `src/components/QuestionCard.tsx`, `src/components/PracticeRunner.tsx`, `src/app/(app)/app/[subject]/practice/[sessionId]/page.tsx`

- [ ] **Step 1: VoteBar.tsx**

```tsx
// src/components/VoteBar.tsx
export function VoteBar({ votes }: { votes: Record<string, number> }) {
  const entries = Object.entries(votes).sort((a, b) => b[1] - a[1]);
  return (
    <div className="mt-2 flex items-center gap-2 text-xs text-faint">
      <span>Community:</span>
      <div className="flex h-2.5 w-40 overflow-hidden rounded-full bg-line">
        {entries.map(([key, pct], i) => (
          <div
            key={key}
            style={{ width: `${pct}%` }}
            className={i === 0 ? 'bg-good' : 'bg-faint'}
            title={`${key} ${pct}%`}
          />
        ))}
      </div>
      <span>{entries.map(([k, p]) => `${k} ${p}%`).join(' · ')}</span>
    </div>
  );
}
```

- [ ] **Step 2: QuestionCard.tsx** (presentational; used by both runners)

```tsx
// src/components/QuestionCard.tsx
export interface ClientChoice { key: string; text: string }

export function QuestionCard({
  index, total, scenarioText, questionText, choices, selectedKey, revealedKey, disabled, dark, onSelect,
}: {
  index: number;
  total: number;
  scenarioText: string | null;
  questionText: string;
  choices: ClientChoice[];
  selectedKey: string | null;
  revealedKey: string | null; // correct key, once known (practice after answer / never in exam)
  disabled: boolean;
  dark?: boolean;
  onSelect: (key: string) => void;
}) {
  const base = dark
    ? { card: 'border-hall-line bg-hall-card text-hall-text', choice: 'border-hall-line bg-hall', sel: 'border-sky bg-sky/10' }
    : { card: 'border-line bg-card', choice: 'border-line bg-card', sel: 'border-teal bg-teal-soft' };
  return (
    <div className={`rounded-xl border p-5 ${base.card}`}>
      <p className={`text-xs uppercase tracking-wide ${dark ? 'text-hall-dim' : 'text-faint'}`}>
        Question {index + 1} of {total}
      </p>
      {scenarioText && (
        <details className={`mt-3 rounded-lg border p-3 text-sm ${base.choice}`} open={index === 0}>
          <summary className="cursor-pointer font-medium">Scenario</summary>
          <p className="mt-2 whitespace-pre-line">{scenarioText}</p>
        </details>
      )}
      <p className="mt-4 whitespace-pre-line text-[15px] leading-relaxed">{questionText}</p>
      <div className="mt-4 space-y-2">
        {choices.map((c) => {
          const isSel = selectedKey === c.key;
          const isRight = revealedKey !== null && revealedKey.split(',').includes(c.key);
          const isWrongPick = revealedKey !== null && isSel && !isRight;
          return (
            <button
              key={c.key} type="button" disabled={disabled}
              onClick={() => onSelect(c.key)}
              className={`block w-full rounded-lg border px-4 py-2.5 text-left text-sm transition ${
                isRight ? 'border-good bg-teal-soft text-ink'
                : isWrongPick ? 'border-bad bg-red-50 text-ink'
                : isSel ? base.sel : base.choice
              } ${disabled ? '' : 'hover:border-teal'}`}
            >
              <b className="mr-2">{c.key}.</b>{c.text}
            </button>
          );
        })}
      </div>
    </div>
  );
}
```

- [ ] **Step 3: PracticeRunner.tsx** (client state machine: select → answer action → show explanation → next; question map sidebar)

```tsx
// src/components/PracticeRunner.tsx
'use client';

import { useState, useTransition } from 'react';
import { answerQuestion, submitSession, type AnswerResult } from '@/server/actions/sessions';
import { QuestionCard, type ClientChoice } from '@/components/QuestionCard';
import { VoteBar } from '@/components/VoteBar';

export interface PracticeQuestion {
  questionId: string;
  scenarioText: string | null;
  text: string;
  choices: ClientChoice[]; // already in shuffled order, no correct key included
}

export function PracticeRunner({
  sessionId, questions,
}: {
  sessionId: string;
  questions: PracticeQuestion[];
}) {
  const [current, setCurrent] = useState(0);
  const [results, setResults] = useState<Record<number, AnswerResult & { givenKey: string }>>({});
  const [pending, startTransition] = useTransition();

  const q = questions[current];
  const r = results[current];
  const answeredCount = Object.keys(results).length;

  const select = (key: string) => {
    if (r || pending) return;
    startTransition(async () => {
      const res = await answerQuestion(sessionId, q.questionId, key);
      setResults((prev) => ({ ...prev, [current]: { ...res, givenKey: key } }));
    });
  };

  const finish = () => startTransition(() => submitSession(sessionId));

  return (
    <div className="flex flex-col gap-6 md:flex-row">
      <aside className="md:w-44 md:shrink-0">
        <div className="mb-2 h-1.5 overflow-hidden rounded-full bg-line">
          <div className="h-full bg-good" style={{ width: `${(answeredCount / questions.length) * 100}%` }} />
        </div>
        <div className="flex flex-wrap gap-1">
          {questions.map((_, i) => {
            const res = results[i];
            return (
              <button
                key={i} onClick={() => setCurrent(i)}
                className={`h-7 w-7 rounded-md text-xs font-medium ${
                  i === current ? 'bg-amber text-white'
                  : res ? (res.isCorrect ? 'bg-good text-white' : 'bg-bad text-white')
                  : 'bg-line text-muted'
                }`}
              >
                {i + 1}
              </button>
            );
          })}
        </div>
      </aside>

      <div className="min-w-0 flex-1">
        <QuestionCard
          index={current} total={questions.length}
          scenarioText={q.scenarioText} questionText={q.text} choices={q.choices}
          selectedKey={r?.givenKey ?? null}
          revealedKey={r?.correctKey ?? null}
          disabled={!!r || pending}
          onSelect={select}
        />

        {r && (
          <div className="mt-4 rounded-xl border border-amber/30 bg-amber/5 p-4 text-sm">
            <p className={`font-semibold ${r.isCorrect ? 'text-good' : 'text-bad'}`}>
              {r.isCorrect ? '✓ Correct' : `✗ Not quite — correct answer: ${r.correctKey}`}
            </p>
            <p className="mt-2 whitespace-pre-line text-muted">{r.explanation}</p>
            {r.votes && <VoteBar votes={r.votes} />}
          </div>
        )}

        <div className="mt-6 flex justify-between">
          <button
            disabled={current === 0} onClick={() => setCurrent((c) => c - 1)}
            className="rounded-lg border border-line px-4 py-2 text-sm disabled:opacity-40"
          >
            ← Previous
          </button>
          {current < questions.length - 1 ? (
            <button
              onClick={() => setCurrent((c) => c + 1)}
              className="rounded-lg bg-teal px-5 py-2 text-sm font-semibold text-white"
            >
              Next →
            </button>
          ) : (
            <button
              onClick={finish} disabled={pending}
              className="rounded-lg bg-teal px-5 py-2 text-sm font-semibold text-white disabled:opacity-50"
            >
              Finish session
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Practice page** (server component — builds the client payload WITHOUT correct keys/explanations)

```tsx
// src/app/(app)/app/[subject]/practice/[sessionId]/page.tsx
import { notFound, redirect } from 'next/navigation';
import { and, eq, inArray } from 'drizzle-orm';
import { auth } from '@/auth';
import { getDb, schema } from '@/db';
import { PracticeRunner, type PracticeQuestion } from '@/components/PracticeRunner';

export default async function PracticePage({
  params,
}: {
  params: Promise<{ subject: string; sessionId: string }>;
}) {
  const { subject, sessionId } = await params;
  const authSession = await auth();
  const db = getDb();
  const user = await db.query.users.findFirst({
    where: eq(schema.users.email, authSession!.user!.email!),
  });
  const sess = await db.query.examSessions.findFirst({
    where: and(eq(schema.examSessions.id, sessionId), eq(schema.examSessions.userId, user!.id)),
  });
  if (!sess || sess.mode !== 'practice') notFound();
  if (sess.finishedAt) redirect(`/app/${subject}/results/${sess.id}`);

  const qids = sess.questionOrder.map((o) => o.questionId);
  const qs = await db.query.questions.findMany({
    where: inArray(schema.questions.id, qids),
    columns: { id: true, text: true, choices: true, scenarioId: true },
  });
  const scenarioIds = [...new Set(qs.map((q) => q.scenarioId).filter((s): s is string => !!s))];
  const scen = scenarioIds.length
    ? await db.query.scenarios.findMany({ where: inArray(schema.scenarios.id, scenarioIds) })
    : [];
  const scenById = new Map(scen.map((s) => [s.id, s.text]));
  const qById = new Map(qs.map((q) => [q.id, q]));

  const questions: PracticeQuestion[] = sess.questionOrder.map((o) => {
    const q = qById.get(o.questionId)!;
    return {
      questionId: q.id,
      scenarioText: q.scenarioId ? scenById.get(q.scenarioId) ?? null : null,
      text: q.text,
      choices: o.choiceOrder.map((key) => q.choices.find((c) => c.key === key)!),
    };
  });

  return <PracticeRunner sessionId={sess.id} questions={questions} />;
}
```

- [ ] **Step 5: Verify + commit**

```bash
npm run build && npx tsc --noEmit
git add src/components/ src/app/
git commit -m "feat: practice mode with instant feedback and question map"
```

---

### Task 21: Exam simulation mode

**Files:**
- Create: `src/components/ExamRunner.tsx`, `src/app/(app)/app/[subject]/exam/[sessionId]/page.tsx`

- [ ] **Step 1: ExamRunner.tsx** (dark exam-hall UI; countdown derived from server `startedAt`; flags; confirm-submit; auto-submit at 0)

```tsx
// src/components/ExamRunner.tsx
'use client';

import { useEffect, useMemo, useState, useTransition } from 'react';
import { answerQuestion, submitSession, toggleFlag } from '@/server/actions/sessions';
import { QuestionCard, type ClientChoice } from '@/components/QuestionCard';

export interface ExamQuestion {
  questionId: string;
  scenarioText: string | null;
  text: string;
  choices: ClientChoice[];
}

export function ExamRunner({
  sessionId, questions, startedAtMs, minutes, initialAnswers, initialFlags,
}: {
  sessionId: string;
  questions: ExamQuestion[];
  startedAtMs: number;
  minutes: number;
  initialAnswers: Record<string, string>; // questionId -> givenKey (resume support)
  initialFlags: string[];
}) {
  const [current, setCurrent] = useState(0);
  const [answers, setAnswers] = useState<Record<string, string>>(initialAnswers);
  const [flags, setFlags] = useState<Set<string>>(new Set(initialFlags));
  const [confirming, setConfirming] = useState(false);
  const [now, setNow] = useState(() => Date.now());
  const [pending, startTransition] = useTransition();

  const deadline = startedAtMs + minutes * 60_000;
  const remaining = Math.max(0, deadline - now);

  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(t);
  }, []);

  useEffect(() => {
    if (remaining === 0) startTransition(() => submitSession(sessionId));
  }, [remaining, sessionId]);

  const clock = useMemo(() => {
    const s = Math.floor(remaining / 1000);
    const h = String(Math.floor(s / 3600)).padStart(2, '0');
    const m = String(Math.floor((s % 3600) / 60)).padStart(2, '0');
    const ss = String(s % 60).padStart(2, '0');
    return `${h}:${m}:${ss}`;
  }, [remaining]);

  const q = questions[current];
  const given = answers[q.questionId] ?? null;

  const select = (key: string) => {
    setAnswers((prev) => ({ ...prev, [q.questionId]: key })); // optimistic
    startTransition(async () => { await answerQuestion(sessionId, q.questionId, key); });
  };

  const flag = () => {
    const next = !flags.has(q.questionId);
    setFlags((prev) => {
      const s = new Set(prev);
      if (next) s.add(q.questionId); else s.delete(q.questionId);
      return s;
    });
    startTransition(async () => { await toggleFlag(sessionId, q.questionId, next); });
  };

  const answeredCount = Object.keys(answers).length;

  return (
    <div className="min-h-screen bg-hall text-hall-text">
      <header className="flex items-center justify-between border-b border-hall-line bg-hall-card px-4 py-3">
        <span className="font-display text-sm font-semibold text-sky">⬢ EXAM SIMULATION</span>
        <span className={`rounded-lg border border-hall-line px-3 py-1 font-mono text-sm ${
          remaining < 5 * 60_000 ? 'text-bad' : 'text-timer'
        }`}>⏱ {clock}</span>
      </header>

      <div className="mx-auto flex max-w-5xl flex-col gap-6 px-4 py-6 md:flex-row">
        <aside className="md:w-48 md:shrink-0">
          <p className="mb-2 text-xs text-hall-dim">{answeredCount}/{questions.length} answered · ⚑ {flags.size}</p>
          <div className="flex flex-wrap gap-1">
            {questions.map((qq, i) => (
              <button
                key={qq.questionId} onClick={() => setCurrent(i)}
                className={`h-7 w-7 rounded-md text-xs font-medium ${
                  i === current ? 'bg-sky text-hall'
                  : flags.has(qq.questionId) ? 'bg-timer text-hall'
                  : answers[qq.questionId] ? 'bg-hall-line text-hall-text'
                  : 'bg-hall-card text-hall-dim'
                }`}
              >
                {i + 1}
              </button>
            ))}
          </div>
        </aside>

        <div className="min-w-0 flex-1">
          <QuestionCard
            index={current} total={questions.length} dark
            scenarioText={q.scenarioText} questionText={q.text} choices={q.choices}
            selectedKey={given} revealedKey={null} disabled={false}
            onSelect={select}
          />
          <div className="mt-6 flex items-center justify-between">
            <button onClick={flag} className={`rounded-lg border px-4 py-2 text-sm ${
              flags.has(q.questionId) ? 'border-timer text-timer' : 'border-hall-line text-hall-dim'
            }`}>
              ⚑ {flags.has(q.questionId) ? 'Flagged' : 'Flag for review'}
            </button>
            <div className="flex gap-3">
              <button
                disabled={current === 0} onClick={() => setCurrent((c) => c - 1)}
                className="rounded-lg border border-hall-line px-4 py-2 text-sm text-hall-dim disabled:opacity-40"
              >
                ← Prev
              </button>
              {current < questions.length - 1 ? (
                <button onClick={() => setCurrent((c) => c + 1)}
                  className="rounded-lg bg-sky px-5 py-2 text-sm font-bold text-hall">
                  Next →
                </button>
              ) : (
                <button onClick={() => setConfirming(true)}
                  className="rounded-lg bg-timer px-5 py-2 text-sm font-bold text-hall">
                  Submit exam
                </button>
              )}
            </div>
          </div>
        </div>
      </div>

      {confirming && (
        <div className="fixed inset-0 flex items-center justify-center bg-black/60 p-4">
          <div className="w-full max-w-sm rounded-xl border border-hall-line bg-hall-card p-6 text-center">
            <p className="font-display text-lg">Submit exam?</p>
            <p className="mt-2 text-sm text-hall-dim">
              {answeredCount}/{questions.length} answered
              {flags.size > 0 && ` · ${flags.size} still flagged`}. This cannot be undone.
            </p>
            <div className="mt-5 flex justify-center gap-3">
              <button onClick={() => setConfirming(false)}
                className="rounded-lg border border-hall-line px-4 py-2 text-sm text-hall-dim">
                Keep working
              </button>
              <button
                disabled={pending}
                onClick={() => startTransition(() => submitSession(sessionId))}
                className="rounded-lg bg-timer px-5 py-2 text-sm font-bold text-hall disabled:opacity-50"
              >
                Submit
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
```

- [ ] **Step 2: Exam page** (server component; note it renders full-bleed — the `(app)` layout wraps it in the light chrome, which is acceptable for v1: header + dark canvas below)

```tsx
// src/app/(app)/app/[subject]/exam/[sessionId]/page.tsx
import { notFound, redirect } from 'next/navigation';
import { and, eq, inArray } from 'drizzle-orm';
import { auth } from '@/auth';
import { getDb, schema } from '@/db';
import { ExamRunner, type ExamQuestion } from '@/components/ExamRunner';

export default async function ExamPage({
  params,
}: {
  params: Promise<{ subject: string; sessionId: string }>;
}) {
  const { subject, sessionId } = await params;
  const authSession = await auth();
  const db = getDb();
  const user = await db.query.users.findFirst({
    where: eq(schema.users.email, authSession!.user!.email!),
  });
  const sess = await db.query.examSessions.findFirst({
    where: and(eq(schema.examSessions.id, sessionId), eq(schema.examSessions.userId, user!.id)),
  });
  if (!sess || sess.mode !== 'exam') notFound();
  if (sess.finishedAt) redirect(`/app/${subject}/results/${sess.id}`);

  const qids = sess.questionOrder.map((o) => o.questionId);
  const qs = await db.query.questions.findMany({
    where: inArray(schema.questions.id, qids),
    columns: { id: true, text: true, choices: true, scenarioId: true },
  });
  const scenarioIds = [...new Set(qs.map((q) => q.scenarioId).filter((s): s is string => !!s))];
  const scen = scenarioIds.length
    ? await db.query.scenarios.findMany({ where: inArray(schema.scenarios.id, scenarioIds) })
    : [];
  const scenById = new Map(scen.map((s) => [s.id, s.text]));
  const qById = new Map(qs.map((q) => [q.id, q]));

  const existing = await db.query.sessionAnswers.findMany({
    where: eq(schema.sessionAnswers.sessionId, sess.id),
  });
  const initialAnswers = Object.fromEntries(
    existing.filter((a) => a.givenKey).map((a) => [a.questionId, a.givenKey!]),
  );
  const initialFlags = existing.filter((a) => a.flagged).map((a) => a.questionId);

  const questions: ExamQuestion[] = sess.questionOrder.map((o) => {
    const q = qById.get(o.questionId)!;
    return {
      questionId: q.id,
      scenarioText: q.scenarioId ? scenById.get(q.scenarioId) ?? null : null,
      text: q.text,
      choices: o.choiceOrder.map((key) => q.choices.find((c) => c.key === key)!),
    };
  });

  return (
    <ExamRunner
      sessionId={sess.id}
      questions={questions}
      startedAtMs={sess.startedAt.getTime()}
      minutes={sess.config.minutes ?? 90}
      initialAnswers={initialAnswers}
      initialFlags={initialFlags}
    />
  );
}
```

- [ ] **Step 3: Verify + commit**

```bash
npm run build && npx tsc --noEmit
git add src/components/ExamRunner.tsx src/app/
git commit -m "feat: timed exam simulation with flags, resume, auto-submit"
```

### Task 22: Admin console

**Files:**
- Create: `src/app/(app)/admin/page.tsx`, `src/components/AdminDecideButtons.tsx`

- [ ] **Step 1: Write AdminDecideButtons.tsx** (client wrapper for the decide action)

```tsx
// src/components/AdminDecideButtons.tsx
'use client';

import { useTransition } from 'react';
import { decideAccessRequest } from '@/server/actions/admin';

export function AdminDecideButtons({ requestId }: { requestId: string }) {
  const [pending, startTransition] = useTransition();
  return (
    <div className="flex gap-2">
      <button
        disabled={pending}
        onClick={() => startTransition(() => decideAccessRequest(requestId, 'approved'))}
        className="rounded-lg bg-teal px-3 py-1.5 text-xs font-semibold text-white disabled:opacity-50"
      >
        Approve
      </button>
      <button
        disabled={pending}
        onClick={() => startTransition(() => decideAccessRequest(requestId, 'rejected'))}
        className="rounded-lg border border-line px-3 py-1.5 text-xs text-muted disabled:opacity-50"
      >
        Reject
      </button>
    </div>
  );
}
```

- [ ] **Step 2: Write admin page** (inside `(app)` so the gate layout applies; adds its own role check — non-admins get 404)

```tsx
// src/app/(app)/admin/page.tsx
import { notFound } from 'next/navigation';
import { desc, eq, sql } from 'drizzle-orm';
import { auth } from '@/auth';
import { getDb, schema } from '@/db';
import { AdminDecideButtons } from '@/components/AdminDecideButtons';

export default async function AdminPage() {
  const session = await auth();
  const db = getDb();
  const me = await db.query.users.findFirst({
    where: eq(schema.users.email, session!.user!.email!),
  });
  if (me?.role !== 'admin') notFound();

  const requests = await db.query.accessRequests.findMany({
    orderBy: desc(schema.accessRequests.createdAt),
    limit: 50,
  });
  const users = await db.query.users.findMany({ orderBy: desc(schema.users.approvedAt) });
  const [{ sessionCount }] = await db
    .select({ sessionCount: sql<number>`count(*)::int` })
    .from(schema.examSessions);

  return (
    <div className="space-y-10">
      <section>
        <h1 className="font-display text-2xl">Access requests</h1>
        <ul className="mt-4 divide-y divide-line rounded-xl border border-line bg-card">
          {requests.length === 0 && (
            <li className="px-4 py-6 text-center text-sm text-faint">No requests.</li>
          )}
          {requests.map((r) => (
            <li key={r.id} className="flex items-center justify-between gap-4 px-4 py-3 text-sm">
              <div className="min-w-0">
                <p className="font-medium">{r.email}</p>
                {r.message && <p className="truncate text-xs text-faint">{r.message}</p>}
                <p className="text-xs text-faint">{r.createdAt.toISOString().slice(0, 16).replace('T', ' ')}</p>
              </div>
              {r.status === 'pending' ? (
                <AdminDecideButtons requestId={r.id} />
              ) : (
                <span className={`text-xs font-medium ${r.status === 'approved' ? 'text-good' : 'text-bad'}`}>
                  {r.status}
                </span>
              )}
            </li>
          ))}
        </ul>
      </section>

      <section>
        <h2 className="font-display text-xl">Users</h2>
        <ul className="mt-4 divide-y divide-line rounded-xl border border-line bg-card">
          {users.map((u) => (
            <li key={u.id} className="flex items-center justify-between px-4 py-3 text-sm">
              <span>{u.email}</span>
              <span className="text-xs text-faint">
                {u.role}{u.approvedAt ? ` · approved ${u.approvedAt.toISOString().slice(0, 10)}` : ' · not approved'}
              </span>
            </li>
          ))}
        </ul>
        <p className="mt-3 text-xs text-faint">{sessionCount} total study sessions recorded.</p>
      </section>
    </div>
  );
}
```

- [ ] **Step 3: Verify + commit**

```bash
npm run build && npx tsc --noEmit
git add src/app/ src/components/AdminDecideButtons.tsx
git commit -m "feat: admin console (access requests, users)"
```

---

### Task 23: Local end-to-end verification + polish pass

No new files planned — this task exercises the whole app against a real database and fixes what falls out. Use the webapp-testing skill (Playwright) for the browser steps.

- [ ] **Step 1: Create a dev database and push schema.** Create a free Neon project (dashboard: https://console.neon.tech, project name `exam-nanoteofficial`) — or reuse an existing Neon account branch. Then:

```bash
cd /project/src/exam.nanoteofficial.me
cp .env.example .env
# fill DATABASE_URL with the Neon connection string, AUTH_SECRET with `npx auth secret` output,
# AUTH_RESEND_KEY from the Resend account used by plan.nanoteofficial.me
DATABASE_URL="<neon-url>" npx drizzle-kit push
npm run seed
```

Expected seed output: `✓ seeded iso-27001-li v1.0.0: 285 inserted, 0 updated, N scenarios`.

- [ ] **Step 2: Full walkthrough with Playwright (webapp-testing skill)** — `npm run dev`, then verify:
  1. `/` renders: hero, 3 subject cards, request-access form. Submit a fake email → success message; submit 3 more from same IP → rate-limit message.
  2. `/signin` with `khantee9@gmail.com` (allowlisted) → "check your email"; complete the magic link from the Resend dashboard log (or click the link in the received email) → lands on `/app` as approved admin.
  3. Start a 25-question practice session → answer a question wrong on purpose → red state + explanation + vote bar appear; question map shows red; finish → results page.
  4. Start an exam simulation (50 Q / 90 min) → timer ticks down; flag a question (amber in navigator); answer some; refresh the page → answers and flags survive (resume works); submit → results with review.
  5. `/app/results` lists both sessions; result detail shows correct/incorrect choices + explanations.
  6. `/admin` shows the fake access request → approve it → status flips.
  7. Signed-out access to `/app/...` redirects to `/signin`; a non-admin (approve a second test email) gets 404 on `/admin`.

- [ ] **Step 3: Fix everything found.** Commit fixes individually with descriptive messages (`fix: ...`).

- [ ] **Step 4: Polish sweep** (frontend-design plugin conventions): check mobile at 390px width — practice map wraps above the card, exam navigator collapses, landing hero scales; check focus states on all buttons/inputs; check empty states. Commit as `polish: responsive + focus states pass`.

- [ ] **Step 5: Full gate**

```bash
npm run lint && npx tsc --noEmit && npm test && npm run validate:content && npm run build
git add -A && git commit -m "chore: v1 verification pass complete"   # only if changes exist
```

---

### Task 24: Infra & release (base-deployment)

Follow the base-deployment skill's workflow shape (verify → version → push → confirm production). Steps below are the concrete sequence for this project.

- [ ] **Step 1: Create the PRIVATE GitHub repo and push**

```bash
cd /project/src/exam.nanoteofficial.me
gh repo create khantee8/exam.nanoteofficial.me --private --source=. --push
```

**Private is mandatory** — `content/` holds the extracted question bank.

- [ ] **Step 2: Create the Vercel project** linked to the repo (Vercel MCP `create_git_project` or dashboard). Framework preset: Next.js. Then set production env vars (`vercel:env` skill or dashboard): `DATABASE_URL` (production Neon), `AUTH_SECRET` (fresh `npx auth secret`), `AUTH_RESEND_KEY`, `AUTH_RESEND_FROM=ExamPrep <exam@nanoteofficial.me>`, `ALLOWED_EMAILS=khantee9@gmail.com`.

- [ ] **Step 3: Production database**: create the production Neon database (separate from dev, or the dev project's `main` branch if dev used a branch), then:

```bash
DATABASE_URL="<prod-neon-url>" npx drizzle-kit push
DATABASE_URL="<prod-neon-url>" npm run seed
```

- [ ] **Step 4: Domain**: add `exam.nanoteofficial.me` to the Vercel project. **Ask the user (NaNote) to add the Namecheap CNAME** `exam → cname.vercel-dns.com` — this is their manual step; wait for confirmation before the final smoke test.

- [ ] **Step 5: Tag and release**

```bash
git tag v1.0.0 && git push origin main --tags
```

Vercel auto-deploys `main`. Confirm the deployment is green (Vercel MCP `get_deployment` / dashboard).

- [ ] **Step 6: Production smoke test**: on https://exam.nanoteofficial.me — landing loads over HTTPS, magic-link sign-in with the admin email works end-to-end, one practice question answers correctly, `/api/auth`-gated routes redirect when signed out. Fix-forward anything broken.

- [ ] **Step 7: Document**: add an `### exam.nanoteofficial.me` section to `/project/CLAUDE.md` (stack, commands, architecture summary, env vars) and a memory-index entry; commit the dotfiles repo separately:

```bash
cd /project
git add CLAUDE.md && git commit -m "docs: add exam.nanoteofficial.me project section" && git push origin main
```

---

## Self-Review Notes (performed at write time)

1. **Spec coverage:** UI direction + landing (Tasks 18–21 ✓), login+approval (14, 17, 22 ✓), first subject + pipeline with with/without-answer variants + explanations (3–12 ✓), random + scenario grouping + choice shuffle (16 ✓), exam sim + timer (21 ✓), saved history (17, 19 ✓), repo + release + DNS (24 ✓), private-content constraint (1, 18, 24 ✓), multi-subject readiness (schema keyed by subjectSlug, content folder per subject ✓).
2. **Placeholder scan:** no TBDs; every code step has complete code; extraction tasks are inherently judgment work and carry an explicit grammar + completion checks instead.
3. **Type consistency:** `OrderedQuestionRef` defined in both `schema.ts` and `shuffle.ts` (structurally identical — jsonb typing needs the schema-side copy; acceptable duplication, noted). `AnswerResult`, `PracticeQuestion`, `ExamQuestion`, `ClientChoice` usage checked across Tasks 17/20/21. `sess.questionOrder`/`sess.config` jsonb types flow from schema `$type<>`.
4. **Known judgment calls for the executor:** Auth.js adapter lazy-init (Task 14 note), Next 16 API drift (always check `node_modules/next/dist/docs/` or context7), exam page rendering inside the light `(app)` chrome (accepted for v1).






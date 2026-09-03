# exam.nanoteofficial.me v1.2.0 — Design Spec

**Status:** Approved
**Date:** 2026-09-03
**Author:** NaNote + Claude
**Builds on:** v1.1.1 (live at https://exam.nanoteofficial.me)
**Previous specs:** `2026-09-02-exam-nanoteofficial-design.md`, `2026-09-02-exam-nanoteofficial-v1.1-design.md`

---

## 1. Overview

v1.2 makes a session configurable instead of fixed. Today a learner gets two
modes and three sizes, with order and choice order decided for them. That suits
revision but not a first pass, where the goal is to read the bank through in
order and see the reasoning before guessing.

Six changes:

1. **A third mode, `study`** — untimed, answer revealed on demand.
2. **More sizes** — 10 / 20 / 25 / 50 / 100 / All.
3. **Question order** — in-order or shuffled, chosen per session.
4. **Choice order** — fixed or shuffled, applied only where it is safe (§6).
5. **Bookmarks and retry-wrong** — star questions; build a session from
   bookmarks or from questions previously answered incorrectly.
6. **A redesigned start screen** — mode first, then one shared block of controls.

## 2. Goals / non-goals

**Goals:** support a genuine first pass through the bank; let a returning learner
target exactly what they got wrong; keep every explanation truthful under every
setting; keep the start screen legible on a phone.

**Non-goals:** per-question mastery statistics over time; a second subject; any
change to an answer key; a mascot or bookmark control inside the exam runner.

## 3. Modes

| Mode | Timed | Feedback | Score |
|---|---|---|---|
| `study` | no | revealed on demand, before or without answering | none — shows "reviewed N of M" |
| `practice` | no | after the learner commits to an answer | correct / total |
| `exam` | yes | only after submit | correct / total |

`study` exists because a score is meaningless when the answer is one tap away.
Study sessions are still saved to history so a learner can see what they have
worked through; the results screen shows coverage rather than a percentage.

Answering in study mode is optional. A **Show answer** control sits below the
choices; revealing marks the question reviewed. If the learner does answer first,
the behaviour matches practice.

## 4. Start screen

Layout: mode cards first, then one shared block of controls that adapts to the
selected mode.

- **Mode** — Study / Practice / Exam, as three cards.
- **How many** — 10, 20, 25, 50, 100, All. Presets larger than the available pool
  are hidden rather than shown and rejected.
- **Question order** — In order / Shuffled. Defaults: in-order for study,
  shuffled for practice and exam.
- **Choice order** — Fixed / Shuffled. Default fixed. See §6.
- **Draw from** — Whole bank / Bookmarks / Questions I got wrong. Sources with
  nothing in them are disabled with the count shown, never silently empty.
- **Minutes** — exam only: 90 / 120 / 150.

The block is a single column on phones; controls are segmented buttons with a
44px minimum touch target, consistent with the v1.1 responsive pass.

## 5. Question order

`in order` yields ascending question number. `shuffled` keeps the existing
behaviour: scenario blocks stay contiguous and internally ascending, and whole
blocks are shuffled with a seeded RNG.

Both orders still respect whole-block preservation, so a session may contain
fewer questions than requested; callers continue to read `order.length` and
`config.questionCount` continues to store the actual length.

## 6. Choice order and the lettered-explanation constraint

83 of the 285 explanations refer to an option by letter ("option B is tempting").
Shuffling choices makes those references point at the wrong text — a defect that
already shipped once in v1.0 and was fixed by disabling choice shuffling.

v1.2 reintroduces the toggle safely:

- `validate:content` scans every explanation, **English and Thai**, for a letter
  reference and records the result. English pattern: an option/statement/choice/
  answer word followed by a bare `A`–`F`. Thai pattern: `ตัวเลือก` followed by
  `A`–`F`. The scan is part of the content gate, so the set is derived, never a
  hand-maintained list.
- The result is stored as `questions.lettersInExplanation`.
- When choice order is `shuffled`, the session engine shuffles the choices of
  questions where the flag is false and leaves the rest canonical.
- The UI states this plainly next to the control rather than hiding it.

**A separate task in this release rewrites those 83 explanations**, in both
languages, to name the answer's content instead of its letter. When the flag
count reaches zero the toggle covers all 285 with no code change. The validator
reports the remaining count on every run so the number is visible.

## 7. Bookmarks and retry-wrong

- New table `bookmark`: `userId`, `questionId`, `createdAt`, primary key
  (`userId`, `questionId`). Deleting a user or question cascades.
- A star control appears on each question in study and practice, **never in
  exam** — the same reasoning that keeps the mascot out: nothing in a timed
  attempt should invite reflection about the answer.
- `Draw from: Bookmarks` builds the pool from the learner's bookmarks.
- `Draw from: Questions I got wrong` builds it from questions with an incorrect
  answer in any of that learner's finished sessions, de-duplicated.
- The results screen gains **Retry the N you missed**, which starts a practice
  session over exactly that set. Hidden when N is zero.

## 8. Data model

- `examSessions.mode` gains `'study'`.
- `examSessions.config` (jsonb) gains `order: 'sequential' | 'shuffled'`,
  `choiceOrder: 'fixed' | 'shuffled'`, `source: 'all' | 'bookmarks' | 'wrong'`.
  jsonb needs no migration, but **rows written before v1.2 lack these keys**, so
  every reader must default them (`sequential` is not a safe default for old
  rows — they were shuffled; default `order` to `'shuffled'`).
- `questions.lettersInExplanation boolean not null default false`.
- New `bookmark` table as above.

## 9. Session engine

`buildQuestionOrder` gains options:

```ts
interface OrderOptions {
  order: 'sequential' | 'shuffled';
  choiceOrder: 'fixed' | 'shuffled';
}
```

and each `PoolQuestion` carries `letterSafe: boolean`. Sequential order sorts
groups by their first question number instead of shuffling them; choice shuffling
applies only when `choiceOrder === 'shuffled' && letterSafe`. The function stays
pure and seeded, and its existing tests continue to hold for the shuffled path.

## 10. Security

Unchanged invariants apply to every new action: bookmark and session-source
queries filter by the signed-in `userId`; a bookmark for a question outside the
subject is rejected; `source: 'wrong'` reads only that user's own sessions. The
exam runner still receives no `correctKey`, and study mode's reveal returns the
answer through the same server action that practice uses, so the key is never in
the initial payload.

## 11. Verification

Gate unchanged: `tsc` + `lint` + `test` + `validate:content` + `build`, with
`validate:content` additionally reporting the count of explanations still naming
a letter. Plus a live pass covering: a study session revealing an answer without
guessing, an in-order session starting at Q1, a shuffled-choice session leaving a
flagged question canonical, bookmarking then drawing from bookmarks, and
retry-wrong from a finished result.

## 12. Release

Tag `v1.2.0` after live verification. Bank version bumps to `1.2.0` only if the
83 explanations are rewritten in this release; otherwise it stays `1.1.0` and the
rewrite ships as `1.2.1`.

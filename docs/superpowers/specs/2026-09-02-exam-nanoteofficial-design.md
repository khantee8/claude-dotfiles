# exam.nanoteofficial.me — Design Spec

**Status:** Approved
**Date:** 2026-09-02
**Author:** NaNote + Claude
**Version target:** v1.0.0

---

## 1. Overview

A private, invite-only exam-practice web application for IT / cybersecurity certification exams, hosted at `exam.nanoteofficial.me`. v1 ships a single subject — **PECB ISO/IEC 27001 Lead Implementer** (285 questions sourced from the user's ExamTopics contributor-access PDFs) — but every layer (content format, data model, routing, UI) is multi-subject from day one. Adding a subject later means: drop source files in a folder, run the content pipeline, seed, done.

**Privacy constraint (hard requirement):** the question bank originates from ExamTopics contributor content. All question content sits behind the login + admin-approval gate. The public landing page shows only subject names, question counts, and feature descriptions — never actual bank questions.

## 2. Goals

1. UI/UX in the spirit of ExamTopics (question cards, reveal-style flow) but with its own distinct, hand-crafted brand — explicitly *not* looking AI-generated or template-default.
2. Public landing page + magic-link login with admin (NaNote) approval of every account.
3. First subject: PECB ISO/IEC 27001 Lead Implementer; architecture ready for more IT/cyber certs.
4. Content pipeline: source PDFs → OCR/extraction → curated, versioned markdown (with and without answer key) → Postgres seed. Every answer gets a written explanation for the examinee.
5. Practice features: randomized question order and shuffled choices, with scenario-based question groups kept contiguous; timed exam-simulation mode.
6. Saved session history ("My results").
7. Deployed to Vercel with its own repo and release tags, via the base-deployment workflow.

## 3. Non-goals (v1)

- Discussion threads / comments per question
- Weak-area analytics, per-topic mastery, spaced repetition (v2 candidates)
- Payments or public self-serve signup
- Thai translation of question content (UI is English in v1)
- Additional subjects (folders may exist; only ISO 27001 LI is seeded/visible)
- Editing questions through an admin UI (markdown in git is the editing surface)

## 4. Stack

| Layer | Choice | Rationale |
|---|---|---|
| Framework | Next.js 16 (App Router), React 19, TypeScript | House standard |
| Styling | Tailwind v4 | House standard |
| Auth | Auth.js v5 + Resend magic link | Proven in plan.nanoteofficial.me; passwordless |
| DB | Neon Postgres + Drizzle ORM | Proven in plan.nanoteofficial.me |
| Hosting | Vercel Hobby, auto-deploy from `main` | House standard |
| Repo | `khantee8/exam.nanoteofficial.me` (new) | One repo per subdomain project |
| DNS | `exam` CNAME → Vercel (Namecheap) | Same as other subdomains |

No test runner: the verification gate is `npm run build` (must pass with `DATABASE_URL` unset) + `npx tsc --noEmit` + `npm run lint`, matching plan.nanoteofficial.me. Pure logic modules (markdown parser, shuffler) are written as small dependency-free functions so a test runner can be added later without refactoring.

## 5. Content pipeline

Source layout (already present):

```
/project/src/exam.nanoteofficial.me/ISO27001-Lead-Implementer/
  1-50.pdf          1-50-answer.pdf
  51-100.pdf        51-100-answer.pdf
  101-150.pdf       101-150-answer.pdf
  151-200.pdf       151-200-answer.pdf
  201-250.pdf       201-250-answer.pdf
  251-285.pdf       251-285-answer.pdf
```

Question PDFs contain question text + choices; answer PDFs are the same pages with the correct answer highlighted plus community vote distribution. Many questions reference shared scenarios ("Scenario 1: HealthGenic…", "Refer to scenario 3").

Pipeline (executed by Claude, best-effort OCR via PDF page reading):

1. Read each PDF page-by-page; extract per question: number (1–285), topic, scenario reference, question text, choices (A/B/C — occasionally more), correct answer, community vote distribution.
2. Cross-check question PDF vs answer PDF; where community vote disagrees with the marked answer, keep the marked answer as `correct` and record the vote split.
3. Write a short explanation for every question — why the correct answer is right (grounded in ISO/IEC 27001:2022, ISO/IEC 27002, ISO 27000 definitions where applicable), and one line on why distractors are wrong when useful.
4. Emit per-subject files, committed to the project repo:

```
content/iso-27001-li/
  subject.json        # id, name, cert body, count, default exam settings (question count, minutes)
  bank.md             # MASTER: version header + scenarios + all questions with answers,
                      # votes, explanations
  questions-only.md   # generated from bank.md — no answer key (the "without" variant)
```

`bank.md` format (parser contract):

```markdown
---
subject: iso-27001-li
version: 1.0.0
generated: 2026-09-02
---

## Scenario 1
<scenario text>

### Q1 [scenario: 1] [topic: 1]
<question text>
- (A) <choice>
- (B) <choice> ✅
- (C) <choice>
> **Answer: B** — votes: B 100%
> **Why:** <explanation>
```

5. `npm run seed` parses `bank.md` + `subject.json` → upserts into Postgres (idempotent, keyed by subject + question number). Markdown in git is the source of truth; the DB is a queryable copy.

Quality bar: all 285 questions present, zero missing correct answers, every question has an explanation, scenario links resolve. A `npm run validate:content` script checks these invariants without a DB.

## 6. Data model (Drizzle / Postgres)

- `subjects` — slug, name, certBody, isLive, defaultExamQuestionCount, defaultExamMinutes, bankVersion
- `scenarios` — subjectId, number, text
- `questions` — subjectId, number, topic, scenarioId (nullable), text, choices (jsonb `[{key, text}]`), correctKey, explanation, votes (jsonb)
- `users` — email, name, role (`admin` | `member`), approvedAt
- `access_requests` — email, message, status (`pending` | `approved` | `rejected`), createdAt, decidedAt
- `exam_sessions` — userId, subjectId, mode (`practice` | `exam`), config (jsonb: questionCount, minutes, shuffleSeed), questionOrder (jsonb), startedAt, finishedAt, score
- `session_answers` — sessionId, questionId, givenKey, isCorrect, flagged, answeredAt

Auth.js tables (users/accounts/verification tokens) via the Drizzle adapter; app `users` extends the Auth.js user with role/approval.

## 7. Access model

1. Visitor lands on `/` → "Request access" form (email + optional note) → creates `access_requests` row. Emails on `ALLOWED_EMAILS` env (the admin) skip approval entirely.
2. Admin sees pending requests at `/admin` → approve or reject. Approval creates/flags the user as approved.
3. Approved user signs in via magic link (Resend). Unapproved sign-in attempts land on a polite "pending approval" page.
4. Gate implementation: route-group layout `src/app/(app)/layout.tsx` checks session + approval — **no middleware/proxy** (same pattern as plan.nanoteofficial.me). Admin routes additionally check `role === 'admin'`.

## 8. Routes

| Route | Access | Purpose |
|---|---|---|
| `/` | public | Landing: hero, stats, subject catalog (live + coming-soon), request access, sign in |
| `/signin` | public | Magic-link form |
| `/pending` | signed-in, unapproved | "Waiting for approval" |
| `/app` | approved | Subject picker / home (v1: one subject card) |
| `/app/[subject]` | approved | Subject overview: start practice, start exam sim, resume, recent results |
| `/app/[subject]/practice` | approved | Practice mode |
| `/app/[subject]/exam` | approved | Exam simulation (setup → running → submit) |
| `/app/[subject]/results/[sessionId]` | approved (owner) | Result detail + per-question review |
| `/app/results` | approved | My results history |
| `/admin` | admin | Access requests, user list, session overview |

Server actions handle: request access, approve/reject, start session, answer question, flag, submit session. No public API routes in v1.

## 9. Modes & mechanics

**Randomization (requirement 5.1):** question order is shuffled per session with a stored seed, but questions sharing a scenario stay contiguous and in ascending order within their block (the scenario is shuffled as a unit). Choices are shuffled per question per session (seed-derived), with the answer key mapped accordingly; `session_answers` stores canonical keys.

**Practice mode** (calm study-app look — warm paper `#fafaf7`, teal `#0f766e`): question-map sidebar (answered/correct/current), progress bar, pick an answer → immediate right/wrong + explanation panel + community vote bar → next. Session size presets: 25, 50, or all remaining questions. Practice sessions are saved to history like exams (mode-tagged).

**Exam simulation** (focused exam-hall look — dark slate `#0f172a`, sky/amber accents): setup screen (question count, minutes — defaults from `subject.json`), countdown timer in the top bar, flag-for-review, question navigator, no feedback during the run, confirm-submit (auto-submit at 0:00), then a results screen: score, pass-style band, time used, per-question review with explanations.

**Timer integrity:** server records `startedAt`; remaining time derives from server time on load, ticks client-side. Refresh-safe resume.

## 10. Look & feel

- Distinct hand-crafted brand: warm paper background, ink text, teal primary, generous whitespace, a serif display face for headings paired with a clean sans for UI — deliberately avoiding default-Tailwind/AI-template tells (no generic purple gradients, no emoji-grid feature sections).
- Exam mode swaps to the dark exam-hall palette — a clear "you're in the testing room now" mode switch.
- ExamTopics-familiar bones: numbered question cards, banner-style question headers, reveal-flow — reinterpreted in the new brand.
- Responsive: practice comfortably usable on a phone.

## 11. Security

- All question content behind the approval gate; landing page contains no bank content.
- Server actions validate session ownership (users can only read/write their own sessions).
- No `dangerouslySetInnerHTML`; question/explanation markdown rendered through a safe renderer.
- Secrets (`DATABASE_URL`, `AUTH_SECRET`, `AUTH_RESEND_KEY`, `ALLOWED_EMAILS`) in Vercel env only.
- Rate-limit request-access submissions (simple per-IP check) to prevent spam rows.
- Magic-link tokens are the only auth path; no passwords stored.

## 12. Deployment & release

1. New repo `khantee8/exam.nanoteofficial.me` (source lives in `/project/src/exam.nanoteofficial.me/`; the source PDFs folder is gitignored — only derived markdown is committed).
2. Vercel project + Neon DB + Resend domain config; `exam` CNAME in Namecheap.
3. base-deployment workflow: verify (build + tsc + lint + content validation) → commit → tag `v1.0.0` → push → confirm production deploy.
4. `docs/` in the dotfiles repo gets the CLAUDE.md project section added after release.

## 13. Milestones

1. **M1 — Content**: pipeline run, `bank.md` complete + validated (285/285), `questions-only.md`, seed script.
2. **M2 — Skeleton**: repo scaffold, DB schema, auth + approval flow, landing page.
3. **M3 — Practice mode**: subject page, practice UI, explanations, history writes.
4. **M4 — Exam simulation**: setup, timer, flags, submit, results + review.
5. **M5 — Admin + polish**: admin console, results history page, responsive/brand pass.
6. **M6 — Release**: DNS, env, seed production, v1.0.0 tag, live smoke test.

## 14. Future (v2+)

More subjects (CISSP, Security+, CEH…), weak-area analytics, spaced repetition, discussion notes, TH UI translation, Telegram notification on new access requests.

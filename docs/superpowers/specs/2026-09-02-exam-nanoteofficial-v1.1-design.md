# exam.nanoteofficial.me v1.1.0 — Design Spec

**Status:** Approved
**Date:** 2026-09-02
**Author:** NaNote + Claude
**Builds on:** v1.0.0 (live at https://exam.nanoteofficial.me)
**Previous spec:** `2026-09-02-exam-nanoteofficial-design.md`

---

## 1. Overview

v1.1 makes the existing ISO/IEC 27001 Lead Implementer trainer usable in Thai,
comfortable on a phone or tablet, easier on the eyes at night, and a little more
alive. It adds no new subject and changes no existing answer key.

Six changes:

1. **Bilingual explanations** — every one of the 285 explanations gains a Thai
   translation, switched by a global TH/EN toggle.
2. **Dark mode** — follows the OS by default, with a manual per-device override.
3. **Shield Keeper mascot** — an inline-SVG character that reacts to your answers.
4. **Interface animation** — motion on reveal, progress and navigation.
5. **Responsive pass** — a real audit at phone, tablet and desktop widths.
6. **Delete a result** — remove a saved session (and its answers) from history.

## 2. Goals / non-goals

**Goals:** Thai comprehension support for a Thai examinee sitting an English exam;
a UI that is pleasant on any device and in any lighting; more life without losing
the calm, professional tone; and control over one's own saved history.

**Non-goals:** translating questions, choices or scenarios (the real PECB exam is
sat in English — practising on Thai wording would mislead); a second subject;
changing any `correctKey`; a mascot inside the exam simulator.

## 3. Bilingual explanations

### 3.1 Bank grammar extension

An optional Thai block follows the English one. The parser contract becomes:

```markdown
### Q1 [scenario: 1] [topic: 1]
Which of the following indicates that the confidentiality of information was compromised?
- (A) Service interruptions due to the increased number of users
- (B) Invasion of patients' privacy
- (C) Modification of patients' medical reports
> **Answer: B** — votes: B 100%
> **Why:** Confidentiality means information is not disclosed to unauthorised parties…
> **ทำไม:** การรักษาความลับหมายถึงข้อมูลจะไม่ถูกเปิดเผยต่อผู้ที่ไม่ได้รับอนุญาต…
```

Rules: `> **ทำไม:** ` starts the Thai block and, like `> **Why:**`, continues on
subsequent `> `-prefixed lines. It must come after the English block. It is optional
in the grammar (so the parser stays backward-compatible with v1.0 files) but
**required by the validator** once translation is complete.

- `ParsedQuestion` gains `explanationTh: string | null`.
- `bank.md` frontmatter `version` becomes `1.1.0`.
- `questions-only.md` continues to strip every `> ` line, so it is unaffected.

### 3.2 Translation process

Done in six batches of ~50 questions, one subagent each, then a second agent
reviews each batch against the English. Requirements:

- Translate meaning, not words. The reader is a Thai IT professional studying for
  an English-language certification.
- **Keep in English, never transliterate:** clause numbers (`6.1.3`), Annex A
  control identifiers (`A.5.15`), standard names (`ISO/IEC 27001:2022`), and the
  option letters referenced in the text (`option B`).
- **Glossary — use these consistently across all batches** so wording does not
  drift between questions:

  | English | Thai |
  |---|---|
  | information security | ความมั่นคงปลอดภัยสารสนเทศ |
  | confidentiality / integrity / availability | การรักษาความลับ / ความถูกต้องสมบูรณ์ / ความพร้อมใช้งาน |
  | asset | สินทรัพย์ |
  | threat / vulnerability | ภัยคุกคาม / ช่องโหว่ |
  | risk assessment / risk treatment | การประเมินความเสี่ยง / การจัดการความเสี่ยง |
  | control | มาตรการควบคุม |
  | nonconformity / corrective action | ความไม่สอดคล้อง / การปฏิบัติการแก้ไข |
  | internal audit / management review | การตรวจประเมินภายใน / การทบทวนของฝ่ายบริหาร |
  | ISMS | ระบบบริหารจัดการความมั่นคงปลอดภัยสารสนเทศ (ISMS) |
  | Statement of Applicability | เอกสารแสดงการบังคับใช้ (SoA) |

- Preserve the sentence that flags a marked-answer-vs-community disagreement where
  the English has one.
- Length should stay within roughly ±40% of the English; a translation far longer
  usually means the translator added commentary.

**Quality caveat (documented, not solved):** these are machine translations of
technical standards language. The review pass catches errors of meaning, but the
user should spot-check a sample before relying on them for exam preparation. The
UI therefore always allows switching back to the English original.

### 3.3 Data model

`questions.explanationTh text` (nullable). The seed script writes it. No migration
concerns beyond `drizzle-kit push` — the column is additive and the existing
`explanation` is untouched.

### 3.4 Language switching

- `src/lib/lang.ts` — reads/writes a `lang` cookie (`th` | `en`, default `en`),
  server-readable so the first paint is already correct (no flash of English).
- `src/lib/i18n.ts` — a flat dictionary of UI strings keyed by `en`/`th`. Every
  user-visible string in the app moves into it.
- A header toggle (`TH | EN`) sets the cookie via a server action and refreshes.
- Explanation rendering: show `explanationTh` when the language is `th` **and** a
  translation exists; otherwise fall back to English. When Thai is displayed, a
  small "EN" link reveals the original inline — technical translation should always
  be checkable against the source.
- Typography: `Noto Sans Thai` loaded via `next/font`, applied through the existing
  `--font-sans` stack so Thai and Latin sit together correctly.

## 4. Dark mode

- Class-based: `dark` on `<html>`, using Tailwind v4's `@variant dark`.
- Resolution order: explicit choice in `localStorage` → OS `prefers-color-scheme`.
- A blocking inline script in `<head>` applies the class before first paint to
  avoid a white flash; the toggle lives in the header beside the language switch.
- The `@theme` tokens gain dark values that keep the warm character rather than
  going flat grey: ink→`#f5f3ef`, paper→`#17161a`, card→`#201f24`, line→`#33313a`,
  muted→`#a8a29e`, teal lifted to `#2dd4bf` for contrast on dark.
- The exam simulator already uses the fixed "exam hall" palette and looks the same
  in both modes — that is deliberate, and its contrast is already verified.
- Contrast: every text/background pair must meet WCAG AA (4.5:1 for body text).

## 5. Shield Keeper mascot

`src/components/Mascot.tsx` — inline SVG, no image assets, inherits theme colours.

States: `idle` (gentle bob, occasional blink), `thinking` (while an answer is being
submitted), `correct` (nod + sparkle), `wrong` (soft squash, sympathetic expression).

Placement: the practice sidebar (reacts to each answer), the results summary (its
expression scaled to the score band), and empty states ("no sessions yet").
**Never in the exam simulator** — a reacting cartoon would undercut the testing-room
seriousness, and it would also hint at correctness, which the exam must not do.

## 6. Animation

CSS keyframes in `globals.css`, no animation library:

- explanation panel slides up and fades in on reveal
- the correct choice pulses a ring once when revealed
- question-map cells transition colour on state change
- the progress bar eases to its new width
- page content fades in on navigation

Every animation sits inside `@media (prefers-reduced-motion: no-preference)`, so a
user who asks their OS for reduced motion gets a still interface. Nothing animates
in a way that delays interaction.

## 7. Responsive pass

Audit and fix at **390px** (phone), **768px** (tablet), **1280px** (desktop) for
every screen: landing, sign-in, subject list, subject overview, practice runner,
exam runner, results review, history, admin.

Known weak points to fix rather than merely shrink:
- the exam navigator sidebar (should become a horizontal scroller above the card on
  phones, not a squeezed column)
- the results review (choice rows and the ✓/✗ marker must not overlap on narrow
  screens)
- the subject overview's two start panels (stack, with the dark exam panel keeping
  its full padding)

Acceptance: no horizontal page scroll at any of the three widths, all tap targets
≥ 44px, and no text below 12px.

## 8. Delete a result

- `deleteSession(sessionId)` server action: loads the session filtered by both `id`
  and the signed-in `userId`, deletes it; `session_answer` rows follow via the
  existing `ON DELETE CASCADE`. Returns to `/app/results`.
- UI: each row in `/app/results` gets a quiet delete control, and the result detail
  page gets one too. **A confirmation step is required** — deletion is permanent and
  a mis-tap would silently destroy a completed attempt.
- In-progress sessions can be deleted too (that is how you abandon one).
- Deleting affects only your own history; question content is never touched.

## 9. Verification

Gate unchanged: `tsc` + `lint` + `test` + `validate:content` + `build`, with
`validate:content` extended to require a Thai explanation for all 285 questions.
Plus a live pass on the deployed site covering: TH and EN in both light and dark,
the three viewport widths, a practice answer in Thai, a result deletion, and
`prefers-reduced-motion` honoured.

## 10. Release

Tag `v1.1.0` after the live verification passes. `bank.md` version → `1.1.0`, seeded
to production. `CLAUDE.md` updated with the grammar extension, the i18n split and
the dark-mode token rules.

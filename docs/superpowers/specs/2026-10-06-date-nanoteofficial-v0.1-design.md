# date.nanoteofficial.me v0.1 — Date invitation web app (design)

**Date:** 2026-10-06
**Status:** design approved in chat; spec awaiting owner review
**Repo:** `khantee8/date.nanoteofficial.me` (private, new) · **Live:** https://date.nanoteofficial.me

## 1. Purpose

NaNote wants to ask K.Montira on a date without filling her Instagram DMs. He sends
one link. The page asks the question with a cute mascot, makes "No" comically hard to
press, and, once she says yes, collects the practical details in under a minute. She
leaves with a summary she can scan or add to her calendar; he gets the answers in a
private admin log.

Success means: she smiles, she can finish on her phone with one thumb, and nothing on
the page looks machine-made.

## 2. Scope

In v0.1:

- The question screen with the runaway No button (desktop and mobile behaviours).
- A quiet "maybe" link, so she is never truly cornered.
- The details form, the summary page, QR code, `.ics` download, Google Calendar link.
- Optional confirmation email to her; notification email to NaNote.
- `/admin` behind a magic link for `khantee9@gmail.com` only, with a log page.
- Production deploy, tagged `v0.1.0`.

Out of v0.1: multiple invitees or reusable invitations, editing a submission after
sending, an EN toggle, Google Places autocomplete, push or Telegram notifications.

## 3. Decisions taken in brainstorming

| Topic | Decision |
|---|---|
| Who chooses date and restaurant | She picks everything freely |
| Mascot | Original animated SVG in the style of Meta's Muse mascot "Jolly"; no Meta artwork is used |
| Language | Thai, playful, single language |
| Domain | `date.nanoteofficial.me` |
| Declining | No stays uncatchable, but a "ขอคิดดูก่อนนะ" link appears after a few attempts |
| Stack | Same as `exam` and `cyber` |

| Her name on the page | The nickname "คุณเอ๊ม" |

### Beats taken from the reference clip

The owner supplied the clip (`/project/src/Dating Webapp.mp4`, 17 s). It shows a pale
pink page with one small centred card per step, serif headlines, and falling confetti
and hearts. We keep its structure and pacing and replace its look (section 9):

1. Card with a picture and "Will you go on a date with me?", a Yes button inside the
   card and a small No button that has escaped to outside the card.
2. A surprised interstitial: "WAIT YOU ACTUALLY SAID YES??", the line "I was so ready
   for you to say no", and an "okay okay →" button, with confetti.
3. "So... when are you free?" with a day and a time, and a "set the date!" button that
   stays disabled until both are filled.
4. "What are we feeling?" with a grid of six food tiles.
5. A closing card with a self-deprecating P.S. ("normal people text. I made a website…
   no big deal.").

## 4. Stack and structure

Next.js 16 (App Router), React 19, TypeScript, Tailwind v4, Auth.js v5 with the Resend
provider, Neon Postgres with Drizzle, Vitest, `motion` for springs, `qrcode` for the QR
image. Read `node_modules/next/dist/docs/` before writing Next-specific code.

```
src/
  app/
    page.tsx                 the question
    plan/page.tsx            the details form
    done/[id]/page.tsx       the summary
    done/[id]/date.ics/route.ts
    maybe/page.tsx           gentle "take your time" screen
    api/event/route.ts       event beacon
    signin/page.tsx
    (admin)/layout.tsx       the auth gate
    (admin)/admin/page.tsx   the log
    api/auth/[...nextauth]/route.ts
  components/
    mascot/Mascot.tsx        one SVG, pose prop
    ask/RunawayNo.tsx        the No button
    ask/AskScreen.tsx
    plan/*                   one component per question card
    done/Ticket.tsx
  lib/
    runaway.ts               pure: next position for the No button
    ics.ts                   pure: build the calendar file
    maps.ts                  pure: build and validate map links
    validate.ts              pure: submission schema
    mail.ts                  Resend sender (never throws)
    rateLimit.ts
  db/{index.ts,schema.ts}
  auth.ts
```

Rules carried over from `exam` and `cyber`: the gate is the `(admin)` layout, there is
no middleware; the Auth.js adapter uses an eager DB instance and everything else uses a
lazy `getDb()`; `npm run build` must pass with `DATABASE_URL` unset; server actions and
route handlers check the session themselves because invoking them never renders the
layout.

## 5. Her flow

### 5.1 `/` — the question

Full-screen, no scrolling. The mascot enters with a bounce and waves. Headline in
Thai asks her out by name. Two buttons: **ไปสิ!** (Yes) and **ไม่ไป** (No).

**No button, pointer devices** (`matchMedia('(hover: hover) and (pointer: fine)')`):

- When the pointer comes within 110 px of the button's edge, the button springs to a
  new position at least 220 px from the pointer and fully inside the viewport, with
  16 px padding. `runaway.ts` picks the position; it is a pure function of pointer,
  button size, viewport and a random seed.
- If the pointer has it cornered, it teleports to the far side with a small puff.
- It has `tabIndex={-1}` and ignores Enter and Space, so the keyboard cannot reach it.
  Yes keeps normal focus order.

**No button, touch devices:**

- On `touchstart` (before a tap can register) it hops to a new spot.
- Each attempt shrinks it by 8% down to a floor of 55%, grows Yes by 6% up to 150%,
  and swaps the label through a list: "ไม่ไป" → "แน่ใจนะ?" → "คิดอีกที~" →
  "ใจร้ายจัง" → "กดไม่โดนหรอก" → "ยอมแล้ว…".
- After 7 attempts the button gives up: it flips over and becomes a second Yes.

**Mascot reactions:** waving (idle), curious (pointer near No), pleading (attempts
1–3), teary (4–6), overjoyed (Yes). Poses cross-fade through one SVG.

**Maybe link:** after 3 No attempts, a small text link "ขอคิดดูก่อนนะ" fades in under
the buttons. It does not run away. It goes to `/maybe`, which thanks her, tells her
there is no rush, and offers one button back to the question. The tap is logged.

**Yes:** confetti burst and the mascot jumps. The card flips to the surprised
interstitial from the clip: "เดี๋ยวนะ… ตอบตกลงจริงเหรอ??" with the smaller line
"เตรียมใจโดนปฏิเสธไว้แล้วเชียว" and one button, "โอเค ๆ ไปต่อ →", which leads to `/plan`.

The headline on the question card addresses her as "คุณเอ๊ม". As in the clip, Yes sits
inside the card and No starts just outside it, already looking like it wants to leave.

### 5.2 `/plan` — the details

One question per card, a progress row of small dots, Back and Next. The mascot sits in
the corner and comments on each answer. State lives in the client until submit and is
mirrored to `sessionStorage` so a refresh does not lose it.

| # | Question | Control | Required |
|---|---|---|---|
| 1 | Date | Native date input, min = today | yes |
| 2 | Time | Chips 11:30 / 13:00 / 18:00 / 19:00 / 20:00, plus a native time input | yes |
| 3 | Restaurant | "วันนี้อยากกินอะไรดี?" Six food-mood tiles as in the clip (ญี่ปุ่น, ปิ้งย่าง/ชาบู, อิตาเลียน, ไทย, คาเฟ่/ของหวาน, แล้วแต่เลย); tapping one is optional and pre-fills the Maps search. Below: a text field for the restaurant name; "หาใน Google Maps" opens a Maps search (mood + name) in a new tab; optional field to paste a Maps link | name yes, mood and link no |
| 4 | Car | Two cards: "ไปรับนะ" (he drives) / "เจอกันที่ร้าน" (meet there) | yes |
| 5 | Alcohol | Two cards: "ดื่มได้" / "ไม่ดื่ม" | yes |
| 6 | Pace | Two cards: "กลับเร็ว" / "ดึกได้" | yes |
| 7 | Email + note | Optional email, optional short note (max 300 chars) | no |

All times are `Asia/Bangkok`. Submit is a server action: validate, rate-limit, insert,
send emails, redirect to `/done/[id]`.

### 5.3 `/done/[id]` — the summary

A "ticket" card with a perforated edge, stamped in with a spring:

- Date and time in Thai long form, restaurant name, the three choices as stickers.
- **Map link:** her pasted link if valid, otherwise a Maps search link built from the
  restaurant name.
- **QR code** of this page's URL, rendered server-side as inline SVG.
- **Add to calendar:** `.ics` download (`/done/[id]/date.ics`) and an "Add to Google
  Calendar" link. Event length defaults to 2 hours; alarms at 1 day and 2 hours before.
- A "save this page" hint, since the id is the only key to it.
- The clip's closing P.S. in small italics under the ticket: "ป.ล. คนปกติเขาก็แค่ทักแชต
  ส่วนเราทำเว็บมาให้ทั้งเว็บ… ไม่ได้ตั้งใจอะไรมากหรอกนะ". If she chose pickup, the headline
  reads like the clip's: "ดีใจที่ไม่ปฏิเสธนะ เดี๋ยวไปรับเอง".

`id` is a 21-character nanoid. An unknown id returns 404.

## 6. Data

Two tables besides the Auth.js four (`users`, `accounts`, `sessions`,
`verificationTokens`).

**`submission`**: `id` (nanoid, pk), `dateOn` (date), `timeAt` (time),
`foodMood` (nullable), `restaurantName`, `mapsUrl` (nullable), `car` (`pickup` | `meet`), `alcohol` (bool),
`pace` (`early` | `late`), `email` (nullable), `note` (nullable), `noAttempts` (int),
`device` (`desktop` | `mobile`), `userAgent`, `createdAt`.

**`event`**: `id` (serial), `visitorId` (random id in a first-party cookie), `kind`
(`open` | `no_attempt` | `maybe` | `yes` | `plan_step` | `submit`), `detail` (jsonb,
e.g. the attempt count or step number), `device`, `createdAt`.

Events arrive through `POST /api/event` via `navigator.sendBeacon`. `no_attempt` is
sent once per attempt but capped at 20 per visitor. No IP address is stored.

## 7. Admin

- `/signin` asks for an email and always shows the same "check your inbox" message.
- `auth.ts` allows sign-in only when the address is in `ALLOWED_EMAILS`
  (`khantee9@gmail.com`); the `signIn` callback returns false for anything else, so no
  token is created and no email is sent to strangers.
- `(admin)/layout.tsx` redirects to `/signin` without a session.
- `/admin` shows:
  - **Submissions**, newest first, each expandable to every field, with links to the
    summary page and the map.
  - **Timeline**: events grouped by visitor, so the story reads as "opened, tried No 5
    times, said yes, finished the form in 48 s".
  - A "maybe" visitor with no submission is shown as its own row.
- Submissions are kept; v0.1 has no delete button.

## 8. Email

`lib/mail.ts` is the `cyber` sender (plain fetch to Resend, never throws), with from
address `NaNote <date@nanoteofficial.me>` on the already-verified domain.

- **To NaNote, on submit:** all fields, plus a link to `/admin`.
- **To her, if she gave an email:** a short warm note, the summary, the map link and
  the `.ics` attached. Multipart text and HTML.
- **To NaNote, on maybe:** one line.

A failed send is logged and never blocks the redirect.

## 9. Look and motion

The brief is "cute, clearly hand-made, impressive". The rules that keep it from
looking generated:

- **Palette** taken from the mascot: cream `#FFF6E6` ground, blush `#FFB8C6`, butter
  `#FFE08A`, cocoa `#4A342E` for text and outlines, and one strong accent, cherry
  `#FF4D6D`, used only for Yes and the confetti. Flat colour; no gradients, no glass,
  no glow.
- **Type:** `Mali` (handwritten Thai, Google Fonts) for headlines and buttons,
  `IBM Plex Sans Thai Looped` for body text. Loaded with `next/font`.
- **Shapes:** 3 px cocoa outlines with slightly uneven radii, hard offset shadows
  (4 px, no blur) like stickers, an SVG paper-grain overlay, and small hand-drawn
  doodles (hearts, stars, squiggles) that drift slowly in the background.
- **Mascot:** a round cream body with a fuzzy outline (SVG turbulence on the stroke),
  beady eyes, rosy cheeks, stubby arms. Idle breathing and blinking run always; poses
  are driven by a `pose` prop. It is our own drawing, credited nowhere as Meta's.
- **Motion:** springs for everything interactive (press squash, card slides, ticket
  stamp), staggered entrances, a canvas confetti burst on Yes and on the ticket.
  Animate only `transform` and `opacity`. Under `prefers-reduced-motion` the springs
  become fades, confetti is skipped, and the No button still relocates but without the
  chase animation.
- **Layout:** designed at 390 px first, then 768 and 1280. `100dvh`, safe-area insets,
  tap targets of at least 48 px.

## 10. Privacy and abuse

- `robots.txt` disallows everything and every page sends `noindex, nofollow`.
- The submit action accepts 5 submissions per visitor cookie per hour and 30 per day
  overall (counted in Postgres); `/api/event` is capped per visitor.
- Input is validated server-side: date not in the past, lengths capped, `mapsUrl`
  accepted only for `google.com/maps`, `maps.google.com`, `maps.app.goo.gl` and
  `goo.gl/maps` over https.
- All user text is rendered as text, never as HTML, in pages and emails.
- The summary page is reachable only by its unguessable id.

## 11. Errors

- Validation failure: the form returns to the first invalid card with a friendly Thai
  message; nothing is lost.
- Database unreachable on submit: an apologetic mascot screen with a retry button; the
  answers stay in `sessionStorage`.
- Rate limit hit: the same screen with a "try again later" message.
- Without `DATABASE_URL` (local build), `/` and `/plan` render and submit shows the
  error screen.

## 12. Testing

- **Vitest:** `runaway.ts` (always in bounds, always at least the minimum distance,
  cornered case), `ics.ts` (valid VCALENDAR, Bangkok time converted to UTC, escaping,
  alarms), `maps.ts` (allowlist, search-link fallback), `validate.ts`, `rateLimit.ts`.
- **Playwright, against the dev server:** at 1280 px the No button cannot be clicked in
  30 pointer attempts and is not focusable; at 390 px with touch it gives up on the 7th
  tap; the maybe link appears after 3 attempts; a full Yes → form → summary run
  produces a QR code and a downloadable `.ics`; `/admin` redirects when signed out.
- **Gate before deploy:** `npm run lint && npx tsc --noEmit && npm test && npm run build`.

## 13. Deployment

1. Create the private GitHub repo and a new Vercel project (auto-deploy from `main`).
2. `vercel integration add neon` for a fresh database; `drizzle-kit push`.
3. Env: `DATABASE_URL`, `AUTH_SECRET`, `AUTH_RESEND_KEY`, `AUTH_RESEND_FROM`,
   `ALLOWED_EMAILS=khantee9@gmail.com`, `NOTIFY_EMAIL=khantee9@gmail.com`.
4. Bind `date.nanoteofficial.me` explicitly; it overrides the portfolio wildcard. The
   domain is on Vercel nameservers, so no Namecheap record is needed.
5. Verify the live flow on a real phone, sign in to `/admin`, then tag `v0.1.0`.
6. Afterwards: add the project to `/project/CLAUDE.md`, to memory, and decide whether
   it belongs on the tools map (it is private and personal, so probably not).

## 14. Open items

- The Thai copy in this spec is a first draft; NaNote reviews every line before the
  link is sent.

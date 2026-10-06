# date.nanoteofficial.me v0.1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a private, Thai-language date invitation site for คุณเอ๊ม: a runaway-No question screen, a details form, a summary ticket with QR and calendar export, and a magic-link admin log.

**Architecture:** One Next.js 16 App Router project. All logic that can be wrong lives in pure, unit-tested modules under `src/lib/` (No-button geometry, calendar file, map links, validation, QR path, timeline grouping). Client components do the animation; one server action writes a submission; a beacon route writes events; `/admin` sits behind an Auth.js magic link allowlisted to one address.

**Tech Stack:** Next.js 16.3.4, React 19.2.8, TypeScript, Tailwind v4, Auth.js v5 (`next-auth@^5.0.0-beta.32`, Resend provider), `@auth/drizzle-adapter`, `@neondatabase/serverless`, `drizzle-orm`, `motion@^14`, `qrcode@^1.5`, `nanoid@^6`, Vitest 4, `@playwright/test@^1.63`.

**Spec:** `/project/docs/superpowers/specs/2026-10-06-date-nanoteofficial-v0.1-design.md` — read it before any task. Reference clip: `/project/src/Dating Webapp.mp4`.

## Global Constraints

- Project root: `/project/src/date.nanoteofficial.me` (its own git repo; `/project/src` is gitignored by the dotfiles repo). All paths below are relative to it.
- Next.js 16 differs from training data. Before writing page, route-handler, server-action or `next/font` code, read the matching file under `node_modules/next/dist/docs/01-app/`. `params` and `searchParams` are Promises; use the generated `PageProps<'/route'>` and `RouteContext<'/route'>` helpers.
- No middleware and no `proxy.ts`. The only gate is `src/app/(admin)/layout.tsx`. Server actions and route handlers that need auth call `auth()` themselves.
- The Auth.js adapter uses the eager `db`; all other code calls `getDb()`.
- `npm run build` must pass with `DATABASE_URL` unset.
- Dev server port is **3100** (`next dev -p 3100`); port 3000 is taken on this machine.
- UI language is Thai only. She is addressed as **คุณเอ๊ม**. All times are `Asia/Bangkok` (UTC+7, no daylight saving).
- Colours, exact values: cream `#FFF6E6`, blush `#FFB8C6`, butter `#FFE08A`, cocoa `#4A342E`, cherry `#FF4D6D`. Flat fills only: no gradients, no blur/glass, no glow. Cherry is used only for Yes and confetti.
- Fonts: `Mali` (headlines, buttons) and `IBM Plex Sans Thai Looped` (body), through `next/font/google`.
- Outlines are 3 px cocoa; shadows are hard offsets (`4px 4px 0 #4A342E`), never blurred.
- Animate only `transform` and `opacity`. Honour `prefers-reduced-motion`.
- No emoji in UI (doodles are SVG). No `dangerouslySetInnerHTML`. User text is always rendered as text.
- No IP address is stored anywhere.
- Every page is `noindex, nofollow`.
- The mascot is an original drawing. Do not download, trace or embed any Meta artwork, and do not use the names "Jolly", "Muse" or "Meta" in the UI.
- Commits go to `main` of the project repo, conventional-commit style, ending with:
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
- Deviation from the spec, on purpose: `submission` gains a `visitorId` column (the spec's rate limit and timeline both need it).

## File Map

```
package.json, tsconfig.json, next.config.ts, postcss.config.mjs, eslint.config.mjs,
vitest.config.mts, playwright.config.ts, drizzle.config.ts, .gitignore, .env.example,
README.md, CLAUDE.md
src/
  app/
    layout.tsx               fonts, metadata (noindex), body shell
    globals.css              tokens + sticker utilities
    robots.ts                disallow all
    icon.svg                 mascot face
    page.tsx                 renders <AskScreen/>
    maybe/page.tsx           "no rush" screen
    plan/page.tsx            renders <PlanForm/>
    plan/actions.ts          submitPlan server action
    done/[id]/page.tsx       summary ticket
    done/[id]/date.ics/route.ts
    api/event/route.ts       event beacon
    api/auth/[...nextauth]/route.ts
    signin/page.tsx
    (admin)/layout.tsx       the gate
    (admin)/admin/page.tsx   the log
  components/
    mascot/Mascot.tsx        one SVG, `pose` prop
    ui/Card.tsx, ui/StickerButton.tsx, ui/Confetti.tsx, ui/Doodles.tsx
    ask/AskScreen.tsx, ask/RunawayNo.tsx
    plan/PlanForm.tsx, plan/steps.tsx
    done/Ticket.tsx, done/QrCode.tsx
  lib/
    runaway.ts   maps.ts   validate.ts   ics.ts   qr.ts   timeline.ts   rateLimit.ts
    copy.ts      every Thai string, one object
    track.ts     client beacon helper
    visitor.ts   server: read/create the visitor cookie
    mail.ts      Resend sender + the three messages
    site.ts      SITE_URL, TZ constants
  db/index.ts, db/schema.ts
  auth.ts
e2e/flow.spec.ts
```

---

### Task 1: Scaffold, theme tokens, fonts, headers

**Files:**
- Create: `package.json`, `tsconfig.json`, `next.config.ts`, `postcss.config.mjs`, `eslint.config.mjs`, `vitest.config.mts`, `.gitignore`, `.env.example`, `src/app/layout.tsx`, `src/app/globals.css`, `src/app/robots.ts`, `src/app/page.tsx` (temporary), `src/lib/site.ts`

**Interfaces:**
- Produces: CSS variables `--cream --blush --butter --cocoa --cherry`; Tailwind colour utilities `bg-cream text-cocoa bg-blush bg-butter bg-cherry`; font utilities `font-head` and `font-body`; CSS classes `.sticker` (outline + hard shadow) and `.grain`; `SITE_URL` and `TZ_OFFSET_HOURS` from `@/lib/site`.

- [ ] **Step 1: Create the repo and copy the config files that are identical to `cyber`**

```bash
mkdir -p /project/src/date.nanoteofficial.me && cd /project/src/date.nanoteofficial.me && git init -b main
cp ../cyber.nanoteofficial.me/{tsconfig.json,postcss.config.mjs,eslint.config.mjs,vitest.config.mts} .
```

- [ ] **Step 2: Write `package.json`**

```json
{
  "name": "date.nanoteofficial.me",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev -p 3100",
    "build": "next build",
    "start": "next start -p 3100",
    "lint": "eslint",
    "test": "vitest run",
    "e2e": "playwright test"
  },
  "dependencies": {
    "@auth/drizzle-adapter": "^1.11.3",
    "@neondatabase/serverless": "^1.1.0",
    "drizzle-orm": "^0.45.2",
    "motion": "^14.0.0",
    "nanoid": "^6.0.2",
    "next": "16.3.4",
    "next-auth": "^5.0.0-beta.32",
    "qrcode": "^1.5.4",
    "react": "19.2.8",
    "react-dom": "19.2.8",
    "server-only": "^0.0.1"
  },
  "devDependencies": {
    "@playwright/test": "^1.63.0",
    "@tailwindcss/postcss": "^4",
    "@types/node": "^20",
    "@types/qrcode": "^1.5.5",
    "@types/react": "^19",
    "@types/react-dom": "^19",
    "drizzle-kit": "^0.31.10",
    "eslint": "^9",
    "eslint-config-next": "16.3.4",
    "tailwindcss": "^4",
    "typescript": "^5",
    "vitest": "^4.1.11"
  }
}
```

Run: `npm install`. Expected: exits 0 and writes `package-lock.json`.

- [ ] **Step 3: Write `.gitignore` and `.env.example`**

`.gitignore`:

```
node_modules/
.next/
out/
.env
.env.*
!.env.example
.DS_Store
*.tsbuildinfo
.vercel
/test-results/
/playwright-report/
```

`.env.example`:

```
# Neon Postgres (pooled URL). The build must pass without it.
DATABASE_URL=
# Local only: Neon-protocol proxy in front of a plain Postgres.
NEON_LOCAL_PROXY=
AUTH_SECRET=
AUTH_RESEND_KEY=
AUTH_RESEND_FROM="NaNote <date@nanoteofficial.me>"
# The only address allowed to sign in to /admin.
ALLOWED_EMAILS=khantee9@gmail.com
# Where submit / maybe notifications go.
NOTIFY_EMAIL=khantee9@gmail.com
```

- [ ] **Step 4: Write `next.config.ts`** (security headers; same policy as `cyber`)

```ts
import type { NextConfig } from "next";

const dev = process.env.NODE_ENV === "development";

const csp = [
  "default-src 'self'",
  `script-src 'self' 'unsafe-inline'${dev ? " 'unsafe-eval'" : ""}`,
  "style-src 'self' 'unsafe-inline'",
  "img-src 'self' data:",
  "font-src 'self'",
  "connect-src 'self'",
  "frame-ancestors 'none'",
  "base-uri 'self'",
  "form-action 'self'",
].join("; ");

const nextConfig: NextConfig = {
  poweredByHeader: false,
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: [
          { key: "Content-Security-Policy", value: csp },
          { key: "Strict-Transport-Security", value: "max-age=63072000; includeSubDomains; preload" },
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "X-Frame-Options", value: "DENY" },
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
          { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=()" },
          { key: "X-Robots-Tag", value: "noindex, nofollow" },
        ],
      },
    ];
  },
};

export default nextConfig;
```

- [ ] **Step 5: Write `src/lib/site.ts`**

```ts
export const SITE_URL = 'https://date.nanoteofficial.me';
/** Asia/Bangkok is UTC+7 all year. */
export const TZ_OFFSET_HOURS = 7;
```

- [ ] **Step 6: Write `src/app/globals.css`**

```css
@import "tailwindcss";

:root {
  --cream: #fff6e6;
  --blush: #ffb8c6;
  --butter: #ffe08a;
  --cocoa: #4a342e;
  --cherry: #ff4d6d;
}

@theme inline {
  --color-cream: var(--cream);
  --color-blush: var(--blush);
  --color-butter: var(--butter);
  --color-cocoa: var(--cocoa);
  --color-cherry: var(--cherry);
  --font-head: var(--font-mali), system-ui, sans-serif;
  --font-body: var(--font-plex-thai), system-ui, sans-serif;
}

html, body { height: 100%; }
body {
  background: var(--cream);
  color: var(--cocoa);
  font-family: var(--font-body);
  -webkit-tap-highlight-color: transparent;
  overscroll-behavior: none;
}

/* Sticker look: thick outline, hard offset shadow, slightly uneven corners. */
.sticker {
  border: 3px solid var(--cocoa);
  box-shadow: 4px 4px 0 var(--cocoa);
  border-radius: 26px 22px 28px 20px / 22px 28px 20px 26px;
}
.sticker-sm {
  border: 3px solid var(--cocoa);
  box-shadow: 3px 3px 0 var(--cocoa);
  border-radius: 16px 14px 18px 13px / 14px 18px 13px 16px;
}

/* Paper grain: a fixed, non-interactive SVG noise layer. */
.grain::before {
  content: "";
  position: fixed;
  inset: 0;
  pointer-events: none;
  z-index: 50;
  opacity: 0.06;
  background-image: url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='160' height='160'><filter id='n'><feTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='2'/></filter><rect width='160' height='160' filter='url(%23n)'/></svg>");
}

.field {
  width: 100%;
  min-height: 52px;
  padding: 12px 14px;
  background: #fff;
  font-size: 17px;
  border: 3px solid var(--cocoa);
  border-radius: 14px 16px 13px 17px / 16px 13px 17px 14px;
}
.field:focus-visible, button:focus-visible, a:focus-visible {
  outline: 3px dashed var(--cherry);
  outline-offset: 3px;
}

@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after { animation-duration: 0.01ms !important; animation-iteration-count: 1 !important; }
}
```

- [ ] **Step 7: Write `src/app/layout.tsx`**

Read `node_modules/next/dist/docs/01-app/` for the current `next/font` API first.

```tsx
import type { Metadata, Viewport } from 'next';
import type { ReactNode } from 'react';
import { Mali, IBM_Plex_Sans_Thai_Looped } from 'next/font/google';
import './globals.css';

const mali = Mali({ subsets: ['thai', 'latin'], weight: ['500', '700'], variable: '--font-mali', display: 'swap' });
const plex = IBM_Plex_Sans_Thai_Looped({ subsets: ['thai', 'latin'], weight: ['400', '600'], variable: '--font-plex-thai', display: 'swap' });

export const metadata: Metadata = {
  title: 'มีเรื่องจะถาม',
  description: 'มีเรื่องจะถามนิดนึง',
  robots: { index: false, follow: false },
};

export const viewport: Viewport = { themeColor: '#FFF6E6', width: 'device-width', initialScale: 1, viewportFit: 'cover' };

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="th" className={`${mali.variable} ${plex.variable}`}>
      <body className="grain min-h-dvh">{children}</body>
    </html>
  );
}
```

- [ ] **Step 8: Write `src/app/robots.ts` and a temporary `src/app/page.tsx`**

```ts
import type { MetadataRoute } from 'next';

export default function robots(): MetadataRoute.Robots {
  return { rules: [{ userAgent: '*', disallow: '/' }] };
}
```

```tsx
export default function Home() {
  return (
    <main className="flex min-h-dvh items-center justify-center p-6">
      <div className="sticker bg-white p-8 font-head text-2xl">สวัสดี</div>
    </main>
  );
}
```

- [ ] **Step 9: Verify**

Run: `npx tsc --noEmit && npm run lint && npm run build`
Expected: all exit 0; build lists `/` and `/robots.txt`.

Run: `npm run dev` in the background, then `curl -sI http://localhost:3100/ | grep -i -E 'x-robots-tag|content-security'`
Expected: both headers present. Stop the dev server.

- [ ] **Step 10: Commit**

```bash
git add -A && git commit -m "chore: scaffold Next.js 16 app with theme tokens, fonts and security headers

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: No-button geometry (`runaway.ts`)

**Files:**
- Create: `src/lib/runaway.ts`
- Test: `src/lib/runaway.test.ts`

**Interfaces:**
- Produces:
  ```ts
  export type Pt = { x: number; y: number };
  export type Size = { w: number; h: number };
  export type Rect = Pt & Size;                       // x,y = top-left
  export const TRIGGER = 110;   // px from the button edge that starts an escape
  export const MIN_DIST = 220;  // px between pointer and the new button centre
  export const PAD = 16;        // px kept clear at every viewport edge
  export function distToRect(p: Pt, r: Rect): number;
  export function clampSpot(spot: Pt, size: Size, viewport: Size): Pt;
  export function overlaps(a: Rect, b: Rect, gap?: number): boolean;
  // top-left of the new spot; never lands on an `avoid` rect (the Yes button, the maybe link)
  export function nextSpot(input: { pointer: Pt; size: Size; viewport: Size; rand: () => number; avoid?: Rect[] }): Pt;
  export const NO_LABELS: readonly string[];          // 6 labels
  export const GIVE_UP_AT = 7;
  export const MAYBE_AT = 3;
  export function noScale(attempts: number): number;  // 1 → floor 0.55, −8% per attempt
  export function yesScale(attempts: number): number; // 1 → cap 1.5, +6% per attempt
  export function noLabel(attempts: number): string;
  ```

- [ ] **Step 1: Write the failing test** — `src/lib/runaway.test.ts`

```ts
import { describe, expect, it } from 'vitest';
import {
  GIVE_UP_AT, MIN_DIST, NO_LABELS, PAD, clampSpot, distToRect, nextSpot, noLabel, noScale, overlaps, yesScale,
} from './runaway';

/** Deterministic PRNG so failures reproduce. */
function seeded(seed: number) {
  let s = seed;
  return () => {
    s = (s * 1664525 + 1013904223) % 4294967296;
    return s / 4294967296;
  };
}

const size = { w: 96, h: 48 };
const viewports = [{ w: 1280, h: 800 }, { w: 390, h: 700 }, { w: 768, h: 1024 }];

describe('distToRect', () => {
  const r = { x: 100, y: 100, w: 50, h: 20 };
  it('is 0 inside the rect', () => expect(distToRect({ x: 120, y: 110 }, r)).toBe(0));
  it('measures to the nearest edge', () => expect(distToRect({ x: 90, y: 110 }, r)).toBe(10));
  it('measures to the nearest corner', () => expect(distToRect({ x: 97, y: 96 }, r)).toBe(5));
});

describe('nextSpot', () => {
  it('always lands fully inside the padded viewport', () => {
    for (const viewport of viewports) {
      const rand = seeded(7);
      for (let i = 0; i < 500; i++) {
        const pointer = { x: rand() * viewport.w, y: rand() * viewport.h };
        const s = nextSpot({ pointer, size, viewport, rand });
        expect(s.x).toBeGreaterThanOrEqual(PAD);
        expect(s.y).toBeGreaterThanOrEqual(PAD);
        expect(s.x + size.w).toBeLessThanOrEqual(viewport.w - PAD);
        expect(s.y + size.h).toBeLessThanOrEqual(viewport.h - PAD);
      }
    }
  });

  it('always puts the centre at least MIN_DIST from the pointer', () => {
    for (const viewport of viewports) {
      const rand = seeded(11);
      for (let i = 0; i < 500; i++) {
        const pointer = { x: rand() * viewport.w, y: rand() * viewport.h };
        const s = nextSpot({ pointer, size, viewport, rand });
        const d = Math.hypot(s.x + size.w / 2 - pointer.x, s.y + size.h / 2 - pointer.y);
        expect(d).toBeGreaterThanOrEqual(MIN_DIST);
      }
    }
  });

  it('falls back to the farthest corner when random tries all fail', () => {
    const viewport = { w: 390, h: 700 };
    // rand() === 0.5 always proposes the centre, which is too close to a centred pointer.
    const s = nextSpot({ pointer: { x: 195, y: 350 }, size, viewport, rand: () => 0.5 });
    const corners = [PAD, viewport.w - PAD - size.w];
    expect(corners).toContain(s.x);
    expect([PAD, viewport.h - PAD - size.h]).toContain(s.y);
  });
});

describe('avoid', () => {
  it('detects overlap, including a gap around the rect', () => {
    const a = { x: 0, y: 0, w: 10, h: 10 };
    expect(overlaps(a, { x: 5, y: 5, w: 10, h: 10 })).toBe(true);
    expect(overlaps(a, { x: 15, y: 0, w: 10, h: 10 })).toBe(false);
    expect(overlaps(a, { x: 15, y: 0, w: 10, h: 10 }, 6)).toBe(true);
  });

  it('never lands on the Yes button or the maybe link', () => {
    const viewport = { w: 390, h: 700 };
    const avoid = [{ x: 135, y: 380, w: 120, h: 56 }, { x: 120, y: 520, w: 150, h: 40 }];
    const rand = seeded(23);
    for (let i = 0; i < 500; i++) {
      const pointer = { x: rand() * viewport.w, y: rand() * viewport.h };
      const s = nextSpot({ pointer, size, viewport, rand, avoid });
      for (const a of avoid) expect(overlaps({ ...s, ...size }, a)).toBe(false);
    }
  });
});

describe('clampSpot', () => {
  it('pulls an off-screen spot back inside', () => {
    expect(clampSpot({ x: 2000, y: -50 }, size, { w: 390, h: 700 })).toEqual({ x: 390 - PAD - size.w, y: PAD });
  });
});

describe('scales and labels', () => {
  it('No shrinks 8% per attempt to a floor of 0.55', () => {
    expect(noScale(0)).toBe(1);
    expect(noScale(1)).toBeCloseTo(0.92);
    expect(noScale(50)).toBe(0.55);
  });
  it('Yes grows 6% per attempt to a cap of 1.5', () => {
    expect(yesScale(0)).toBe(1);
    expect(yesScale(2)).toBeCloseTo(1.12);
    expect(yesScale(50)).toBe(1.5);
  });
  it('labels advance and then hold on the last one', () => {
    expect(NO_LABELS).toHaveLength(6);
    expect(noLabel(0)).toBe('ไม่ไป');
    expect(noLabel(1)).toBe('แน่ใจนะ?');
    expect(noLabel(99)).toBe('ยอมแล้ว…');
    expect(GIVE_UP_AT).toBe(7);
  });
});
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `npx vitest run src/lib/runaway.test.ts`
Expected: FAIL, cannot resolve `./runaway`.

- [ ] **Step 3: Implement** — `src/lib/runaway.ts`

```ts
export type Pt = { x: number; y: number };
export type Size = { w: number; h: number };
export type Rect = Pt & Size;

export const TRIGGER = 110;
export const MIN_DIST = 220;
export const PAD = 16;
export const GIVE_UP_AT = 7;
export const MAYBE_AT = 3;

export const NO_LABELS = ['ไม่ไป', 'แน่ใจนะ?', 'คิดอีกที~', 'ใจร้ายจัง', 'กดไม่โดนหรอก', 'ยอมแล้ว…'] as const;

/** Shortest distance from a point to a rectangle; 0 when the point is inside. */
export function distToRect(p: Pt, r: Rect): number {
  const dx = Math.max(r.x - p.x, 0, p.x - (r.x + r.w));
  const dy = Math.max(r.y - p.y, 0, p.y - (r.y + r.h));
  return Math.hypot(dx, dy);
}

export function clampSpot(spot: Pt, size: Size, viewport: Size): Pt {
  const maxX = Math.max(PAD, viewport.w - PAD - size.w);
  const maxY = Math.max(PAD, viewport.h - PAD - size.h);
  return { x: Math.min(Math.max(spot.x, PAD), maxX), y: Math.min(Math.max(spot.y, PAD), maxY) };
}

/** True when the rects intersect, treating `b` as `gap` px larger on every side. */
export function overlaps(a: Rect, b: Rect, gap = 0): boolean {
  return a.x < b.x + b.w + gap && a.x + a.w > b.x - gap && a.y < b.y + b.h + gap && a.y + a.h > b.y - gap;
}

function centreDist(spot: Pt, size: Size, pointer: Pt): number {
  return Math.hypot(spot.x + size.w / 2 - pointer.x, spot.y + size.h / 2 - pointer.y);
}

/**
 * Where the No button goes next (top-left corner). Tries random spots first so the
 * movement is unpredictable; if the pointer has it cornered, jumps to whichever
 * viewport corner is farthest away. It never lands on an `avoid` rect, so it cannot
 * cover the Yes button or the maybe link and turn a chase into an accidental press.
 */
export function nextSpot(input: { pointer: Pt; size: Size; viewport: Size; rand: () => number; avoid?: Rect[] }): Pt {
  const { pointer, size, viewport, rand, avoid = [] } = input;
  const clear = (spot: Pt) => avoid.every((a) => !overlaps({ ...spot, ...size }, a, 12));
  const spanX = Math.max(0, viewport.w - 2 * PAD - size.w);
  const spanY = Math.max(0, viewport.h - 2 * PAD - size.h);

  for (let i = 0; i < 40; i++) {
    const spot = { x: PAD + rand() * spanX, y: PAD + rand() * spanY };
    if (centreDist(spot, size, pointer) >= MIN_DIST && clear(spot)) return spot;
  }

  const corners: Pt[] = [
    { x: PAD, y: PAD },
    { x: PAD + spanX, y: PAD },
    { x: PAD, y: PAD + spanY },
    { x: PAD + spanX, y: PAD + spanY },
  ];
  // Corners sit at the screen edge, away from the centred card; prefer the clear ones.
  const pool = corners.filter(clear).length > 0 ? corners.filter(clear) : corners;
  return pool.reduce((best, c) => (centreDist(c, size, pointer) > centreDist(best, size, pointer) ? c : best));
}

export function noScale(attempts: number): number {
  return Math.max(0.55, Number((1 - 0.08 * attempts).toFixed(2)));
}

export function yesScale(attempts: number): number {
  return Math.min(1.5, Number((1 + 0.06 * attempts).toFixed(2)));
}

export function noLabel(attempts: number): string {
  return NO_LABELS[Math.min(attempts, NO_LABELS.length - 1)];
}
```

- [ ] **Step 4: Run it and confirm it passes**

Run: `npx vitest run src/lib/runaway.test.ts`
Expected: PASS, all tests.

- [ ] **Step 5: Commit**

```bash
git add src/lib/runaway.ts src/lib/runaway.test.ts && git commit -m "feat: No-button escape geometry

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Map links and submission validation

**Files:**
- Create: `src/lib/maps.ts`, `src/lib/validate.ts`
- Test: `src/lib/maps.test.ts`, `src/lib/validate.test.ts`

**Interfaces:**
- Produces:
  ```ts
  // maps.ts
  export function searchUrl(name: string, mood?: string | null): string;
  export function cleanMapsUrl(raw: string): string | null;      // null = not an allowed Google Maps https link
  export function mapLink(s: { restaurantName: string; mapsUrl: string | null; foodMood: string | null }): string;

  // validate.ts
  export const FOOD_MOODS = ['japanese', 'grill', 'italian', 'thai', 'cafe', 'any'] as const;
  export type FoodMood = (typeof FOOD_MOODS)[number];
  export type Car = 'pickup' | 'meet';
  export type Pace = 'early' | 'late';
  export type SubmissionInput = {
    dateOn: string;          // YYYY-MM-DD
    timeAt: string;          // HH:MM, 24h
    foodMood: FoodMood | null;
    restaurantName: string;
    mapsUrl: string | null;
    car: Car;
    alcohol: boolean;
    pace: Pace;
    email: string | null;
    note: string | null;
  };
  export type Field = keyof SubmissionInput;
  export type ParseResult = { ok: true; value: SubmissionInput } | { ok: false; field: Field; message: string };
  export function bangkokToday(now: Date): string;                // YYYY-MM-DD in UTC+7
  export function parseSubmission(raw: unknown, today: string): ParseResult;
  ```

- [ ] **Step 1: Write the failing tests**

`src/lib/maps.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { cleanMapsUrl, mapLink, searchUrl } from './maps';

describe('searchUrl', () => {
  it('builds a Maps search for the name', () => {
    expect(searchUrl('ร้านส้มตำ ป้าแดง')).toBe(
      `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent('ร้านส้มตำ ป้าแดง')}`,
    );
  });
  it('puts the mood in front when there is one', () => {
    expect(searchUrl('Sukhumvit', 'ญี่ปุ่น')).toContain(encodeURIComponent('ญี่ปุ่น Sukhumvit'));
  });
});

describe('cleanMapsUrl', () => {
  it.each([
    'https://maps.app.goo.gl/AbCdEf123',
    'https://www.google.com/maps/place/Somewhere/@13.7,100.5,17z',
    'https://google.com/maps?q=13.7,100.5',
    'https://maps.google.com/?cid=123',
    'https://goo.gl/maps/xyz',
  ])('accepts %s', (u) => expect(cleanMapsUrl(u)).toBe(u));

  it.each([
    'http://maps.app.goo.gl/AbCdEf123',           // not https
    'https://www.google.com/search?q=maps',        // not /maps
    'https://evil.example/maps',
    'https://maps.google.com.evil.example/',
    'https://goo.gl/abc',                          // goo.gl but not /maps
    'javascript:alert(1)',
    'not a url',
    '',
  ])('rejects %s', (u) => expect(cleanMapsUrl(u)).toBeNull());

  it('trims whitespace', () => {
    expect(cleanMapsUrl('  https://maps.app.goo.gl/x  ')).toBe('https://maps.app.goo.gl/x');
  });
});

describe('mapLink', () => {
  it('prefers her pasted link', () => {
    expect(mapLink({ restaurantName: 'A', mapsUrl: 'https://maps.app.goo.gl/x', foodMood: null })).toBe('https://maps.app.goo.gl/x');
  });
  it('falls back to a search by name only', () => {
    expect(mapLink({ restaurantName: 'A', mapsUrl: null, foodMood: 'thai' })).toBe(searchUrl('A'));
  });
});
```

`src/lib/validate.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { bangkokToday, parseSubmission } from './validate';

const today = '2026-10-06';
const good = {
  dateOn: '2026-10-10', timeAt: '19:00', foodMood: 'japanese', restaurantName: '  Sushi Hiro  ',
  mapsUrl: 'https://maps.app.goo.gl/x', car: 'pickup', alcohol: false, pace: 'early',
  email: ' Em@Example.com ', note: 'แพ้กุ้งนะ',
};

describe('bangkokToday', () => {
  it('rolls over at 17:00 UTC', () => {
    expect(bangkokToday(new Date('2026-10-06T16:59:00Z'))).toBe('2026-10-06');
    expect(bangkokToday(new Date('2026-10-06T17:00:00Z'))).toBe('2026-10-07');
  });
});

describe('parseSubmission', () => {
  it('accepts a full, valid submission and normalises it', () => {
    const r = parseSubmission(good, today);
    expect(r).toEqual({
      ok: true,
      value: { ...good, restaurantName: 'Sushi Hiro', email: 'em@example.com' },
    });
  });

  it('accepts the minimum (optional fields empty)', () => {
    const r = parseSubmission({ ...good, foodMood: null, mapsUrl: '', email: '', note: '' }, today);
    expect(r.ok && r.value).toMatchObject({ foodMood: null, mapsUrl: null, email: null, note: null });
  });

  it('accepts today', () => expect(parseSubmission({ ...good, dateOn: today }, today).ok).toBe(true));

  it.each([
    ['dateOn', { dateOn: '2026-10-05' }],            // past
    ['dateOn', { dateOn: '2026-13-40' }],            // not a date
    ['dateOn', { dateOn: '2028-01-01' }],            // more than a year ahead
    ['timeAt', { timeAt: '25:00' }],
    ['timeAt', { timeAt: '7pm' }],
    ['foodMood', { foodMood: 'pizza' }],
    ['restaurantName', { restaurantName: '   ' }],
    ['restaurantName', { restaurantName: 'x'.repeat(121) }],
    ['mapsUrl', { mapsUrl: 'https://evil.example/maps' }],
    ['car', { car: 'taxi' }],
    ['alcohol', { alcohol: 'yes' }],
    ['pace', { pace: 'whenever' }],
    ['email', { email: 'not-an-email' }],
    ['note', { note: 'x'.repeat(301) }],
  ])('rejects a bad %s', (field, patch) => {
    const r = parseSubmission({ ...good, ...patch }, today);
    expect(r.ok).toBe(false);
    if (!r.ok) {
      expect(r.field).toBe(field);
      expect(r.message.length).toBeGreaterThan(0);
    }
  });

  it('rejects non-objects', () => {
    expect(parseSubmission(null, today).ok).toBe(false);
    expect(parseSubmission('x', today).ok).toBe(false);
  });
});
```

- [ ] **Step 2: Run and confirm failure**

Run: `npx vitest run src/lib/maps.test.ts src/lib/validate.test.ts`
Expected: FAIL, modules not found.

- [ ] **Step 3: Implement `src/lib/maps.ts`**

```ts
export function searchUrl(name: string, mood?: string | null): string {
  const query = [mood, name].filter(Boolean).join(' ').trim();
  return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(query)}`;
}

/** Returns the trimmed URL if it is an https Google Maps link, otherwise null. */
export function cleanMapsUrl(raw: string): string | null {
  const text = raw.trim();
  let u: URL;
  try {
    u = new URL(text);
  } catch {
    return null;
  }
  if (u.protocol !== 'https:') return null;
  const host = u.hostname.toLowerCase();
  const underMaps = u.pathname === '/maps' || u.pathname.startsWith('/maps/');
  const ok =
    host === 'maps.app.goo.gl' ||
    host === 'maps.google.com' ||
    ((host === 'www.google.com' || host === 'google.com') && underMaps) ||
    (host === 'goo.gl' && underMaps);
  return ok ? text : null;
}

export function mapLink(s: { restaurantName: string; mapsUrl: string | null; foodMood: string | null }): string {
  return s.mapsUrl ?? searchUrl(s.restaurantName);
}
```

- [ ] **Step 4: Implement `src/lib/validate.ts`**

```ts
import { cleanMapsUrl } from './maps';
import { TZ_OFFSET_HOURS } from './site';

export const FOOD_MOODS = ['japanese', 'grill', 'italian', 'thai', 'cafe', 'any'] as const;
export type FoodMood = (typeof FOOD_MOODS)[number];
export type Car = 'pickup' | 'meet';
export type Pace = 'early' | 'late';

export type SubmissionInput = {
  dateOn: string;
  timeAt: string;
  foodMood: FoodMood | null;
  restaurantName: string;
  mapsUrl: string | null;
  car: Car;
  alcohol: boolean;
  pace: Pace;
  email: string | null;
  note: string | null;
};
export type Field = keyof SubmissionInput;
export type ParseResult = { ok: true; value: SubmissionInput } | { ok: false; field: Field; message: string };

export function bangkokToday(now: Date): string {
  return new Date(now.getTime() + TZ_OFFSET_HOURS * 3_600_000).toISOString().slice(0, 10);
}

function isRealDate(s: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s)) return false;
  const d = new Date(`${s}T00:00:00Z`);
  return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === s;
}

function plusOneYear(today: string): string {
  const d = new Date(`${today}T00:00:00Z`);
  d.setUTCFullYear(d.getUTCFullYear() + 1);
  return d.toISOString().slice(0, 10);
}

const str = (v: unknown) => (typeof v === 'string' ? v.trim() : '');
const fail = (field: Field, message: string): ParseResult => ({ ok: false, field, message });

export function parseSubmission(raw: unknown, today: string): ParseResult {
  if (typeof raw !== 'object' || raw === null) return fail('dateOn', 'ข้อมูลไม่ครบ ลองใหม่อีกทีนะ');
  const r = raw as Record<string, unknown>;

  const dateOn = str(r.dateOn);
  if (!isRealDate(dateOn)) return fail('dateOn', 'เลือกวันก่อนน้า');
  if (dateOn < today) return fail('dateOn', 'วันนั้นผ่านไปแล้วนะ เลือกวันใหม่หน่อย');
  if (dateOn > plusOneYear(today)) return fail('dateOn', 'ไกลไปหน่อยมั้ย ขอไม่เกินหนึ่งปีนะ');

  const timeAt = str(r.timeAt);
  if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(timeAt)) return fail('timeAt', 'เลือกเวลาด้วยน้า');

  const moodRaw = r.foodMood;
  let foodMood: FoodMood | null = null;
  if (moodRaw !== null && moodRaw !== undefined && moodRaw !== '') {
    if (!FOOD_MOODS.includes(moodRaw as FoodMood)) return fail('foodMood', 'เลือกแนวอาหารใหม่อีกทีนะ');
    foodMood = moodRaw as FoodMood;
  }

  const restaurantName = str(r.restaurantName);
  if (!restaurantName) return fail('restaurantName', 'พิมพ์ชื่อร้านที่อยากไปหน่อยน้า');
  if (restaurantName.length > 120) return fail('restaurantName', 'ชื่อร้านยาวไปนิด ย่อหน่อยนะ');

  const mapsRaw = str(r.mapsUrl);
  let mapsUrl: string | null = null;
  if (mapsRaw) {
    if (mapsRaw.length > 500) return fail('mapsUrl', 'ลิงก์ยาวเกินไป ลองลิงก์แชร์จาก Google Maps นะ');
    mapsUrl = cleanMapsUrl(mapsRaw);
    if (!mapsUrl) return fail('mapsUrl', 'ลิงก์นี้ไม่ใช่ Google Maps ลองก๊อปใหม่อีกทีนะ');
  }

  if (r.car !== 'pickup' && r.car !== 'meet') return fail('car', 'เลือกก่อนว่าจะให้ไปรับมั้ย');
  if (typeof r.alcohol !== 'boolean') return fail('alcohol', 'ดื่มหรือไม่ดื่มดี เลือกหน่อยน้า');
  if (r.pace !== 'early' && r.pace !== 'late') return fail('pace', 'กลับเร็วหรือดึกได้ เลือกหน่อยน้า');

  const emailRaw = str(r.email).toLowerCase();
  let email: string | null = null;
  if (emailRaw) {
    if (emailRaw.length > 200 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(emailRaw)) return fail('email', 'อีเมลดูแปลก ๆ เช็กอีกทีนะ');
    email = emailRaw;
  }

  const noteRaw = str(r.note);
  if (noteRaw.length > 300) return fail('note', 'โน้ตยาวไปนิด ขอไม่เกิน 300 ตัวอักษรนะ');

  return {
    ok: true,
    value: { dateOn, timeAt, foodMood, restaurantName, mapsUrl, car: r.car, alcohol: r.alcohol, pace: r.pace, email, note: noteRaw || null },
  };
}
```

- [ ] **Step 5: Run and confirm pass**

Run: `npx vitest run src/lib/maps.test.ts src/lib/validate.test.ts && npx tsc --noEmit`
Expected: PASS; tsc exits 0.

- [ ] **Step 6: Commit**

```bash
git add src/lib/maps.ts src/lib/maps.test.ts src/lib/validate.ts src/lib/validate.test.ts && git commit -m "feat: map link allowlist and submission validation

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Calendar export (`ics.ts`)

**Files:**
- Create: `src/lib/ics.ts`
- Test: `src/lib/ics.test.ts`

**Interfaces:**
- Consumes: `TZ_OFFSET_HOURS`, `SITE_URL` from `@/lib/site`.
- Produces:
  ```ts
  export type DateEvent = { id: string; dateOn: string; timeAt: string; restaurantName: string; mapUrl: string; pageUrl: string };
  export const EVENT_HOURS = 2;
  export const EVENT_TITLE = 'เดตกับโน้ต';
  export function toUtcStamp(dateOn: string, timeAt: string, addHours?: number): string; // 'YYYYMMDDTHHMMSSZ'
  export function buildIcs(e: DateEvent, now: Date): string;   // CRLF-terminated VCALENDAR
  export function googleCalUrl(e: DateEvent): string;
  export function thaiDateTime(dateOn: string, timeAt: string): string; // 'วันเสาร์ที่ 10 ตุลาคม 2569 เวลา 19:00 น.'
  ```

- [ ] **Step 1: Write the failing test** — `src/lib/ics.test.ts`

```ts
import { describe, expect, it } from 'vitest';
import { buildIcs, googleCalUrl, thaiDateTime, toUtcStamp } from './ics';

const e = {
  id: 'abc123', dateOn: '2026-10-10', timeAt: '19:00',
  restaurantName: 'Sushi; Hiro, สาขา 2', mapUrl: 'https://maps.app.goo.gl/x', pageUrl: 'https://date.nanoteofficial.me/done/abc123',
};
const now = new Date('2026-10-06T05:00:00Z');

describe('toUtcStamp', () => {
  it('converts Bangkok time to UTC', () => expect(toUtcStamp('2026-10-10', '19:00')).toBe('20261010T120000Z'));
  it('crosses midnight backwards', () => expect(toUtcStamp('2026-10-10', '02:30')).toBe('20261009T193000Z'));
  it('adds hours', () => expect(toUtcStamp('2026-10-10', '23:00', 2)).toBe('20261010T180000Z'));
});

describe('buildIcs', () => {
  const ics = buildIcs(e, now);
  const lines = ics.split('\r\n');

  it('is a CRLF-terminated VCALENDAR with one VEVENT', () => {
    expect(lines[0]).toBe('BEGIN:VCALENDAR');
    expect(ics.endsWith('END:VCALENDAR\r\n')).toBe(true);
    expect(ics.match(/BEGIN:VEVENT/g)).toHaveLength(1);
    expect(ics.replace(/\r\n/g, '')).not.toContain('\n');
  });
  it('has start, end (+2h) and a stable UID', () => {
    expect(lines).toContain('DTSTART:20261010T120000Z');
    expect(lines).toContain('DTEND:20261010T140000Z');
    expect(lines).toContain('UID:abc123@date.nanoteofficial.me');
    expect(lines).toContain('DTSTAMP:20261006T050000Z');
  });
  it('escapes ; and , in text values', () => {
    expect(ics).toContain('LOCATION:Sushi\; Hiro\\, สาขา 2');
  });
  it('has reminders 1 day and 2 hours before', () => {
    expect(ics.match(/BEGIN:VALARM/g)).toHaveLength(2);
    expect(lines).toContain('TRIGGER:-P1D');
    expect(lines).toContain('TRIGGER:-PT2H');
  });
  it('folds no line beyond 75 octets', () => {
    const enc = new TextEncoder();
    for (const l of lines) expect(enc.encode(l).length).toBeLessThanOrEqual(75);
  });
  it('unfolds back to the full description', () => {
    expect(ics.replace(/\r\n /g, '')).toContain('https://date.nanoteofficial.me/done/abc123');
  });
});

describe('googleCalUrl', () => {
  it('builds a template link with UTC dates', () => {
    const u = new URL(googleCalUrl(e));
    expect(u.origin + u.pathname).toBe('https://calendar.google.com/calendar/render');
    expect(u.searchParams.get('action')).toBe('TEMPLATE');
    expect(u.searchParams.get('dates')).toBe('20261010T120000Z/20261010T140000Z');
    expect(u.searchParams.get('location')).toBe('Sushi; Hiro, สาขา 2');
  });
});

describe('thaiDateTime', () => {
  it('formats in Thai long form with the Buddhist year', () => {
    expect(thaiDateTime('2026-10-10', '19:00')).toBe('วันเสาร์ที่ 10 ตุลาคม 2569 เวลา 19:00 น.');
  });
});
```

- [ ] **Step 2: Run and confirm failure**

Run: `npx vitest run src/lib/ics.test.ts`
Expected: FAIL, module not found.

- [ ] **Step 3: Implement** — `src/lib/ics.ts`

```ts
import { TZ_OFFSET_HOURS } from './site';

export type DateEvent = { id: string; dateOn: string; timeAt: string; restaurantName: string; mapUrl: string; pageUrl: string };

export const EVENT_HOURS = 2;
export const EVENT_TITLE = 'เดตกับโน้ต';

const stamp = (d: Date) => d.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '');

export function toUtcStamp(dateOn: string, timeAt: string, addHours = 0): string {
  const local = new Date(`${dateOn}T${timeAt}:00Z`);
  return stamp(new Date(local.getTime() + (addHours - TZ_OFFSET_HOURS) * 3_600_000));
}

const esc = (s: string) => s.replace(/\\/g, '\\\\').replace(/;/g, '\;').replace(/,/g, '\\,').replace(/\r?\n/g, '\\n');

/** RFC 5545 line folding at 75 octets, never splitting a UTF-8 character. */
function fold(line: string): string[] {
  const enc = new TextEncoder();
  const out: string[] = [];
  let cur = '';
  let bytes = 0;
  for (const ch of line) {
    const n = enc.encode(ch).length;
    const limit = out.length === 0 ? 75 : 74; // continuation lines start with one space
    if (bytes + n > limit) {
      out.push(out.length === 0 ? cur : ` ${cur}`);
      cur = '';
      bytes = 0;
    }
    cur += ch;
    bytes += n;
  }
  out.push(out.length === 0 ? cur : ` ${cur}`);
  return out;
}

function description(e: DateEvent): string {
  return `ร้าน: ${e.restaurantName}\nแผนที่: ${e.mapUrl}\nรายละเอียด: ${e.pageUrl}`;
}

export function buildIcs(e: DateEvent, now: Date): string {
  const alarm = (trigger: string) => [
    'BEGIN:VALARM', 'ACTION:DISPLAY', `DESCRIPTION:${esc(EVENT_TITLE)}`, `TRIGGER:${trigger}`, 'END:VALARM',
  ];
  const raw = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//NaNote//date.nanoteofficial.me//TH',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'BEGIN:VEVENT',
    `UID:${e.id}@date.nanoteofficial.me`,
    `DTSTAMP:${stamp(now)}`,
    `DTSTART:${toUtcStamp(e.dateOn, e.timeAt)}`,
    `DTEND:${toUtcStamp(e.dateOn, e.timeAt, EVENT_HOURS)}`,
    `SUMMARY:${esc(EVENT_TITLE)}`,
    `LOCATION:${esc(e.restaurantName)}`,
    `DESCRIPTION:${esc(description(e))}`,
    `URL:${e.pageUrl}`,
    ...alarm('-P1D'),
    ...alarm('-PT2H'),
    'END:VEVENT',
    'END:VCALENDAR',
  ];
  return raw.flatMap(fold).join('\r\n') + '\r\n';
}

export function googleCalUrl(e: DateEvent): string {
  const p = new URLSearchParams({
    action: 'TEMPLATE',
    text: EVENT_TITLE,
    dates: `${toUtcStamp(e.dateOn, e.timeAt)}/${toUtcStamp(e.dateOn, e.timeAt, EVENT_HOURS)}`,
    location: e.restaurantName,
    details: description(e),
  });
  return `https://calendar.google.com/calendar/render?${p.toString()}`;
}

const DAYS = ['อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์'];
const MONTHS = ['มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน', 'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'];

/** Hand-rolled so the output does not depend on the runtime's ICU data. */
export function thaiDateTime(dateOn: string, timeAt: string): string {
  const d = new Date(`${dateOn}T00:00:00Z`);
  return `วัน${DAYS[d.getUTCDay()]}ที่ ${d.getUTCDate()} ${MONTHS[d.getUTCMonth()]} ${d.getUTCFullYear() + 543} เวลา ${timeAt} น.`;
}
```

- [ ] **Step 4: Run and confirm pass**

Run: `npx vitest run src/lib/ics.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/lib/ics.ts src/lib/ics.test.ts && git commit -m "feat: calendar file, Google Calendar link and Thai date formatting

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: QR path, rate limits and timeline grouping

**Files:**
- Create: `src/lib/qr.ts`, `src/lib/rateLimit.ts`, `src/lib/timeline.ts`
- Test: `src/lib/qr.test.ts`, `src/lib/rateLimit.test.ts`, `src/lib/timeline.test.ts`

**Interfaces:**
- Produces:
  ```ts
  // qr.ts
  export function qrPath(text: string): { size: number; d: string }; // d = SVG path, 1 unit per module

  // rateLimit.ts
  export const EVENT_KINDS = ['open', 'no_attempt', 'maybe', 'yes', 'plan_step', 'submit'] as const;
  export type EventKind = (typeof EVENT_KINDS)[number];
  export const LIMITS = { perVisitorHour: 5, perDay: 30, eventsPerVisitor: 200, noAttemptsPerVisitor: 20 } as const;
  export function submitAllowed(c: { visitorLastHour: number; allLastDay: number }): boolean;
  export function eventAllowed(kind: EventKind, c: { visitorTotal: number; visitorNoAttempts: number }): boolean;

  // timeline.ts
  export type EventRow = { visitorId: string; kind: EventKind; detail: unknown; device: string; createdAt: Date };
  export type Outcome = 'submitted' | 'maybe' | 'yes' | 'looking';
  export type Visit = {
    visitorId: string; device: string; firstAt: Date; lastAt: Date;
    opens: number; noAttempts: number; outcome: Outcome;
    secondsToFinish: number | null;   // first 'yes' → first 'submit'
    submissionIds: string[];
  };
  export function groupTimeline(events: EventRow[], subs: { id: string; visitorId: string }[]): Visit[]; // newest lastAt first
  ```

- [ ] **Step 1: Write the failing tests**

`src/lib/qr.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { qrPath } from './qr';

describe('qrPath', () => {
  const q = qrPath('https://date.nanoteofficial.me/done/V1StGXR8_Z5jdHi6B-myT');
  it('returns a square module count', () => {
    expect(q.size).toBeGreaterThanOrEqual(21);
    expect((q.size - 17) % 4).toBe(0); // QR versions are 21, 25, 29, …
  });
  it('emits one unit square per dark module, all inside the grid', () => {
    const cells = [...q.d.matchAll(/M(\d+) (\d+)h1v1h-1z/g)];
    expect(cells.length).toBeGreaterThan(100);
    expect(q.d.replace(/M\d+ \d+h1v1h-1z/g, '')).toBe('');
    for (const [, x, y] of cells) {
      expect(Number(x)).toBeLessThan(q.size);
      expect(Number(y)).toBeLessThan(q.size);
    }
  });
  it('draws the top-left finder corner', () => expect(q.d.startsWith('M0 0h1v1h-1z')).toBe(true));
  it('is deterministic', () => expect(qrPath('abc')).toEqual(qrPath('abc')));
});
```

`src/lib/rateLimit.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { eventAllowed, submitAllowed } from './rateLimit';

describe('submitAllowed', () => {
  it('allows under both limits', () => expect(submitAllowed({ visitorLastHour: 4, allLastDay: 29 })).toBe(true));
  it('blocks the 6th from one visitor in an hour', () => expect(submitAllowed({ visitorLastHour: 5, allLastDay: 5 })).toBe(false));
  it('blocks the 31st overall in a day', () => expect(submitAllowed({ visitorLastHour: 0, allLastDay: 30 })).toBe(false));
});

describe('eventAllowed', () => {
  it('allows normal traffic', () => expect(eventAllowed('open', { visitorTotal: 3, visitorNoAttempts: 0 })).toBe(true));
  it('caps no_attempt at 20 per visitor', () => {
    expect(eventAllowed('no_attempt', { visitorTotal: 25, visitorNoAttempts: 19 })).toBe(true);
    expect(eventAllowed('no_attempt', { visitorTotal: 25, visitorNoAttempts: 20 })).toBe(false);
  });
  it('still records yes after the no_attempt cap', () => expect(eventAllowed('yes', { visitorTotal: 25, visitorNoAttempts: 20 })).toBe(true));
  it('caps everything at 200 per visitor', () => expect(eventAllowed('yes', { visitorTotal: 200, visitorNoAttempts: 0 })).toBe(false));
});
```

`src/lib/timeline.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { groupTimeline, type EventRow } from './timeline';

const at = (s: number) => new Date(Date.UTC(2026, 9, 6, 12, 0, s));
const ev = (visitorId: string, kind: EventRow['kind'], s: number, device = 'mobile'): EventRow => ({ visitorId, kind, detail: null, device, createdAt: at(s) });

describe('groupTimeline', () => {
  const events = [
    ev('a', 'open', 0), ev('a', 'no_attempt', 2), ev('a', 'no_attempt', 3), ev('a', 'yes', 5),
    ev('a', 'plan_step', 9), ev('a', 'submit', 53),
    ev('b', 'open', 20, 'desktop'), ev('b', 'no_attempt', 21, 'desktop'), ev('b', 'maybe', 30, 'desktop'),
    ev('c', 'open', 40), ev('c', 'yes', 41),
    ev('d', 'open', 10),
  ];
  const visits = groupTimeline(events, [{ id: 'sub1', visitorId: 'a' }]);
  const by = (id: string) => visits.find((v) => v.visitorId === id)!;

  it('makes one row per visitor, newest activity first', () => {
    expect(visits.map((v) => v.visitorId)).toEqual(['a', 'c', 'b', 'd']);
  });
  it('summarises a finished visit', () => {
    expect(by('a')).toMatchObject({ opens: 1, noAttempts: 2, outcome: 'submitted', secondsToFinish: 48, submissionIds: ['sub1'], device: 'mobile' });
    expect(by('a').firstAt).toEqual(at(0));
    expect(by('a').lastAt).toEqual(at(53));
  });
  it('labels maybe, yes-without-submit and just-looking', () => {
    expect(by('b')).toMatchObject({ outcome: 'maybe', noAttempts: 1, secondsToFinish: null, device: 'desktop' });
    expect(by('c').outcome).toBe('yes');
    expect(by('d').outcome).toBe('looking');
  });
  it('handles unordered input and no events', () => {
    expect(groupTimeline([...events].reverse(), [])[0].visitorId).toBe('a');
    expect(groupTimeline([], [])).toEqual([]);
  });
});
```

- [ ] **Step 2: Run and confirm failure**

Run: `npx vitest run src/lib/qr.test.ts src/lib/rateLimit.test.ts src/lib/timeline.test.ts`
Expected: FAIL, modules not found.

- [ ] **Step 3: Implement `src/lib/qr.ts`**

```ts
import QRCode from 'qrcode';

/** The QR code as one SVG path in a `size × size` unit grid, so it renders as plain JSX. */
export function qrPath(text: string): { size: number; d: string } {
  const { modules } = QRCode.create(text, { errorCorrectionLevel: 'M' });
  const { size, data } = modules;
  let d = '';
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      if (data[y * size + x]) d += `M${x} ${y}h1v1h-1z`;
    }
  }
  return { size, d };
}
```

- [ ] **Step 4: Implement `src/lib/rateLimit.ts`**

```ts
export const EVENT_KINDS = ['open', 'no_attempt', 'maybe', 'yes', 'plan_step', 'submit'] as const;
export type EventKind = (typeof EVENT_KINDS)[number];

export const LIMITS = { perVisitorHour: 5, perDay: 30, eventsPerVisitor: 200, noAttemptsPerVisitor: 20 } as const;

export function submitAllowed(c: { visitorLastHour: number; allLastDay: number }): boolean {
  return c.visitorLastHour < LIMITS.perVisitorHour && c.allLastDay < LIMITS.perDay;
}

export function eventAllowed(kind: EventKind, c: { visitorTotal: number; visitorNoAttempts: number }): boolean {
  if (c.visitorTotal >= LIMITS.eventsPerVisitor) return false;
  if (kind === 'no_attempt' && c.visitorNoAttempts >= LIMITS.noAttemptsPerVisitor) return false;
  return true;
}
```

- [ ] **Step 5: Implement `src/lib/timeline.ts`**

```ts
import type { EventKind } from './rateLimit';

export type EventRow = { visitorId: string; kind: EventKind; detail: unknown; device: string; createdAt: Date };
export type Outcome = 'submitted' | 'maybe' | 'yes' | 'looking';
export type Visit = {
  visitorId: string; device: string; firstAt: Date; lastAt: Date;
  opens: number; noAttempts: number; outcome: Outcome;
  secondsToFinish: number | null;
  submissionIds: string[];
};

export function groupTimeline(events: EventRow[], subs: { id: string; visitorId: string }[]): Visit[] {
  const byVisitor = new Map<string, EventRow[]>();
  for (const e of events) {
    const list = byVisitor.get(e.visitorId) ?? [];
    list.push(e);
    byVisitor.set(e.visitorId, list);
  }

  const visits: Visit[] = [];
  for (const [visitorId, list] of byVisitor) {
    list.sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime());
    const first = (kind: EventKind) => list.find((e) => e.kind === kind);
    const count = (kind: EventKind) => list.filter((e) => e.kind === kind).length;
    const yes = first('yes');
    const submit = first('submit');
    const outcome: Outcome = submit ? 'submitted' : first('maybe') ? 'maybe' : yes ? 'yes' : 'looking';

    visits.push({
      visitorId,
      device: list[0].device,
      firstAt: list[0].createdAt,
      lastAt: list[list.length - 1].createdAt,
      opens: count('open'),
      noAttempts: count('no_attempt'),
      outcome,
      secondsToFinish: yes && submit ? Math.round((submit.createdAt.getTime() - yes.createdAt.getTime()) / 1000) : null,
      submissionIds: subs.filter((s) => s.visitorId === visitorId).map((s) => s.id),
    });
  }
  return visits.sort((a, b) => b.lastAt.getTime() - a.lastAt.getTime());
}
```

- [ ] **Step 6: Run and confirm pass**

Run: `npm test && npx tsc --noEmit`
Expected: every test file passes; tsc exits 0.

- [ ] **Step 7: Commit**

```bash
git add src/lib && git commit -m "feat: QR path, rate limits and visitor timeline grouping

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Database, auth, sign-in page and the admin gate

**Files:**
- Create: `drizzle.config.ts`, `src/db/schema.ts`, `src/db/index.ts`, `src/auth.ts`, `src/app/api/auth/[...nextauth]/route.ts`, `src/app/signin/page.tsx`, `src/app/(admin)/layout.tsx`, `src/app/(admin)/admin/page.tsx` (placeholder body, replaced in Task 11), `src/lib/visitor.ts`

**Interfaces:**
- Consumes: `EVENT_KINDS` from `@/lib/rateLimit`; `FOOD_MOODS` from `@/lib/validate`.
- Produces:
  ```ts
  // @/db
  export const db;                     // eager drizzle instance (adapter only)
  export function getDb();             // throws 'DATABASE_URL is not set'
  export { schema };
  // @/db/schema — tables: users, accounts, sessions, verificationTokens, submissions, events
  export type Submission = typeof submissions.$inferSelect;
  // @/auth
  export const { handlers, auth, signIn, signOut };
  export function isAllowed(email: string | null | undefined): boolean;
  // @/lib/visitor (server only)
  export const VISITOR_COOKIE = 'vid';
  export async function getOrCreateVisitorId(): Promise<string>; // only callable where cookies can be set (action, route handler)
  ```

- [ ] **Step 1: Write `drizzle.config.ts` and `src/db/index.ts`**

```ts
import { defineConfig } from 'drizzle-kit';

export default defineConfig({
  schema: './src/db/schema.ts',
  dialect: 'postgresql',
  dbCredentials: { url: process.env.DATABASE_URL! },
});
```

```ts
import { neon, neonConfig } from '@neondatabase/serverless';
import { drizzle } from 'drizzle-orm/neon-http';
import * as schema from './schema';

// `@auth/drizzle-adapter` needs a real drizzle instance at module load, and `neon()`
// must not throw on a missing connection string or `next build` fails. A format-valid
// placeholder keeps construction safe; a missing env then fails only the DB request.
const PLACEHOLDER_URL =
  'postgresql://placeholder:placeholder@placeholder.neon.tech/placeholder?sslmode=require';

// Local development only: a Neon-protocol proxy in front of a plain Postgres.
if (process.env.NEON_LOCAL_PROXY) {
  neonConfig.fetchEndpoint = process.env.NEON_LOCAL_PROXY;
}

export const db = drizzle(neon(process.env.DATABASE_URL || PLACEHOLDER_URL), { schema });

/** App code uses this — it fails loudly instead of querying the placeholder. */
export function getDb() {
  if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is not set');
  return db;
}

export { schema };
```

- [ ] **Step 2: Write `src/db/schema.ts`**

```ts
import { boolean, date, index, integer, jsonb, pgTable, primaryKey, serial, text, time, timestamp } from 'drizzle-orm/pg-core';
import type { AdapterAccountType } from 'next-auth/adapters';
import { EVENT_KINDS } from '@/lib/rateLimit';
import { FOOD_MOODS } from '@/lib/validate';

// ── Auth.js tables ──────────────────────────────────────────
export const users = pgTable('user', {
  id: text('id').primaryKey().$defaultFn(() => crypto.randomUUID()),
  name: text('name'),
  email: text('email').notNull().unique(),
  emailVerified: timestamp('emailVerified', { mode: 'date' }),
  image: text('image'),
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

// ── The date ────────────────────────────────────────────────
export const submissions = pgTable('submission', {
  id: text('id').primaryKey(),                       // 21-char nanoid; the only key to /done/[id]
  visitorId: text('visitorId').notNull(),
  dateOn: date('dateOn', { mode: 'string' }).notNull(),
  timeAt: time('timeAt').notNull(),                  // 'HH:MM:SS' from Postgres; slice(0, 5) when reading
  foodMood: text('foodMood', { enum: FOOD_MOODS }),
  restaurantName: text('restaurantName').notNull(),
  mapsUrl: text('mapsUrl'),
  car: text('car', { enum: ['pickup', 'meet'] }).notNull(),
  alcohol: boolean('alcohol').notNull(),
  pace: text('pace', { enum: ['early', 'late'] }).notNull(),
  email: text('email'),
  note: text('note'),
  noAttempts: integer('noAttempts').notNull().default(0),
  device: text('device', { enum: ['desktop', 'mobile'] }).notNull(),
  userAgent: text('userAgent'),
  createdAt: timestamp('createdAt', { mode: 'date' }).notNull().defaultNow(),
}, (t) => [index('submission_visitor_idx').on(t.visitorId), index('submission_created_idx').on(t.createdAt)]);

export const events = pgTable('event', {
  id: serial('id').primaryKey(),
  visitorId: text('visitorId').notNull(),
  kind: text('kind', { enum: EVENT_KINDS }).notNull(),
  detail: jsonb('detail'),
  device: text('device', { enum: ['desktop', 'mobile'] }).notNull(),
  createdAt: timestamp('createdAt', { mode: 'date' }).notNull().defaultNow(),
}, (t) => [index('event_visitor_idx').on(t.visitorId), index('event_created_idx').on(t.createdAt)]);

export type Submission = typeof submissions.$inferSelect;
export type EventRecord = typeof events.$inferSelect;
```

- [ ] **Step 3: Write `src/auth.ts`**

The `signIn` callback runs before Auth.js creates a token or sends mail, so returning `false` for a stranger means no email is ever sent to them. Auth.js then redirects to `/signin?error=AccessDenied`; the page shows the same "check your inbox" text for that case, so the form never reveals which address is allowed.

```ts
import NextAuth from 'next-auth';
import Resend from 'next-auth/providers/resend';
import { DrizzleAdapter } from '@auth/drizzle-adapter';
import { db, schema } from '@/db';

const allowed = (process.env.ALLOWED_EMAILS ?? '')
  .split(',').map((e) => e.trim().toLowerCase()).filter(Boolean);

export function isAllowed(email: string | null | undefined): boolean {
  return Boolean(email) && allowed.includes(email!.toLowerCase());
}

export const { handlers, auth, signIn, signOut } = NextAuth({
  adapter: DrizzleAdapter(db, {
    usersTable: schema.users,
    accountsTable: schema.accounts,
    sessionsTable: schema.sessions,
    verificationTokensTable: schema.verificationTokens,
  }),
  providers: [
    Resend({
      apiKey: process.env.AUTH_RESEND_KEY,
      from: process.env.AUTH_RESEND_FROM ?? 'NaNote <date@nanoteofficial.me>',
      // The default Auth.js mail has no plain-text part and Gmail scores it as spam.
      async sendVerificationRequest({ identifier, url, provider }) {
        const text = ['ลิงก์เข้าหน้าแอดมิน ใช้ได้ครั้งเดียว หมดอายุใน 24 ชั่วโมง', '', url].join('\n');
        const html = `<!doctype html><html lang="th"><body style="margin:0;padding:24px;background:#FFF6E6;font-family:-apple-system,'Segoe UI',Roboto,sans-serif;color:#4A342E">
<p style="font-size:15px;line-height:1.6">ลิงก์เข้าหน้าแอดมิน ใช้ได้ครั้งเดียว หมดอายุใน 24 ชั่วโมง</p>
<p><a href="${url}" style="display:inline-block;padding:12px 22px;background:#FF4D6D;color:#fff;text-decoration:none;border-radius:12px;font-weight:600">เข้าสู่ระบบ</a></p>
<p style="font-size:12px;word-break:break-all;color:#7a655f">${url}</p></body></html>`;
        const res = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: { Authorization: `Bearer ${provider.apiKey}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({
            from: provider.from, to: identifier, subject: 'ลิงก์เข้าหน้าแอดมิน', html, text,
            headers: { 'X-Entity-Ref-ID': crypto.randomUUID() },
          }),
        });
        if (!res.ok) throw new Error(`Resend rejected the sign-in email: ${res.status} ${await res.text()}`);
      },
    }),
  ],
  session: { strategy: 'database' },
  // No query strings here: Auth.js appends its own (?provider=…, ?error=…).
  pages: { signIn: '/signin', verifyRequest: '/signin', error: '/signin' },
  callbacks: {
    signIn({ user }) {
      return isAllowed(user.email);
    },
  },
});
```

- [ ] **Step 4: Write the auth route, sign-in page, gate and placeholder admin page**

`src/app/api/auth/[...nextauth]/route.ts`:

```ts
import { handlers } from '@/auth';

export const { GET, POST } = handlers;
```

`src/app/signin/page.tsx`:

```tsx
import { signIn } from '@/auth';

export const metadata = { title: 'Sign in' };

export default async function SignInPage({ searchParams }: PageProps<'/signin'>) {
  const params = await searchParams;
  // ?provider= means a link was sent; AccessDenied means the address is not allowed.
  // Both show the same message so the form does not reveal the allowlist.
  const sent = Boolean(params.provider) || params.error === 'AccessDenied';
  const broken = Boolean(params.error) && params.error !== 'AccessDenied';

  return (
    <main className="flex min-h-dvh items-center justify-center p-5">
      <div className="sticker w-full max-w-sm bg-white p-7">
        <h1 className="font-head text-2xl font-bold">หลังบ้าน</h1>
        {sent ? (
          <p className="mt-4 leading-relaxed">ถ้าอีเมลนี้มีสิทธิ์ ลิงก์เข้าสู่ระบบจะไปถึงกล่องจดหมายในไม่กี่นาที</p>
        ) : (
          <form
            className="mt-5 space-y-3"
            action={async (formData: FormData) => {
              'use server';
              await signIn('resend', { email: String(formData.get('email')), redirectTo: '/admin' });
            }}
          >
            <label htmlFor="email" className="block text-sm">อีเมล</label>
            <input id="email" name="email" type="email" autoComplete="email" required className="field" />
            <button type="submit" className="sticker-sm w-full bg-butter px-4 py-3 font-head font-bold">ส่งลิงก์</button>
            {broken ? <p className="text-sm text-cherry">ส่งลิงก์ไม่สำเร็จ ลองใหม่อีกครั้ง</p> : null}
          </form>
        )}
      </div>
    </main>
  );
}
```

`src/app/(admin)/layout.tsx`:

```tsx
import type { ReactNode } from 'react';
import { redirect } from 'next/navigation';
import { auth, isAllowed, signOut } from '@/auth';

/**
 * The only gate in front of /admin — this project has no middleware. The allowlist is
 * re-checked on every request, so removing an address from ALLOWED_EMAILS locks it out
 * even if a session row still exists.
 */
export default async function AdminLayout({ children }: { children: ReactNode }) {
  const session = await auth();
  if (!isAllowed(session?.user?.email)) redirect('/signin');

  return (
    <div className="mx-auto max-w-5xl px-4 py-6">
      <header className="mb-6 flex items-center justify-between">
        <p className="font-head text-xl font-bold">หลังบ้าน</p>
        <form action={async () => { 'use server'; await signOut({ redirectTo: '/signin' }); }}>
          <button type="submit" className="text-sm underline">ออกจากระบบ</button>
        </form>
      </header>
      {children}
    </div>
  );
}
```

`src/app/(admin)/admin/page.tsx` (replaced in Task 11):

```tsx
export const metadata = { title: 'Admin' };

export default function AdminPage() {
  return <p>log</p>;
}
```

- [ ] **Step 5: Write `src/lib/visitor.ts`**

```ts
import 'server-only';
import { cookies } from 'next/headers';
import { nanoid } from 'nanoid';

export const VISITOR_COOKIE = 'vid';

/** Reads the visitor id, creating it if absent. Call only from a server action or route handler. */
export async function getOrCreateVisitorId(): Promise<string> {
  const jar = await cookies();
  const existing = jar.get(VISITOR_COOKIE)?.value;
  if (existing && /^[\w-]{10,40}$/.test(existing)) return existing;
  const id = nanoid();
  jar.set(VISITOR_COOKIE, id, { httpOnly: true, sameSite: 'lax', secure: process.env.NODE_ENV === 'production', path: '/', maxAge: 60 * 60 * 24 * 180 });
  return id;
}
```

- [ ] **Step 6: Start the local database** (one time; Neon's HTTP driver cannot talk to plain Postgres, so a proxy sits in front)

```bash
docker run -d --name date-pg --restart unless-stopped --security-opt apparmor=unconfined -e POSTGRES_PASSWORD=pg -e POSTGRES_DB=date -p 55433:5432 postgres:16-alpine
docker network create date-net && docker network connect date-net date-pg
docker run -d --name date-neon-proxy --restart unless-stopped --security-opt apparmor=unconfined --network date-net -p 4445:4444 \
  -e PG_CONNECTION_STRING="postgres://postgres:pg@date-pg:5432/date" ghcr.io/timowilhelm/local-neon-http-proxy:main
sleep 5
docker exec -i date-pg psql -U postgres -d date -c "CREATE SCHEMA IF NOT EXISTS neon_control_plane; CREATE TABLE IF NOT EXISTS neon_control_plane.endpoints (endpoint_id VARCHAR(255) PRIMARY KEY, allowed_ips VARCHAR(255)); INSERT INTO neon_control_plane.endpoints (endpoint_id, allowed_ips) VALUES ('localhost', '0.0.0.0/0'), ('date-pg', '0.0.0.0/0') ON CONFLICT DO NOTHING;"
```

Apply the schema (`drizzle-kit push` hangs through the proxy; generate SQL and pipe it instead):

```bash
OUT=$(mktemp -d) && npx drizzle-kit generate --schema src/db/schema.ts --dialect postgresql --out "$OUT" \
  && cat "$OUT"/*.sql | sed 's/--> statement-breakpoint//' | docker exec -i date-pg psql -U postgres -d date
docker exec -i date-pg psql -U postgres -d date -c '\dt'
```

Expected: six tables listed: `account`, `event`, `session`, `submission`, `user`, `verificationToken`.

Write `.env.local` (gitignored):

```
DATABASE_URL=postgres://postgres:pg@date-pg:5432/date
NEON_LOCAL_PROXY=http://localhost:4445/sql
AUTH_SECRET=dev-secret-not-for-production
ALLOWED_EMAILS=khantee9@gmail.com
NOTIFY_EMAIL=khantee9@gmail.com
```

- [ ] **Step 7: Verify the gate**

Run: `npx tsc --noEmit && npm run lint && env -u DATABASE_URL npm run build`
Expected: all exit 0 (the build passes with no database).

Run `npm run dev` in the background, then:

```bash
curl -s -o /dev/null -w '%{http_code} %{redirect_url}\n' http://localhost:3100/admin
```

Expected: `307 http://localhost:3100/signin`.

Sign in without email (the documented local shortcut), then request `/admin` with the session cookie:

```bash
docker exec -i date-pg psql -U postgres -d date -c "INSERT INTO \"user\" (id, email) VALUES ('u1', 'khantee9@gmail.com') ON CONFLICT DO NOTHING; INSERT INTO session (\"sessionToken\", \"userId\", expires) VALUES ('devtoken', 'u1', now() + interval '30 days') ON CONFLICT DO NOTHING;"
curl -s -o /dev/null -w '%{http_code}\n' -H 'Cookie: authjs.session-token=devtoken' http://localhost:3100/admin
```

Expected: `200`. Then prove a non-allowlisted session is refused:

```bash
docker exec -i date-pg psql -U postgres -d date -c "INSERT INTO \"user\" (id, email) VALUES ('u2', 'stranger@example.com'); INSERT INTO session (\"sessionToken\", \"userId\", expires) VALUES ('strangertoken', 'u2', now() + interval '1 day');"
curl -s -o /dev/null -w '%{http_code}\n' -H 'Cookie: authjs.session-token=strangertoken' http://localhost:3100/admin
docker exec -i date-pg psql -U postgres -d date -c "DELETE FROM \"user\" WHERE id = 'u2';"
```

Expected: `307`. Stop the dev server.

- [ ] **Step 8: Commit**

```bash
git add -A && git commit -m "feat: database schema, magic-link auth for one address, admin gate

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Copy, mascot and UI primitives

**Files:**
- Create: `src/lib/copy.ts`, `src/components/mascot/Mascot.tsx`, `src/components/ui/Motion.tsx`, `src/components/ui/Card.tsx`, `src/components/ui/StickerButton.tsx`, `src/components/ui/Confetti.tsx`, `src/components/ui/Doodles.tsx`, `src/app/icon.svg`, `src/app/dev-kit/page.tsx` (temporary gallery, deleted in Task 12)
- Modify: `src/app/globals.css` (append keyframes), `src/app/layout.tsx` (wrap children in `<Motion>`)
- Test: `src/lib/copy.test.ts`

**Interfaces:**
- Consumes: `Submission` from `@/db/schema`; `FoodMood` from `@/lib/validate`; `thaiDateTime` from `@/lib/ics`.
- Produces:
  ```ts
  // copy.ts
  export const HER = 'คุณเอ๊ม';
  export const COPY: { ask: {...}; yes: {...}; maybe: {...}; plan: {...}; done: {...}; error: {...} }; // exact keys in Step 3
  export const MOODS: { id: FoodMood; label: string; search: string | null }[];   // 6 entries
  export const TIME_CHIPS: readonly string[];                                     // ['11:30','13:00','18:00','19:00','20:00']
  export function summaryRows(s: Pick<Submission, 'dateOn'|'timeAt'|'foodMood'|'restaurantName'|'car'|'alcohol'|'pace'|'note'>): { label: string; value: string }[];

  // components
  export type Pose = 'wave' | 'curious' | 'plead' | 'teary' | 'joy' | 'shy' | 'sorry';
  <Mascot pose={Pose} size={number /* px, default 160 */} />
  <Card className? children />                       // white sticker card with a spring entrance
  <StickerButton tone={'cherry'|'butter'|'white'|'blush'} ...buttonProps />
  <Confetti burst={number} />                        // fires each time `burst` changes to a new value > 0
  <Doodles />                                        // fixed background layer
  ```

- [ ] **Step 1: Write the failing test** — `src/lib/copy.test.ts`

```ts
import { describe, expect, it } from 'vitest';
import { COPY, HER, MOODS, TIME_CHIPS, summaryRows } from './copy';
import { FOOD_MOODS } from './validate';

describe('copy', () => {
  it('addresses her by nickname in the question', () => {
    expect(HER).toBe('คุณเอ๊ม');
    expect(COPY.ask.headline).toContain(HER);
  });
  it('has one mood tile per FOOD_MOODS id, in order', () => {
    expect(MOODS.map((m) => m.id)).toEqual([...FOOD_MOODS]);
    expect(MOODS.find((m) => m.id === 'any')!.search).toBeNull();
  });
  it('offers the five time chips from the spec', () => {
    expect(TIME_CHIPS).toEqual(['11:30', '13:00', '18:00', '19:00', '20:00']);
  });
  it('never mentions the reference brand', () => {
    expect(JSON.stringify(COPY)).not.toMatch(/jolly|muse|meta/i);
  });
});

describe('summaryRows', () => {
  const base = {
    dateOn: '2026-10-10', timeAt: '19:00:00', foodMood: 'japanese' as const, restaurantName: 'Sushi Hiro',
    car: 'pickup' as const, alcohol: false, pace: 'early' as const, note: null,
  };
  it('lists the answers in Thai, trimming seconds from the time', () => {
    expect(summaryRows(base)).toEqual([
      { label: 'วันเวลา', value: 'วันเสาร์ที่ 10 ตุลาคม 2569 เวลา 19:00 น.' },
      { label: 'ร้าน', value: 'Sushi Hiro' },
      { label: 'แนวอาหาร', value: 'ญี่ปุ่น' },
      { label: 'การเดินทาง', value: 'ไปรับนะ' },
      { label: 'เครื่องดื่ม', value: 'ไม่ดื่ม' },
      { label: 'กลับบ้าน', value: 'กลับเร็ว' },
    ]);
  });
  it('omits the mood when absent and appends the note when present', () => {
    const rows = summaryRows({ ...base, foodMood: null, car: 'meet', alcohol: true, pace: 'late', note: 'แพ้กุ้ง' });
    expect(rows.map((r) => r.label)).toEqual(['วันเวลา', 'ร้าน', 'การเดินทาง', 'เครื่องดื่ม', 'กลับบ้าน', 'โน้ต']);
    expect(rows.map((r) => r.value).slice(2)).toEqual(['เจอกันที่ร้าน', 'ดื่มได้', 'ดึกได้', 'แพ้กุ้ง']);
  });
});
```

- [ ] **Step 2: Run and confirm failure**

Run: `npx vitest run src/lib/copy.test.ts`
Expected: FAIL, module not found.

- [ ] **Step 3: Implement `src/lib/copy.ts`**

Every string the visitor reads lives here so NaNote can review the copy in one file.

```ts
import type { Submission } from '@/db/schema';
import { thaiDateTime } from './ics';
import type { FoodMood } from './validate';

export const HER = 'คุณเอ๊ม';

export const COPY = {
  ask: {
    eyebrow: 'มีเรื่องจะถามนิดนึง',
    headline: `${HER} ไปเดตกับโน้ตมั้ย?`,
    yes: 'ไปสิ!',
    gaveUpYes: 'ไปก็ได้!',
    maybe: 'ขอคิดดูก่อนนะ',
  },
  yes: {
    headline: 'เดี๋ยวนะ… ตอบตกลงจริงเหรอ??',
    sub: 'เตรียมใจโดนปฏิเสธไว้แล้วเชียว',
    next: 'โอเค ๆ ไปต่อ →',
  },
  maybe: {
    headline: 'ได้เลย ไม่รีบน้า',
    body: 'ขอบคุณที่กดเข้ามาดูนะ คิดได้เมื่อไหร่ค่อยกลับมาก็ได้ หน้านี้รออยู่ตรงนี้แหละ',
    back: 'กลับไปหน้าคำถาม',
  },
  plan: {
    next: 'ต่อไป',
    back: 'ย้อนกลับ',
    submit: 'ส่งเลย!',
    sending: 'กำลังส่ง…',
    date: { q: 'ว่างวันไหนดี?', hint: 'เลือกวันที่สะดวกได้เลย', mascot: 'วันไหนก็ว่างหมดแหละ' },
    time: { q: 'กี่โมงดี?', hint: 'จิ้มเวลา หรือเลือกเองด้านล่าง', other: 'เวลาอื่น', mascot: 'ตรงเวลาแน่นอน สัญญา' },
    food: {
      q: 'วันนี้อยากกินอะไรดี?', hint: 'เลือกแนวก่อนก็ได้ ไม่เลือกก็ได้',
      nameLabel: 'ชื่อร้านที่อยากไป', namePlaceholder: 'พิมพ์ชื่อร้าน หรือย่านที่อยากไป',
      search: 'หาใน Google Maps', linkLabel: 'วางลิงก์ Google Maps (ถ้ามี)', linkPlaceholder: 'https://maps.app.goo.gl/…',
      mascot: 'กินอะไรก็อร่อยถ้าไปด้วยกัน',
    },
    car: { q: 'ให้ไปรับมั้ย?', pickup: 'ไปรับนะ', pickupSub: 'เดี๋ยวขับไปรับถึงที่', meet: 'เจอกันที่ร้าน', meetSub: 'ต่างคนต่างไป เจอกันหน้าร้าน', mascot: 'ขับดี ไม่ซิ่ง' },
    alcohol: { q: 'ดื่มกันมั้ย?', yes: 'ดื่มได้', yesSub: 'แก้วสองแก้วพอกรึ่ม', no: 'ไม่ดื่ม', noSub: 'น้ำเปล่า ชาเย็น ก็แฮปปี้', mascot: 'แบบไหนก็ได้เลย' },
    pace: { q: 'กลับบ้านกี่โมงดี?', early: 'กลับเร็ว', earlySub: 'พรุ่งนี้มีงาน ขอนอนไว', late: 'ดึกได้', lateSub: 'ไม่รีบ นั่งคุยยาว ๆ', mascot: 'ส่งถึงบ้านปลอดภัยแน่นอน' },
    extra: {
      q: 'ฝากอะไรเพิ่มมั้ย?', hint: 'ข้ามได้เลย ไม่บังคับ',
      emailLabel: 'อีเมล (ถ้าอยากได้สรุปส่งไปให้)', emailPlaceholder: 'you@example.com',
      noteLabel: 'โน้ตถึงโน้ต', notePlaceholder: 'แพ้อาหารอะไร หรืออยากบอกอะไรก็พิมพ์ได้',
      mascot: 'ใกล้เสร็จแล้ว!',
    },
  },
  done: {
    headline: 'นัดเรียบร้อย!',
    headlinePickup: 'ดีใจที่ไม่ปฏิเสธนะ เดี๋ยวไปรับเอง',
    map: 'เปิดแผนที่',
    ics: 'ดาวน์โหลดไฟล์ปฏิทิน (.ics)',
    gcal: 'เพิ่มใน Google Calendar',
    qr: 'สแกนเพื่อเปิดหน้านี้อีกครั้ง',
    save: 'เซฟหน้านี้ไว้นะ ลิงก์นี้เป็นทางเดียวที่จะกลับมาดูได้',
    ps: 'ป.ล. คนปกติเขาก็แค่ทักแชต ส่วนเราทำเว็บมาให้ทั้งเว็บ… ไม่ได้ตั้งใจอะไรมากหรอกนะ',
  },
  error: {
    title: 'อุ๊ย มีอะไรผิดพลาดนิดหน่อย',
    db: 'ส่งไม่ผ่าน แต่คำตอบยังอยู่ครบนะ ลองกดอีกทีได้เลย',
    limit: 'ส่งบ่อยไปหน่อย พักแป๊บนึงแล้วลองใหม่นะ',
    retry: 'ลองอีกที',
  },
} as const;

export const MOODS: { id: FoodMood; label: string; search: string | null }[] = [
  { id: 'japanese', label: 'ญี่ปุ่น', search: 'ร้านอาหารญี่ปุ่น' },
  { id: 'grill', label: 'ปิ้งย่าง / ชาบู', search: 'ปิ้งย่าง ชาบู' },
  { id: 'italian', label: 'อิตาเลียน', search: 'ร้านอาหารอิตาเลียน' },
  { id: 'thai', label: 'ไทย', search: 'ร้านอาหารไทย' },
  { id: 'cafe', label: 'คาเฟ่ / ของหวาน', search: 'คาเฟ่ ของหวาน' },
  { id: 'any', label: 'แล้วแต่เลย', search: null },
];

export const TIME_CHIPS = ['11:30', '13:00', '18:00', '19:00', '20:00'] as const;

export function summaryRows(
  s: Pick<Submission, 'dateOn' | 'timeAt' | 'foodMood' | 'restaurantName' | 'car' | 'alcohol' | 'pace' | 'note'>,
): { label: string; value: string }[] {
  const p = COPY.plan;
  const mood = MOODS.find((m) => m.id === s.foodMood);
  return [
    { label: 'วันเวลา', value: thaiDateTime(s.dateOn, s.timeAt.slice(0, 5)) },
    { label: 'ร้าน', value: s.restaurantName },
    ...(mood ? [{ label: 'แนวอาหาร', value: mood.label }] : []),
    { label: 'การเดินทาง', value: s.car === 'pickup' ? p.car.pickup : p.car.meet },
    { label: 'เครื่องดื่ม', value: s.alcohol ? p.alcohol.yes : p.alcohol.no },
    { label: 'กลับบ้าน', value: s.pace === 'early' ? p.pace.early : p.pace.late },
    ...(s.note ? [{ label: 'โน้ต', value: s.note }] : []),
  ];
}
```

Run: `npx vitest run src/lib/copy.test.ts` — Expected: PASS.

- [ ] **Step 4: Append keyframes to `src/app/globals.css`**

```css
@keyframes drift {
  0% { transform: translate3d(0, 0, 0) rotate(0deg); }
  50% { transform: translate3d(12px, -18px, 0) rotate(8deg); }
  100% { transform: translate3d(0, 0, 0) rotate(0deg); }
}
@keyframes blink {
  0%, 92%, 100% { transform: scaleY(1); }
  95% { transform: scaleY(0.1); }
}
@keyframes breathe {
  0%, 100% { transform: scale(1, 1); }
  50% { transform: scale(1.02, 0.98); }
}
@keyframes wave {
  0%, 100% { transform: rotate(0deg); }
  50% { transform: rotate(-28deg); }
}
@keyframes tear {
  0% { transform: translateY(0); opacity: 0; }
  20% { opacity: 1; }
  100% { transform: translateY(26px); opacity: 0; }
}
@keyframes hop {
  0%, 100% { transform: translateY(0); }
  40% { transform: translateY(-14px); }
}
```

- [ ] **Step 5: Write `src/components/mascot/Mascot.tsx`**

An original character: a round cream body with a wobbly fuzzy outline, two nub ears, bead eyes, blush cheeks and stubby arms. One SVG; `pose` switches eyes, mouth, arms and extras. Idle breathing and blinking are CSS so they cost nothing.

```tsx
export type Pose = 'wave' | 'curious' | 'plead' | 'teary' | 'joy' | 'shy' | 'sorry';

const INK = '#4A342E';
const FUR = '#FFF1D6';
const BLUSH = '#FFB8C6';

const MOUTHS: Record<Pose, string> = {
  wave: 'M88 122 Q100 134 112 122',
  curious: 'M95 124 Q100 120 105 124 Q100 130 95 124',
  plead: 'M90 128 Q100 120 110 128',
  teary: 'M88 130 Q100 118 112 130',
  joy: 'M84 118 Q100 144 116 118 Z',
  shy: 'M92 124 Q100 129 108 124',
  sorry: 'M90 128 Q100 122 110 128',
};

function Eyes({ pose }: { pose: Pose }) {
  if (pose === 'joy') {
    return (
      <g fill="none" stroke={INK} strokeWidth="4" strokeLinecap="round">
        <path d="M70 100 Q78 90 86 100" />
        <path d="M114 100 Q122 90 130 100" />
      </g>
    );
  }
  const big = pose === 'plead' || pose === 'teary';
  const r = big ? 9 : 6;
  const dx = pose === 'curious' ? 4 : pose === 'shy' ? -3 : 0;
  return (
    <g style={{ transformOrigin: '100px 100px', animation: 'blink 4.2s infinite' }}>
      {[78, 122].map((cx) => (
        <g key={cx}>
          <circle cx={cx + dx} cy="100" r={r} fill={INK} />
          <circle cx={cx + dx + r / 3} cy={100 - r / 3} r={r / 3} fill="#fff" />
          {big ? <circle cx={cx + dx - r / 3} cy={100 + r / 3} r={r / 5} fill="#fff" /> : null}
        </g>
      ))}
      {big ? (
        <g fill="none" stroke={INK} strokeWidth="3" strokeLinecap="round">
          <path d="M66 86 Q76 80 88 86" />
          <path d="M112 86 Q124 80 134 86" />
        </g>
      ) : null}
    </g>
  );
}

export default function Mascot({ pose, size = 160 }: { pose: Pose; size?: number }) {
  const armsUp = pose === 'joy';
  const waving = pose === 'wave';
  const begging = pose === 'plead' || pose === 'teary' || pose === 'sorry';

  return (
    <svg
      width={size} height={size} viewBox="0 0 200 200" role="img" aria-label="มาสคอต"
      style={{ animation: pose === 'joy' ? 'hop 0.6s ease-in-out infinite' : undefined, overflow: 'visible' }}
    >
      <defs>
        <filter id="fuzz" x="-10%" y="-10%" width="120%" height="120%">
          <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" seed="4" result="n" />
          <feDisplacementMap in="SourceGraphic" in2="n" scale="5" />
        </filter>
      </defs>

      <ellipse cx="100" cy="186" rx="52" ry="7" fill={INK} opacity="0.12" />

      <g style={{ transformOrigin: '100px 180px', animation: 'breathe 3.4s ease-in-out infinite' }}>
        {/* ears */}
        <g filter="url(#fuzz)" fill={FUR} stroke={INK} strokeWidth="4">
          <ellipse cx="58" cy="52" rx="16" ry="20" transform="rotate(-18 58 52)" />
          <ellipse cx="142" cy="52" rx="16" ry="20" transform="rotate(18 142 52)" />
        </g>
        <ellipse cx="58" cy="54" rx="7" ry="10" fill={BLUSH} transform="rotate(-18 58 54)" />
        <ellipse cx="142" cy="54" rx="7" ry="10" fill={BLUSH} transform="rotate(18 142 54)" />

        {/* arms sit behind the body unless raised */}
        <g filter="url(#fuzz)" fill={FUR} stroke={INK} strokeWidth="4">
          <ellipse
            cx="38" cy={armsUp ? 84 : begging ? 128 : 124} rx="13" ry="20"
            transform={armsUp ? 'rotate(-40 38 84)' : begging ? 'rotate(50 38 128)' : 'rotate(20 38 124)'}
          />
          <g style={waving ? { transformOrigin: '160px 120px', animation: 'wave 0.9s ease-in-out infinite' } : undefined}>
            <ellipse
              cx="162" cy={armsUp || waving ? 84 : begging ? 128 : 124} rx="13" ry="20"
              transform={armsUp || waving ? 'rotate(40 162 84)' : begging ? 'rotate(-50 162 128)' : 'rotate(-20 162 124)'}
            />
          </g>
        </g>

        {/* body */}
        <ellipse cx="100" cy="112" rx="64" ry="68" fill={FUR} stroke={INK} strokeWidth="4" filter="url(#fuzz)" />
        <ellipse cx="100" cy="140" rx="34" ry="30" fill="#fff" opacity="0.55" />

        {/* cheeks */}
        <ellipse cx="62" cy="118" rx="11" ry="7" fill={BLUSH} opacity={pose === 'shy' || pose === 'joy' ? 1 : 0.8} />
        <ellipse cx="138" cy="118" rx="11" ry="7" fill={BLUSH} opacity={pose === 'shy' || pose === 'joy' ? 1 : 0.8} />

        <Eyes pose={pose} />

        <path d={MOUTHS[pose]} fill={pose === 'joy' ? '#FF4D6D' : 'none'} stroke={INK} strokeWidth="4" strokeLinecap="round" strokeLinejoin="round" />

        {pose === 'teary' ? (
          <g fill="#8FD3F4" stroke={INK} strokeWidth="2">
            <path d="M70 112 q-5 9 0 12 q5 -3 0 -12z" style={{ animation: 'tear 1.4s ease-in infinite' }} />
            <path d="M130 112 q-5 9 0 12 q5 -3 0 -12z" style={{ animation: 'tear 1.4s ease-in 0.5s infinite' }} />
          </g>
        ) : null}

        {pose === 'curious' ? (
          <text x="150" y="44" fontSize="30" fontWeight="700" fill={INK} fontFamily="var(--font-mali)">?</text>
        ) : null}
      </g>
    </svg>
  );
}
```

- [ ] **Step 6: Write the UI primitives**

`src/components/ui/Motion.tsx` — one switch for the whole app. With `reducedMotion="user"`, visitors who ask for reduced motion get opacity fades instead of springs and slides:

```tsx
'use client';

import type { ReactNode } from 'react';
import { MotionConfig } from 'motion/react';

export default function Motion({ children }: { children: ReactNode }) {
  return <MotionConfig reducedMotion="user">{children}</MotionConfig>;
}
```

In `src/app/layout.tsx`, import it and change the body to:

```tsx
      <body className="grain min-h-dvh"><Motion>{children}</Motion></body>
```

`src/components/ui/Card.tsx`:

```tsx
'use client';

import type { ReactNode } from 'react';
import { motion } from 'motion/react';

export default function Card({ children, className = '' }: { children: ReactNode; className?: string }) {
  return (
    <motion.div
      className={`sticker w-full max-w-[420px] bg-white p-6 sm:p-8 ${className}`}
      initial={{ opacity: 0, y: 28, scale: 0.94, rotate: -1.5 }}
      animate={{ opacity: 1, y: 0, scale: 1, rotate: 0 }}
      exit={{ opacity: 0, y: -20, scale: 0.96 }}
      transition={{ type: 'spring', stiffness: 260, damping: 20 }}
    >
      {children}
    </motion.div>
  );
}
```

`src/components/ui/StickerButton.tsx`:

```tsx
'use client';

import type { ComponentProps } from 'react';
import { motion } from 'motion/react';

const TONES = {
  cherry: 'bg-cherry text-white',
  butter: 'bg-butter text-cocoa',
  blush: 'bg-blush text-cocoa',
  white: 'bg-white text-cocoa',
} as const;

type Props = ComponentProps<typeof motion.button> & { tone?: keyof typeof TONES };

export default function StickerButton({ tone = 'butter', className = '', ...rest }: Props) {
  return (
    <motion.button
      type="button"
      whileHover={{ y: -2, rotate: -1 }}
      whileTap={{ scale: 0.94, x: 3, y: 3, boxShadow: '0px 0px 0 #4A342E' }}
      transition={{ type: 'spring', stiffness: 500, damping: 18 }}
      className={`sticker-sm min-h-[52px] px-6 py-3 font-head text-lg font-bold disabled:opacity-40 ${TONES[tone]} ${className}`}
      {...rest}
    />
  );
}
```

`src/components/ui/Confetti.tsx`:

```tsx
'use client';

import { useEffect, useRef } from 'react';

const COLOURS = ['#FF4D6D', '#FFB8C6', '#FFE08A', '#4A342E', '#FFFFFF'];

type Bit = { x: number; y: number; vx: number; vy: number; rot: number; vr: number; w: number; h: number; c: string; heart: boolean };

/** A one-shot canvas burst from the centre. Does nothing under reduced motion. */
export default function Confetti({ burst }: { burst: number }) {
  const ref = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    if (burst <= 0) return;
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    const canvas = ref.current;
    const ctx = canvas?.getContext('2d');
    if (!canvas || !ctx) return;

    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const W = window.innerWidth;
    const H = window.innerHeight;
    canvas.width = W * dpr;
    canvas.height = H * dpr;
    ctx.scale(dpr, dpr);

    const bits: Bit[] = Array.from({ length: 140 }, (_, i) => {
      const angle = Math.random() * Math.PI * 2;
      const speed = 6 + Math.random() * 12;
      return {
        x: W / 2, y: H * 0.45, vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed - 6,
        rot: Math.random() * 6, vr: (Math.random() - 0.5) * 0.4,
        w: 6 + Math.random() * 8, h: 4 + Math.random() * 6, c: COLOURS[i % COLOURS.length], heart: i % 5 === 0,
      };
    });

    let raf = 0;
    let frame = 0;
    const tick = () => {
      frame += 1;
      ctx.clearRect(0, 0, W, H);
      for (const b of bits) {
        b.vy += 0.32;
        b.vx *= 0.985;
        b.x += b.vx;
        b.y += b.vy;
        b.rot += b.vr;
        ctx.save();
        ctx.translate(b.x, b.y);
        ctx.rotate(b.rot);
        ctx.fillStyle = b.c;
        if (b.heart) {
          const s = b.w / 10;
          ctx.beginPath();
          ctx.moveTo(0, 3 * s);
          ctx.bezierCurveTo(-10 * s, -4 * s, -4 * s, -10 * s, 0, -4 * s);
          ctx.bezierCurveTo(4 * s, -10 * s, 10 * s, -4 * s, 0, 3 * s);
          ctx.fill();
        } else {
          ctx.fillRect(-b.w / 2, -b.h / 2, b.w, b.h);
        }
        ctx.restore();
      }
      if (frame < 220) raf = requestAnimationFrame(tick);
      else ctx.clearRect(0, 0, W, H);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [burst]);

  return <canvas ref={ref} aria-hidden className="pointer-events-none fixed inset-0 z-40 h-full w-full" />;
}
```

`src/components/ui/Doodles.tsx`:

```tsx
const HEART = 'M12 21s-7-4.6-9.5-9C.6 8.6 2.4 5 6 5c2 0 3.4 1.1 4 2.2C10.6 6.1 12 5 14 5c3.6 0 5.4 3.6 3.5 7-2.5 4.4-9.5 9-9.5 9z';
const STAR = 'M12 2l2.6 6.3 6.8.5-5.2 4.4 1.7 6.6L12 16.2 6.1 19.8l1.7-6.6L2.6 8.8l6.8-.5z';
const SQUIGGLE = 'M2 12c3-6 5 6 8 0s5 6 8 0 4 3 4 3';

const ITEMS = [
  { d: HEART, x: '8%', y: '12%', s: 34, fill: '#FFB8C6', t: 7 },
  { d: STAR, x: '84%', y: '9%', s: 40, fill: '#FFE08A', t: 9 },
  { d: SQUIGGLE, x: '76%', y: '78%', s: 54, fill: 'none', t: 8 },
  { d: HEART, x: '14%', y: '82%', s: 26, fill: '#FFE08A', t: 10 },
  { d: STAR, x: '6%', y: '48%', s: 22, fill: '#FFB8C6', t: 6 },
  { d: HEART, x: '90%', y: '46%', s: 28, fill: '#FFB8C6', t: 11 },
  { d: SQUIGGLE, x: '40%', y: '5%', s: 46, fill: 'none', t: 12 },
];

/** Slow hand-drawn shapes behind everything. Decorative only. */
export default function Doodles() {
  return (
    <div aria-hidden className="pointer-events-none fixed inset-0 z-0 overflow-hidden">
      {ITEMS.map((it, i) => (
        <svg
          key={i} viewBox="0 0 24 24" width={it.s} height={it.s}
          style={{ position: 'absolute', left: it.x, top: it.y, animation: `drift ${it.t}s ease-in-out ${-i}s infinite` }}
        >
          <path d={it.d} fill={it.fill} stroke="#4A342E" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      ))}
    </div>
  );
}
```

`src/app/icon.svg` (the mascot's face):

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <rect width="64" height="64" rx="16" fill="#FFB8C6"/>
  <circle cx="32" cy="34" r="21" fill="#FFF1D6" stroke="#4A342E" stroke-width="3"/>
  <circle cx="25" cy="31" r="3" fill="#4A342E"/><circle cx="39" cy="31" r="3" fill="#4A342E"/>
  <ellipse cx="20" cy="38" rx="4" ry="2.5" fill="#FFB8C6"/><ellipse cx="44" cy="38" rx="4" ry="2.5" fill="#FFB8C6"/>
  <path d="M27 39q5 5 10 0" fill="none" stroke="#4A342E" stroke-width="3" stroke-linecap="round"/>
</svg>
```

- [ ] **Step 7: Write the temporary gallery** — `src/app/dev-kit/page.tsx`

```tsx
'use client';

import { useState } from 'react';
import Mascot, { type Pose } from '@/components/mascot/Mascot';
import Card from '@/components/ui/Card';
import Confetti from '@/components/ui/Confetti';
import Doodles from '@/components/ui/Doodles';
import StickerButton from '@/components/ui/StickerButton';

const POSES: Pose[] = ['wave', 'curious', 'plead', 'teary', 'joy', 'shy', 'sorry'];

export default function DevKit() {
  const [burst, setBurst] = useState(0);
  return (
    <main className="relative flex min-h-dvh flex-col items-center gap-6 p-6">
      <Doodles />
      <Confetti burst={burst} />
      <div className="relative z-10 flex flex-wrap justify-center gap-4">
        {POSES.map((p) => (
          <figure key={p} className="text-center"><Mascot pose={p} size={140} /><figcaption>{p}</figcaption></figure>
        ))}
      </div>
      <Card className="relative z-10">
        <h1 className="font-head text-2xl font-bold">หัวข้อทดสอบ</h1>
        <p className="mt-2">ตัวอย่างข้อความภาษาไทยสำหรับดูฟอนต์</p>
        <div className="mt-4 flex flex-wrap gap-3">
          <StickerButton tone="cherry" onClick={() => setBurst((n) => n + 1)}>ไปสิ!</StickerButton>
          <StickerButton tone="butter">ต่อไป</StickerButton>
          <StickerButton tone="blush">ไม่ไป</StickerButton>
          <StickerButton tone="white">ย้อนกลับ</StickerButton>
        </div>
      </Card>
    </main>
  );
}
```

- [ ] **Step 8: Look at it**

Run `npm run dev` in the background and take screenshots of `http://localhost:3100/dev-kit` with the Playwright MCP tools at 390×844 and 1280×800 (click the cherry button once before the second shot). Read both screenshots and check, fixing the SVG until each holds:

- All seven poses are clearly different and read as: waving, curious, pleading, teary, overjoyed, shy, sorry.
- The outline looks fuzzy and hand-drawn, not a clean vector circle. If the displacement tears the stroke apart, lower `scale` to 3–4.
- Thai text renders in Mali (headline, buttons) and IBM Plex Sans Thai Looped (body), with no fallback boxes.
- Buttons have a 3 px outline and a hard shadow; pressing one moves it into its shadow.
- Confetti fires and clears; nothing overflows horizontally at 390 px.

Stop the dev server.

- [ ] **Step 9: Gate and commit**

Run: `npm run lint && npx tsc --noEmit && npm test`
Expected: all pass.

```bash
git add -A && git commit -m "feat: Thai copy, original mascot with seven poses, sticker UI kit

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: The question screen, the runaway No, event beacon and `/maybe`

**Files:**
- Create: `src/lib/track.ts`, `src/lib/mail.ts`, `src/app/api/event/route.ts`, `src/components/ask/RunawayNo.tsx`, `src/components/ask/AskScreen.tsx`, `src/app/maybe/page.tsx`
- Modify: `src/app/page.tsx` (replace the temporary body)

**Interfaces:**
- Consumes: everything from `@/lib/runaway`; `eventAllowed`, `EVENT_KINDS`, `EventKind` from `@/lib/rateLimit`; `getOrCreateVisitorId`; `getDb`, `schema`; `COPY`, `summaryRows`; `buildIcs`, `DateEvent`; `mapLink`; `Mascot`, `Card`, `StickerButton`, `Confetti`, `Doodles`.
- Produces:
  ```ts
  // track.ts (client)
  export type Device = 'desktop' | 'mobile';
  export function getDevice(): Device;                       // 'desktop' iff (hover: hover) and (pointer: fine)
  export function track(kind: EventKind, detail?: { n?: number; step?: number }): void;
  export const ATTEMPTS_KEY = 'date.noAttempts';             // sessionStorage key, read by PlanForm

  // mail.ts (server)
  export async function sendMail(input: { to: string; subject: string; text: string; html: string; attachments?: { filename: string; content: string }[] }): Promise<boolean>;
  export async function notifyMaybe(): Promise<void>;
  export async function notifySubmission(s: Submission): Promise<void>;
  export async function confirmToHer(s: Submission): Promise<void>;   // no-op when s.email is null
  export function toDateEvent(s: Submission): DateEvent;

  // RunawayNo
  <RunawayNo attempts={number} gaveUp={boolean} home={RefObject<HTMLDivElement | null>} onAttempt={() => void} onNear={(near: boolean) => void} onYes={() => void} />
  ```

- [ ] **Step 1: Write `src/lib/track.ts`**

```ts
import type { EventKind } from './rateLimit';

export type Device = 'desktop' | 'mobile';
export const ATTEMPTS_KEY = 'date.noAttempts';

export function getDevice(): Device {
  return window.matchMedia('(hover: hover) and (pointer: fine)').matches ? 'desktop' : 'mobile';
}

/** Fire-and-forget. Tracking must never break or slow the page. */
export function track(kind: EventKind, detail?: { n?: number; step?: number }): void {
  try {
    const body = new Blob([JSON.stringify({ kind, detail: detail ?? null, device: getDevice() })], { type: 'application/json' });
    navigator.sendBeacon('/api/event', body);
  } catch {
    /* ignore */
  }
}
```

- [ ] **Step 2: Write `src/lib/mail.ts`**

```ts
import 'server-only';
import type { Submission } from '@/db/schema';
import { COPY, HER, summaryRows } from './copy';
import { buildIcs, type DateEvent } from './ics';
import { mapLink } from './maps';
import { SITE_URL } from './site';

type Mail = { to: string; subject: string; text: string; html: string; attachments?: { filename: string; content: string }[] };

/** Never throws: a failed email must not turn a successful submission into an error. */
export async function sendMail(input: Mail): Promise<boolean> {
  const apiKey = process.env.AUTH_RESEND_KEY;
  const from = process.env.AUTH_RESEND_FROM ?? 'NaNote <date@nanoteofficial.me>';
  if (!apiKey) {
    console.error('sendMail: AUTH_RESEND_KEY is not set');
    return false;
  }
  try {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ from, ...input, headers: { 'X-Entity-Ref-ID': crypto.randomUUID() } }),
    });
    if (!res.ok) {
      console.error(`sendMail: Resend ${res.status} ${await res.text()}`);
      return false;
    }
    return true;
  } catch (err) {
    console.error('sendMail failed', err);
    return false;
  }
}

const esc = (s: string) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

function shell(title: string, bodyHtml: string): string {
  return `<!doctype html><html lang="th"><body style="margin:0;padding:24px;background:#FFF6E6;font-family:-apple-system,'Segoe UI',Roboto,sans-serif;color:#4A342E">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:520px;margin:0 auto;background:#fff;border:3px solid #4A342E;border-radius:20px"><tr><td style="padding:24px">
<h1 style="margin:0 0 16px;font-size:20px">${esc(title)}</h1>${bodyHtml}
</td></tr></table></body></html>`;
}

function rowsHtml(rows: { label: string; value: string }[]): string {
  return `<table role="presentation" cellpadding="0" cellspacing="0" style="font-size:15px;line-height:1.7">${rows
    .map((r) => `<tr><td style="padding-right:14px;color:#7a655f;vertical-align:top;white-space:nowrap">${esc(r.label)}</td><td>${esc(r.value)}</td></tr>`)
    .join('')}</table>`;
}

const link = (href: string, label: string) =>
  `<p style="margin:18px 0 0"><a href="${esc(href)}" style="display:inline-block;padding:11px 20px;background:#FFE08A;color:#4A342E;text-decoration:none;border:3px solid #4A342E;border-radius:12px;font-weight:600">${esc(label)}</a></p>`;

export function toDateEvent(s: Submission): DateEvent {
  return {
    id: s.id, dateOn: s.dateOn, timeAt: s.timeAt.slice(0, 5), restaurantName: s.restaurantName,
    mapUrl: mapLink(s), pageUrl: `${SITE_URL}/done/${s.id}`,
  };
}

const notifyTo = () => process.env.NOTIFY_EMAIL ?? '';

export async function notifyMaybe(): Promise<void> {
  if (!notifyTo()) return;
  const text = `${HER} กด "${COPY.ask.maybe}" ดูรายละเอียดได้ที่ ${SITE_URL}/admin`;
  await sendMail({ to: notifyTo(), subject: `${HER} ขอคิดดูก่อน`, text, html: shell(`${HER} ขอคิดดูก่อน`, link(`${SITE_URL}/admin`, 'เปิดหลังบ้าน')) });
}

export async function notifySubmission(s: Submission): Promise<void> {
  if (!notifyTo()) return;
  const rows = [
    ...summaryRows(s),
    { label: 'อีเมล', value: s.email ?? '-' },
    { label: 'กด "ไม่ไป"', value: `${s.noAttempts} ครั้ง (${s.device})` },
  ];
  const e = toDateEvent(s);
  const text = [...rows.map((r) => `${r.label}: ${r.value}`), '', `แผนที่: ${e.mapUrl}`, `สรุป: ${e.pageUrl}`, `หลังบ้าน: ${SITE_URL}/admin`].join('\n');
  await sendMail({
    to: notifyTo(),
    subject: `${HER} ตอบตกลงแล้ว!`,
    text,
    html: shell(`${HER} ตอบตกลงแล้ว!`, rowsHtml(rows) + link(e.mapUrl, COPY.done.map) + link(`${SITE_URL}/admin`, 'เปิดหลังบ้าน')),
    attachments: [{ filename: 'date.ics', content: Buffer.from(buildIcs(e, new Date())).toString('base64') }],
  });
}

export async function confirmToHer(s: Submission): Promise<void> {
  if (!s.email) return;
  const rows = summaryRows(s);
  const e = toDateEvent(s);
  const text = [COPY.done.headline, '', ...rows.map((r) => `${r.label}: ${r.value}`), '', `แผนที่: ${e.mapUrl}`, `ดูสรุปอีกครั้ง: ${e.pageUrl}`, '', COPY.done.ps].join('\n');
  await sendMail({
    to: s.email,
    subject: 'สรุปนัดของเรา',
    text,
    html: shell(COPY.done.headline, rowsHtml(rows) + link(e.mapUrl, COPY.done.map) + link(e.pageUrl, 'ดูสรุปอีกครั้ง') + `<p style="margin:20px 0 0;font-size:13px;font-style:italic;color:#7a655f">${esc(COPY.done.ps)}</p>`),
    attachments: [{ filename: 'date.ics', content: Buffer.from(buildIcs(e, new Date())).toString('base64') }],
  });
}
```

- [ ] **Step 3: Write `src/app/api/event/route.ts`**

Read the route-handler and `after()` docs under `node_modules/next/dist/docs/01-app/` first.

```ts
import { after } from 'next/server';
import { and, count, eq } from 'drizzle-orm';
import { getDb, schema } from '@/db';
import { notifyMaybe } from '@/lib/mail';
import { EVENT_KINDS, eventAllowed, type EventKind } from '@/lib/rateLimit';
import { getOrCreateVisitorId } from '@/lib/visitor';

const done = () => new Response(null, { status: 204 });

/** Event beacon. Always answers 204: a tracking problem is never the visitor's problem. */
export async function POST(request: Request) {
  try {
    const raw = await request.text();
    if (raw.length > 500) return done();
    const body = JSON.parse(raw) as { kind?: unknown; detail?: unknown; device?: unknown };

    if (!EVENT_KINDS.includes(body.kind as EventKind)) return done();
    const kind = body.kind as EventKind;
    if (kind === 'submit') return done(); // written by the server action only
    const device = body.device === 'desktop' ? 'desktop' : 'mobile';

    // Keep only the two small numbers we expect; drop anything else a client sends.
    const d = (typeof body.detail === 'object' && body.detail !== null ? body.detail : {}) as Record<string, unknown>;
    const num = (v: unknown) => (typeof v === 'number' && Number.isInteger(v) && v >= 0 && v <= 999 ? v : undefined);
    const detail = { n: num(d.n), step: num(d.step) };

    const visitorId = await getOrCreateVisitorId();
    const db = getDb();
    const { events } = schema;

    const [[total], [nos], [maybes]] = await Promise.all([
      db.select({ c: count() }).from(events).where(eq(events.visitorId, visitorId)),
      db.select({ c: count() }).from(events).where(and(eq(events.visitorId, visitorId), eq(events.kind, 'no_attempt'))),
      db.select({ c: count() }).from(events).where(and(eq(events.visitorId, visitorId), eq(events.kind, 'maybe'))),
    ]);
    if (!eventAllowed(kind, { visitorTotal: total.c, visitorNoAttempts: nos.c })) return done();

    await db.insert(events).values({ visitorId, kind, detail, device });

    // One email per visitor, sent after the response so the beacon stays fast.
    if (kind === 'maybe' && maybes.c === 0) after(() => notifyMaybe());
  } catch (err) {
    console.error('event beacon failed', err);
  }
  return done();
}
```

- [ ] **Step 4: Write `src/components/ask/RunawayNo.tsx`**

The button is `position: fixed` at the viewport origin and moved with a transform, so `nextSpot` coordinates map straight onto it. Its first position is measured from an empty "home" slot that `AskScreen` renders just below the card.

```tsx
'use client';

import { useCallback, useEffect, useLayoutEffect, useRef, useState, type RefObject } from 'react';
import { motion, useReducedMotion } from 'motion/react';
import { COPY } from '@/lib/copy';
import { TRIGGER, clampSpot, distToRect, nextSpot, noLabel, noScale, type Pt, type Rect } from '@/lib/runaway';

/** Elements the No button must never cover: AskScreen marks them with `data-no-avoid`. */
function avoidRects(): Rect[] {
  return [...document.querySelectorAll('[data-no-avoid]')].map((el) => {
    const r = el.getBoundingClientRect();
    return { x: r.left, y: r.top, w: r.width, h: r.height };
  });
}

type Props = {
  attempts: number;
  gaveUp: boolean;
  home: RefObject<HTMLDivElement | null>;
  onAttempt: () => void;
  onNear: (near: boolean) => void;
  onYes: () => void;
};

export default function RunawayNo({ attempts, gaveUp, home, onAttempt, onNear, onYes }: Props) {
  const ref = useRef<HTMLButtonElement>(null);
  const lastEscape = useRef(0);
  const lastDown = useRef(0);
  const [pos, setPos] = useState<Pt | null>(null);
  const reduced = useReducedMotion();

  const viewport = () => ({ w: window.innerWidth, h: window.innerHeight });
  const box = () => ref.current!.getBoundingClientRect();

  // Sit in the home slot until the first escape.
  useLayoutEffect(() => {
    const slot = home.current?.getBoundingClientRect();
    // Measuring layout is the one legitimate reason to set state in a layout effect.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    if (slot) setPos({ x: slot.left, y: slot.top });
  }, [home]);

  const escape = useCallback((pointer: Pt) => {
    const now = performance.now();
    if (now - lastEscape.current < 140) return; // one escape per gesture
    lastEscape.current = now;
    const b = box();
    setPos(nextSpot({ pointer, size: { w: b.width, h: b.height }, viewport: viewport(), rand: Math.random, avoid: avoidRects() }));
    onAttempt();
  }, [onAttempt]);

  // Mouse / pen: run when the pointer gets close. Touch is handled on the button itself.
  useEffect(() => {
    if (gaveUp) return;
    const onMove = (e: PointerEvent) => {
      if (e.pointerType === 'touch' || !ref.current) return;
      const b = box();
      const d = distToRect({ x: e.clientX, y: e.clientY }, { x: b.left, y: b.top, w: b.width, h: b.height });
      onNear(d < TRIGGER * 2);
      if (d < TRIGGER) escape({ x: e.clientX, y: e.clientY });
    };
    window.addEventListener('pointermove', onMove, { passive: true });
    return () => window.removeEventListener('pointermove', onMove);
  }, [escape, gaveUp, onNear]);

  // Keep it on screen when the viewport changes (rotation, mobile URL bar).
  useEffect(() => {
    const onResize = () => {
      if (!ref.current) return;
      const b = box();
      setPos((p) => (p ? clampSpot(p, { w: b.width, h: b.height }, viewport()) : p));
    };
    window.addEventListener('resize', onResize);
    return () => window.removeEventListener('resize', onResize);
  }, []);

  return (
    <motion.button
      ref={ref}
      type="button"
      data-testid="no-button"
      // Unreachable by keyboard until it gives up and becomes a Yes.
      tabIndex={gaveUp ? 0 : -1}
      aria-hidden={gaveUp ? undefined : true}
      className={`sticker-sm fixed left-0 top-0 z-30 min-h-[48px] touch-none select-none whitespace-nowrap px-5 py-2 font-head text-base font-bold ${gaveUp ? 'bg-cherry text-white' : 'bg-blush text-cocoa'}`}
      style={{ visibility: pos ? 'visible' : 'hidden' }}
      initial={false}
      animate={{ x: pos?.x ?? 0, y: pos?.y ?? 0, scale: gaveUp ? 1 : noScale(attempts), rotate: gaveUp ? 0 : attempts % 2 ? 4 : -4 }}
      transition={reduced ? { duration: 0 } : { type: 'spring', stiffness: 420, damping: 22, mass: 0.7 }}
      onPointerDown={(e) => {
        if (gaveUp) return;
        // Touch: jump before the tap can land. Mouse: only reachable if the browser
        // skipped a pointermove, so jump as well.
        e.preventDefault();
        lastDown.current = performance.now();
        escape({ x: e.clientX, y: e.clientY });
      }}
      onClick={(e) => {
        if (gaveUp) return onYes();
        e.preventDefault();
        // A real tap or click already escaped on pointerdown; counting its click too
        // would double the attempt. Only clicks with no pointerdown (keyboard,
        // assistive tech, scripts) reach the escape below, and they never decline either.
        if (performance.now() - lastDown.current < 700) return;
        const b = box();
        escape({ x: b.left + b.width / 2, y: b.top + b.height / 2 });
      }}
    >
      {gaveUp ? COPY.ask.gaveUpYes : noLabel(attempts)}
    </motion.button>
  );
}
```

- [ ] **Step 5: Write `src/components/ask/AskScreen.tsx`**

```tsx
'use client';

import { useCallback, useEffect, useRef, useState, useSyncExternalStore } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { AnimatePresence, motion } from 'motion/react';
import Mascot, { type Pose } from '@/components/mascot/Mascot';
import Card from '@/components/ui/Card';
import Confetti from '@/components/ui/Confetti';
import Doodles from '@/components/ui/Doodles';
import StickerButton from '@/components/ui/StickerButton';
import { COPY } from '@/lib/copy';
import { GIVE_UP_AT, MAYBE_AT, yesScale } from '@/lib/runaway';
import { ATTEMPTS_KEY, getDevice, track, type Device } from '@/lib/track';
import RunawayNo from './RunawayNo';

const subscribeNever = () => () => {};

function poseFor(attempts: number, near: boolean): Pose {
  if (attempts >= 4) return 'teary';
  if (attempts >= 1) return 'plead';
  return near ? 'curious' : 'wave';
}

export default function AskScreen() {
  const router = useRouter();
  const home = useRef<HTMLDivElement>(null);
  // Server render and first paint assume a phone; the real answer arrives on hydration.
  const device = useSyncExternalStore<Device>(subscribeNever, getDevice, () => 'mobile');
  const attemptsRef = useRef(0);
  const [attempts, setAttempts] = useState(0);
  const [near, setNear] = useState(false);
  const [saidYes, setSaidYes] = useState(false);
  const [burst, setBurst] = useState(0);

  useEffect(() => {
    track('open');
  }, []);

  // The count lives in a ref as well, so the beacon is sent exactly once per attempt
  // (a state updater may run twice in StrictMode).
  const onAttempt = useCallback(() => {
    attemptsRef.current += 1;
    setAttempts(attemptsRef.current);
    track('no_attempt', { n: attemptsRef.current });
  }, []);

  const sayYes = useCallback(() => {
    try {
      sessionStorage.setItem(ATTEMPTS_KEY, String(attempts));
    } catch { /* private mode */ }
    track('yes', { n: attempts });
    setSaidYes(true);
    setBurst((n) => n + 1);
  }, [attempts]);

  // Only touch devices get a button that gives up; with a mouse it stays uncatchable.
  const gaveUp = device === 'mobile' && attempts >= GIVE_UP_AT;

  return (
    <main className="relative flex min-h-dvh flex-col items-center justify-center overflow-hidden px-5 pb-[env(safe-area-inset-bottom)]">
      <Doodles />
      <Confetti burst={burst} />

      <AnimatePresence mode="wait">
        {saidYes ? (
          <Card key="yes" className="relative z-10 text-center">
            <div className="flex justify-center"><Mascot pose="joy" size={150} /></div>
            <h1 className="mt-3 font-head text-[26px] font-bold leading-snug">{COPY.yes.headline}</h1>
            <p className="mt-2 text-[15px] opacity-80">{COPY.yes.sub}</p>
            <StickerButton tone="cherry" className="mt-6" onClick={() => router.push('/plan')}>{COPY.yes.next}</StickerButton>
          </Card>
        ) : (
          <motion.div key="ask" className="relative z-10 flex w-full flex-col items-center" exit={{ opacity: 0, scale: 0.9 }}>
            <Card className="text-center">
              <div className="flex justify-center"><Mascot pose={poseFor(attempts, near)} size={170} /></div>
              <p className="mt-2 text-sm opacity-70">{COPY.ask.eyebrow}</p>
              <h1 className="mt-1 font-head text-[28px] font-bold leading-snug">{COPY.ask.headline}</h1>
              <motion.div
                data-no-avoid
                className="mx-auto mt-6 flex w-fit justify-center"
                animate={{ scale: yesScale(attempts) }}
                transition={{ type: 'spring', stiffness: 300, damping: 14 }}
              >
                <StickerButton tone="cherry" data-testid="yes-button" onClick={sayYes}>{COPY.ask.yes}</StickerButton>
              </motion.div>
            </Card>

            {/* The No button starts here, already outside the card, as in the reference clip. */}
            <div ref={home} aria-hidden className="mt-7 h-12 w-24" />

            <div data-no-avoid className="mt-4 h-10 w-44 text-center">
              <AnimatePresence>
                {attempts >= MAYBE_AT ? (
                  <motion.div initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }}>
                    <Link
                      href="/maybe" data-testid="maybe-link" onClick={() => track('maybe', { n: attempts })}
                      className="inline-block px-3 py-2 text-[15px] underline decoration-dashed underline-offset-4"
                    >
                      {COPY.ask.maybe}
                    </Link>
                  </motion.div>
                ) : null}
              </AnimatePresence>
            </div>

            <RunawayNo attempts={attempts} gaveUp={gaveUp} home={home} onAttempt={onAttempt} onNear={setNear} onYes={sayYes} />
          </motion.div>
        )}
      </AnimatePresence>
    </main>
  );
}
```

- [ ] **Step 6: Replace `src/app/page.tsx` and write `src/app/maybe/page.tsx`**

```tsx
import AskScreen from '@/components/ask/AskScreen';

export default function Home() {
  return <AskScreen />;
}
```

```tsx
import Link from 'next/link';
import Mascot from '@/components/mascot/Mascot';
import Doodles from '@/components/ui/Doodles';
import { COPY } from '@/lib/copy';

export const metadata = { title: 'ไม่รีบน้า' };

export default function MaybePage() {
  return (
    <main className="relative flex min-h-dvh items-center justify-center px-5">
      <Doodles />
      <div className="sticker relative z-10 w-full max-w-[420px] bg-white p-7 text-center">
        <div className="flex justify-center"><Mascot pose="shy" size={150} /></div>
        <h1 className="mt-3 font-head text-[26px] font-bold">{COPY.maybe.headline}</h1>
        <p className="mt-3 leading-relaxed">{COPY.maybe.body}</p>
        <Link href="/" className="sticker-sm mt-6 inline-block bg-butter px-6 py-3 font-head text-lg font-bold">{COPY.maybe.back}</Link>
      </div>
    </main>
  );
}
```

- [ ] **Step 7: Verify in a real browser**

Run `npm run dev` in the background (the local DB from Task 6 must be up). With the Playwright MCP tools:

1. **Desktop, 1280×800.** Open `/`. Move the mouse toward the No button from several directions, 20 times. Expected: it never lets the pointer inside its box; it never leaves the viewport; the mascot turns curious as the pointer nears, pleading after the first escape, teary after the fourth; the maybe link appears after 3 escapes. Press Tab repeatedly: focus reaches Yes and the maybe link, never No.
2. **Phone, 390×844 with touch emulation.** Open `/`. Tap No. Expected: it hops away before the tap lands, shrinks, the label changes, Yes grows. On the 7th tap it turns cherry and reads "ไปก็ได้!"; tapping it shows the surprised card with confetti.
3. Tap "โอเค ๆ ไปต่อ →". Expected: navigates to `/plan` (a 404 until Task 9).
4. Reload `/`, tap No 3 times, tap the maybe link. Expected: `/maybe` renders; "กลับไปหน้าคำถาม" returns to `/`.
5. Check the database:

```bash
docker exec -i date-pg psql -U postgres -d date -c 'SELECT kind, count(*) FROM event GROUP BY kind ORDER BY kind;'
```

Expected: rows for `open`, `no_attempt`, `yes`, `maybe`. The dev log shows `sendMail: AUTH_RESEND_KEY is not set` once for the maybe (correct locally).

Take one screenshot of each viewport and read them: the card is centred, nothing overflows, the No button sits just under the card before the first escape. Fix any layout problem before committing. Stop the dev server.

- [ ] **Step 8: Gate and commit**

Run: `npm run lint && npx tsc --noEmit && npm test && env -u DATABASE_URL npm run build`
Expected: all pass.

```bash
git add -A && git commit -m "feat: question screen with runaway No, maybe link and event beacon

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: The details form and the submit action

**Files:**
- Create: `src/app/plan/actions.ts`, `src/app/plan/page.tsx`, `src/components/plan/draft.ts`, `src/components/plan/steps.tsx`, `src/components/plan/PlanForm.tsx`
- Test: `src/components/plan/draft.test.ts`

**Interfaces:**
- Consumes: `parseSubmission`, `bangkokToday`, `Field`, `FoodMood`, `Car`, `Pace`; `submitAllowed`; `getOrCreateVisitorId`; `notifySubmission`, `confirmToHer`; `COPY`, `MOODS`, `TIME_CHIPS`; `searchUrl`; `track`, `getDevice`, `ATTEMPTS_KEY`.
- Produces:
  ```ts
  // actions.ts
  export type SubmitResult =
    | { ok: true; id: string }
    | { ok: false; kind: 'invalid'; field: Field; message: string }
    | { ok: false; kind: 'limit' | 'db'; message: string };
  export async function submitPlan(raw: unknown, meta: { noAttempts: unknown; device: unknown }): Promise<SubmitResult>;

  // draft.ts
  export type Draft = { dateOn: string; timeAt: string; foodMood: FoodMood | null; restaurantName: string; mapsUrl: string; car: Car | null; alcohol: boolean | null; pace: Pace | null; email: string; note: string };
  export const EMPTY_DRAFT: Draft;
  export const STEP_COUNT = 7;
  export const FIELD_STEP: Record<Field, number>;
  export const DRAFT_KEY = 'date.draft';
  export function stepReady(step: number, d: Draft): boolean;   // may the visitor press Next?
  export function readDraft(json: string | null): Draft;        // tolerant of junk
  ```

- [ ] **Step 1: Write the failing test** — `src/components/plan/draft.test.ts`

The Vitest include pattern `src/**/*.test.ts` already covers this path.

```ts
import { describe, expect, it } from 'vitest';
import { EMPTY_DRAFT, FIELD_STEP, STEP_COUNT, readDraft, stepReady } from './draft';

describe('stepReady', () => {
  it('blocks every required step while empty and allows the optional last one', () => {
    expect([0, 1, 2, 3, 4, 5, 6].map((s) => stepReady(s, EMPTY_DRAFT))).toEqual([false, false, false, false, false, false, true]);
  });
  it('opens each step once its answer exists', () => {
    const d = { ...EMPTY_DRAFT, dateOn: '2026-10-10', timeAt: '19:00', restaurantName: ' Hiro ', car: 'meet' as const, alcohol: false, pace: 'late' as const };
    expect([0, 1, 2, 3, 4, 5, 6].every((s) => stepReady(s, d))).toBe(true);
  });
  it('needs a name on the food step, not just a mood', () => {
    expect(stepReady(2, { ...EMPTY_DRAFT, foodMood: 'thai' })).toBe(false);
    expect(stepReady(2, { ...EMPTY_DRAFT, restaurantName: '   ' })).toBe(false);
  });
});

describe('FIELD_STEP', () => {
  it('maps every field to a step inside the form', () => {
    expect(Object.keys(FIELD_STEP).sort()).toEqual(['alcohol', 'car', 'dateOn', 'email', 'foodMood', 'mapsUrl', 'note', 'pace', 'restaurantName', 'timeAt']);
    for (const step of Object.values(FIELD_STEP)) expect(step).toBeLessThan(STEP_COUNT);
    expect(FIELD_STEP.mapsUrl).toBe(2);
    expect(FIELD_STEP.email).toBe(6);
  });
});

describe('readDraft', () => {
  it('returns the empty draft for null or junk', () => {
    expect(readDraft(null)).toEqual(EMPTY_DRAFT);
    expect(readDraft('{not json')).toEqual(EMPTY_DRAFT);
    expect(readDraft('[1,2]')).toEqual(EMPTY_DRAFT);
  });
  it('keeps well-typed fields and drops the rest', () => {
    const d = readDraft(JSON.stringify({ dateOn: '2026-10-10', car: 'pickup', alcohol: true, pace: 'whenever', foodMood: 'pizza', email: 5, extra: 'x' }));
    expect(d).toEqual({ ...EMPTY_DRAFT, dateOn: '2026-10-10', car: 'pickup', alcohol: true });
  });
});
```

Run: `npx vitest run src/components/plan/draft.test.ts` — Expected: FAIL, module not found.

- [ ] **Step 2: Implement `src/components/plan/draft.ts`**

```ts
import { FOOD_MOODS, type Car, type Field, type FoodMood, type Pace } from '@/lib/validate';

export type Draft = {
  dateOn: string; timeAt: string; foodMood: FoodMood | null; restaurantName: string; mapsUrl: string;
  car: Car | null; alcohol: boolean | null; pace: Pace | null; email: string; note: string;
};

export const EMPTY_DRAFT: Draft = {
  dateOn: '', timeAt: '', foodMood: null, restaurantName: '', mapsUrl: '', car: null, alcohol: null, pace: null, email: '', note: '',
};

export const STEP_COUNT = 7;
export const DRAFT_KEY = 'date.draft';

export const FIELD_STEP: Record<Field, number> = {
  dateOn: 0, timeAt: 1, foodMood: 2, restaurantName: 2, mapsUrl: 2, car: 3, alcohol: 4, pace: 5, email: 6, note: 6,
};

export function stepReady(step: number, d: Draft): boolean {
  switch (step) {
    case 0: return d.dateOn !== '';
    case 1: return d.timeAt !== '';
    case 2: return d.restaurantName.trim() !== '';
    case 3: return d.car !== null;
    case 4: return d.alcohol !== null;
    case 5: return d.pace !== null;
    default: return true;
  }
}

export function readDraft(json: string | null): Draft {
  if (!json) return EMPTY_DRAFT;
  let raw: unknown;
  try {
    raw = JSON.parse(json);
  } catch {
    return EMPTY_DRAFT;
  }
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return EMPTY_DRAFT;
  const r = raw as Record<string, unknown>;
  const s = (v: unknown) => (typeof v === 'string' ? v : '');
  return {
    dateOn: s(r.dateOn),
    timeAt: s(r.timeAt),
    foodMood: FOOD_MOODS.includes(r.foodMood as FoodMood) ? (r.foodMood as FoodMood) : null,
    restaurantName: s(r.restaurantName),
    mapsUrl: s(r.mapsUrl),
    car: r.car === 'pickup' || r.car === 'meet' ? r.car : null,
    alcohol: typeof r.alcohol === 'boolean' ? r.alcohol : null,
    pace: r.pace === 'early' || r.pace === 'late' ? r.pace : null,
    email: s(r.email),
    note: s(r.note),
  };
}
```

Run: `npx vitest run src/components/plan/draft.test.ts` — Expected: PASS.

- [ ] **Step 3: Write `src/app/plan/actions.ts`**

Read the server-action docs under `node_modules/next/dist/docs/01-app/` first. The action returns a result instead of redirecting so the client can keep the answers on failure.

```ts
'use server';

import { headers } from 'next/headers';
import { after } from 'next/server';
import { and, count, eq, gt } from 'drizzle-orm';
import { nanoid } from 'nanoid';
import { getDb, schema } from '@/db';
import { COPY } from '@/lib/copy';
import { confirmToHer, notifySubmission } from '@/lib/mail';
import { submitAllowed } from '@/lib/rateLimit';
import { bangkokToday, parseSubmission, type Field } from '@/lib/validate';
import { getOrCreateVisitorId } from '@/lib/visitor';

export type SubmitResult =
  | { ok: true; id: string }
  | { ok: false; kind: 'invalid'; field: Field; message: string }
  | { ok: false; kind: 'limit' | 'db'; message: string };

export async function submitPlan(raw: unknown, meta: { noAttempts: unknown; device: unknown }): Promise<SubmitResult> {
  const parsed = parseSubmission(raw, bangkokToday(new Date()));
  if (!parsed.ok) return { ok: false, kind: 'invalid', field: parsed.field, message: parsed.message };

  const noAttempts = typeof meta.noAttempts === 'number' && Number.isInteger(meta.noAttempts) ? Math.min(Math.max(meta.noAttempts, 0), 999) : 0;
  const device = meta.device === 'desktop' ? 'desktop' : 'mobile';

  try {
    const visitorId = await getOrCreateVisitorId();
    const db = getDb();
    const { submissions, events } = schema;
    const hourAgo = new Date(Date.now() - 3_600_000);
    const dayAgo = new Date(Date.now() - 86_400_000);

    const [[mine], [all]] = await Promise.all([
      db.select({ c: count() }).from(submissions).where(and(eq(submissions.visitorId, visitorId), gt(submissions.createdAt, hourAgo))),
      db.select({ c: count() }).from(submissions).where(gt(submissions.createdAt, dayAgo)),
    ]);
    if (!submitAllowed({ visitorLastHour: mine.c, allLastDay: all.c })) {
      return { ok: false, kind: 'limit', message: COPY.error.limit };
    }

    const userAgent = ((await headers()).get('user-agent') ?? '').slice(0, 300) || null;
    const [row] = await db
      .insert(submissions)
      .values({ id: nanoid(), visitorId, ...parsed.value, noAttempts, device, userAgent })
      .returning();
    await db.insert(events).values({ visitorId, kind: 'submit', detail: { n: noAttempts }, device });

    // Emails go out after the response; a failed send never blocks her.
    after(async () => {
      await notifySubmission(row);
      await confirmToHer(row);
    });

    return { ok: true, id: row.id };
  } catch (err) {
    console.error('submitPlan failed', err);
    return { ok: false, kind: 'db', message: COPY.error.db };
  }
}
```

- [ ] **Step 4: Write `src/components/plan/steps.tsx`**

```tsx
'use client';

import type { ReactNode } from 'react';
import { motion } from 'motion/react';
import { COPY, MOODS, TIME_CHIPS } from '@/lib/copy';
import { searchUrl } from '@/lib/maps';
import type { Draft } from './draft';

type StepProps = { draft: Draft; set: (patch: Partial<Draft>) => void; today: string; error?: string };

const P = COPY.plan;

function Label({ htmlFor, children }: { htmlFor: string; children: ReactNode }) {
  return <label htmlFor={htmlFor} className="mb-1.5 mt-4 block text-sm font-semibold">{children}</label>;
}

function Chip({ active, onClick, children }: { active: boolean; onClick: () => void; children: ReactNode }) {
  return (
    <motion.button
      type="button" aria-pressed={active} onClick={onClick} whileTap={{ scale: 0.92 }}
      className={`sticker-sm min-h-[48px] px-4 py-2 font-head font-bold ${active ? 'bg-butter' : 'bg-white'}`}
    >
      {children}
    </motion.button>
  );
}

function Choice({ active, onClick, title, sub }: { active: boolean; onClick: () => void; title: string; sub: string }) {
  return (
    <motion.button
      type="button" aria-pressed={active} onClick={onClick}
      whileTap={{ scale: 0.96 }} animate={{ rotate: active ? -1.5 : 0, y: active ? -3 : 0 }}
      className={`sticker-sm w-full p-4 text-left ${active ? 'bg-butter' : 'bg-white'}`}
    >
      <span className="block font-head text-xl font-bold">{title}</span>
      <span className="mt-1 block text-sm opacity-75">{sub}</span>
    </motion.button>
  );
}

export function DateStep({ draft, set, today }: StepProps) {
  return (
    <>
      <Label htmlFor="dateOn">{P.date.hint}</Label>
      <input id="dateOn" type="date" className="field" min={today} value={draft.dateOn} onChange={(e) => set({ dateOn: e.target.value })} />
    </>
  );
}

export function TimeStep({ draft, set }: StepProps) {
  return (
    <>
      <p className="mt-4 text-sm">{P.time.hint}</p>
      <div className="mt-3 flex flex-wrap gap-2.5">
        {TIME_CHIPS.map((t) => <Chip key={t} active={draft.timeAt === t} onClick={() => set({ timeAt: t })}>{t}</Chip>)}
      </div>
      <Label htmlFor="timeAt">{P.time.other}</Label>
      <input id="timeAt" type="time" className="field" value={draft.timeAt} onChange={(e) => set({ timeAt: e.target.value })} />
    </>
  );
}

export function FoodStep({ draft, set }: StepProps) {
  const mood = MOODS.find((m) => m.id === draft.foodMood);
  const query = draft.restaurantName.trim();
  // The search button works with a mood alone, a name alone, or both.
  const href = query || mood?.search ? searchUrl(query, mood?.search) : null;
  return (
    <>
      <p className="mt-4 text-sm">{P.food.hint}</p>
      <div className="mt-3 grid grid-cols-2 gap-2.5">
        {MOODS.map((m) => (
          <Chip key={m.id} active={draft.foodMood === m.id} onClick={() => set({ foodMood: draft.foodMood === m.id ? null : m.id })}>{m.label}</Chip>
        ))}
      </div>
      <Label htmlFor="restaurantName">{P.food.nameLabel}</Label>
      <input id="restaurantName" className="field" maxLength={120} placeholder={P.food.namePlaceholder} value={draft.restaurantName} onChange={(e) => set({ restaurantName: e.target.value })} />
      {href ? (
        <a href={href} target="_blank" rel="noopener noreferrer" className="sticker-sm mt-3 inline-block bg-blush px-4 py-2.5 font-head font-bold">{P.food.search}</a>
      ) : null}
      <Label htmlFor="mapsUrl">{P.food.linkLabel}</Label>
      <input id="mapsUrl" type="url" inputMode="url" className="field" maxLength={500} placeholder={P.food.linkPlaceholder} value={draft.mapsUrl} onChange={(e) => set({ mapsUrl: e.target.value })} />
    </>
  );
}

export function CarStep({ draft, set }: StepProps) {
  return (
    <div className="mt-5 grid gap-3">
      <Choice active={draft.car === 'pickup'} onClick={() => set({ car: 'pickup' })} title={P.car.pickup} sub={P.car.pickupSub} />
      <Choice active={draft.car === 'meet'} onClick={() => set({ car: 'meet' })} title={P.car.meet} sub={P.car.meetSub} />
    </div>
  );
}

export function AlcoholStep({ draft, set }: StepProps) {
  return (
    <div className="mt-5 grid gap-3">
      <Choice active={draft.alcohol === true} onClick={() => set({ alcohol: true })} title={P.alcohol.yes} sub={P.alcohol.yesSub} />
      <Choice active={draft.alcohol === false} onClick={() => set({ alcohol: false })} title={P.alcohol.no} sub={P.alcohol.noSub} />
    </div>
  );
}

export function PaceStep({ draft, set }: StepProps) {
  return (
    <div className="mt-5 grid gap-3">
      <Choice active={draft.pace === 'early'} onClick={() => set({ pace: 'early' })} title={P.pace.early} sub={P.pace.earlySub} />
      <Choice active={draft.pace === 'late'} onClick={() => set({ pace: 'late' })} title={P.pace.late} sub={P.pace.lateSub} />
    </div>
  );
}

export function ExtraStep({ draft, set }: StepProps) {
  return (
    <>
      <p className="mt-4 text-sm">{P.extra.hint}</p>
      <Label htmlFor="email">{P.extra.emailLabel}</Label>
      <input id="email" type="email" autoComplete="email" className="field" maxLength={200} placeholder={P.extra.emailPlaceholder} value={draft.email} onChange={(e) => set({ email: e.target.value })} />
      <Label htmlFor="note">{P.extra.noteLabel}</Label>
      <textarea id="note" rows={3} className="field" maxLength={300} placeholder={P.extra.notePlaceholder} value={draft.note} onChange={(e) => set({ note: e.target.value })} />
    </>
  );
}

export const STEPS = [
  { key: 'date', q: P.date.q, mascot: P.date.mascot, pose: 'wave', Body: DateStep },
  { key: 'time', q: P.time.q, mascot: P.time.mascot, pose: 'curious', Body: TimeStep },
  { key: 'food', q: P.food.q, mascot: P.food.mascot, pose: 'joy', Body: FoodStep },
  { key: 'car', q: P.car.q, mascot: P.car.mascot, pose: 'wave', Body: CarStep },
  { key: 'alcohol', q: P.alcohol.q, mascot: P.alcohol.mascot, pose: 'shy', Body: AlcoholStep },
  { key: 'pace', q: P.pace.q, mascot: P.pace.mascot, pose: 'curious', Body: PaceStep },
  { key: 'extra', q: P.extra.q, mascot: P.extra.mascot, pose: 'joy', Body: ExtraStep },
] as const;
```

- [ ] **Step 5: Write `src/components/plan/PlanForm.tsx`**

```tsx
'use client';

import { useEffect, useState, useSyncExternalStore, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { AnimatePresence, motion } from 'motion/react';
import { submitPlan } from '@/app/plan/actions';
import Mascot from '@/components/mascot/Mascot';
import Doodles from '@/components/ui/Doodles';
import StickerButton from '@/components/ui/StickerButton';
import { COPY } from '@/lib/copy';
import { ATTEMPTS_KEY, getDevice, track } from '@/lib/track';
import { bangkokToday } from '@/lib/validate';
import { DRAFT_KEY, FIELD_STEP, STEP_COUNT, readDraft, stepReady, type Draft } from './draft';
import { STEPS } from './steps';

const subscribeNever = () => () => {};
const read = (key: string) => {
  try {
    return sessionStorage.getItem(key);
  } catch {
    return null;
  }
};

/** sessionStorage only exists in the browser, so the form mounts after hydration. */
export default function PlanForm() {
  const hydrated = useSyncExternalStore(subscribeNever, () => true, () => false);
  return (
    <main className="relative flex min-h-dvh flex-col items-center justify-center px-5 py-8 pb-[calc(2rem+env(safe-area-inset-bottom))]">
      <Doodles />
      {hydrated ? <Inner /> : null}
    </main>
  );
}

function Inner() {
  const router = useRouter();
  const [draft, setDraft] = useState<Draft>(() => readDraft(read(DRAFT_KEY)));
  const [step, setStep] = useState(0);
  const [dir, setDir] = useState(1);
  const [fieldError, setFieldError] = useState<string | null>(null);
  const [failure, setFailure] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();
  const [today] = useState(() => bangkokToday(new Date()));

  useEffect(() => {
    try {
      sessionStorage.setItem(DRAFT_KEY, JSON.stringify(draft));
    } catch { /* private mode */ }
  }, [draft]);

  const set = (patch: Partial<Draft>) => {
    setFieldError(null);
    setDraft((d) => ({ ...d, ...patch }));
  };

  const go = (to: number) => {
    setDir(to > step ? 1 : -1);
    setStep(to);
    setFieldError(null);
    if (to > step) track('plan_step', { step: to });
  };

  const submit = () => {
    setFailure(null);
    startTransition(async () => {
      const noAttempts = Number(read(ATTEMPTS_KEY) ?? 0) || 0;
      const result = await submitPlan(draft, { noAttempts, device: getDevice() });
      if (result.ok) {
        try {
          sessionStorage.removeItem(DRAFT_KEY);
          sessionStorage.removeItem(ATTEMPTS_KEY);
        } catch { /* private mode */ }
        router.push(`/done/${result.id}`);
      } else if (result.kind === 'invalid') {
        setDir(-1);
        setStep(FIELD_STEP[result.field]);
        setFieldError(result.message);
      } else {
        setFailure(result.message);
      }
    });
  };

  if (failure) {
    return (
      <div className="sticker relative z-10 w-full max-w-[420px] bg-white p-7 text-center" role="alert">
        <div className="flex justify-center"><Mascot pose="sorry" size={140} /></div>
        <h1 className="mt-3 font-head text-2xl font-bold">{COPY.error.title}</h1>
        <p className="mt-2 leading-relaxed">{failure}</p>
        <StickerButton tone="cherry" className="mt-5" onClick={submit} disabled={pending}>{pending ? COPY.plan.sending : COPY.error.retry}</StickerButton>
      </div>
    );
  }

  const current = STEPS[step];
  const Body = current.Body;
  const last = step === STEP_COUNT - 1;

  return (
    <div className="relative z-10 w-full max-w-[440px]">
      {/* progress dots */}
      <ol className="mb-4 flex justify-center gap-2" aria-label={`ขั้นที่ ${step + 1} จาก ${STEP_COUNT}`}>
        {STEPS.map((s, i) => (
          <motion.li
            key={s.key} className="h-3 w-3 rounded-full border-2 border-cocoa"
            animate={{ scale: i === step ? 1.35 : 1, backgroundColor: i <= step ? '#FF4D6D' : '#FFFFFF' }}
          />
        ))}
      </ol>

      <AnimatePresence mode="wait" custom={dir}>
        <motion.section
          key={current.key}
          custom={dir}
          className="sticker bg-white p-6 sm:p-7"
          variants={{
            enter: (d: number) => ({ opacity: 0, x: 60 * d, rotate: 2 * d }),
            centre: { opacity: 1, x: 0, rotate: 0 },
            exit: (d: number) => ({ opacity: 0, x: -60 * d, rotate: -2 * d }),
          }}
          initial="enter" animate="centre" exit="exit"
          transition={{ type: 'spring', stiffness: 320, damping: 26 }}
        >
          <div className="flex items-end gap-3">
            <Mascot pose={current.pose} size={84} />
            <p className="sticker-sm mb-3 bg-cream px-3 py-2 text-sm">{current.mascot}</p>
          </div>
          <h1 className="mt-2 font-head text-[26px] font-bold leading-snug">{current.q}</h1>

          <Body draft={draft} set={set} today={today} />

          {fieldError ? <p role="alert" className="mt-3 text-sm font-semibold text-cherry">{fieldError}</p> : null}

          <div className="mt-6 flex items-center justify-between gap-3">
            {step > 0 ? (
              <StickerButton tone="white" onClick={() => go(step - 1)} disabled={pending}>{COPY.plan.back}</StickerButton>
            ) : <span />}
            {last ? (
              <StickerButton tone="cherry" data-testid="submit" onClick={submit} disabled={pending}>{pending ? COPY.plan.sending : COPY.plan.submit}</StickerButton>
            ) : (
              <StickerButton tone="butter" data-testid="next" onClick={() => go(step + 1)} disabled={!stepReady(step, draft)}>{COPY.plan.next}</StickerButton>
            )}
          </div>
        </motion.section>
      </AnimatePresence>
    </div>
  );
}
```

- [ ] **Step 6: Write `src/app/plan/page.tsx`**

```tsx
import PlanForm from '@/components/plan/PlanForm';

export const metadata = { title: 'นัดวันกัน' };

export default function PlanPage() {
  return <PlanForm />;
}
```

- [ ] **Step 7: Verify**

Run `npm run dev` in the background. With the Playwright MCP tools at 390×844:

1. Open `/plan`. Next is disabled until a date is picked; pick a date three days ahead; Next.
2. Tap the `19:00` chip; Next. Tap "ญี่ปุ่น", type `Sushi Hiro`; confirm the "หาใน Google Maps" link's `href` starts with `https://www.google.com/maps/search/?api=1&query=` and contains the encoded mood and name; paste `https://evil.example/maps` into the link field; Next.
3. Pick "ไปรับนะ", "ไม่ดื่ม", "กลับเร็ว" (Next after each). On the last card press "ส่งเลย!".
4. Expected: the form jumps back to the food card showing "ลิงก์นี้ไม่ใช่ Google Maps ลองก๊อปใหม่อีกทีนะ" and every earlier answer is still filled in.
5. Clear the link field, go forward to the last card, submit. Expected: navigates to `/done/<21 characters>` (a 404 until Task 10).
6. Reload `/plan` mid-way through a second run. Expected: answers so far are restored.

```bash
docker exec -i date-pg psql -U postgres -d date -c 'SELECT id, "dateOn", "timeAt", "foodMood", "restaurantName", car, alcohol, pace, device FROM submission;'
```

Expected: one row with the values entered.

Then stop the proxy to prove the failure path: `docker stop date-neon-proxy`, submit again. Expected: the sorry-mascot card with "ส่งไม่ผ่าน แต่คำตอบยังอยู่ครบนะ ลองกดอีกทีได้เลย". Run `docker start date-neon-proxy`, wait 5 s, press "ลองอีกที". Expected: it succeeds. Stop the dev server.

- [ ] **Step 8: Gate and commit**

Run: `npm run lint && npx tsc --noEmit && npm test && env -u DATABASE_URL npm run build`
Expected: all pass.

```bash
git add -A && git commit -m "feat: seven-card details form with validated, rate-limited submit

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: The summary ticket, QR code and calendar download

**Files:**
- Create: `src/lib/submission.ts`, `src/components/done/QrCode.tsx`, `src/components/done/Ticket.tsx`, `src/app/done/[id]/page.tsx`, `src/app/done/[id]/date.ics/route.ts`

**Interfaces:**
- Consumes: `getDb`, `schema`, `Submission`; `qrPath`; `toDateEvent` (from `@/lib/mail`); `buildIcs`, `googleCalUrl`; `summaryRows`, `COPY`; `SITE_URL`; `Mascot`, `Confetti`, `Doodles`.
- Produces:
  ```ts
  // submission.ts (server)
  export async function findSubmission(id: string): Promise<Submission | null>; // null for a malformed id, a missing row, or no database
  ```

- [ ] **Step 1: Write `src/lib/submission.ts`**

```ts
import 'server-only';
import { eq } from 'drizzle-orm';
import { getDb, schema } from '@/db';
import type { Submission } from '@/db/schema';

export async function findSubmission(id: string): Promise<Submission | null> {
  if (!/^[\w-]{21}$/.test(id)) return null;
  try {
    const [row] = await getDb().select().from(schema.submissions).where(eq(schema.submissions.id, id)).limit(1);
    return row ?? null;
  } catch (err) {
    console.error('findSubmission failed', err);
    return null;
  }
}
```

- [ ] **Step 2: Write `src/components/done/QrCode.tsx`**

```tsx
import { qrPath } from '@/lib/qr';

/** Server-rendered QR as plain SVG: no client JS, no image request. */
export default function QrCode({ text, size = 148, label }: { text: string; size?: number; label: string }) {
  const { size: n, d } = qrPath(text);
  const quiet = 2; // modules of white margin so scanners lock on
  return (
    <svg
      data-testid="qr" role="img" aria-label={label} width={size} height={size}
      viewBox={`${-quiet} ${-quiet} ${n + quiet * 2} ${n + quiet * 2}`} shapeRendering="crispEdges"
    >
      <rect x={-quiet} y={-quiet} width={n + quiet * 2} height={n + quiet * 2} fill="#fff" />
      <path d={d} fill="#4A342E" />
    </svg>
  );
}
```

- [ ] **Step 3: Write `src/components/done/Ticket.tsx`**

The QR code is passed in as `children` so it stays a server component.

```tsx
'use client';

import type { ReactNode } from 'react';
import { motion } from 'motion/react';
import Mascot from '@/components/mascot/Mascot';
import Confetti from '@/components/ui/Confetti';
import { COPY } from '@/lib/copy';

type Props = {
  headline: string;
  rows: { label: string; value: string }[];
  mapUrl: string;
  icsHref: string;
  gcalUrl: string;
  children: ReactNode; // the QR code
};

const item = { hidden: { opacity: 0, y: 10 }, show: { opacity: 1, y: 0 } };

export default function Ticket({ headline, rows, mapUrl, icsHref, gcalUrl, children }: Props) {
  return (
    <>
      <Confetti burst={1} />
      <motion.article
        className="sticker relative z-10 w-full max-w-[440px] bg-white"
        // Stamped onto the page: big and tilted, then slammed down.
        initial={{ opacity: 0, scale: 1.6, rotate: -9 }}
        animate={{ opacity: 1, scale: 1, rotate: -1 }}
        transition={{ type: 'spring', stiffness: 380, damping: 17 }}
      >
        <header className="flex items-center gap-3 p-6 pb-4">
          <Mascot pose="joy" size={88} />
          <h1 className="font-head text-[24px] font-bold leading-snug">{headline}</h1>
        </header>

        <motion.dl
          className="space-y-2 px-6" initial="hidden" animate="show"
          transition={{ staggerChildren: 0.07, delayChildren: 0.35 }}
        >
          {rows.map((r) => (
            <motion.div key={r.label} variants={item} className="flex gap-3">
              <dt className="w-24 shrink-0 text-sm opacity-70">{r.label}</dt>
              <dd className="font-semibold [overflow-wrap:anywhere]">{r.value}</dd>
            </motion.div>
          ))}
        </motion.dl>

        <div className="px-6 pt-4">
          <a href={mapUrl} target="_blank" rel="noopener noreferrer" data-testid="map-link" className="sticker-sm inline-block bg-blush px-4 py-2.5 font-head font-bold">{COPY.done.map}</a>
        </div>

        {/* perforation */}
        <div aria-hidden className="relative my-5 border-t-[3px] border-dashed border-cocoa">
          <span className="absolute -left-[14px] -top-[13px] h-6 w-6 rounded-full border-[3px] border-cocoa bg-cream" />
          <span className="absolute -right-[14px] -top-[13px] h-6 w-6 rounded-full border-[3px] border-cocoa bg-cream" />
        </div>

        <div className="flex items-center gap-4 px-6">
          <div className="sticker-sm shrink-0 bg-white p-2">{children}</div>
          <p className="text-sm leading-relaxed">{COPY.done.qr}</p>
        </div>

        <div className="grid gap-2.5 p-6">
          <a href={icsHref} data-testid="ics-link" className="sticker-sm bg-butter px-4 py-3 text-center font-head font-bold">{COPY.done.ics}</a>
          <a href={gcalUrl} target="_blank" rel="noopener noreferrer" data-testid="gcal-link" className="sticker-sm bg-white px-4 py-3 text-center font-head font-bold">{COPY.done.gcal}</a>
        </div>
      </motion.article>

      <p className="relative z-10 mt-5 max-w-[440px] text-center text-sm">{COPY.done.save}</p>
      <p className="relative z-10 mt-3 max-w-[440px] text-center text-[13px] italic opacity-75">{COPY.done.ps}</p>
    </>
  );
}
```

- [ ] **Step 4: Write `src/app/done/[id]/page.tsx`**

```tsx
import { notFound } from 'next/navigation';
import QrCode from '@/components/done/QrCode';
import Ticket from '@/components/done/Ticket';
import Doodles from '@/components/ui/Doodles';
import { COPY, summaryRows } from '@/lib/copy';
import { googleCalUrl } from '@/lib/ics';
import { toDateEvent } from '@/lib/mail';
import { findSubmission } from '@/lib/submission';

export const metadata = { title: 'นัดเรียบร้อย' };

export default async function DonePage({ params }: PageProps<'/done/[id]'>) {
  const { id } = await params;
  const s = await findSubmission(id);
  if (!s) notFound();

  const event = toDateEvent(s);
  return (
    <main className="relative flex min-h-dvh flex-col items-center justify-center px-5 py-10 pb-[calc(2.5rem+env(safe-area-inset-bottom))]">
      <Doodles />
      <Ticket
        headline={s.car === 'pickup' ? COPY.done.headlinePickup : COPY.done.headline}
        rows={summaryRows(s)}
        mapUrl={event.mapUrl}
        icsHref={`/done/${s.id}/date.ics`}
        gcalUrl={googleCalUrl(event)}
      >
        <QrCode text={event.pageUrl} label={COPY.done.qr} />
      </Ticket>
    </main>
  );
}
```

- [ ] **Step 5: Write `src/app/done/[id]/date.ics/route.ts`**

```ts
import { buildIcs } from '@/lib/ics';
import { toDateEvent } from '@/lib/mail';
import { findSubmission } from '@/lib/submission';

export async function GET(_request: Request, ctx: RouteContext<'/done/[id]/date.ics'>) {
  const { id } = await ctx.params;
  const s = await findSubmission(id);
  if (!s) return new Response('Not found', { status: 404 });

  return new Response(buildIcs(toDateEvent(s), new Date()), {
    headers: {
      'Content-Type': 'text/calendar; charset=utf-8',
      'Content-Disposition': 'attachment; filename="date.ics"',
      'Cache-Control': 'private, no-store',
    },
  });
}
```

- [ ] **Step 6: Verify**

Run `npm run dev` in the background. Take the id from Task 9:

```bash
ID=$(docker exec -i date-pg psql -U postgres -d date -Atc 'SELECT id FROM submission ORDER BY "createdAt" DESC LIMIT 1')
curl -s -D - "http://localhost:3100/done/$ID/date.ics" | head -30
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:3100/done/not-a-real-id-000000000
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:3100/done/aaaaaaaaaaaaaaaaaaaaa/date.ics
```

Expected: the first prints `content-type: text/calendar; charset=utf-8`, an attachment disposition, and a body starting `BEGIN:VCALENDAR` with `DTSTART:` seven hours behind the Bangkok time entered; the other two print `404`.

Open `/done/$ID` with the Playwright MCP tools at 390×844 and 1280×800, screenshot both, and read them. Check: the ticket stamps in; every answer is shown in Thai; the pickup headline appears because "ไปรับนะ" was chosen; the QR code is crisp with a white margin; nothing overflows at 390 px; the P.S. is below the ticket.

Decode the QR to prove it points at the right page. First save an element screenshot of `[data-testid=qr]` (page zoomed so the code is at least 400 px wide) to `qr.png` in the session scratchpad directory, then:

```bash
pip install --break-system-packages -q opencv-python-headless
python3 -I - "$ID" "<scratchpad>/qr.png" <<'PY'
import sys, cv2
text, _, _ = cv2.QRCodeDetector().detectAndDecode(cv2.imread(sys.argv[2]))
print(text)
assert text == f'https://date.nanoteofficial.me/done/{sys.argv[1]}', text
PY
```

Expected: prints the production URL for this id and exits 0. Stop the dev server.

- [ ] **Step 7: Gate and commit**

Run: `npm run lint && npx tsc --noEmit && npm test && env -u DATABASE_URL npm run build`
Expected: all pass.

```bash
git add -A && git commit -m "feat: summary ticket with QR code, map link and calendar export

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: The admin log

**Files:**
- Modify: `src/app/(admin)/admin/page.tsx` (replace the placeholder)

**Interfaces:**
- Consumes: `auth`, `isAllowed`; `getDb`, `schema`; `groupTimeline`, `Visit`, `EventRow`; `summaryRows`; `mapLink`.
- Produces: nothing used by later tasks.

- [ ] **Step 1: Write `src/app/(admin)/admin/page.tsx`**

The layout already gates this page; the page checks again because it reads personal data and a page must not rely on its layout alone.

```tsx
import { redirect } from 'next/navigation';
import { desc } from 'drizzle-orm';
import { auth, isAllowed } from '@/auth';
import { getDb, schema } from '@/db';
import { summaryRows } from '@/lib/copy';
import { mapLink } from '@/lib/maps';
import { groupTimeline, type EventRow, type Outcome } from '@/lib/timeline';

export const metadata = { title: 'Admin' };
export const dynamic = 'force-dynamic';

const when = (d: Date) =>
  new Intl.DateTimeFormat('th-TH', { timeZone: 'Asia/Bangkok', dateStyle: 'medium', timeStyle: 'short' }).format(d);

const OUTCOME: Record<Outcome, { label: string; cls: string }> = {
  submitted: { label: 'ส่งแผนแล้ว', cls: 'bg-butter' },
  yes: { label: 'กดไปสิ ยังไม่ส่งแผน', cls: 'bg-blush' },
  maybe: { label: 'ขอคิดดูก่อน', cls: 'bg-white' },
  looking: { label: 'เปิดดูเฉย ๆ', cls: 'bg-white' },
};

export default async function AdminPage() {
  const session = await auth();
  if (!isAllowed(session?.user?.email)) redirect('/signin');

  const db = getDb();
  const [subs, evts] = await Promise.all([
    db.select().from(schema.submissions).orderBy(desc(schema.submissions.createdAt)).limit(200),
    db.select().from(schema.events).orderBy(desc(schema.events.createdAt)).limit(2000),
  ]);
  const visits = groupTimeline(evts as EventRow[], subs.map((s) => ({ id: s.id, visitorId: s.visitorId })));

  return (
    <div className="space-y-10">
      <section>
        <h1 className="font-head text-2xl font-bold">คำตอบ ({subs.length})</h1>
        {subs.length === 0 ? <p className="mt-3 opacity-70">ยังไม่มีคำตอบ</p> : null}
        <ul className="mt-4 space-y-4">
          {subs.map((s) => (
            <li key={s.id} className="sticker bg-white p-5">
              <details open={subs[0].id === s.id}>
                <summary className="cursor-pointer font-head text-lg font-bold">
                  {summaryRows(s)[0].value} · {s.restaurantName}
                </summary>
                <dl className="mt-4 grid gap-x-4 gap-y-1.5 sm:grid-cols-[9rem_1fr]">
                  {[
                    ...summaryRows(s),
                    { label: 'อีเมล', value: s.email ?? '-' },
                    { label: 'กด "ไม่ไป"', value: `${s.noAttempts} ครั้ง` },
                    { label: 'อุปกรณ์', value: s.device },
                    { label: 'ส่งเมื่อ', value: when(s.createdAt) },
                    { label: 'User agent', value: s.userAgent ?? '-' },
                  ].map((r) => (
                    <div key={r.label} className="contents">
                      <dt className="text-sm opacity-70">{r.label}</dt>
                      <dd className="[overflow-wrap:anywhere]">{r.value}</dd>
                    </div>
                  ))}
                </dl>
                <p className="mt-4 flex flex-wrap gap-4 text-sm">
                  <a className="underline" href={mapLink(s)} target="_blank" rel="noopener noreferrer">แผนที่</a>
                  <a className="underline" href={`/done/${s.id}`}>หน้าสรุป</a>
                  <a className="underline" href={`/done/${s.id}/date.ics`}>ไฟล์ปฏิทิน</a>
                </p>
              </details>
            </li>
          ))}
        </ul>
      </section>

      <section>
        <h2 className="font-head text-2xl font-bold">ไทม์ไลน์ผู้เข้าชม ({visits.length})</h2>
        <div className="mt-4 overflow-x-auto">
          <table className="w-full min-w-[640px] border-collapse text-left text-sm">
            <thead>
              <tr className="border-b-[3px] border-cocoa">
                {['ล่าสุด', 'ผลลัพธ์', 'อุปกรณ์', 'เปิด', 'กด "ไม่ไป"', 'ใช้เวลากรอก', 'คำตอบ'].map((h) => (
                  <th key={h} className="px-2 py-2 font-semibold">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {visits.map((v) => (
                <tr key={v.visitorId} className="border-b border-cocoa/20">
                  <td className="px-2 py-2 whitespace-nowrap">{when(v.lastAt)}</td>
                  <td className="px-2 py-2"><span className={`sticker-sm inline-block px-2 py-0.5 ${OUTCOME[v.outcome].cls}`}>{OUTCOME[v.outcome].label}</span></td>
                  <td className="px-2 py-2">{v.device}</td>
                  <td className="px-2 py-2">{v.opens}</td>
                  <td className="px-2 py-2">{v.noAttempts}</td>
                  <td className="px-2 py-2">{v.secondsToFinish === null ? '-' : `${v.secondsToFinish} วิ`}</td>
                  <td className="px-2 py-2">
                    {v.submissionIds.length === 0 ? '-' : v.submissionIds.map((id) => <a key={id} className="mr-2 underline" href={`/done/${id}`}>เปิด</a>)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
```

- [ ] **Step 2: Verify**

Run `npm run dev` in the background.

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:3100/admin
curl -s -H 'Cookie: authjs.session-token=devtoken' http://localhost:3100/admin | grep -o 'คำตอบ ([0-9]*)\|ไทม์ไลน์ผู้เข้าชม ([0-9]*)'
```

Expected: `307`, then both headings with counts of at least 1. Open `/admin` with the Playwright MCP tools using the `devtoken` cookie, screenshot it at 1280×800 and 390×844, and check: the newest submission is expanded with every field; the timeline has a "ส่งแผนแล้ว" row with a seconds figure and a "ขอคิดดูก่อน" row from Task 8; the table scrolls sideways on the phone instead of overflowing the page. Stop the dev server.

- [ ] **Step 3: Gate and commit**

Run: `npm run lint && npx tsc --noEmit && npm test && env -u DATABASE_URL npm run build`
Expected: all pass.

```bash
git add -A && git commit -m "feat: admin log with submissions and visitor timeline

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: End-to-end tests, 404 page, cleanup and project docs

**Files:**
- Create: `playwright.config.ts`, `e2e/flow.spec.ts`, `src/app/not-found.tsx`, `README.md`, `CLAUDE.md`
- Delete: `src/app/dev-kit/page.tsx`

**Interfaces:**
- Consumes: the running app and the local database from Task 6; test ids `no-button`, `yes-button`, `maybe-link`, `next`, `submit`, `qr`, `ics-link`, `map-link`, `gcal-link`.

- [ ] **Step 1: Write `playwright.config.ts`**

```ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: false,
  workers: 1,
  retries: 0,
  use: { baseURL: 'http://localhost:3100', trace: 'retain-on-failure' },
  webServer: { command: 'npm run dev', url: 'http://localhost:3100', reuseExistingServer: true, timeout: 120_000 },
  projects: [
    { name: 'desktop', use: { ...devices['Desktop Chrome'], viewport: { width: 1280, height: 800 } } },
    { name: 'mobile', use: { ...devices['Pixel 7'], viewport: { width: 390, height: 844 } } },
  ],
});
```

Run: `npx playwright install chromium` — Expected: exits 0.

- [ ] **Step 2: Write `e2e/flow.spec.ts`**

```ts
import { expect, test, type Page } from '@playwright/test';

const centre = async (page: Page, testId: string) => {
  const box = await page.getByTestId(testId).boundingBox();
  if (!box) throw new Error(`${testId} has no box`);
  return { x: box.x + box.width / 2, y: box.y + box.height / 2, box };
};

const inDays = (n: number) => new Date(Date.now() + (n * 24 + 7) * 3_600_000).toISOString().slice(0, 10);

test.describe('desktop', () => {
  test.skip(({ isMobile }) => isMobile, 'pointer behaviour');

  test('the No button cannot be clicked or focused', async ({ page }) => {
    await page.goto('/');
    await expect(page.getByTestId('no-button')).toBeVisible();

    for (let i = 0; i < 30; i++) {
      const { x, y } = await centre(page, 'no-button');
      await page.mouse.move(x, y, { steps: 6 });
      await page.mouse.down();
      await page.mouse.up();
      await page.waitForTimeout(160);
      const { box } = await centre(page, 'no-button');
      // The pointer is never left inside the button, and the button never leaves the screen.
      expect(x < box.x || x > box.x + box.width || y < box.y || y > box.y + box.height).toBe(true);
      expect(box.x).toBeGreaterThanOrEqual(0);
      expect(box.y).toBeGreaterThanOrEqual(0);
      expect(box.x + box.width).toBeLessThanOrEqual(1280);
      expect(box.y + box.height).toBeLessThanOrEqual(800);
    }

    // Still on the question, and with a mouse it never gives up.
    await expect(page.getByTestId('yes-button')).toBeVisible();
    await expect(page.getByTestId('no-button')).not.toHaveText('ไปก็ได้!');
    await expect(page.getByTestId('no-button')).toHaveAttribute('tabindex', '-1');

    for (let i = 0; i < 12; i++) {
      await page.keyboard.press('Tab');
      expect(await page.evaluate(() => document.activeElement?.getAttribute('data-testid'))).not.toBe('no-button');
    }
  });

  test('a scripted click on No does not decline', async ({ page }) => {
    await page.goto('/');
    await page.getByTestId('no-button').dispatchEvent('click');
    await expect(page.getByTestId('yes-button')).toBeVisible();
    await expect(page).toHaveURL('/');
  });

  test('/admin sends a signed-out visitor to /signin', async ({ page }) => {
    await page.goto('/admin');
    await expect(page).toHaveURL(/\/signin/);
  });
});

test.describe('mobile', () => {
  test.skip(({ isMobile }) => !isMobile, 'touch behaviour');

  const tapNo = async (page: Page) => {
    const { x, y } = await centre(page, 'no-button');
    await page.touchscreen.tap(x, y);
    await page.waitForTimeout(260);
  };

  test('maybe appears after 3 taps and leads to the no-rush page', async ({ page }) => {
    await page.goto('/');
    await tapNo(page);
    await tapNo(page);
    await expect(page.getByTestId('maybe-link')).toHaveCount(0);
    await tapNo(page);
    await page.getByTestId('maybe-link').tap();
    await expect(page).toHaveURL('/maybe');
    await expect(page.getByRole('heading', { name: 'ได้เลย ไม่รีบน้า' })).toBeVisible();
  });

  test('No gives up on the 7th tap; the whole flow ends on a ticket', async ({ page, request }) => {
    await page.goto('/');
    for (let i = 0; i < 6; i++) await tapNo(page);
    await expect(page.getByTestId('no-button')).not.toHaveText('ไปก็ได้!');
    await tapNo(page);
    await expect(page.getByTestId('no-button')).toHaveText('ไปก็ได้!');

    await page.getByTestId('no-button').tap();
    await expect(page.getByRole('heading', { name: 'เดี๋ยวนะ… ตอบตกลงจริงเหรอ??' })).toBeVisible();
    await page.getByRole('button', { name: 'โอเค ๆ ไปต่อ →' }).tap();
    await expect(page).toHaveURL('/plan');

    await expect(page.getByTestId('next')).toBeDisabled();
    await page.locator('#dateOn').fill(inDays(3));
    await page.getByTestId('next').tap();

    await page.getByRole('button', { name: '19:00' }).tap();
    await page.getByTestId('next').tap();

    await page.getByRole('button', { name: 'ญี่ปุ่น' }).tap();
    await page.locator('#restaurantName').fill('Sushi Hiro');
    await page.getByTestId('next').tap();

    await page.getByRole('button', { name: /ไปรับนะ/ }).tap();
    await page.getByTestId('next').tap();
    await page.getByRole('button', { name: /ไม่ดื่ม/ }).tap();
    await page.getByTestId('next').tap();
    await page.getByRole('button', { name: /กลับเร็ว/ }).tap();
    await page.getByTestId('next').tap();

    await page.locator('#note').fill('<b>แพ้กุ้ง</b>');
    await page.getByTestId('submit').tap();

    await expect(page).toHaveURL(/\/done\/[\w-]{21}$/);
    await expect(page.getByRole('heading', { name: 'ดีใจที่ไม่ปฏิเสธนะ เดี๋ยวไปรับเอง' })).toBeVisible();
    await expect(page.getByText('Sushi Hiro')).toBeVisible();
    // The note is shown as text, not parsed as HTML.
    await expect(page.getByText('<b>แพ้กุ้ง</b>')).toBeVisible();
    await expect(page.getByTestId('qr')).toBeVisible();
    await expect(page.getByTestId('map-link')).toHaveAttribute('href', /^https:\/\/www\.google\.com\/maps\/search\/\?api=1&query=Sushi/);
    await expect(page.getByTestId('gcal-link')).toHaveAttribute('href', /^https:\/\/calendar\.google\.com\/calendar\/render\?action=TEMPLATE/);

    const ics = await request.get(`${page.url()}/date.ics`);
    expect(ics.status()).toBe(200);
    expect(ics.headers()['content-type']).toContain('text/calendar');
    const body = await ics.text();
    expect(body).toContain('BEGIN:VEVENT');
    expect(body).toContain(`DTSTART:${inDays(3).replace(/-/g, '')}T120000Z`);
  });
});
```

- [ ] **Step 3: Run the end-to-end tests**

The local database from Task 6 must be running. The rate limit allows 30 submissions a day overall, so clear earlier test rows first:

```bash
docker exec -i date-pg psql -U postgres -d date -c 'TRUNCATE submission, event;'
npm run e2e
```

Expected: 5 passed, the rest skipped by project (3 desktop tests run in `desktop`, 2 mobile tests in `mobile`). If the mobile project reports the device as desktop (`getDevice()` returns `'desktop'` so No never gives up), confirm with `page.evaluate(() => matchMedia('(hover: hover) and (pointer: fine)').matches)`; it must be `false` under the Pixel 7 profile. Fix the app, not the test, if a real behaviour is wrong.

- [ ] **Step 4: Write `src/app/not-found.tsx` and delete the gallery**

```tsx
import Link from 'next/link';
import Mascot from '@/components/mascot/Mascot';

export default function NotFound() {
  return (
    <main className="flex min-h-dvh items-center justify-center px-5">
      <div className="sticker w-full max-w-[420px] bg-white p-7 text-center">
        <div className="flex justify-center"><Mascot pose="curious" size={140} /></div>
        <h1 className="mt-3 font-head text-2xl font-bold">หาหน้านี้ไม่เจอ</h1>
        <p className="mt-2">ลิงก์อาจพิมพ์ผิด หรือหน้านี้ไม่มีอยู่แล้ว</p>
        <Link href="/" className="sticker-sm mt-5 inline-block bg-butter px-6 py-3 font-head text-lg font-bold">กลับหน้าแรก</Link>
      </div>
    </main>
  );
}
```

```bash
git rm -q src/app/dev-kit/page.tsx
```

- [ ] **Step 5: Write `README.md` and `CLAUDE.md`**

`README.md`:

```markdown
# date.nanoteofficial.me

A private, single-purpose invitation page. One link, one question, a No button that will
not hold still, and a short form that turns a yes into a plan with a calendar file.

Next.js 16 · React 19 · Tailwind v4 · Auth.js (magic link) · Neon Postgres + Drizzle.

    npm run dev      # http://localhost:3100
    npm run lint && npx tsc --noEmit && npm test && npm run build
    npm run e2e      # needs the local database (see CLAUDE.md)

The mascot is an original drawing made for this page.
```

`CLAUDE.md`:

```markdown
# CLAUDE.md

Private date-invitation site for one person. Thai UI. Live at https://date.nanoteofficial.me.
Design spec: `/project/docs/superpowers/specs/2026-10-06-date-nanoteofficial-v0.1-design.md`.

## Commands

    npm run dev              # http://localhost:3100 (3000 is taken on this machine)
    npm run lint && npx tsc --noEmit && npm test
    npm run build            # must pass with DATABASE_URL unset
    npm run e2e              # Playwright, desktop + mobile projects, needs the local DB

Next.js 16: read `node_modules/next/dist/docs/` before writing Next-specific code.

## Shape

- `/` question (`AskScreen` + `RunawayNo`) → `/plan` seven-card form (`PlanForm`, server
  action `submitPlan`) → `/done/[id]` ticket (QR, `.ics`, Google Calendar). `/maybe` is the
  gentle exit. `/admin` is the log.
- Everything that can be wrong is a pure, tested module in `src/lib/`: `runaway.ts`
  (No-button geometry and escalation), `validate.ts`, `maps.ts` (Google Maps allowlist),
  `ics.ts`, `qr.ts`, `rateLimit.ts`, `timeline.ts`. Components only animate.
- **Every Thai string is in `src/lib/copy.ts`.** Change wording there and nowhere else.
- No middleware. The gate is `src/app/(admin)/layout.tsx`, and `/admin` checks again.
  Sign-in is allowed only for `ALLOWED_EMAILS`; `/signin` shows the same message for any
  address so it does not reveal the allowlist.
- `db` (eager) is for the Auth.js adapter only; app code calls `getDb()`.
- Visitors are identified by an httpOnly `vid` cookie set by `/api/event` or the submit
  action. No IP address is stored.
- Emails go out in `after()`; `sendMail` never throws.

## Rules

- Palette is fixed: cream `#FFF6E6`, blush `#FFB8C6`, butter `#FFE08A`, cocoa `#4A342E`,
  cherry `#FF4D6D` (Yes and confetti only). Flat fills, 3 px outlines, hard shadows.
- Animate only `transform` and `opacity`; honour `prefers-reduced-motion`.
- No emoji in UI, no `dangerouslySetInnerHTML`, user text is always rendered as text.
- The mascot is original. Never add third-party character art or brand names.
- Rate limits: 5 submissions per visitor per hour, 30 per day overall.

## Local database

Neon's HTTP driver needs a proxy in front of plain Postgres:

    docker start date-pg date-neon-proxy
    # .env.local: DATABASE_URL=postgres://postgres:pg@date-pg:5432/date
    #             NEON_LOCAL_PROXY=http://localhost:4445/sql

Schema changes locally: `npx drizzle-kit generate --schema src/db/schema.ts --dialect
postgresql --out <tmpdir>` and pipe the SQL into `docker exec -i date-pg psql -U postgres
-d date` (`drizzle-kit push` hangs through the proxy). To skip the magic link, insert a
`user` row for the allowlisted address and a `session` row, then send
`authjs.session-token=<sessionToken>` as a cookie.

## Releases

Vercel auto-deploys `main`. Bump `package.json` and both `version` fields in
`package-lock.json`, run the gate, commit, `git tag -a vX.Y.Z`, push `main` and the tag.
```

- [ ] **Step 6: Full gate and commit**

Run: `npm run lint && npx tsc --noEmit && npm test && env -u DATABASE_URL npm run build && npm run e2e`
Expected: all pass; the build's route list has no `/dev-kit`.

```bash
git add -A && git commit -m "test: end-to-end flow on desktop and mobile; docs and 404 page

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: Copy review, production deploy and v0.1.0

**Files:**
- Modify: `src/lib/copy.ts` (only if NaNote changes wording), `/project/CLAUDE.md`, `/root/.claude/projects/-project/memory/MEMORY.md`
- Create: `/root/.claude/projects/-project/memory/project_date_deployment.md`

This task creates a GitHub repo, a Vercel project and a Neon database, and puts a page on the public internet. Secrets are never printed: write them to files created under `umask 077` in the session scratchpad and pipe them into the CLI.

- [ ] **Step 1: Copy review — STOP for NaNote**

Show NaNote the full contents of `src/lib/copy.ts` and screenshots of every screen at 390×844 (question, surprised card, all seven form cards, ticket, maybe page). Ask for wording changes. Apply them in `copy.ts` only, update any test in `copy.test.ts` or `e2e/flow.spec.ts` that asserts changed text, rerun the gate, and commit as `chore: copy review`. Do not continue until NaNote approves the copy.

- [ ] **Step 2: Create the private repo and push**

```bash
cd /project/src/date.nanoteofficial.me
gh repo create khantee8/date.nanoteofficial.me --private --source . --remote origin --push
```

Expected: the repo exists and `main` is pushed. Confirm it is private: `gh repo view khantee8/date.nanoteofficial.me --json visibility -q .visibility` prints `PRIVATE`.

- [ ] **Step 3: Create the Vercel project and the database**

```bash
vercel link --yes --project date-nanoteofficial-me
vercel git connect
vercel integration add neon
```

Follow the Neon prompts (free plan, a new database named `date`). Expected afterwards: `vercel env ls` lists `DATABASE_URL` and `DATABASE_URL_UNPOOLED` for Production and Preview.

- [ ] **Step 4: Set the remaining environment variables**

`AUTH_RESEND_KEY` is the key the `cyber` project already uses. Copy it without printing it:

```bash
umask 077
S=<scratchpad>/env && mkdir -p "$S"
(cd /project/src/cyber.nanoteofficial.me && vercel env pull "$S/cyber.env" --environment production --yes >/dev/null)
grep '^AUTH_RESEND_KEY=' "$S/cyber.env" | cut -d= -f2- | tr -d '"\n' > "$S/resend.key"
test -s "$S/resend.key" && echo "key copied"
cd /project/src/date.nanoteofficial.me
for ENV in production preview; do
  vercel env add AUTH_RESEND_KEY "$ENV" < "$S/resend.key"
  openssl rand -base64 33 | tr -d '\n' | vercel env add AUTH_SECRET "$ENV"
  printf 'NaNote <date@nanoteofficial.me>' | vercel env add AUTH_RESEND_FROM "$ENV"
  printf 'khantee9@gmail.com' | vercel env add ALLOWED_EMAILS "$ENV"
  printf 'khantee9@gmail.com' | vercel env add NOTIFY_EMAIL "$ENV"
done
vercel env ls
```

Expected: seven variable names listed for Production (values hidden). If `vercel env pull` on `cyber` returns no `AUTH_RESEND_KEY` (it is marked sensitive), stop and ask NaNote to paste a Resend API key into `vercel env add AUTH_RESEND_KEY production` themselves.

- [ ] **Step 5: Apply the schema to production**

Neon's HTTP endpoint is not reachable from this container, so `drizzle-kit push` does not work here; use generated SQL over the direct connection:

```bash
vercel env pull "$S/date.env" --environment production --yes >/dev/null
URL=$(grep '^DATABASE_URL_UNPOOLED=' "$S/date.env" | cut -d= -f2- | tr -d '"')
OUT=$(mktemp -d) && npx drizzle-kit generate --schema src/db/schema.ts --dialect postgresql --out "$OUT"
cat "$OUT"/*.sql | sed 's/--> statement-breakpoint//' | psql "$URL" -v ON_ERROR_STOP=1
psql "$URL" -c '\dt'
```

Expected: six tables: `account`, `event`, `session`, `submission`, `user`, `verificationToken`.

- [ ] **Step 6: Deploy and bind the domain**

```bash
git commit --allow-empty -m "chore: trigger first production deploy

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" && git push origin main
vercel domains add date.nanoteofficial.me
```

Wait for the deployment (`vercel ls` shows the newest as `Ready`, Production). The domain is on Vercel nameservers, so no DNS record is needed; the explicit binding overrides the portfolio's `*.nanoteofficial.me` wildcard.

- [ ] **Step 7: Verify production**

```bash
B=https://date.nanoteofficial.me
curl -sI $B/ | grep -i -E '^HTTP|x-robots-tag|content-security-policy|strict-transport'
curl -s $B/robots.txt
curl -s -o /dev/null -w '%{http_code} %{redirect_url}\n' $B/admin
curl -s -o /dev/null -w '%{http_code}\n' $B/done/aaaaaaaaaaaaaaaaaaaaa
curl -s $B/ | grep -c 'คุณเอ๊ม'
```

Expected: `200` with `x-robots-tag: noindex, nofollow`, a CSP and HSTS; robots disallows `/`; `/admin` answers `307` to `/signin`; the unknown ticket is `404`; the nickname count is at least 1.

Run one real pass through the live site with the Playwright MCP tools at 390×844: tap No three times, tap Yes, fill the form with restaurant name `TEST - please ignore` and no email, submit. Expected: the ticket page loads at `/done/<id>`, and NaNote receives the "ตอบตกลงแล้ว!" email with `date.ics` attached. Record the id.

Check for errors: use the Vercel MCP `get_runtime_errors` tool (or `vercel logs`) for the production deployment. Expected: none from this pass.

- [ ] **Step 8: NaNote signs in — STOP for NaNote**

Ask NaNote to open `https://date.nanoteofficial.me/signin`, enter `khantee9@gmail.com`, click the emailed link, and confirm `/admin` shows the test submission and its timeline row. Also ask them to open the test ticket on their own phone, scan the QR code, and add the `.ics` to their calendar. Do not continue until they confirm all three work.

- [ ] **Step 9: Remove the test data so her log starts clean**

Only the rows created in Step 7 are removed. Look before deleting:

```bash
psql "$URL" -c "SELECT id, \"visitorId\", \"restaurantName\", \"createdAt\" FROM submission;"
```

Expected: exactly one row, named `TEST - please ignore`. If anything else is there, stop and ask NaNote. Otherwise:

```bash
psql "$URL" -v ON_ERROR_STOP=1 <<'SQL'
BEGIN;
DELETE FROM event WHERE "visitorId" IN (SELECT "visitorId" FROM submission WHERE "restaurantName" = 'TEST - please ignore');
DELETE FROM submission WHERE "restaurantName" = 'TEST - please ignore';
COMMIT;
SELECT (SELECT count(*) FROM submission) AS submissions, (SELECT count(*) FROM event) AS events;
SQL
rm -rf "$S"
```

Expected: `submissions` is 0. `events` may be above 0 if NaNote browsed the site; show NaNote the count and delete those rows only if they say so.

- [ ] **Step 10: Tag the release**

`package.json` already says `0.1.0`.

```bash
git tag -a v0.1.0 -m "v0.1.0 — date invitation: runaway No, details form, ticket with QR and calendar, admin log"
git push origin v0.1.0
```

- [ ] **Step 11: Record the project in the dotfiles repo and memory**

In `/project/CLAUDE.md`, add this section after the `kb.nanoteofficial.me` section:

```markdown
### date.nanoteofficial.me — Date Invitation

**Stack**: Next.js 16 (App Router), React 19, TypeScript, Tailwind v4, Auth.js v5 (Resend magic-link), Neon Postgres + Drizzle, `motion`, Vitest, Playwright
**Repo**: `khantee8/date.nanoteofficial.me` (**private**, personal) · **Live**: https://date.nanoteofficial.me (v0.1.0, 2026-10-06)

    cd /project/src/date.nanoteofficial.me
    npm run dev        # http://localhost:3100
    npm run lint && npx tsc --noEmit && npm test && npm run build
    npm run e2e        # needs the local DB containers date-pg + date-neon-proxy

Single-purpose Thai invitation page: `/` asks the question with an original mascot and a No button that cannot be caught (it gives up after 7 taps on touch devices; a quiet "maybe" link appears after 3), `/plan` collects date, time, restaurant, car, alcohol, pace and an optional email, `/done/[id]` is a ticket with a QR code, `.ics` and Google Calendar link. `/admin` (magic link, `ALLOWED_EMAILS` only) lists submissions and a per-visitor timeline. All Thai copy is in `src/lib/copy.ts`. Not on the tools map (personal). See `src/date.nanoteofficial.me/CLAUDE.md`.
```

Write `/root/.claude/projects/-project/memory/project_date_deployment.md`:

```markdown
---
name: project-date-deployment
description: date.nanoteofficial.me — private date-invitation site, v0.1.0 live 2026-10-06, own Vercel project + Neon, admin magic link for khantee9@gmail.com
metadata:
  type: project
---

date.nanoteofficial.me v0.1.0 went live on 2026-10-06: a private Thai invitation page for คุณเอ๊ม (K.Montira) with an original mascot, a runaway No button, a details form, a QR/.ics ticket and an /admin log. Private repo `khantee8/date.nanoteofficial.me`, own Vercel project and Neon database, Resend key shared with cyber.

**Why:** NaNote wanted to ask her out without flooding her Instagram DMs; she likes the fuzzy cream mascot style, so the page is built around an original character in that style.

**How to apply:** It is personal, so keep it off the public tools map and portfolio. Wording changes go in `src/lib/copy.ts` only. Production schema changes use `drizzle-kit generate` piped to `psql` (the Neon HTTP endpoint is unreachable from this container). Related: [[project-cyber-deployment]], [[project-exam-deployment]].
```

Add this line to `MEMORY.md`:

```markdown
- [date.nanoteofficial.me deployment](project_date_deployment.md) — PRIVATE date-invitation site for คุณเอ๊ม, v0.1.0 live 2026-10-06, own Vercel + Neon, copy lives in src/lib/copy.ts, keep off the tools map
```

Commit the dotfiles change:

```bash
cd /project && git add CLAUDE.md && git commit -m "docs: date.nanoteofficial.me v0.1.0

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Push only if NaNote asks.

- [ ] **Step 12: Hand over**

Tell NaNote: the link to send is `https://date.nanoteofficial.me`; the log is at `/admin`; an email arrives when she submits or taps "ขอคิดดูก่อนนะ"; the local test containers `date-pg` and `date-neon-proxy` are still running and can be stopped with `docker stop date-pg date-neon-proxy`.

---

## Execution notes (2026-10-06)

Executed inline; v0.1.0 tagged and live. Where the shipped code differs from the tasks above:

- **Copy:** after review the page invites her to a meal, not a date, and never names the sender ("ไปกินข้าวกันมั้ย?", event title "นัดกินข้าว", sender name "นัดกินข้าว"). A test in `copy.test.ts` guards this.
- **Added after review:** a "หมาล่า" food tile (first of seven), a save-ticket-as-image button (`src/lib/ticketImage.ts`, `src/lib/wrap.ts`), and the `.ics` is served `inline` so iPhone opens its add-to-calendar sheet.
- **RunawayNo fixes found by the tests:** the tap that makes it give up no longer also counts as Yes (`escapedOnDown` flag instead of the time check); the spot reserves 176 px for the longest label using layout size; x/y are critically damped; once defeated it returns to its home slot.
- **Headlines** carry explicit `\n` breaks (`whitespace-pre-line`) because browsers break Thai mid-word.
- **Tooling:** `.npmrc` has `legacy-peer-deps=true` (npm 10 crashes resolving vitest 4 peers); Playwright runs with `--no-sandbox`; the Playwright MCP browser cannot launch as root, so browser checks used `@playwright/test` scripts.
- **Deploy:** `AUTH_RESEND_KEY` could not be copied from `cyber` (sensitive); the owner added it by hand. `vercel domains add` needs the project name as a second argument.

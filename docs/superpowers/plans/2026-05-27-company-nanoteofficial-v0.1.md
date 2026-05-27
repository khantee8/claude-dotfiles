# company.nanoteofficial.me v0.1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship v0.1 of company.nanoteofficial.me — an isometric 3D pixel-art office showing 5 AI department agents walking around with simulated activity, deployed to production at `company.nanoteofficial.me`.

**Architecture:** Next.js 16 App Router with a single client-side page. HTML5 Canvas renders the isometric office; pure React for the sidebar/terminal/topbar UI. All agent behaviour and terminal logs are simulated client-side for v0.1 (real Claude backend is v0.2). Mirrors the existing `nanoteofficial.me` portfolio site stack.

**Tech Stack:**
- Next.js 16.2.6 (App Router) + React 19
- TypeScript (strict)
- Tailwind CSS v4 (`@tailwindcss/postcss`)
- Vanilla HTML5 Canvas for isometric rendering
- Vitest for unit tests on pure math/state code
- Deploy: Vercel (separate project, same pattern as finance.nanoteofficial.me)

**Reference mockup:** `/project/.superpowers/brainstorm/30611-1779895638/content/iso-office-v2.html` (working vanilla JS reference — port to TypeScript modules).

**Spec:** `docs/superpowers/specs/2026-05-27-company-nanoteofficial-design.md`

---

## File Structure

```
src/company.nanoteofficial.me/
├── package.json
├── tsconfig.json
├── next.config.ts
├── postcss.config.mjs
├── eslint.config.mjs
├── vitest.config.ts
├── .gitignore
├── README.md
├── public/
│   └── favicon.ico
└── src/
    ├── app/
    │   ├── layout.tsx              ← Root layout + metadata
    │   ├── page.tsx                ← Mount OfficeApp
    │   ├── globals.css             ← Tailwind + base styles
    │   ├── robots.ts
    │   └── sitemap.ts
    ├── components/
    │   ├── OfficeApp.tsx           ← Top-level client component, owns shared state
    │   ├── OfficeCanvas.tsx        ← Canvas mount + render loop
    │   ├── DepartmentSidebar.tsx   ← Left dept list + task panel
    │   ├── TerminalFeed.tsx        ← Live log feed
    │   └── TopBar.tsx              ← Top navigation
    └── lib/
        ├── iso/
        │   ├── engine.ts           ← g(), poly(), tile(), box() — pure math/draw
        │   ├── camera.ts           ← Camera pan state + panTo()
        │   ├── room.ts             ← Floor, walls, windows, partitions, labels
        │   ├── furniture.ts        ← All desks, racks, meeting room, break room
        │   ├── lights.ts           ← Ceiling lights with glow cones
        │   └── zoneHighlight.ts    ← Selected zone pulse + agent spotlight
        ├── agents/
        │   ├── sprites.ts          ← SVG sprite strings + loader
        │   ├── Agent.ts            ← Agent class (position, state, draw)
        │   └── behaviours.ts       ← Named waypoints + script runner
        └── data/
            ├── departments.ts      ← Dept config (id, name, color, home pos)
            ├── waypoints.ts        ← Named locations (meeting, coffee, ...)
            └── logMessages.ts      ← Static terminal feed pool
```

---

## Testing Strategy

Visual canvas code is verified manually in the browser. Pure functions get Vitest unit tests:

- `lib/iso/engine.ts` — coordinate transforms (`g()`)
- `lib/iso/camera.ts` — pan target calculation
- `lib/agents/Agent.ts` — state machine transitions (idle ↔ walking ↔ working)

Everything else is verified by running `npm run dev` and looking at the result.

---

## Task 1: Project Scaffold

**Files:**
- Create: `/project/src/company.nanoteofficial.me/package.json`
- Create: `/project/src/company.nanoteofficial.me/tsconfig.json`
- Create: `/project/src/company.nanoteofficial.me/next.config.ts`
- Create: `/project/src/company.nanoteofficial.me/postcss.config.mjs`
- Create: `/project/src/company.nanoteofficial.me/eslint.config.mjs`
- Create: `/project/src/company.nanoteofficial.me/.gitignore`
- Create: `/project/src/company.nanoteofficial.me/README.md`
- Create: `/project/src/company.nanoteofficial.me/src/app/layout.tsx`
- Create: `/project/src/company.nanoteofficial.me/src/app/page.tsx`
- Create: `/project/src/company.nanoteofficial.me/src/app/globals.css`

- [ ] **Step 1: Create project directory and package.json**

```bash
mkdir -p /project/src/company.nanoteofficial.me/src/app
mkdir -p /project/src/company.nanoteofficial.me/src/components
mkdir -p /project/src/company.nanoteofficial.me/src/lib/iso
mkdir -p /project/src/company.nanoteofficial.me/src/lib/agents
mkdir -p /project/src/company.nanoteofficial.me/src/lib/data
mkdir -p /project/src/company.nanoteofficial.me/public
```

Create `/project/src/company.nanoteofficial.me/package.json`:

```json
{
  "name": "company.nanoteofficial.me",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "eslint",
    "test": "vitest run",
    "test:watch": "vitest"
  },
  "dependencies": {
    "next": "16.2.6",
    "react": "19.2.4",
    "react-dom": "19.2.4"
  },
  "devDependencies": {
    "@tailwindcss/postcss": "^4",
    "@types/node": "^20",
    "@types/react": "^19",
    "@types/react-dom": "^19",
    "eslint": "^9",
    "eslint-config-next": "16.2.6",
    "tailwindcss": "^4",
    "typescript": "^5",
    "vitest": "^3"
  },
  "overrides": {
    "postcss": ">=8.5.10"
  }
}
```

- [ ] **Step 2: Create tsconfig.json**

```json
{
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "react-jsx",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
```

- [ ] **Step 3: Create next.config.ts with security headers**

```typescript
import type { NextConfig } from "next";

const securityHeaders = [
  { key: "X-Frame-Options", value: "DENY" },
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=()" },
  { key: "Strict-Transport-Security", value: "max-age=63072000; includeSubDomains; preload" },
  {
    key: "Content-Security-Policy",
    value: [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline'",
      "style-src 'self' 'unsafe-inline'",
      "img-src 'self' data: blob:",
      "font-src 'self'",
      "connect-src 'self'",
      "frame-ancestors 'none'",
    ].join("; "),
  },
];

const nextConfig: NextConfig = {
  poweredByHeader: false,
  async headers() {
    return [{ source: "/:path*", headers: securityHeaders }];
  },
};

export default nextConfig;
```

- [ ] **Step 4: Create postcss.config.mjs**

```javascript
const config = {
  plugins: {
    "@tailwindcss/postcss": {},
  },
};

export default config;
```

- [ ] **Step 5: Create eslint.config.mjs**

```javascript
import { FlatCompat } from "@eslint/eslintrc";

const compat = new FlatCompat({ baseDirectory: import.meta.dirname });

export default [
  ...compat.extends("next/core-web-vitals", "next/typescript"),
];
```

- [ ] **Step 6: Create .gitignore**

```
node_modules
.next
.vercel
*.tsbuildinfo
.DS_Store
```

- [ ] **Step 7: Create README.md**

```markdown
# company.nanoteofficial.me

Live AI company simulator — 5 pixel-art agents working together in an isometric 3D office.

**Live:** https://company.nanoteofficial.me

## Tech Stack
- Next.js 16, React 19, TypeScript
- Tailwind v4
- HTML5 Canvas (isometric engine)
- Vercel

## Scripts
- `npm run dev` — http://localhost:3000
- `npm run build`
- `npm run lint`
- `npm test`
```

- [ ] **Step 8: Create src/app/globals.css**

```css
@import "tailwindcss";

html, body {
  margin: 0;
  padding: 0;
  background: #060610;
  color: #ccc;
  font-family: 'Courier New', monospace;
  overflow: hidden;
  height: 100vh;
}

* { box-sizing: border-box; }
```

- [ ] **Step 9: Create src/app/layout.tsx**

```tsx
import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "NaNote Corp — AI Company Simulator",
  description: "5 AI agents working together in an isometric pixel office. Marketing, R&D, Operations, Finance — coordinated by NaNote CEO.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
```

- [ ] **Step 10: Create src/app/page.tsx (placeholder)**

```tsx
export default function Page() {
  return (
    <main style={{ padding: 24 }}>
      <h1>NaNote Corp — booting agents...</h1>
    </main>
  );
}
```

- [ ] **Step 11: Install dependencies and verify dev server**

```bash
cd /project/src/company.nanoteofficial.me && npm install
```

Then start dev server:
```bash
cd /project/src/company.nanoteofficial.me && npm run dev
```
Expected: server starts on http://localhost:3000, page shows "NaNote Corp — booting agents..."

Kill with Ctrl+C after verifying.

- [ ] **Step 12: Init local git and commit**

```bash
cd /project/src/company.nanoteofficial.me && git init && git add -A
git commit -m "feat: bootstrap Next.js 16 project for company.nanoteofficial.me v0.1"
```

- [ ] **Step 13: Create GitHub repo + push initial commit**

Follows the same pattern as the other NaNote projects (`khantee8/finance.nanoteofficial.me`, `khantee8/nanoteofficial.me`).

```bash
cd /project/src/company.nanoteofficial.me
gh repo create khantee8/company.nanoteofficial.me \
  --public \
  --description "AI Company Simulator — isometric pixel-art office with 5 Claude-powered agents" \
  --source=. \
  --remote=origin \
  --push
```
Expected: GitHub repo created at https://github.com/khantee8/company.nanoteofficial.me with the initial commit pushed.

Verify with:
```bash
gh repo view khantee8/company.nanoteofficial.me --json url,name,isPrivate
```

---

## Task 2: Static Data + Sprite Definitions

**Files:**
- Create: `src/company.nanoteofficial.me/src/lib/data/departments.ts`
- Create: `src/company.nanoteofficial.me/src/lib/data/waypoints.ts`
- Create: `src/company.nanoteofficial.me/src/lib/data/logMessages.ts`
- Create: `src/company.nanoteofficial.me/src/lib/agents/sprites.ts`

- [ ] **Step 1: Create departments.ts**

```typescript
// src/lib/data/departments.ts
export type DeptId = 'ceo' | 'mkt' | 'rnd' | 'ops' | 'fin';

export interface Department {
  id: DeptId;
  name: string;
  shortName: string;
  color: string;
  homeX: number;
  homeY: number;
  task: string;
}

export const DEPARTMENTS: Department[] = [
  { id: 'ceo', name: 'NaNote CEO',  shortName: 'NaNote', color: '#ffdd57', homeX: 1.6,  homeY: 2.5, task: '● directing team' },
  { id: 'mkt', name: 'Marketing',   shortName: 'MKT',    color: '#ff6b9d', homeX: 5.2,  homeY: 2.5, task: '● posting content' },
  { id: 'rnd', name: 'R&D Lab',     shortName: 'R&D',    color: '#00cfff', homeX: 9.5,  homeY: 2.5, task: '○ idle' },
  { id: 'ops', name: 'Operations',  shortName: 'OPS',    color: '#ff9a3c', homeX: 14.8, homeY: 2.8, task: '● deploying v1.3' },
  { id: 'fin', name: 'Finance',     shortName: 'FIN',    color: '#7f8cff', homeX: 18.4, homeY: 2.2, task: '● analyzing ROI' },
];

export const DEPT_ZONE_BOUNDS: Record<DeptId, { x0: number; y0: number; x1: number; y1: number; gx: number; gy: number }> = {
  ceo: { x0: 0.1,  y0: 0.1, x1: 3.8,  y1: 3.8, gx: 1.8,  gy: 1.8 },
  mkt: { x0: 4.1,  y0: 0.1, x1: 7.8,  y1: 3.8, gx: 5.5,  gy: 1.8 },
  rnd: { x0: 8.1,  y0: 0.1, x1: 12.8, y1: 3.8, gx: 10.2, gy: 1.8 },
  ops: { x0: 13.1, y0: 0.1, x1: 16.8, y1: 3.8, gx: 14.8, gy: 2.0 },
  fin: { x0: 17.1, y0: 0.1, x1: 19.8, y1: 3.8, gx: 18.2, gy: 1.8 },
};
```

- [ ] **Step 2: Create waypoints.ts**

```typescript
// src/lib/data/waypoints.ts
export const WAYPOINTS = {
  MEETING:    { x: 10,   y: 7   },
  COFFEE:     { x: 17.2, y: 7   },
  WHITEBOARD: { x: 10,   y: 0.9 },
  SERVER_RACK:{ x: 14.0, y: 0.9 },
};
```

- [ ] **Step 3: Create logMessages.ts (structured tokens — no HTML strings)**

```typescript
// src/lib/data/logMessages.ts
import type { DeptId } from './departments';

/** Discriminated-union token — rendered as React spans (no innerHTML). */
export type LogToken =
  | { type: 'text'; value: string }
  | { type: 'ok';   value: string }
  | { type: 'warn'; value: string };

export interface LogMessage {
  dept: DeptId;
  tokens: LogToken[];
}

const t   = (value: string): LogToken => ({ type: 'text', value });
const ok  = (value: string): LogToken => ({ type: 'ok',   value });
const wn  = (value: string): LogToken => ({ type: 'warn', value });

export const LOG_MESSAGES: LogMessage[] = [
  { dept: 'ceo', tokens: [t('Session started — '),                         ok('5 agents online ✓')] },
  { dept: 'ceo', tokens: [t('Dispatching weekly brief → '),                ok('all departments')] },
  { dept: 'mkt', tokens: [t('generate_content.py '),                       ok('started')] },
  { dept: 'fin', tokens: [t('Market pull — '),                             wn('BTCUSDT +3.2% ▲')] },
  { dept: 'ops', tokens: [t('Deploy pipeline: '),                          ok('████████░░ 82%')] },
  { dept: 'rnd', tokens: [t('Waiting CEO approval on proposal #7...')] },
  { dept: 'mkt', tokens: [t('Content ready → '),                           ok('/output/post_today.md ✓')] },
  { dept: 'fin', tokens: [t('Portfolio → '),                               ok('report.pdf generated ✓')] },
  { dept: 'ops', tokens: [t('Deploy: '),                                   ok('finance.nanoteofficial.me v1.3.2 ✓')] },
  { dept: 'ceo', tokens: [t('R&D proposal #7 '),                           ok('approved ✓')] },
  { dept: 'rnd', tokens: [t('Starting '),                                  ok('market_analysis_v2.py')] },
  { dept: 'mkt', tokens: [t('Published → '),                               ok('Twitter, LinkedIn, Instagram ✓')] },
  { dept: 'fin', tokens: [t('Q2 archived → '),                             ok('ROI +12.3% ✓')] },
  { dept: 'ops', tokens: [t('Watchtower: 3 containers updated → '),        ok('healthy ✓')] },
  { dept: 'rnd', tokens: [t('Model accuracy: '),                           ok('94.7%'), t(' — submitted')] },
  { dept: 'ceo', tokens: [t('All nominal. '),                              ok('Next review: 4h.')] },
];

/** Flat plain-text representation — used for sidebar task text + accessibility. */
export function tokensToPlain(tokens: LogToken[]): string {
  return tokens.map(t => t.value).join('');
}
```

- [ ] **Step 4: Create sprites.ts (structured rect data — no HTML strings)**

```typescript
// src/lib/agents/sprites.ts
import type { DeptId } from '../data/departments';

/** One pixel-art rectangle on a 9-wide grid. */
export interface PixelRect {
  x: number; y: number; w: number; h: number; fill: string;
}

/** Sprite data per dept — typed structured data, no HTML strings. */
const SPRITE_DATA: Record<DeptId, PixelRect[]> = {
  ceo: [
    { x: 2, y: 0, w: 1, h: 1, fill: '#ffdd57' }, { x: 4, y: 0, w: 1, h: 1, fill: '#ffdd57' }, { x: 6, y: 0, w: 1, h: 1, fill: '#ffdd57' },
    { x: 1, y: 1, w: 7, h: 1, fill: '#ffaa00' },
    { x: 1, y: 2, w: 7, h: 3, fill: '#f5c5a3' }, { x: 2, y: 3, w: 1, h: 1, fill: '#222' }, { x: 6, y: 3, w: 1, h: 1, fill: '#222' }, { x: 3, y: 4, w: 3, h: 1, fill: '#c0785a' },
    { x: 1, y: 5, w: 7, h: 4, fill: '#1a1a3e' }, { x: 4, y: 5, w: 1, h: 4, fill: '#7f8cff' },
    { x: 0, y: 5, w: 1, h: 3, fill: '#1a1a3e' }, { x: 8, y: 5, w: 1, h: 3, fill: '#1a1a3e' },
    { x: 0, y: 8, w: 1, h: 1, fill: '#f5c5a3' }, { x: 8, y: 8, w: 1, h: 1, fill: '#f5c5a3' },
    { x: 2, y: 9, w: 2, h: 2, fill: '#0d0d2e' }, { x: 5, y: 9, w: 2, h: 2, fill: '#0d0d2e' },
    { x: 1, y: 10, w: 3, h: 1, fill: '#111' }, { x: 5, y: 10, w: 3, h: 1, fill: '#111' },
  ],
  mkt: [
    { x: 1, y: 0, w: 7, h: 2, fill: '#ff6b9d' },
    { x: 0, y: 2, w: 1, h: 3, fill: '#555' }, { x: 8, y: 2, w: 1, h: 3, fill: '#555' }, { x: 0, y: 3, w: 1, h: 1, fill: '#ff6b9d' },
    { x: 1, y: 2, w: 7, h: 3, fill: '#ffd1a3' }, { x: 2, y: 3, w: 1, h: 1, fill: '#222' }, { x: 6, y: 3, w: 1, h: 1, fill: '#222' }, { x: 3, y: 4, w: 3, h: 1, fill: '#e8a090' },
    { x: 1, y: 5, w: 7, h: 4, fill: '#ff6b9d' }, { x: 0, y: 5, w: 1, h: 3, fill: '#ff6b9d' }, { x: 8, y: 5, w: 1, h: 3, fill: '#ff6b9d' },
    { x: 4, y: 6, w: 1, h: 2, fill: '#fff' }, { x: 3, y: 7, w: 3, h: 1, fill: '#fff' },
    { x: 0, y: 8, w: 1, h: 1, fill: '#ffd1a3' }, { x: 8, y: 8, w: 1, h: 1, fill: '#ffd1a3' },
    { x: 2, y: 9, w: 2, h: 2, fill: '#333' }, { x: 5, y: 9, w: 2, h: 2, fill: '#333' },
    { x: 1, y: 10, w: 3, h: 1, fill: '#222' }, { x: 5, y: 10, w: 3, h: 1, fill: '#222' },
  ],
  rnd: [
    { x: 1, y: 0, w: 7, h: 2, fill: '#aaa' },
    { x: 0, y: 2, w: 9, h: 1, fill: '#555' },
    { x: 1, y: 2, w: 7, h: 3, fill: '#ffe0b2' },
    { x: 1, y: 3, w: 3, h: 1, fill: '#00cfff44' }, { x: 5, y: 3, w: 3, h: 1, fill: '#00cfff44' }, { x: 4, y: 3, w: 1, h: 1, fill: '#666' },
    { x: 2, y: 3, w: 1, h: 1, fill: '#222' }, { x: 6, y: 3, w: 1, h: 1, fill: '#222' }, { x: 3, y: 4, w: 3, h: 1, fill: '#c09070' },
    { x: 1, y: 5, w: 7, h: 4, fill: '#dde0f0' }, { x: 0, y: 5, w: 1, h: 3, fill: '#dde0f0' }, { x: 8, y: 5, w: 1, h: 3, fill: '#dde0f0' },
    { x: 2, y: 6, w: 2, h: 2, fill: '#00cfff' },
    { x: 0, y: 8, w: 1, h: 1, fill: '#ffe0b2' }, { x: 8, y: 8, w: 1, h: 1, fill: '#ffe0b2' },
    { x: 2, y: 9, w: 2, h: 2, fill: '#444' }, { x: 5, y: 9, w: 2, h: 2, fill: '#444' },
    { x: 1, y: 10, w: 3, h: 1, fill: '#222' }, { x: 5, y: 10, w: 3, h: 1, fill: '#222' },
  ],
  ops: [
    { x: 1, y: 0, w: 7, h: 1, fill: '#ff9a3c' }, { x: 0, y: 1, w: 9, h: 1, fill: '#ffaa00' },
    { x: 1, y: 2, w: 7, h: 3, fill: '#f5c5a3' }, { x: 2, y: 3, w: 1, h: 1, fill: '#222' }, { x: 6, y: 3, w: 1, h: 1, fill: '#222' }, { x: 3, y: 4, w: 3, h: 1, fill: '#c0785a' },
    { x: 1, y: 5, w: 7, h: 4, fill: '#ff9a3c' }, { x: 0, y: 5, w: 1, h: 3, fill: '#ff9a3c' }, { x: 8, y: 5, w: 1, h: 3, fill: '#ff9a3c' },
    { x: 1, y: 8, w: 7, h: 1, fill: '#5a3010' },
    { x: 0, y: 8, w: 1, h: 1, fill: '#f5c5a3' }, { x: 8, y: 8, w: 1, h: 1, fill: '#f5c5a3' },
    { x: 2, y: 9, w: 2, h: 2, fill: '#e8890a' }, { x: 5, y: 9, w: 2, h: 2, fill: '#e8890a' },
    { x: 1, y: 10, w: 3, h: 1, fill: '#333' }, { x: 5, y: 10, w: 3, h: 1, fill: '#333' },
  ],
  fin: [
    { x: 2, y: 0, w: 5, h: 2, fill: '#4a4a6a' },
    { x: 1, y: 2, w: 7, h: 3, fill: '#f5c5a3' }, { x: 2, y: 3, w: 1, h: 1, fill: '#222' }, { x: 6, y: 3, w: 1, h: 1, fill: '#222' }, { x: 3, y: 4, w: 3, h: 1, fill: '#c0785a' },
    { x: 1, y: 5, w: 7, h: 4, fill: '#2a2a5e' }, { x: 0, y: 5, w: 1, h: 3, fill: '#2a2a5e' }, { x: 8, y: 5, w: 1, h: 3, fill: '#2a2a5e' },
    { x: 4, y: 5, w: 1, h: 4, fill: '#7f8cff' }, { x: 3, y: 6, w: 3, h: 1, fill: '#7f8cff' }, { x: 3, y: 7, w: 3, h: 1, fill: '#7f8cff' },
    { x: 0, y: 8, w: 1, h: 1, fill: '#f5c5a3' }, { x: 8, y: 8, w: 1, h: 1, fill: '#f5c5a3' },
    { x: 2, y: 9, w: 2, h: 2, fill: '#1a1a3e' }, { x: 5, y: 9, w: 2, h: 2, fill: '#1a1a3e' },
    { x: 1, y: 10, w: 3, h: 1, fill: '#111' }, { x: 5, y: 10, w: 3, h: 1, fill: '#111' },
  ],
};

export const SPRITE_WIDTH = 36;
export const SPRITE_HEIGHT = 44;
export const SPRITE_VIEWBOX_W = 9;
export const SPRITE_VIEWBOX_H = 11;

export type SpriteMap = Partial<Record<DeptId, HTMLImageElement>>;

/** Get raw rect data — used by React components to render <svg><rect/>...</svg>. */
export function getSpriteRects(id: DeptId): PixelRect[] {
  return SPRITE_DATA[id];
}

/** Serialize rects to SVG string — used internally for Image loading. Not exported as innerHTML. */
function rectsToSvgString(rects: PixelRect[]): string {
  const inner = rects.map(r =>
    `<rect x="${r.x}" y="${r.y}" width="${r.w}" height="${r.h}" fill="${r.fill}"/>`
  ).join('');
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${SPRITE_WIDTH}" height="${SPRITE_HEIGHT}" viewBox="0 0 ${SPRITE_VIEWBOX_W} ${SPRITE_VIEWBOX_H}">${inner}</svg>`;
}

/** Loads all 5 sprites as HTMLImageElement (for canvas drawImage). */
export function loadSprites(): Promise<SpriteMap> {
  const ids = Object.keys(SPRITE_DATA) as DeptId[];
  return Promise.all(
    ids.map(id => new Promise<[DeptId, HTMLImageElement]>(res => {
      const img = new Image();
      const svg = rectsToSvgString(SPRITE_DATA[id]);
      img.onload  = () => res([id, img]);
      img.onerror = () => res([id, img]);
      img.src = 'data:image/svg+xml,' + encodeURIComponent(svg);
    }))
  ).then(entries => Object.fromEntries(entries) as SpriteMap);
}
```

- [ ] **Step 5: Commit**

```bash
cd /project/src/company.nanoteofficial.me
git add src/lib/data src/lib/agents/sprites.ts
git commit -m "feat: add department data, waypoints, log messages, and sprite definitions"
```

---

## Task 3: Isometric Engine + Camera (with tests)

**Files:**
- Create: `src/company.nanoteofficial.me/src/lib/iso/engine.ts`
- Create: `src/company.nanoteofficial.me/src/lib/iso/camera.ts`
- Create: `src/company.nanoteofficial.me/src/lib/iso/engine.test.ts`
- Create: `src/company.nanoteofficial.me/src/lib/iso/camera.test.ts`
- Create: `src/company.nanoteofficial.me/vitest.config.ts`

- [ ] **Step 1: Create vitest.config.ts**

```typescript
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'jsdom',
    globals: true,
  },
});
```

- [ ] **Step 2: Install vitest test deps**

```bash
cd /project/src/company.nanoteofficial.me
npm install -D vitest jsdom @types/jsdom
```

- [ ] **Step 3: Write engine tests first (TDD)**

Create `src/lib/iso/engine.test.ts`:

```typescript
import { describe, it, expect, beforeEach } from 'vitest';
import { createEngine, type IsoEngine } from './engine';

describe('IsoEngine', () => {
  let engine: IsoEngine;
  beforeEach(() => {
    engine = createEngine();
    engine.setLayout({ canvasWidth: 1000, canvasHeight: 600, wallH: 68 });
  });

  it('places grid origin (0,0,0) at expected screen coords', () => {
    const p = engine.g(0, 0, 0);
    expect(p.x).toBe(engine.OX);
    expect(p.y).toBe(engine.OY);
  });

  it('moves +x to the screen right and down', () => {
    const a = engine.g(0, 0, 0);
    const b = engine.g(1, 0, 0);
    expect(b.x).toBeGreaterThan(a.x);
    expect(b.y).toBeGreaterThan(a.y);
  });

  it('moves +y to the screen left and down', () => {
    const a = engine.g(0, 0, 0);
    const b = engine.g(0, 1, 0);
    expect(b.x).toBeLessThan(a.x);
    expect(b.y).toBeGreaterThan(a.y);
  });

  it('subtracts pz (height) from y so things lift off the floor', () => {
    const floor = engine.g(0, 0, 0);
    const high  = engine.g(0, 0, 20);
    expect(high.y).toBe(floor.y - 20);
  });

  it('applies camera offset', () => {
    engine.setCam(50, 30);
    const p = engine.g(0, 0, 0);
    expect(p.x).toBe(engine.OX + 50);
    expect(p.y).toBe(engine.OY + 30);
  });
});
```

- [ ] **Step 4: Run tests — expected to fail**

```bash
cd /project/src/company.nanoteofficial.me && npx vitest run src/lib/iso/engine.test.ts
```
Expected: FAIL — module not found.

- [ ] **Step 5: Create engine.ts implementation**

```typescript
// src/lib/iso/engine.ts
export const ROOM_W = 20;
export const ROOM_D = 14;
export const WALL_H = 68;

export interface Point { x: number; y: number; }

export interface IsoEngine {
  /** Tile width in pixels (full width of a diamond). */
  TW: number;
  /** Tile height in pixels (full height of a diamond). */
  TH: number;
  /** Origin X — screen pixel where grid (0,0) lives. */
  OX: number;
  /** Origin Y — screen pixel where grid (0,0) lives. */
  OY: number;

  /** Grid (gx, gy, pz_height) → screen point. */
  g(gx: number, gy: number, pz?: number): Point;

  /** Set camera offset (added to every g() result). */
  setCam(camX: number, camY: number): void;
  /** Current camera offset. */
  getCam(): Point;

  /** Recompute tile sizes + origin based on canvas + wall height. */
  setLayout(params: { canvasWidth: number; canvasHeight: number; wallH: number }): void;

  /** Painter helpers (Canvas2D required). */
  attachContext(ctx: CanvasRenderingContext2D): void;
  poly(pts: Point[], fill?: string | null, stroke?: string | null): void;
  tile(gx: number, gy: number, fill: string): void;
  box(gx: number, gy: number, pz: number, gw: number, gd: number, ph: number, topC: string | null, rightC: string | null, leftC: string | null): void;
}

export function createEngine(): IsoEngine {
  let TW = 56, TH = 28;
  let OX = 0, OY = 0;
  let camX = 0, camY = 0;
  let ctx: CanvasRenderingContext2D | null = null;

  const engine: IsoEngine = {
    get TW() { return TW; },
    get TH() { return TH; },
    get OX() { return OX; },
    get OY() { return OY; },

    g(gx, gy, pz = 0) {
      return {
        x: OX + (gx - gy) * (TW / 2) + camX,
        y: OY + (gx + gy) * (TH / 2) - pz + camY,
      };
    },

    setCam(x, y) { camX = x; camY = y; },
    getCam() { return { x: camX, y: camY }; },

    setLayout({ canvasWidth, canvasHeight, wallH }) {
      const scW = (canvasWidth * 2) / (ROOM_W + ROOM_D);
      const scH = ((canvasHeight - wallH - 24) * 2) / (ROOM_W + ROOM_D);
      TH = Math.min(30, Math.max(14, Math.floor(Math.min(scW / 2, scH))));
      TW = TH * 2;
      OX = canvasWidth / 2 - ((ROOM_W - ROOM_D) * TW) / 4;
      OY = wallH + 18;
    },

    attachContext(c) { ctx = c; },

    poly(pts, fill, stroke) {
      if (!ctx || pts.length === 0) return;
      ctx.beginPath();
      ctx.moveTo(pts[0].x, pts[0].y);
      for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i].x, pts[i].y);
      ctx.closePath();
      if (fill)   { ctx.fillStyle = fill; ctx.fill(); }
      if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = 0.5; ctx.stroke(); }
    },

    tile(gx, gy, fill) {
      engine.poly([engine.g(gx, gy), engine.g(gx + 1, gy), engine.g(gx + 1, gy + 1), engine.g(gx, gy + 1)], fill, 'rgba(0,0,0,0.2)');
    },

    box(gx, gy, pz, gw, gd, ph, topC, rightC, leftC) {
      const A = engine.g(gx, gy, pz + ph);
      const B = engine.g(gx + gw, gy, pz + ph);
      const C = engine.g(gx + gw, gy + gd, pz + ph);
      const D = engine.g(gx, gy + gd, pz + ph);
      const B0 = engine.g(gx + gw, gy, pz);
      const C0 = engine.g(gx + gw, gy + gd, pz);
      const D0 = engine.g(gx, gy + gd, pz);
      if (rightC) engine.poly([B, C, C0, B0], rightC, 'rgba(0,0,0,0.25)');
      if (leftC)  engine.poly([D, C, C0, D0], leftC, 'rgba(0,0,0,0.2)');
      if (topC)   engine.poly([A, B, C, D], topC, 'rgba(0,0,0,0.12)');
    },
  };
  return engine;
}

/** Brighten a #rrggbb hex by `a` per channel and return rgb() string. */
export function lighten(hex: string, a: number): string {
  const r = Math.min(255, parseInt(hex.slice(1, 3), 16) + a);
  const g = Math.min(255, parseInt(hex.slice(3, 5), 16) + a);
  const b = Math.min(255, parseInt(hex.slice(5, 7), 16) + a);
  return `rgb(${r},${g},${b})`;
}

/** Rounded rect path helper. */
export function roundRect(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y); ctx.quadraticCurveTo(x + w, y, x + w, y + r);
  ctx.lineTo(x + w, y + h - r); ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  ctx.lineTo(x + r, y + h); ctx.quadraticCurveTo(x, y + h, x, y + h - r);
  ctx.lineTo(x, y + r); ctx.quadraticCurveTo(x, y, x + r, y);
  ctx.closePath();
}
```

- [ ] **Step 6: Run engine tests — expected to pass**

```bash
cd /project/src/company.nanoteofficial.me && npx vitest run src/lib/iso/engine.test.ts
```
Expected: 5 passing tests.

- [ ] **Step 7: Write camera tests**

Create `src/lib/iso/camera.test.ts`:

```typescript
import { describe, it, expect, beforeEach } from 'vitest';
import { createCamera, type Camera } from './camera';
import { createEngine, type IsoEngine } from './engine';

describe('Camera', () => {
  let engine: IsoEngine;
  let cam: Camera;
  beforeEach(() => {
    engine = createEngine();
    engine.setLayout({ canvasWidth: 1000, canvasHeight: 600, wallH: 68 });
    cam = createCamera(engine);
  });

  it('starts at origin', () => {
    expect(cam.getTarget()).toEqual({ x: 0, y: 0 });
  });

  it('panTo computes target so dept center sits at canvas midpoint', () => {
    cam.panTo({ gx: 10, gy: 2 }, 1000, 600 - 106);
    const tgt = cam.getTarget();
    // Raw screen pos of (10,2) WITHOUT cam:
    const rawX = engine.OX + (10 - 2) * (engine.TW / 2);
    const rawY = engine.OY + (10 + 2) * (engine.TH / 2);
    expect(tgt.x).toBe(500 - rawX);
    expect(tgt.y).toBe((600 - 106) / 2 - rawY);
  });

  it('reset returns target to origin', () => {
    cam.panTo({ gx: 5, gy: 5 }, 800, 500);
    cam.reset();
    expect(cam.getTarget()).toEqual({ x: 0, y: 0 });
  });

  it('update lerps current toward target', () => {
    cam.panTo({ gx: 0, gy: 0 }, 0, 0); // target (-OX, -OY)
    const start = cam.getCurrent();
    cam.update();
    const after = cam.getCurrent();
    // After one update, current should have moved closer (not equal) to target
    expect(after.x).not.toBe(start.x);
  });
});
```

- [ ] **Step 8: Run camera tests — expected to fail**

```bash
cd /project/src/company.nanoteofficial.me && npx vitest run src/lib/iso/camera.test.ts
```
Expected: FAIL — module not found.

- [ ] **Step 9: Create camera.ts**

```typescript
// src/lib/iso/camera.ts
import type { IsoEngine, Point } from './engine';

export interface Camera {
  /** Smoothly lerp current toward target — call once per frame. */
  update(): void;
  /** Snap target to whatever brings (gx, gy) under (centerScreenX, centerScreenY). */
  panTo(g: { gx: number; gy: number }, centerScreenX: number, centerScreenY: number): void;
  reset(): void;
  getCurrent(): Point;
  getTarget(): Point;
  /** Wires updated current values into the engine. Call after update(). */
  apply(): void;
}

const LERP = 0.07;

export function createCamera(engine: IsoEngine): Camera {
  let curX = 0, curY = 0;
  let tgtX = 0, tgtY = 0;

  return {
    update() {
      curX += (tgtX - curX) * LERP;
      curY += (tgtY - curY) * LERP;
    },
    panTo(g, centerScreenX, centerScreenY) {
      const rawX = engine.OX + (g.gx - g.gy) * (engine.TW / 2);
      const rawY = engine.OY + (g.gx + g.gy) * (engine.TH / 2);
      tgtX = centerScreenX - rawX;
      tgtY = centerScreenY - rawY;
    },
    reset() { tgtX = 0; tgtY = 0; },
    getCurrent() { return { x: curX, y: curY }; },
    getTarget()  { return { x: tgtX, y: tgtY }; },
    apply() { engine.setCam(curX, curY); },
  };
}
```

- [ ] **Step 10: Run all tests — expected to pass**

```bash
cd /project/src/company.nanoteofficial.me && npm test
```
Expected: all tests pass.

- [ ] **Step 11: Commit**

```bash
cd /project/src/company.nanoteofficial.me
git add vitest.config.ts package.json package-lock.json src/lib/iso
git commit -m "feat: add isometric engine + camera with unit tests"
```

---

## Task 4: Room Drawing (floor, walls, windows, labels)

**Files:**
- Create: `src/company.nanoteofficial.me/src/lib/iso/room.ts`

- [ ] **Step 1: Create room.ts**

```typescript
// src/lib/iso/room.ts
import { ROOM_W, ROOM_D, WALL_H, lighten, type IsoEngine, type Point } from './engine';

function zoneColor(x: number, y: number): string {
  if (x < 4 && y < 4) return '#131328';
  if (x < 8 && x >= 4 && y < 4) return '#180e22';
  if (x < 13 && x >= 8 && y < 4) return '#0a1522';
  if (x < 17 && x >= 13 && y < 4) return '#180e08';
  if (x >= 17 && y < 4) return '#0e0c24';
  if (x >= 6 && x < 14 && y >= 5 && y < 9) return '#111020';
  if (x >= 15 && y >= 6 && y < 12) return '#14101a';
  return '#0f0f1e';
}

function rug(engine: IsoEngine, gx: number, gy: number, gw: number, gd: number, color: string) {
  engine.poly(
    [engine.g(gx, gy), engine.g(gx + gw, gy), engine.g(gx + gw, gy + gd), engine.g(gx, gy + gd)],
    color, null,
  );
}

export function drawFloorAndWalls(engine: IsoEngine, ctx: CanvasRenderingContext2D) {
  // Floor (back → front for painter's algorithm)
  for (let y = ROOM_D - 1; y >= 0; y--) {
    for (let x = 0; x < ROOM_W; x++) {
      const base = zoneColor(x, y);
      engine.tile(x, y, (x + y) % 2 === 0 ? base : lighten(base, 5));
    }
  }
  // Zone rugs
  rug(engine, 0.2, 0.2, 3.5, 3.5, 'rgba(100,80,200,0.07)');
  rug(engine, 4.2, 0.2, 3.5, 3.5, 'rgba(220,80,140,0.06)');
  rug(engine, 8.2, 0.2, 4.5, 3.5, 'rgba(0,180,240,0.06)');
  rug(engine, 13.2, 0.2, 3.5, 3.5, 'rgba(240,130,40,0.06)');
  rug(engine, 17.2, 0.2, 2.5, 3.5, 'rgba(120,90,240,0.06)');
  rug(engine, 6.5, 5.4, 7, 3.2, 'rgba(80,60,120,0.09)');
  rug(engine, 15.3, 6.8, 4.2, 4.5, 'rgba(100,60,40,0.07)');

  // Back wall
  for (let x = 0; x < ROOM_W; x++) {
    let wc = '#0e0e22';
    if (x < 4) wc = '#0e0e2c';
    else if (x < 8) wc = '#140a20';
    else if (x < 13) wc = '#0a1222';
    else if (x < 17) wc = '#14100a';
    else wc = '#0e0c26';
    const t0 = engine.g(x, 0, WALL_H), t1 = engine.g(x + 1, 0, WALL_H);
    const b0 = engine.g(x, 0, 0), b1 = engine.g(x + 1, 0, 0);
    engine.poly([t0, t1, b1, b0], wc, 'rgba(0,0,0,0.3)');
    // Skirting board
    engine.poly([engine.g(x, 0, 5), engine.g(x + 1, 0, 5), b1, b0], '#1e1e3e', null);
    // Wall trim
    engine.poly([t0, t1, { x: t1.x, y: t1.y + 1.5 }, { x: t0.x, y: t0.y + 1.5 }], '#3a3a6a', null);
  }
  // Left wall
  for (let y = 0; y < ROOM_D; y++) {
    const t0 = engine.g(0, y, WALL_H), t1 = engine.g(0, y + 1, WALL_H);
    const b0 = engine.g(0, y, 0), b1 = engine.g(0, y + 1, 0);
    engine.poly([t0, t1, b1, b0], '#0c0c1e', 'rgba(0,0,0,0.4)');
    engine.poly([engine.g(0, y, 5), engine.g(0, y + 1, 5), b1, b0], '#1e1e3e', null);
  }
}

export function drawWindows(engine: IsoEngine, ctx: CanvasRenderingContext2D) {
  const wins = [{ gx: 0.8 }, { gx: 5.5 }, { gx: 9.5 }, { gx: 14.0 }];
  wins.forEach(w => {
    const gx = w.gx, pw = 1.6, h0 = 22, h1 = 58;
    const tl = engine.g(gx, 0, h1), tr = engine.g(gx + pw, 0, h1);
    const ml = engine.g(gx, 0, h0), mr = engine.g(gx + pw, 0, h0);
    engine.poly([tl, tr, mr, ml], '#1e3a6e', '#2a4a8e');
    // Frame cross
    const cmx = (tl.x + tr.x) / 2;
    ctx.strokeStyle = '#2a4a8e'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.moveTo(cmx, tl.y); ctx.lineTo(cmx, ml.y); ctx.stroke();
    // Horizontal frame
    const hy1 = (tl.y + ml.y) / 2, hy2 = (tr.y + mr.y) / 2;
    ctx.beginPath(); ctx.moveTo(tl.x, hy1); ctx.lineTo(tr.x, hy2); ctx.stroke();
    // Glow
    const cx = (tl.x + mr.x) / 2, cy = (tl.y + mr.y) / 2 + 10;
    const grd = ctx.createRadialGradient(cx, cy, 0, cx, cy, 40);
    grd.addColorStop(0, 'rgba(100,160,255,0.07)');
    grd.addColorStop(1, 'transparent');
    ctx.fillStyle = grd;
    ctx.fillRect(cx - 50, cy - 50, 100, 100);
  });
  // Left-wall window
  const lt = engine.g(0, 2.5, 55), lb = engine.g(0, 4.0, 55);
  const lbt = engine.g(0, 2.5, 20), lbb = engine.g(0, 4.0, 20);
  engine.poly([lt, lb, lbb, lbt], '#1e3a6e', '#2a4a8e');
}

export function drawZoneLabels(engine: IsoEngine, ctx: CanvasRenderingContext2D) {
  const labels = [
    { t: 'CEO OFFICE', gx: 1.8, gy: 1.8, c: 'rgba(180,160,255,0.4)' },
    { t: 'MARKETING',  gx: 5.5, gy: 1.8, c: 'rgba(255,100,150,0.35)' },
    { t: 'R&D LAB',    gx: 10,  gy: 1.8, c: 'rgba(0,200,255,0.35)' },
    { t: 'OPERATIONS', gx: 14.5,gy: 1.8, c: 'rgba(255,160,60,0.35)' },
    { t: 'FINANCE',    gx: 18.2,gy: 1.8, c: 'rgba(140,110,255,0.35)' },
    { t: 'MEETING',    gx: 9.8, gy: 7.0, c: 'rgba(200,200,255,0.2)' },
    { t: 'BREAK ROOM', gx: 17.5,gy: 9.0, c: 'rgba(200,150,100,0.2)' },
  ];
  ctx.font = 'bold 7px Courier New';
  ctx.textAlign = 'center';
  labels.forEach(l => {
    const p = engine.g(l.gx, l.gy, 1);
    ctx.fillStyle = l.c;
    ctx.fillText(l.t, p.x, p.y);
  });
}
```

- [ ] **Step 2: Commit**

```bash
cd /project/src/company.nanoteofficial.me
git add src/lib/iso/room.ts
git commit -m "feat: add room drawing — floor, walls, windows, zone labels"
```

---

## Task 5: Furniture Drawing

**Files:**
- Create: `src/company.nanoteofficial.me/src/lib/iso/furniture.ts`

- [ ] **Step 1: Create furniture.ts**

```typescript
// src/lib/iso/furniture.ts
import { WALL_H, lighten, type IsoEngine } from './engine';

const DK = ['#6a4820', '#4a3010', '#5a3a18'] as const; // desk wood: top, right, left
const MN = ['#181828', '#0a0a18', '#141420'] as const; // monitor frame

function mon(engine: IsoEngine, gx: number, gy: number, pz: number, glow: string) {
  engine.box(gx, gy, pz, 0.55, 0.08, 16, MN[0], glow, MN[2]);
}

function drawPlant(engine: IsoEngine, ctx: CanvasRenderingContext2D, gx: number, gy: number) {
  engine.box(gx, gy, 0, 0.4, 0.4, 15, '#5a3010', '#3a1a08', '#4a2810');
  const t = engine.g(gx + 0.2, gy + 0.2, 22);
  for (let i = 0; i < 3; i++) {
    const a = (i / 3) * Math.PI * 2;
    const lx2 = t.x + Math.cos(a) * 8;
    const ly2 = t.y + Math.sin(a) * 4;
    ctx.beginPath();
    ctx.arc(lx2, ly2, 9, 0, Math.PI * 2);
    ctx.fillStyle = i === 1 ? '#1a7025' : '#1a6020';
    ctx.fill();
  }
  ctx.beginPath();
  ctx.arc(t.x, t.y, 6, 0, Math.PI * 2);
  ctx.fillStyle = '#1a8030';
  ctx.fill();
}

function drawGlassPartition(engine: IsoEngine, gx: number) {
  for (let yy = 0; yy < 4; yy++) {
    const pt = engine.g(gx, yy, WALL_H * 0.8);
    const pb = engine.g(gx, yy, 0);
    const pt2 = engine.g(gx, yy + 1, WALL_H * 0.8);
    const pb2 = engine.g(gx, yy + 1, 0);
    engine.poly([pt, pt2, pb2, pb], 'rgba(150,180,255,0.08)', 'rgba(100,120,255,0.25)');
  }
}

export function drawFurniture(engine: IsoEngine, ctx: CanvasRenderingContext2D) {
  // ── CEO OFFICE ──
  engine.box(0.1, 0.08, 0, 0.5, 2.8, 50, '#2a1a08', '#1a0e05', '#241508');
  const bookCols = ['#7f8cff', '#ff6b9d', '#00cfff', '#ffdd57', '#ff9a3c'];
  for (let i = 0; i < 4; i++) {
    engine.box(0.12, 0.12 + i * 0.65, i * 10 + 2, 0.26, 0.55, 8, bookCols[i], '#00000044', bookCols[i]);
  }
  engine.box(0.6, 0.4, 0, 2.8, 0.85, 18, DK[0], DK[1], DK[2]);
  engine.box(0.6, 1.25, 0, 1.1, 0.7, 18, DK[0], DK[1], DK[2]);
  mon(engine, 0.8, 0.45, 18, '#7f8cff33');
  mon(engine, 1.55, 0.45, 18, '#ffdd5722');
  engine.box(2.5, 0.45, 18, 0.3, 0.22, 14, '#ffdd57', '#cc9900', '#e6ac00');
  engine.box(2.55, 0.45, 32, 0.2, 0.14, 6, '#ffaa00', '#cc8800', '#ddaa00');
  engine.box(1.8, 2.1, 0, 0.6, 0.5, 10, '#2a2a4e', '#1a1a38', '#222244');
  engine.box(2.5, 2.1, 0, 0.6, 0.5, 10, '#2a2a4e', '#1a1a38', '#222244');
  engine.box(1.2, 1.5, 0, 0.7, 0.55, 12, '#0a0a28', '#060618', '#0e0e32');
  engine.box(3.1, 0.44, 18, 0.3, 0.28, 10, '#3a1a06', '#2a1004', '#322008');
  const pp = engine.g(3.22, 0.55, 30);
  ctx.beginPath(); ctx.arc(pp.x, pp.y, 6, 0, Math.PI * 2); ctx.fillStyle = '#1a6a20'; ctx.fill();

  drawGlassPartition(engine, 3.9);

  // ── MARKETING ──
  engine.box(4.5, 0.04, 0, 2.8, 0.07, 52, '#e0e0f0', '#c0c0d0', null);
  ['#ffdd57', '#ff9a3c', '#7f8cff', '#00cfff'].forEach((c, i) => {
    engine.box(4.6 + i * 0.65, 0.05, 28, 0.5, 0.05, 14, c, lighten(c, -30) as string, null);
  });
  engine.box(4.4, 0.5, 0, 2.2, 0.85, 18, DK[0], DK[1], DK[2]);
  mon(engine, 4.9, 0.55, 18, '#ff6b9d44');
  mon(engine, 5.65, 0.55, 18, '#ff6b9d22');
  engine.box(6.35, 0.5, 18, 0.28, 0.25, 16, '#7f8cff', '#5a5acc', '#6a6add');
  engine.box(5.2, 1.6, 0, 0.7, 0.55, 12, '#1a0a18', '#110810', '#180914');
  ['#ffdd57', '#ff6b9d', '#00cfff'].forEach((c, i) => {
    engine.box(7.0 + i * 0.02, 0.04, 20 + i * 8, 0.5, 0.04, 10, c, lighten(c, -20) as string, null);
  });

  drawGlassPartition(engine, 7.9);

  // ── R&D LAB ──
  engine.box(8.5, 0.04, 0, 4.0, 0.07, 58, '#d4d4ec', '#b4b4cc', null);
  for (let i = 0; i < 4; i++) {
    const p1 = engine.g(8.7 + i * 0.05, 0.06, 46 - i * 10);
    const p2 = engine.g(12.1 + i * 0.05, 0.06, 46 - i * 10);
    ctx.strokeStyle = '#4466cc88'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.moveTo(p1.x, p1.y); ctx.lineTo(p2.x, p2.y); ctx.stroke();
  }
  engine.box(8.4, 0.5, 0, 2.5, 0.85, 18, DK[0], DK[1], DK[2]);
  mon(engine, 8.7, 0.55, 18, '#00cfff44');
  mon(engine, 9.5, 0.55, 18, '#00cfff22');
  engine.box(9.2, 1.6, 0, 0.7, 0.55, 12, '#0a1a22', '#061218', '#0e1820');
  engine.box(10.8, 0.3, 0, 2.6, 0.6, 22, '#3a3a2a', '#2a2a1a', '#323222');
  engine.box(11.0, 0.35, 22, 0.3, 0.25, 18, '#00cfff', '#008bbb', '#00aadd');
  engine.box(11.5, 0.35, 22, 0.25, 0.2, 22, '#ff6b9d', '#cc4070', '#ee5585');
  engine.box(12.0, 0.35, 22, 0.3, 0.25, 14, '#ffdd57', '#cc9900', '#eebb00');
  engine.box(11.8, 0.3, 22, 0.4, 0.35, 8, '#333', '#222', '#2a2a2a');
  engine.box(11.9, 0.3, 30, 0.2, 0.18, 16, '#444', '#333', '#3a3a3a');
  engine.box(13.0, 0.3, 22, 0.3, 0.28, 10, '#3a1a06', '#2a1004', '#322008');
  const rp = engine.g(13.1, 0.4, 34);
  ctx.beginPath(); ctx.arc(rp.x, rp.y, 5, 0, Math.PI * 2); ctx.fillStyle = '#1a7025'; ctx.fill();

  drawGlassPartition(engine, 12.9);

  // ── OPERATIONS ──
  engine.box(13.3, 0.15, 0, 0.9, 0.9, 68, '#111', '#0a0a0a', '#181818');
  for (let i = 0; i < 7; i++) {
    const pL = engine.g(13.74, 0.22, 60 - i * 8);
    const pR = engine.g(14.05, 0.22, 60 - i * 8);
    ctx.fillStyle = i % 2 === 0 ? '#00ff88' : '#7f8cff';
    ctx.beginPath(); ctx.arc(pL.x, pL.y, 1.8, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#ff6b9d';
    ctx.beginPath(); ctx.arc(pR.x, pR.y, 1.4, 0, Math.PI * 2); ctx.fill();
  }
  engine.box(14.4, 0.15, 0, 0.9, 0.9, 68, '#111', '#0a0a0a', '#181818');
  for (let i = 0; i < 7; i++) {
    const p = engine.g(14.83, 0.22, 60 - i * 8);
    ctx.fillStyle = i % 3 === 0 ? '#ffaa00' : '#00ff88';
    ctx.beginPath(); ctx.arc(p.x, p.y, 1.8, 0, Math.PI * 2); ctx.fill();
  }
  engine.box(15.5, 0.2, 0, 0.9, 0.7, 22, '#1a1a1a', '#111', '#222');
  engine.box(13.3, 1.7, 0, 2.8, 0.85, 18, DK[0], DK[1], DK[2]);
  mon(engine, 13.6, 1.75, 18, '#ff9a3c44');
  mon(engine, 14.4, 1.75, 18, '#ff9a3c33');
  mon(engine, 15.1, 1.75, 18, '#00ff8822');
  engine.box(14.5, 2.75, 0, 0.7, 0.55, 12, '#1a0e04', '#110a04', '#18100a');
  engine.box(13.3, 1.1, 0, 2.5, 0.4, 6, '#0a0a0a', '#060606', '#0e0e0e');

  drawGlassPartition(engine, 16.9);

  // ── FINANCE ──
  engine.box(17.2, 0.04, 0, 2.5, 0.07, 52, '#0a0a30', '#050520', null);
  const chartPts = [
    { gx: 17.3, pz: 20 }, { gx: 17.7, pz: 32 }, { gx: 18.1, pz: 26 },
    { gx: 18.5, pz: 42 }, { gx: 18.9, pz: 36 }, { gx: 19.3, pz: 48 },
  ];
  ctx.strokeStyle = '#00ff8899'; ctx.lineWidth = 2;
  ctx.beginPath();
  chartPts.forEach((p, i) => {
    const sp = engine.g(p.gx, 0.05, p.pz);
    if (i === 0) ctx.moveTo(sp.x, sp.y); else ctx.lineTo(sp.x, sp.y);
  });
  ctx.stroke();
  engine.box(17.2, 0.5, 0, 2.5, 0.85, 18, DK[0], DK[1], DK[2]);
  mon(engine, 17.4, 0.55, 18, '#7f8cff55');
  mon(engine, 18.2, 0.55, 18, '#00ff8833');
  engine.box(17.1, 1.55, 0, 0.6, 0.9, 38, '#1a1a3e', '#101028', '#181838');
  engine.box(17.12, 1.57, 12, 0.55, 0.82, 10, '#222244', '#181830', '#1e1e3a');
  engine.box(17.12, 1.57, 24, 0.55, 0.82, 10, '#222244', '#181830', '#1e1e3a');
  const fh = engine.g(17.7, 1.58, 18);
  ctx.fillStyle = '#7f8cff'; ctx.fillRect(fh.x - 3, fh.y - 1, 6, 2);
  engine.box(18.2, 1.6, 0, 0.7, 0.55, 12, '#0a0a2e', '#060618', '#0e0e32');

  // ── MEETING ROOM ──
  engine.box(7.5, 5.04, 0, 5.0, 0.07, 55, '#e4e4fc', '#c4c4dc', null);
  const scrPts = [
    engine.g(8.0, 5.05, 48), engine.g(12.0, 5.05, 48),
    engine.g(12.0, 5.05, 18), engine.g(8.0, 5.05, 18),
  ];
  engine.poly(scrPts, '#0a0a3a', null);
  engine.box(7.2, 5.8, 0, 5.5, 2.2, 22, '#3a2810', '#281808', '#322212');
  const mChairs: [number, number][] = [
    [7.3, 5.3], [8.3, 5.3], [9.3, 5.3], [10.3, 5.3], [11.3, 5.3],
    [7.3, 8.1], [8.3, 8.1], [9.3, 8.1], [10.3, 8.1], [11.3, 8.1],
    [6.6, 6.2], [6.6, 7.1], [12.9, 6.2], [12.9, 7.1],
  ];
  mChairs.forEach(([x, y]) => engine.box(x, y, 0, 0.6, 0.4, 10, '#181830', '#0e0e24', '#14142a'));
  engine.box(9.5, 6.5, 22, 0.5, 0.38, 4, '#333', '#222', '#2a2a2a');
  engine.box(10.5, 6.8, 22, 0.8, 0.45, 2, '#e8e8e8', '#ccc', '#ddd');

  // ── BREAK ROOM ──
  engine.box(15.8, 6.3, 0, 3.7, 0.75, 22, DK[0], DK[1], DK[2]);
  engine.box(16.0, 6.4, 0, 0.7, 0.6, 34, '#111', '#0a0a0a', '#181818');
  engine.box(16.1, 6.45, 34, 0.5, 0.4, 8, '#5a3010', '#3a1a08', '#4a2510');
  const cp = engine.g(16.3, 6.6, 42);
  const cg = ctx.createRadialGradient(cp.x, cp.y - 8, 0, cp.x, cp.y - 8, 20);
  cg.addColorStop(0, 'rgba(90,50,10,0.25)'); cg.addColorStop(1, 'transparent');
  ctx.fillStyle = cg; ctx.fillRect(cp.x - 25, cp.y - 30, 50, 40);
  engine.box(17.0, 6.4, 0, 0.6, 0.6, 44, '#a0c8ee', '#80a8cc', '#90b8dd');
  engine.box(17.1, 6.5, 44, 0.4, 0.38, 8, '#c0dcf0', '#a0c0da', '#b0cce8');
  engine.box(18.0, 6.4, 0, 0.7, 0.65, 44, '#d8d8e8', '#b8b8c8', '#c8c8d8');
  engine.box(18.05, 6.45, 22, 0.6, 0.55, 1, '#aaa', '#888', '#999');
  const fh2 = engine.g(18.72, 6.46, 35);
  ctx.fillStyle = '#888'; ctx.fillRect(fh2.x - 2, fh2.y - 3, 3, 6);
  engine.box(16.0, 8.5, 0, 3.5, 1.1, 24, '#2a1a40', '#1a1030', '#221438');
  engine.box(16.0, 8.5, 24, 3.5, 0.28, 18, '#3a2a56', '#2a1a46', '#32234e');
  engine.box(16.0, 8.5, 0, 0.3, 1.1, 42, '#3a2a56', '#2a1a46', '#32234e');
  engine.box(19.2, 8.5, 0, 0.3, 1.1, 42, '#3a2a56', '#2a1a46', '#32234e');
  ['#7f8cff', '#ff6b9d', '#00cfff'].forEach((c, i) =>
    engine.box(16.4 + i * 0.95, 8.55, 24, 0.75, 0.95, 14, c, lighten(c, -40) as string, lighten(c, -20) as string)
  );
  engine.box(16.8, 9.85, 0, 2.0, 0.8, 12, '#3a2810', '#281808', '#322212');
  engine.box(17.5, 9.9, 12, 0.5, 0.35, 3, '#e8e8f0', '#ccc', '#ddd');

  // ── COMMON / HALLWAY ──
  drawPlant(engine, ctx, 0.1, 13.3);
  drawPlant(engine, ctx, 5.0, 13.3);
  drawPlant(engine, ctx, 9.5, 13.3);
  drawPlant(engine, ctx, 14.0, 13.3);
  drawPlant(engine, ctx, 19.3, 13.3);
  drawPlant(engine, ctx, 0.1, 0.1);
  drawPlant(engine, ctx, 4.0, 3.5);
  drawPlant(engine, ctx, 8.0, 3.5);
  drawPlant(engine, ctx, 13.0, 3.5);
  drawPlant(engine, ctx, 17.0, 3.5);

  engine.box(8.5, 10.5, 0, 3.0, 0.07, 40, '#d0a060', '#a07040', '#b88050');
  ['#ffdd57', '#ff6b9d', '#00cfff', '#7f8cff'].forEach((c, i) =>
    engine.box(8.6 + i * 0.72, 10.52, 22 + i * 2, 0.55, 0.05, 12, c, lighten(c, -30) as string, null)
  );

  // Entrance mat
  engine.poly([engine.g(7, 12.5), engine.g(13, 12.5), engine.g(13, 13.5), engine.g(7, 13.5)], 'rgba(80,60,160,0.2)', null);
  // Reception desk
  engine.box(3.5, 12.8, 0, 3.0, 0.7, 20, DK[0], DK[1], DK[2]);
  engine.box(3.5, 12.8, 20, 3.0, 0.15, 8, '#5a3a18', '#3a2008', '#4a2e10');
}
```

- [ ] **Step 2: Commit**

```bash
cd /project/src/company.nanoteofficial.me
git add src/lib/iso/furniture.ts
git commit -m "feat: add full office furniture — desks, racks, meeting + break rooms"
```

---

## Task 6: Ceiling Lights

**Files:**
- Create: `src/company.nanoteofficial.me/src/lib/iso/lights.ts`

- [ ] **Step 1: Create lights.ts**

```typescript
// src/lib/iso/lights.ts
import { WALL_H, type IsoEngine } from './engine';

export function drawCeilingLights(engine: IsoEngine, ctx: CanvasRenderingContext2D) {
  const lights = [
    { gx: 2, gy: 1.5 }, { gx: 6, gy: 1.5 }, { gx: 10.5, gy: 1.5 }, { gx: 15, gy: 1.5 }, { gx: 18, gy: 1.5 },
    { gx: 4, gy: 5 }, { gx: 9.5, gy: 5 }, { gx: 14, gy: 5 },
    { gx: 17, gy: 9 }, { gx: 5, gy: 10 }, { gx: 10, gy: 10 }, { gx: 15, gy: 10 },
  ];
  lights.forEach(l => {
    const p = engine.g(l.gx, l.gy, WALL_H);
    // Fixture
    ctx.fillStyle = '#f0f0e0';
    ctx.beginPath(); ctx.arc(p.x, p.y, 4, 0, Math.PI * 2); ctx.fill();
    // Glow cone
    const grd = ctx.createRadialGradient(p.x, p.y + 15, 0, p.x, p.y + 15, 90);
    grd.addColorStop(0, 'rgba(255,253,200,0.07)');
    grd.addColorStop(1, 'transparent');
    ctx.fillStyle = grd;
    ctx.fillRect(p.x - 100, p.y - 10, 200, 120);
  });
}
```

- [ ] **Step 2: Commit**

```bash
cd /project/src/company.nanoteofficial.me
git add src/lib/iso/lights.ts
git commit -m "feat: add ceiling lights with glow cones"
```

---

## Task 7: Agent Class + Behaviours (with tests)

**Files:**
- Create: `src/company.nanoteofficial.me/src/lib/agents/Agent.ts`
- Create: `src/company.nanoteofficial.me/src/lib/agents/Agent.test.ts`
- Create: `src/company.nanoteofficial.me/src/lib/agents/behaviours.ts`

- [ ] **Step 1: Write Agent tests first (TDD)**

Create `src/lib/agents/Agent.test.ts`:

```typescript
import { describe, it, expect, beforeEach } from 'vitest';
import { Agent } from './Agent';

describe('Agent', () => {
  let a: Agent;
  beforeEach(() => {
    a = new Agent('ceo', 'NaNote', '#fff', 5, 5);
  });

  it('starts at home position in idle state', () => {
    expect(a.gx).toBe(5);
    expect(a.gy).toBe(5);
    expect(a.state).toBe('idle');
  });

  it('moveTo switches to walking', () => {
    a.moveTo(10, 5);
    expect(a.state).toBe('walking');
    expect(a.tx).toBe(10);
    expect(a.ty).toBe(5);
  });

  it('update moves agent toward target', () => {
    a.moveTo(10, 5);
    const startX = a.gx;
    a.update(0.5);
    expect(a.gx).toBeGreaterThan(startX);
    expect(a.gx).toBeLessThanOrEqual(10);
  });

  it('arrives at target and transitions to arriveState', () => {
    a.moveTo(5.05, 5, 'working');
    a.update(0.5);
    expect(a.gx).toBe(5.05);
    expect(a.state).toBe('working');
  });

  it('goHome resets target to home', () => {
    a.moveTo(10, 5);
    a.update(1);
    a.goHome();
    expect(a.tx).toBe(5);
    expect(a.ty).toBe(5);
  });

  it('say sets bubble with positive life', () => {
    a.say('hi');
    expect(a.bubble).toBe('hi');
    expect(a.bubbleLife).toBeGreaterThan(0);
  });

  it('bubble fades after update', () => {
    a.say('hi', 1000);
    a.update(2);
    expect(a.bubble).toBeNull();
  });

  it('faces left when moving left', () => {
    a = new Agent('ceo', 'NaNote', '#fff', 10, 5);
    a.moveTo(2, 5);
    a.update(0.1);
    expect(a.facingLeft).toBe(true);
  });
});
```

- [ ] **Step 2: Run tests — expected to fail**

```bash
cd /project/src/company.nanoteofficial.me && npx vitest run src/lib/agents/Agent.test.ts
```
Expected: FAIL — module not found.

- [ ] **Step 3: Create Agent.ts**

```typescript
// src/lib/agents/Agent.ts
import type { DeptId } from '../data/departments';
import type { IsoEngine } from '../iso/engine';
import { roundRect } from '../iso/engine';
import { SPRITE_WIDTH, SPRITE_HEIGHT, type SpriteMap } from './sprites';

export type AgentState = 'idle' | 'walking' | 'working';

const SPEED = 2.0; // grid units per second

export class Agent {
  gx: number;
  gy: number;
  readonly homeX: number;
  readonly homeY: number;
  tx: number;
  ty: number;
  state: AgentState = 'idle';
  arriveState: AgentState = 'working';
  walkPhase = Math.random() * Math.PI * 2;
  facingLeft = false;
  bubble: string | null = null;
  bubbleLife = 0;
  t = Math.random() * 100;

  constructor(
    public readonly id: DeptId,
    public readonly name: string,
    public readonly color: string,
    homeX: number,
    homeY: number,
  ) {
    this.gx = homeX; this.gy = homeY;
    this.homeX = homeX; this.homeY = homeY;
    this.tx = homeX; this.ty = homeY;
  }

  moveTo(tx: number, ty: number, arriveState: AgentState = 'working') {
    this.tx = tx;
    this.ty = ty;
    this.arriveState = arriveState;
    this.state = 'walking';
  }

  goHome() { this.moveTo(this.homeX, this.homeY, 'working'); }

  say(msg: string, durationMs = 3500) {
    this.bubble = msg;
    this.bubbleLife = durationMs;
  }

  update(dt: number) {
    this.t += dt;
    if (this.state === 'walking') {
      const dx = this.tx - this.gx;
      const dy = this.ty - this.gy;
      const dist = Math.sqrt(dx * dx + dy * dy);
      if (dist < 0.06) {
        this.gx = this.tx;
        this.gy = this.ty;
        this.state = this.arriveState;
      } else {
        this.gx += (dx / dist) * SPEED * dt;
        this.gy += (dy / dist) * SPEED * dt;
        this.walkPhase += dt * 12;
        if (dx < -0.05) this.facingLeft = true;
        else if (dx > 0.05) this.facingLeft = false;
      }
    }
    if (this.bubbleLife > 0) {
      this.bubbleLife -= dt * 1000;
      if (this.bubbleLife <= 0) this.bubble = null;
    }
  }

  draw(ctx: CanvasRenderingContext2D, engine: IsoEngine, sprites: SpriteMap) {
    const fp = engine.g(this.gx, this.gy, 0);
    const bob = this.state === 'walking'
      ? Math.abs(Math.sin(this.walkPhase)) * 5
      : Math.sin(this.t * 1.5) * 2;

    // Shadow
    ctx.beginPath();
    ctx.ellipse(fp.x, fp.y, 16, 8, 0, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(0,0,0,0.35)';
    ctx.fill();

    const sy = fp.y - SPRITE_HEIGHT - bob;
    const spr = sprites[this.id];
    if (spr && spr.complete) {
      ctx.save();
      ctx.translate(fp.x, 0);
      if (this.facingLeft) ctx.scale(-1, 1);
      ctx.drawImage(spr, -SPRITE_WIDTH / 2, sy, SPRITE_WIDTH, SPRITE_HEIGHT);
      ctx.restore();
    } else {
      // Fallback: colored ellipse
      ctx.beginPath();
      ctx.ellipse(fp.x, fp.y - 20 - bob, 10, 6, 0, 0, Math.PI * 2);
      ctx.fillStyle = this.color;
      ctx.fill();
      ctx.beginPath();
      ctx.arc(fp.x, fp.y - 36 - bob, 8, 0, Math.PI * 2);
      ctx.fillStyle = '#f5c5a3';
      ctx.fill();
    }

    // Name tag
    ctx.font = 'bold 8px Courier New';
    ctx.textAlign = 'center';
    ctx.fillStyle = this.color;
    ctx.fillText(this.name, fp.x, sy - 5);

    // Speech bubble
    if (this.bubble) {
      ctx.font = '8px Courier New';
      const bw = ctx.measureText(this.bubble).width + 14;
      const bh = 14;
      const bx = fp.x - bw / 2;
      const by = sy - 26;
      const alpha = Math.min(1, this.bubbleLife / 600);
      ctx.globalAlpha = alpha;
      ctx.fillStyle = 'rgba(255,255,255,0.96)';
      roundRect(ctx, bx, by, bw, bh, 3);
      ctx.fill();
      ctx.beginPath();
      ctx.moveTo(fp.x - 5, by + bh);
      ctx.lineTo(fp.x + 5, by + bh);
      ctx.lineTo(fp.x, by + bh + 6);
      ctx.closePath();
      ctx.fill();
      ctx.fillStyle = '#111';
      ctx.textAlign = 'center';
      ctx.fillText(this.bubble, fp.x, by + 9);
      ctx.globalAlpha = 1;
    }
  }
}
```

- [ ] **Step 4: Run Agent tests — expected to pass**

```bash
cd /project/src/company.nanoteofficial.me && npx vitest run src/lib/agents/Agent.test.ts
```
Expected: 8 passing tests.

- [ ] **Step 5: Create behaviours.ts**

```typescript
// src/lib/agents/behaviours.ts
import type { Agent } from './Agent';
import type { DeptId } from '../data/departments';
import { WAYPOINTS } from '../data/waypoints';

export interface AgentMap {
  ceo: Agent; mkt: Agent; rnd: Agent; ops: Agent; fin: Agent;
}

/** Returns an array of behaviour script steps. Each step manipulates agents directly. */
export function buildScripts(a: AgentMap): Array<() => void> {
  const { ceo, mkt, rnd, ops, fin } = a;
  const { MEETING, COFFEE, WHITEBOARD, SERVER_RACK } = WAYPOINTS;

  return [
    () => { ceo.moveTo(MEETING.x - 1, MEETING.y); ceo.say('Team standup! 📋'); },
    () => { mkt.moveTo(MEETING.x,     MEETING.y); mkt.say('Campaign ready! 📢'); },
    () => { rnd.moveTo(MEETING.x + 1, MEETING.y); rnd.say('New data! 🔬'); },
    () => { ceo.say('Great work ✓'); },
    () => { ops.say('Deploy done! 🚀'); },
    () => { ceo.goHome(); mkt.goHome(); rnd.goHome(); },
    () => { rnd.moveTo(WHITEBOARD.x, WHITEBOARD.y, 'idle'); rnd.say('Hypothesis!'); },
    () => { rnd.goHome(); },
    () => { fin.moveTo(COFFEE.x, COFFEE.y, 'idle'); fin.say('+12.3% ROI ☕'); },
    () => { fin.goHome(); },
    () => { ops.moveTo(SERVER_RACK.x, SERVER_RACK.y, 'working'); ops.say('Checking rack ⚙️'); },
    () => { ops.goHome(); },
    () => { mkt.moveTo(COFFEE.x - 1, COFFEE.y, 'idle'); mkt.say('Coffee break ✨'); },
    () => { mkt.goHome(); },
    () => { ceo.moveTo(fin.homeX - 1, fin.homeY + 1); ceo.say('Budget review?'); },
    () => { fin.say('ROI up 14%! 📈'); },
    () => { ceo.goHome(); },
    () => { rnd.moveTo(MEETING.x - 1, MEETING.y + 1); rnd.say('Proposal ready 📄'); ceo.moveTo(MEETING.x, MEETING.y + 1); },
    () => { ceo.say('Approved! ✓'); rnd.say('Starting now!'); },
    () => { ceo.goHome(); rnd.goHome(); },
    () => { mkt.moveTo(MEETING.x + 1, MEETING.y - 1); mkt.say('Q2 campaign plan!'); ops.moveTo(MEETING.x + 2, MEETING.y); },
    () => { ops.say('Infra is ready'); },
    () => { mkt.goHome(); ops.goHome(); },
  ];
}

/** Starts a recurring scheduler that runs script steps every 3.5–6s. Returns stop fn. */
export function startBehaviourLoop(a: AgentMap): () => void {
  const scripts = buildScripts(a);
  let i = 0;
  let timeoutId: ReturnType<typeof setTimeout> | null = null;
  const tick = () => {
    scripts[i % scripts.length]();
    i++;
    timeoutId = setTimeout(tick, 3500 + Math.random() * 2500);
  };
  timeoutId = setTimeout(tick, 1500);
  return () => { if (timeoutId) clearTimeout(timeoutId); };
}

/** DeptId list used by AgentMap. */
export const AGENT_IDS: readonly DeptId[] = ['ceo', 'mkt', 'rnd', 'ops', 'fin'] as const;
```

- [ ] **Step 6: Run all tests**

```bash
cd /project/src/company.nanoteofficial.me && npm test
```
Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
cd /project/src/company.nanoteofficial.me
git add src/lib/agents/Agent.ts src/lib/agents/Agent.test.ts src/lib/agents/behaviours.ts
git commit -m "feat: add Agent class with state machine + behaviour script runner"
```

---

## Task 8: Zone Highlight

**Files:**
- Create: `src/company.nanoteofficial.me/src/lib/iso/zoneHighlight.ts`

- [ ] **Step 1: Create zoneHighlight.ts**

```typescript
// src/lib/iso/zoneHighlight.ts
import type { IsoEngine } from './engine';
import type { Agent } from '../agents/Agent';
import { DEPT_ZONE_BOUNDS, type DeptId } from '../data/departments';

export function drawZoneHighlight(
  engine: IsoEngine,
  ctx: CanvasRenderingContext2D,
  selectedDept: DeptId | null,
  agents: Record<DeptId, Agent>,
) {
  if (!selectedDept) return;
  const z = DEPT_ZONE_BOUNDS[selectedDept];
  if (!z) return;

  const now = Date.now();
  const pulse = 0.45 + Math.sin(now * 0.004) * 0.35;
  const color = agents[selectedDept].color;

  const tl = engine.g(z.x0, z.y0, 0);
  const tr = engine.g(z.x1, z.y0, 0);
  const br = engine.g(z.x1, z.y1, 0);
  const bl = engine.g(z.x0, z.y1, 0);

  // Glow fill
  ctx.beginPath();
  ctx.moveTo(tl.x, tl.y);
  ctx.lineTo(tr.x, tr.y);
  ctx.lineTo(br.x, br.y);
  ctx.lineTo(bl.x, bl.y);
  ctx.closePath();
  ctx.fillStyle = color + Math.round(pulse * 26).toString(16).padStart(2, '0');
  ctx.fill();

  // Animated dashed border
  ctx.strokeStyle = color + Math.round(pulse * 255).toString(16).padStart(2, '0');
  ctx.lineWidth = 2.5;
  ctx.setLineDash([8, 4]);
  ctx.lineDashOffset = -(now / 60) % 24;
  ctx.stroke();
  ctx.setLineDash([]);

  // Corner sparkles
  [tl, tr, br, bl].forEach(p => {
    ctx.beginPath();
    ctx.arc(p.x, p.y, 3.5, 0, Math.PI * 2);
    ctx.fillStyle = color;
    ctx.fill();
  });

  // Agent spotlight ring
  const agent = agents[selectedDept];
  if (agent) {
    const ap = engine.g(agent.gx, agent.gy, 0);
    const ringR = 20 + Math.sin(now * 0.006) * 4;
    ctx.beginPath();
    ctx.ellipse(ap.x, ap.y, ringR, ringR / 2, 0, 0, Math.PI * 2);
    ctx.strokeStyle = color + 'cc';
    ctx.lineWidth = 2;
    ctx.stroke();
    const grd = ctx.createRadialGradient(ap.x, ap.y, 0, ap.x, ap.y, ringR);
    grd.addColorStop(0, color + '22');
    grd.addColorStop(1, 'transparent');
    ctx.fillStyle = grd;
    ctx.fill();
  }
}
```

- [ ] **Step 2: Commit**

```bash
cd /project/src/company.nanoteofficial.me
git add src/lib/iso/zoneHighlight.ts
git commit -m "feat: add zone highlight with pulsing border and agent spotlight"
```

---

## Task 9: OfficeCanvas Component

**Files:**
- Create: `src/company.nanoteofficial.me/src/components/OfficeCanvas.tsx`

- [ ] **Step 1: Create OfficeCanvas.tsx**

```tsx
// src/components/OfficeCanvas.tsx
'use client';

import { useEffect, useRef } from 'react';
import { createEngine, WALL_H } from '@/lib/iso/engine';
import { createCamera } from '@/lib/iso/camera';
import { drawFloorAndWalls, drawWindows, drawZoneLabels } from '@/lib/iso/room';
import { drawFurniture } from '@/lib/iso/furniture';
import { drawCeilingLights } from '@/lib/iso/lights';
import { drawZoneHighlight } from '@/lib/iso/zoneHighlight';
import { Agent } from '@/lib/agents/Agent';
import { startBehaviourLoop } from '@/lib/agents/behaviours';
import { loadSprites, type SpriteMap } from '@/lib/agents/sprites';
import { DEPARTMENTS, DEPT_ZONE_BOUNDS, type DeptId } from '@/lib/data/departments';

interface Props {
  selectedDept: DeptId | null;
  terminalHeight: number;
}

export function OfficeCanvas({ selectedDept, terminalHeight }: Props) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const selectedDeptRef = useRef<DeptId | null>(selectedDept);
  selectedDeptRef.current = selectedDept;

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const engine = createEngine();
    const camera = createCamera(engine);
    engine.attachContext(ctx);

    // Create agents
    const agentList = DEPARTMENTS.map(d => new Agent(d.id, d.shortName, d.color, d.homeX, d.homeY));
    const agents = Object.fromEntries(agentList.map(a => [a.id, a])) as Record<DeptId, Agent>;

    const resize = () => {
      const parent = canvas.parentElement;
      if (!parent) return;
      canvas.width = parent.clientWidth;
      canvas.height = parent.clientHeight;
      engine.setLayout({ canvasWidth: canvas.width, canvasHeight: canvas.height, wallH: WALL_H });
      camera.reset();
    };
    resize();
    window.addEventListener('resize', resize);

    let stopBehaviour: (() => void) | null = null;
    let raf: number;
    let last = performance.now();
    let sprites: SpriteMap = {};

    const render = (now: number) => {
      const dt = Math.min((now - last) / 1000, 0.05);
      last = now;
      camera.update();
      camera.apply();
      agentList.forEach(a => a.update(dt));

      ctx.clearRect(0, 0, canvas.width, canvas.height);
      drawCeilingLights(engine, ctx);
      drawFloorAndWalls(engine, ctx);
      drawZoneHighlight(engine, ctx, selectedDeptRef.current, agents);
      drawWindows(engine, ctx);
      drawFurniture(engine, ctx);
      drawZoneLabels(engine, ctx);

      // Depth-sort agents (gx+gy)
      [...agentList].sort((a, b) => (a.gx + a.gy) - (b.gx + b.gy)).forEach(a => a.draw(ctx, engine, sprites));

      raf = requestAnimationFrame(render);
    };

    loadSprites().then(loaded => {
      sprites = loaded;
      stopBehaviour = startBehaviourLoop(agents);
      raf = requestAnimationFrame(render);
    });

    // Pan on selectedDept change
    const handlePan = () => {
      const dept = selectedDeptRef.current;
      if (!dept) {
        camera.reset();
        return;
      }
      const z = DEPT_ZONE_BOUNDS[dept];
      camera.panTo({ gx: z.gx, gy: z.gy }, canvas.width / 2, (canvas.height - terminalHeight) / 2);
    };
    const panInterval = setInterval(handlePan, 200); // re-evaluate target periodically; cheap

    return () => {
      window.removeEventListener('resize', resize);
      if (raf) cancelAnimationFrame(raf);
      if (stopBehaviour) stopBehaviour();
      clearInterval(panInterval);
    };
  }, [terminalHeight]);

  return <canvas ref={canvasRef} style={{ display: 'block', width: '100%', height: '100%' }} />;
}
```

- [ ] **Step 2: Commit**

```bash
cd /project/src/company.nanoteofficial.me
git add src/components/OfficeCanvas.tsx
git commit -m "feat: add OfficeCanvas component — render loop integrating engine + agents"
```

---

## Task 10: DepartmentSidebar Component

**Files:**
- Create: `src/company.nanoteofficial.me/src/components/DepartmentSidebar.tsx`

- [ ] **Step 1: Create DepartmentSidebar.tsx**

```tsx
// src/components/DepartmentSidebar.tsx
'use client';

import { DEPARTMENTS, type DeptId, type Department } from '@/lib/data/departments';
import { getSpriteRects, SPRITE_VIEWBOX_W, SPRITE_VIEWBOX_H } from '@/lib/agents/sprites';

interface Props {
  selectedDept: DeptId | null;
  onSelect: (id: DeptId | null) => void;
  taskTexts: Record<DeptId, string>;
}

export function DepartmentSidebar({ selectedDept, onSelect, taskTexts }: Props) {
  const handleClick = (id: DeptId) => {
    onSelect(selectedDept === id ? null : id);
  };

  const panelTitle = selectedDept
    ? `▸ ${DEPARTMENTS.find(d => d.id === selectedDept)?.name} — Tasks`
    : '▸ Overview — All Tasks';

  return (
    <aside style={sidebarStyle}>
      <div style={titleStyle}>Departments</div>
      {DEPARTMENTS.map((d, idx) => (
        <DeptItem
          key={d.id}
          dept={d}
          index={idx}
          active={selectedDept === d.id}
          taskText={taskTexts[d.id] ?? d.task}
          onClick={() => handleClick(d.id)}
        />
      ))}
      <div style={taskPanelStyle}>
        <div style={taskPanelTitleStyle}>{panelTitle}</div>
        <div style={taskRowStyle}>review_reports.py<span style={runStyle}>running</span></div>
        <div style={taskRowStyle}>dispatch_brief.sh<span style={okStyle}>done ✓</span></div>
        <div style={taskRowStyle}>approve_rnd_7.js<span style={runStyle}>pending</span></div>
        <div style={taskRowStyle}>archive_q2.py<span style={{ color: '#252540' }}>idle</span></div>
      </div>
    </aside>
  );
}

interface ItemProps {
  dept: Department;
  index: number;
  active: boolean;
  taskText: string;
  onClick: () => void;
}

function DeptItem({ dept, index, active, taskText, onClick }: ItemProps) {
  const statusDot = dept.task.startsWith('●') ? '#00ff88' : '#252540';
  const dotBlink = dept.task.startsWith('●') ? 'dp 2s infinite' : 'none';
  const animationDelay = `${index * 0.5}s`;

  return (
    <button
      onClick={onClick}
      style={{
        ...deptStyle,
        ...(active ? activeDeptStyle : {}),
        cursor: 'pointer',
        border: 'none',
        textAlign: 'left',
        width: '100%',
        background: active ? '#0a1a10' : 'transparent',
      }}
    >
      <div style={{ width: 36, height: 40, flexShrink: 0 }}>
        <PixelSprite dept={dept.id} animationDelay={animationDelay} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 10, color: active ? '#00ff88' : '#aaa', fontWeight: 'bold' }}>
          {dept.name}
        </div>
        <div style={{ fontSize: 8, color: active ? '#00ff88' : '#333', marginTop: 2, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
          {taskText}
        </div>
      </div>
      <div style={{ width: 7, height: 7, borderRadius: '50%', background: statusDot, animation: dotBlink, flexShrink: 0 }} />
    </button>
  );
}

/** React-rendered pixel-art sprite (no innerHTML). */
function PixelSprite({ dept, animationDelay }: { dept: DeptId; animationDelay: string }) {
  const rects = getSpriteRects(dept);
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width={36}
      height={40}
      viewBox={`0 0 ${SPRITE_VIEWBOX_W} ${SPRITE_VIEWBOX_H - 1}`}
      style={{ display: 'inline-block', animation: 'bob 2s ease-in-out infinite', animationDelay, imageRendering: 'pixelated' }}
    >
      {rects.map((r, i) => (
        <rect key={i} x={r.x} y={r.y} width={r.w} height={r.h} fill={r.fill} />
      ))}
    </svg>
  );
}

const sidebarStyle: React.CSSProperties = {
  width: 186, minWidth: 186, background: '#0a0a1e',
  borderRight: '1px solid #1a1a3a', display: 'flex',
  flexDirection: 'column', overflow: 'hidden',
};
const titleStyle: React.CSSProperties = {
  fontSize: 8, color: '#2a2a4a', letterSpacing: 2,
  padding: '12px 14px 8px', textTransform: 'uppercase',
  borderBottom: '1px solid #111', flexShrink: 0,
};
const deptStyle: React.CSSProperties = {
  display: 'flex', alignItems: 'center', gap: 10,
  padding: '8px 12px', borderLeft: '3px solid transparent',
  borderBottom: '1px solid #0d0d25', transition: 'all 0.2s',
};
const activeDeptStyle: React.CSSProperties = { borderLeftColor: '#00ff88' };
const taskPanelStyle: React.CSSProperties = {
  flex: 1, padding: '10px 12px', borderTop: '1px solid #0e0e25',
  overflowY: 'auto', minHeight: 0,
};
const taskPanelTitleStyle: React.CSSProperties = {
  fontSize: 8, color: '#7f8cff', letterSpacing: 1, marginBottom: 8,
};
const taskRowStyle: React.CSSProperties = {
  fontSize: 8, color: '#444', padding: '4px 0',
  borderBottom: '1px solid #0d0d20', display: 'flex',
  justifyContent: 'space-between', gap: 4,
};
const okStyle: React.CSSProperties = { color: '#00ff88' };
const runStyle: React.CSSProperties = { color: '#ffaa00' };
```

- [ ] **Step 2: Commit**

```bash
cd /project/src/company.nanoteofficial.me
git add src/components/DepartmentSidebar.tsx
git commit -m "feat: add DepartmentSidebar — pixel-art chars, click-to-focus, task panel"
```

---

## Task 11: TerminalFeed Component

**Files:**
- Create: `src/company.nanoteofficial.me/src/components/TerminalFeed.tsx`

- [ ] **Step 1: Create TerminalFeed.tsx (renders structured tokens — no innerHTML)**

```tsx
// src/components/TerminalFeed.tsx
'use client';

import { useEffect, useRef, useState } from 'react';
import { LOG_MESSAGES, tokensToPlain, type LogMessage, type LogToken } from '@/lib/data/logMessages';
import type { DeptId } from '@/lib/data/departments';

const MAX_LINES = 5;
const TICK_MS = 2800;

interface DisplayedLog {
  time: string;
  dept: DeptId;
  tokens: LogToken[];
  id: number;
}

interface Props {
  onLog?: (dept: DeptId, plainText: string) => void;
}

function nowTime(): string {
  const n = new Date();
  return [n.getHours(), n.getMinutes(), n.getSeconds()]
    .map(v => String(v).padStart(2, '0')).join(':');
}

export function TerminalFeed({ onLog }: Props) {
  const [lines, setLines] = useState<DisplayedLog[]>([]);
  const [clock, setClock] = useState(nowTime());
  const idxRef = useRef(0);
  const idRef = useRef(0);
  const onLogRef = useRef(onLog);
  onLogRef.current = onLog;

  useEffect(() => {
    const addLog = () => {
      const msg: LogMessage = LOG_MESSAGES[idxRef.current % LOG_MESSAGES.length];
      idxRef.current++;
      const id = idRef.current++;
      const log: DisplayedLog = { time: nowTime(), dept: msg.dept, tokens: msg.tokens, id };
      setLines(prev => [...prev.slice(-(MAX_LINES - 1)), log]);
      onLogRef.current?.(msg.dept, tokensToPlain(msg.tokens).slice(0, 28));
    };
    addLog();
    const interval = setInterval(addLog, TICK_MS);
    const clockInterval = setInterval(() => setClock(nowTime()), 1000);
    return () => { clearInterval(interval); clearInterval(clockInterval); };
  }, []);

  return (
    <div style={terminalStyle}>
      <div style={headStyle}>
        ◈ LIVE PIPELINE FEED <span>{clock}</span>
      </div>
      <div style={bodyStyle}>
        <div style={linesStyle}>
          {lines.map((l, i) => {
            const isLast = i === lines.length - 1;
            return (
              <div key={l.id} style={lineStyle}>
                <span style={tsStyle}>{l.time}</span>
                <span style={{ ...tdStyle, color: deptColor(l.dept) }}>[{l.dept.toUpperCase()}]</span>
                <span style={tmStyle}>
                  <TokenSpans tokens={l.tokens} />
                  {isLast && <span style={cursorStyle} />}
                </span>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

/** Render LogToken[] as React spans — type-safe, no innerHTML. */
function TokenSpans({ tokens }: { tokens: LogToken[] }) {
  return (
    <>
      {tokens.map((tok, i) => {
        const color = tok.type === 'ok' ? '#00ff88' : tok.type === 'warn' ? '#ffaa00' : undefined;
        return color
          ? <span key={i} style={{ color }}>{tok.value}</span>
          : <span key={i}>{tok.value}</span>;
      })}
    </>
  );
}

function deptColor(d: DeptId): string {
  return { ceo: '#ffdd57', mkt: '#ff6b9d', rnd: '#00cfff', ops: '#ff9a3c', fin: '#7f8cff' }[d];
}

const terminalStyle: React.CSSProperties = {
  height: 106, minHeight: 106, background: '#060614',
  borderTop: '1px solid #0e0e20', display: 'flex',
  flexDirection: 'column', flexShrink: 0,
};
const headStyle: React.CSSProperties = {
  padding: '4px 14px', fontSize: 8, color: '#2a2a4a',
  letterSpacing: 2, borderBottom: '1px solid #0d0d1e',
  flexShrink: 0, display: 'flex', gap: 20,
};
const bodyStyle: React.CSSProperties = { flex: 1, overflow: 'hidden', position: 'relative' };
const linesStyle: React.CSSProperties = {
  position: 'absolute', bottom: 4, left: 0, right: 0, padding: '0 14px',
};
const lineStyle: React.CSSProperties = {
  fontSize: 9, lineHeight: 1.9, display: 'flex', gap: 8,
};
const tsStyle: React.CSSProperties = { color: '#1a1a38', minWidth: 66 };
const tdStyle: React.CSSProperties = { minWidth: 42, fontWeight: 'bold' };
const tmStyle: React.CSSProperties = { color: '#444', flex: 1 };
const cursorStyle: React.CSSProperties = {
  display: 'inline-block', width: 6, height: 10, background: '#00ff88',
  animation: 'dp 1s step-end infinite', verticalAlign: 'bottom', marginLeft: 4,
};
```

> **Security note:** This component uses NO `dangerouslySetInnerHTML`. All log content is rendered as structured React elements via the `TokenSpans` component, eliminating any XSS surface.

- [ ] **Step 2: Commit**

```bash
cd /project/src/company.nanoteofficial.me
git add src/components/TerminalFeed.tsx
git commit -m "feat: add TerminalFeed — scrolling log with cursor + clock"
```

---

## Task 12: TopBar + OfficeApp + page.tsx

**Files:**
- Create: `src/company.nanoteofficial.me/src/components/TopBar.tsx`
- Create: `src/company.nanoteofficial.me/src/components/OfficeApp.tsx`
- Modify: `src/company.nanoteofficial.me/src/app/page.tsx`
- Modify: `src/company.nanoteofficial.me/src/app/globals.css`

- [ ] **Step 1: Create TopBar.tsx**

```tsx
// src/components/TopBar.tsx
'use client';

import type { DeptId } from '@/lib/data/departments';

interface Props {
  focusedDept: DeptId | null;
  onResetView: () => void;
}

export function TopBar({ focusedDept, onResetView }: Props) {
  return (
    <header style={barStyle}>
      <div style={logoStyle}>
        ◈ <em style={{ color: '#7f8cff', fontStyle: 'normal' }}>NANO</em>TE CORP
        <small style={smallStyle}>company.nanoteofficial.me</small>
      </div>
      <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
        {focusedDept && (
          <>
            <span style={hintStyle}>click dept again to reset view</span>
            <button onClick={onResetView} style={resetBtnStyle}>⟲ Full View</button>
          </>
        )}
        <div style={liveBadgeStyle}>● 5 AGENTS LIVE</div>
      </div>
    </header>
  );
}

const barStyle: React.CSSProperties = {
  height: 40, minHeight: 40, background: '#0a0a1e',
  borderBottom: '1px solid #1e1e40', padding: '0 18px',
  display: 'flex', justifyContent: 'space-between',
  alignItems: 'center', flexShrink: 0,
};
const logoStyle: React.CSSProperties = {
  fontSize: 13, fontWeight: 'bold', color: '#fff', letterSpacing: 3,
};
const smallStyle: React.CSSProperties = { color: '#333', fontSize: 9, marginLeft: 10 };
const hintStyle: React.CSSProperties = { fontSize: 8, color: '#333' };
const resetBtnStyle: React.CSSProperties = {
  background: '#1a1a3a', border: '1px solid #3a3a6a', color: '#7f8cff',
  padding: '2px 10px', borderRadius: 12, fontSize: 9, cursor: 'pointer',
  fontFamily: 'inherit',
};
const liveBadgeStyle: React.CSSProperties = {
  background: '#00ff8815', border: '1px solid #00ff8855', color: '#00ff88',
  padding: '2px 10px', borderRadius: 20, fontSize: 9,
  animation: 'glow 2s infinite',
};
```

- [ ] **Step 2: Create OfficeApp.tsx**

```tsx
// src/components/OfficeApp.tsx
'use client';

import { useState, useCallback } from 'react';
import { TopBar } from './TopBar';
import { DepartmentSidebar } from './DepartmentSidebar';
import { OfficeCanvas } from './OfficeCanvas';
import { TerminalFeed } from './TerminalFeed';
import { DEPARTMENTS, type DeptId } from '@/lib/data/departments';

const TERMINAL_HEIGHT = 106;

export function OfficeApp() {
  const [selectedDept, setSelectedDept] = useState<DeptId | null>(null);
  const [taskTexts, setTaskTexts] = useState<Record<DeptId, string>>(() =>
    Object.fromEntries(DEPARTMENTS.map(d => [d.id, d.task])) as Record<DeptId, string>
  );

  const handleLog = useCallback((dept: DeptId, plainText: string) => {
    setTaskTexts(prev => ({ ...prev, [dept]: '● ' + plainText }));
  }, []);

  const resetView = () => setSelectedDept(null);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100vh', overflow: 'hidden' }}>
      <TopBar focusedDept={selectedDept} onResetView={resetView} />
      <div style={{ flex: 1, display: 'flex', overflow: 'hidden', minHeight: 0 }}>
        <DepartmentSidebar
          selectedDept={selectedDept}
          onSelect={setSelectedDept}
          taskTexts={taskTexts}
        />
        <main style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden', minWidth: 0 }}>
          <div style={{ flex: 1, minHeight: 0 }}>
            <OfficeCanvas selectedDept={selectedDept} terminalHeight={TERMINAL_HEIGHT} />
          </div>
          <TerminalFeed onLog={handleLog} />
        </main>
      </div>
    </div>
  );
}
```

- [ ] **Step 3: Replace src/app/page.tsx**

```tsx
// src/app/page.tsx
import { OfficeApp } from '@/components/OfficeApp';

export default function Page() {
  return <OfficeApp />;
}
```

- [ ] **Step 4: Update globals.css with keyframes**

Replace `src/app/globals.css` with:

```css
@import "tailwindcss";

html, body {
  margin: 0;
  padding: 0;
  background: #060610;
  color: #ccc;
  font-family: 'Courier New', monospace;
  overflow: hidden;
  height: 100vh;
}

* { box-sizing: border-box; }

button { font-family: inherit; }

@keyframes bob {
  0%, 100% { transform: translateY(0); }
  50% { transform: translateY(-3px); }
}

@keyframes dp {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.2; }
}

@keyframes glow {
  0%, 100% { box-shadow: 0 0 4px rgba(0, 255, 136, 0.2); }
  50% { box-shadow: 0 0 14px rgba(0, 255, 136, 0.6); }
}
```

- [ ] **Step 5: Verify dev build**

```bash
cd /project/src/company.nanoteofficial.me && npm run dev
```

Open `http://localhost:3000` in browser. Verify:
- Topbar shows "NANOTE CORP" logo + LIVE badge
- Left sidebar shows 5 department items with pixel art characters bobbing
- Canvas shows isometric 3D office with all furniture, agents walking around
- Click a department → camera pans, zone highlight pulses, agent ring glows
- Click same dept again or "⟲ Full View" → camera resets
- Terminal feed at bottom adds new logs every ~3 seconds
- Speech bubbles appear over agents periodically

Kill dev server after verification.

- [ ] **Step 6: Run type check + lint**

```bash
cd /project/src/company.nanoteofficial.me && npx tsc --noEmit && npm run lint
```
Expected: no errors.

- [ ] **Step 7: Commit**

```bash
cd /project/src/company.nanoteofficial.me
git add src/components/TopBar.tsx src/components/OfficeApp.tsx src/app/page.tsx src/app/globals.css
git commit -m "feat: integrate full office app — TopBar, sidebar, canvas, terminal"
```

---

## Task 13: Metadata + SEO

**Files:**
- Modify: `src/company.nanoteofficial.me/src/app/layout.tsx`
- Create: `src/company.nanoteofficial.me/src/app/robots.ts`
- Create: `src/company.nanoteofficial.me/src/app/sitemap.ts`

- [ ] **Step 1: Update layout.tsx with full metadata**

```tsx
// src/app/layout.tsx
import type { Metadata, Viewport } from "next";
import "./globals.css";

const SITE_URL = "https://company.nanoteofficial.me";

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    default: "NaNote Corp — AI Company Simulator",
    template: "%s · NaNote Corp",
  },
  description: "Live isometric pixel-art office showing 5 AI agents — CEO, Marketing, R&D, Operations, Finance — working together 24/7.",
  keywords: ["AI agents", "Claude", "pixel art", "office simulator", "NaNote"],
  authors: [{ name: "NaNote" }],
  openGraph: {
    type: "website",
    url: SITE_URL,
    title: "NaNote Corp — AI Company Simulator",
    description: "5 AI pixel agents working together in a live isometric office.",
  },
  twitter: { card: "summary_large_image" },
  robots: { index: true, follow: true },
};

export const viewport: Viewport = {
  themeColor: "#060610",
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
```

- [ ] **Step 2: Create robots.ts**

```typescript
// src/app/robots.ts
import type { MetadataRoute } from "next";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: { userAgent: "*", allow: "/" },
    sitemap: "https://company.nanoteofficial.me/sitemap.xml",
  };
}
```

- [ ] **Step 3: Create sitemap.ts**

```typescript
// src/app/sitemap.ts
import type { MetadataRoute } from "next";

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    {
      url: "https://company.nanoteofficial.me",
      lastModified: new Date(),
      changeFrequency: "weekly",
      priority: 1,
    },
  ];
}
```

- [ ] **Step 4: Build to confirm production output**

```bash
cd /project/src/company.nanoteofficial.me && npm run build
```
Expected: build succeeds with no errors. Output shows `/`, `/robots.txt`, `/sitemap.xml`.

- [ ] **Step 5: Commit**

```bash
cd /project/src/company.nanoteofficial.me
git add src/app/layout.tsx src/app/robots.ts src/app/sitemap.ts
git commit -m "feat: add metadata, robots.ts, sitemap.ts for SEO"
```

---

## Task 14: Production Deploy via base-deployment Skill

**Files:**
- Modify: `package.json` (bump to 0.1.0 — already at 0.1.0)
- Modify: `/project/CLAUDE.md` (add new project section)

- [ ] **Step 1: Final pre-deploy verification**

```bash
cd /project/src/company.nanoteofficial.me
npm test && npx tsc --noEmit && npm run lint && npm run build
```
All must pass.

- [ ] **Step 2: Manual visual smoke test**

```bash
cd /project/src/company.nanoteofficial.me && npm run dev
```

In browser at http://localhost:3000 verify ALL of:
- [ ] Office renders with all 5 departments visible
- [ ] All 5 agents have correct pixel sprites
- [ ] Agents walk around the office (script runs every ~4s)
- [ ] Speech bubbles appear and fade
- [ ] Terminal feed scrolls with new entries
- [ ] Sidebar dept click → camera pans + zone highlight pulses
- [ ] Reset View button works
- [ ] No console errors

- [ ] **Step 2b: Push all commits to GitHub**

```bash
cd /project/src/company.nanoteofficial.me && git push origin main
```
Verify all task commits are on the remote:
```bash
gh repo view khantee8/company.nanoteofficial.me --json url
```

- [ ] **Step 3: Invoke the base-deployment skill**

The user has installed a `base-deployment` skill that handles the NaNote deployment workflow (verify → commit with version bump → push to Vercel production).

Invoke it using the Skill tool:
```
Skill: base-deployment
```

Then follow the skill's instructions. The skill will guide:
1. Confirming version (0.1.0 — already set)
2. Final commit message
3. Pushing to the new Vercel project
4. Linking the `company.nanoteofficial.me` subdomain in Namecheap DNS (CNAME → cname.vercel-dns.com)
5. Confirming production URL is live

If `base-deployment` skill steps are unclear, fall back to manual Vercel deploy:

```bash
cd /project/src/company.nanoteofficial.me
# Install Vercel CLI if needed
npm i -g vercel
# Link new project (interactive — answer: scope, link to new, project name 'company-nanoteofficial-me')
vercel link
# First production deploy
vercel --prod
```

Then in Vercel dashboard → Settings → Domains → add `company.nanoteofficial.me`.
In Namecheap → Advanced DNS → add CNAME record `company` → `cname.vercel-dns.com`.

- [ ] **Step 4: Verify production URL**

Wait for DNS propagation (1–10 min). Then:
```bash
curl -I https://company.nanoteofficial.me
```
Expected: `HTTP/2 200`.

Open `https://company.nanoteofficial.me` in browser. Verify same checklist as Step 2.

- [ ] **Step 5: Update root CLAUDE.md with new project entry**

Append after the `personal-investment-project` section in `/project/CLAUDE.md`:

```markdown

---

### company.nanoteofficial.me — AI Company Simulator

**Stack**: Next.js 16 (App Router), React 19, TypeScript, Tailwind v4, HTML5 Canvas
**Live**: https://company.nanoteofficial.me (Vercel Hobby, auto-deploys from `main`)

```bash
cd /project/src/company.nanoteofficial.me
npm run dev        # http://localhost:3000
npm run build
npm run lint
npm test           # vitest unit tests
npx tsc --noEmit
```

Pixel-art isometric office showing 5 AI department agents (CEO, Marketing, R&D, Operations, Finance) walking around with simulated activity. v0.1 = visual MVP with simulated logs. v0.2 = real Claude API integration.

Spec: `/project/docs/superpowers/specs/2026-05-27-company-nanoteofficial-design.md`
Plan: `/project/docs/superpowers/plans/2026-05-27-company-nanoteofficial-v0.1.md`
```

- [ ] **Step 6: Commit CLAUDE.md update**

```bash
cd /project
git add CLAUDE.md
git commit -m "docs: register company.nanoteofficial.me v0.1 in root CLAUDE.md"
git push origin main
```

- [ ] **Step 7: Final celebration commit in project repo**

```bash
cd /project/src/company.nanoteofficial.me
git tag v0.1.0
echo "🎉 v0.1.0 shipped to production!"
```

---

## Self-Review

### Spec coverage check:

| Spec Section | Plan Task |
|--------------|-----------|
| §3 Departments & Agents | Task 2 (departments.ts), Task 7 (Agent class) |
| §4.1 Layout | Task 12 (OfficeApp), Task 10 (sidebar), Task 11 (terminal) |
| §4.2 Iso Engine | Task 3 (engine.ts with tests) |
| §4.3 Floor plan | Task 4 (room.ts zone colors) |
| §4.4 Furniture per zone | Task 5 (furniture.ts) |
| §4.5 Character sprites | Task 2 (sprites.ts), Task 7 (Agent.draw) |
| §4.6 Camera | Task 3 (camera.ts), Task 9 (OfficeCanvas pan trigger) |
| §4.7 Zone highlight | Task 8 (zoneHighlight.ts) |
| §5 Behaviour scripts | Task 7 (behaviours.ts) |
| §6 Real backend | **DEFERRED to v0.2** — explicitly out of scope for v0.1 |
| §7 Tech stack | Task 1 (Next.js 16 + Tailwind + TS + Vitest) |
| §8 Component architecture | Tasks 9–12 (matches lib/iso, lib/agents, lib/data, components/) |
| §9 Security | Task 1 (CSP headers); zero `dangerouslySetInnerHTML` in codebase (sprites + logs use React-rendered structured data) |
| §10 Error handling | Task 7 (sprite fallback ellipse), Task 9 (loadSprites resolves on error) |
| §11 Responsive | **DEFERRED to v0.2** — desktop-first for v0.1 |
| §12 Performance | Task 9 (rAF render loop), Task 2 (sprite preload) |
| §13 Out of scope | All v0.1 scope honored — no agent-to-agent msging, no user input |
| §14 Success criteria | Task 14 (deploy verification checklist) |

### v0.1 scope: visual MVP only — backend (§6) and responsive (§11) are v0.2.

### Placeholders: none — every code block is complete.

### Type consistency:
- `DeptId` used throughout (departments.ts → sprites.ts → Agent.ts → behaviours.ts → zoneHighlight.ts → components)
- `IsoEngine` interface defined in engine.ts and consumed by camera/room/furniture/lights/zoneHighlight/Agent
- `SpriteMap` defined in sprites.ts and consumed by Agent + OfficeCanvas
- `Point` type defined in engine.ts and consumed by camera.ts
- Camera `panTo`/`reset` signatures match between camera.ts, camera.test.ts, OfficeCanvas.tsx

---

## Notes for the Implementing Engineer

- **Next.js 16 is post-training-cutoff.** When in doubt about Next.js APIs, use the `context7` MCP tool (`@vercel:next.js`) or read `node_modules/next/dist/docs/`.
- **The mockup is your friend.** `/project/.superpowers/brainstorm/30611-1779895638/content/iso-office-v2.html` is the working reference — if a visual detail in the plan code looks off, compare to the mockup.
- **Canvas debugging tip:** if nothing renders, add `console.log(engine.OX, engine.OY, engine.TW)` after `setLayout` to verify the engine is sized correctly.
- **Tests are minimal by design.** v0.1 is visual MVP. Aggressive testing waits until v0.2 (backend code).
- **Commits per task are mandatory.** Each task ends with a `git commit` — do not batch commits across tasks.
- **The `base-deployment` skill is invoked at Task 14 Step 3.** Read its description before invoking. If it doesn't fit cleanly, the manual fallback is documented in the same step.

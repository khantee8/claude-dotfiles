# company.nanoteofficial.me — Design Spec
**Date:** 2026-05-27  
**Status:** Approved  
**Author:** NaNote + Claude

---

## 1. Overview

`company.nanoteofficial.me` is a live AI company simulator — a website that visualizes five AI sub-agents working together like a real company, displayed as an **isometric 3D pixel-art office**. Each agent represents a department, has their own desk, and physically moves around the office while running real background tasks 24/7. The site is both a visual showcase and a real working pipeline.

**Tagline:** *"Pixel Agents. Real Work."*

---

## 2. Goals

- Show NaNote's AI agents doing real work in a visually compelling way
- Represent each department as a distinct personality with its own pixel-art character
- Make background pipeline activity visible and legible in real-time
- Run agents 24/7, accessible from any device

---

## 3. Departments & Agents

| ID | Name | Character | Color | Role |
|----|------|-----------|-------|------|
| `ceo` | NaNote | Crown + navy suit + blue tie | `#ffdd57` | Orchestrates all agents, approves tasks, reviews reports |
| `mkt` | Marketing | Pink hair + headset + star shirt | `#ff6b9d` | Content generation, social posts, campaign planning |
| `rnd` | R&D | Lab coat + glasses + cyan flask | `#00cfff` | Research, analysis, model experiments, proposals |
| `ops` | Operations | Hard hat + orange overalls + wrench | `#ff9a3c` | Deployments, infra monitoring, server management |
| `fin` | Finance | Navy suit + `$` on chest | `#7f8cff` | Market data, ROI analysis, financial reports |

---

## 4. Visual Design

### 4.1 Layout

```
┌────────────────────────────────────────────────────────┐
│  TOP BAR: ◈ NANOTE CORP   [focus hint]  [⟲ Full View] │
├──────────┬─────────────────────────────────────────────┤
│          │                                             │
│ SIDEBAR  │      ISOMETRIC OFFICE CANVAS (3D)          │
│ 186px    │      HTML5 Canvas — requestAnimationFrame  │
│          │                                             │
│ Dept tabs│                                             │
│ w/ pixel ├─────────────────────────────────────────────┤
│ chars    │  TERMINAL FEED (106px)                      │
│ + tasks  │  Live pipeline log — one entry per ~3s     │
└──────────┴─────────────────────────────────────────────┘
```

### 4.2 Isometric Engine

- **Projection:** Standard isometric (2:1 tile ratio, camera top-right)
- **Room size:** 20 × 14 grid tiles, `TW = 56px, TH = 28px` (adaptive to viewport)
- **Rendering:** HTML5 Canvas, painter's algorithm (back-to-front depth sort)
- **Coordinates:** `screen_x = OX + (gx − gy) × TW/2 + camX`, `screen_y = OY + (gx + gy) × TH/2 − pz + camY`

### 4.3 Office Floor Plan

```
y=0  ══════════════════════════════════════ BACK WALL
  [CEO x:0-4] [MKT x:4-8] [R&D x:8-13] [OPS x:13-17] [FIN x:17-20]
  Glass partitions between zones
y=4  ─────────────── open floor ──────────────────────
  [MEETING ROOM x:6-14, y:5-9]    [BREAK ROOM x:15-20, y:6-12]
y=10 ─────────────── hallway ────────────────────────
  [Plants]  [Notice Board]  [Reception Desk]
y=14 ═══════════════════════════════════════ FRONT EDGE
```

### 4.4 Zone Furniture (per dept)

| Zone | Key Items |
|------|-----------|
| CEO | L-shaped desk, 2 monitors, bookshelf with colored books, trophy, visitor chairs, desk plant |
| Marketing | Personal desk, dual monitors, presentation board + post-its, marker holder |
| R&D | Personal desk, lab bench, whiteboard with formulas, flasks/beaker/microscope |
| Operations | Personal desk + 3 monitors, 2 tall server racks (blinking LEDs), network switch |
| Finance | Wide desk, dual monitors, filing cabinet (2 drawers), stock chart on wall |
| Meeting Room | Long table + 14 chairs, projector screen, laptop + papers on table |
| Break Room | Counter, coffee machine, water dispenser, mini-fridge, sofa + cushions, coffee table |
| Hallway | Plants (7), notice board with pinned notes, reception desk, entrance mat |

### 4.5 Character Sprites

- **Format:** SVG pixel art, 9×11 pixel canvas, rendered at 4× scale (36×44px)
- **Rendering:** Billboard sprites — vertical, always facing camera (classic isometric game style)
- **Animation:** Loaded as `Image` from `data:image/svg+xml` URL; drawn via `ctx.drawImage()`
- **Direction:** Sprite flips horizontally (`ctx.scale(-1,1)`) when moving left
- **Walking:** Vertical bob (`Math.abs(Math.sin(walkPhase)) × 5px`) while in transit
- **Idle:** Gentle sine wave float (`Math.sin(t × 1.5) × 2px`)
- **Working:** Arm wave animation on body ellipse

### 4.6 Camera System

- **Pan:** `camX/Y` offset added to every `g()` call; lerp at `0.07` per frame toward `camTX/Y`
- **Focus trigger:** Clicking a dept in the sidebar → compute `camTX = canvas.width/2 − raw_screen_x`, `camTY = midpoint − raw_screen_y`
- **Reset:** Click same dept again, or `⟲ Full View` button → `camTX = camTY = 0`

### 4.7 Zone Highlight (on dept select)

- Dashed animated border around zone floor (marching ants, dept color)
- Soft color fill over zone tiles (low opacity)
- 4 corner sparkle dots
- Pulsing ellipse ring under the selected agent
- Sidebar item turns green (`focused` CSS state)

---

## 5. Agent Behaviour System (Frontend)

The **visual behaviour system** is a client-side script driving agent movement and speech:

```
Scripts array → runs sequentially, looped
Each script: moves agents to waypoints, triggers speech bubbles
Interval: 3.5–6s between steps (random jitter)
```

**Named waypoints:**
- `MEETING` — center meeting room `(10, 7)`
- `COFFEE` — break room machine `(17.2, 7)`
- `WHITEBOARD` — R&D whiteboard `(10, 0.9)`
- `SERVER_RACK` — OPS rack `(14.0, 0.9)`
- Each agent's `homeX/homeY` — personal desk

**Behaviour patterns:**
1. CEO → meeting room → team standup → all go home
2. R&D → whiteboard → writes → goes home
3. Finance → coffee → ROI bubble → goes home
4. OPS → server rack → deploy bubble → goes home
5. Marketing → coffee break → goes home
6. CEO + FIN bilateral meeting at FIN desk
7. R&D + CEO proposal approval at meeting room
8. Marketing + OPS joint meeting

---

## 6. Real Agent Pipeline (Backend)

Each department has a **real Claude agent** running on a schedule. The frontend reflects actual pipeline state.

### 6.1 Agent Tasks

| Dept | Real Task | Schedule |
|------|-----------|----------|
| CEO | Generates weekly company summary, approves R&D proposals, dispatches tasks to other agents | Daily |
| Marketing | Generates social posts (Twitter/LinkedIn content), drafts blog ideas | Daily |
| R&D | Runs market research, analyses trends, writes hypothesis reports | Weekly |
| Operations | Monitors Vercel deployments, checks container health via API, reports status | Every 6h |
| Finance | Pulls market data (Yahoo Finance / crypto), computes portfolio ROI, saves report | Daily |

### 6.2 Data Flow

```
Claude API (each agent)
    ↓ task output + status
Backend API route  /api/pipeline
    ↓ SSE stream (Server-Sent Events)
Frontend EventSource
    ↓
Terminal feed + agent status dots + sidebar task text
```

### 6.3 API Routes

| Route | Method | Description |
|-------|--------|-------------|
| `/api/pipeline` | GET (SSE) | Stream of `{dept, msg, timestamp}` events |
| `/api/agents` | GET | Current status of all 5 agents (state, lastRun, task) |
| `/api/agents/[id]/run` | POST | Manually trigger an agent (admin only) |

### 6.4 Agent State Machine

```
idle → running → done / error → idle
```

Frontend status dots:
- `●` green = running/done recently
- `●` amber = pending/queued  
- `○` grey = idle (not run yet today)

---

## 7. Tech Stack

| Layer | Choice | Reason |
|-------|--------|--------|
| Framework | Next.js 16, App Router | Consistent with nanoteofficial.me |
| Language | TypeScript | Type safety for agent state |
| Canvas | Vanilla HTML5 Canvas | No library needed for isometric renderer |
| Styling | Tailwind v4 | Consistent with portfolio site |
| Real-time | Server-Sent Events (SSE) | Simpler than WebSocket for one-way stream |
| AI | `@anthropic-ai/sdk` (claude-sonnet-4-6) | Latest Claude, prompt caching for repeated tasks |
| Deployment | Vercel Hobby → Vercel Pro (for cron jobs) | Consistent with existing projects |
| Database | Vercel KV (Redis) | Store agent run history + last output |
| Scheduling | Vercel Cron | Run agents on schedule |

---

## 8. Component Architecture

```
app/
  page.tsx                    ← Main company page
  layout.tsx                  ← Metadata, fonts
  api/
    pipeline/route.ts         ← SSE stream endpoint
    agents/route.ts           ← Agent status GET
    agents/[id]/run/route.ts  ← Manual trigger

components/
  office/
    OfficeCanvas.tsx          ← Canvas container + resize
    IsoEngine.ts              ← g(), tile(), box(), poly() helpers
    AgentSprites.ts           ← SVG sprite loader + drawSprite()
    AgentBrain.ts             ← Agent class (position, movement, state)
    BehaviourSystem.ts        ← Script runner, waypoints
    RoomDrawer.ts             ← drawFloor(), drawWalls(), drawFurniture()
    ZoneHighlight.ts          ← drawZoneHighlight(), camera pan
    TerminalFeed.tsx          ← SSE consumer, scrolling log
  sidebar/
    DeptSidebar.tsx           ← Dept list, pixel chars, task panel
    DeptItem.tsx              ← Single dept row

lib/
  agents/
    ceo.ts                    ← CEO agent prompt + runner
    marketing.ts
    rnd.ts
    operations.ts
    finance.ts
  claude.ts                   ← Anthropic SDK client (with prompt caching)
  kv.ts                       ← Vercel KV helpers
```

---

## 9. Security

- Admin routes (`/api/agents/[id]/run`) protected by `ADMIN_SECRET` env var
- Claude API key stored in Vercel env, never exposed to client
- SSE endpoint rate-limited (max 1 connection per IP)
- No user input in pipeline feed (all content is agent-generated)
- Agent outputs sanitised before storing in KV

---

## 10. Error Handling

| Scenario | Handling |
|----------|---------|
| Agent run fails | Status → `error`, terminal shows `[DEPT] ⚠ task failed: reason`, retries after 1h |
| SSE connection drops | Client auto-reconnects with exponential backoff |
| Canvas not supported | Fallback static screenshot with status table |
| Vercel KV unavailable | In-memory fallback, no persistence for that run |
| Claude API rate limit | Exponential backoff, max 3 retries |

---

## 11. Responsive Design

| Breakpoint | Behaviour |
|------------|-----------|
| `≥ 1024px` | Full layout: sidebar + canvas + terminal |
| `768–1023px` | Sidebar collapses to icon-only strip |
| `< 768px` | Canvas goes full-width, sidebar slides in as drawer, terminal scrollable |

---

## 12. Performance

- Canvas renders at 60fps via `requestAnimationFrame`
- SVG sprites pre-loaded once at init (`Promise.all`)
- Tile size auto-scales to viewport to avoid overflow
- SSE stream batched: max 1 event per 2.8s to avoid log spam
- Prompt caching on all Claude API calls (system prompt cached, 200k token window)

---

## 13. Out of Scope (v1)

- Agent-to-agent direct messaging (v2)
- User ability to give agents tasks (v2)
- Mobile native app (v3)
- Multiple office floors / rooms (v2)
- Sound effects / ambient audio (v2)

---

## 14. Success Criteria

- [ ] All 5 agents visually walk around the office and interact
- [ ] Real Claude agents run daily and output appears in terminal feed
- [ ] Camera pan + zone highlight works on dept click
- [ ] Site loads in < 3s, canvas runs smoothly at 60fps
- [ ] Deployed and accessible at `company.nanoteofficial.me`
- [ ] Works on desktop Chrome, Firefox, Safari

---

## 15. Open Questions (resolved)

| Question | Decision |
|----------|----------|
| Visual style | Isometric 3D top-down, pixel-art billboard sprites |
| Layout | Left sidebar + isometric canvas + terminal feed |
| Characters | Side-view SVG pixel art rendered as vertical billboards |
| Camera interaction | Click dept → smooth pan + zone highlight |
| Agent tech | Claude API, `claude-sonnet-4-6`, SSE for streaming |
| Deployment | Vercel, subdomain `company.nanoteofficial.me` |

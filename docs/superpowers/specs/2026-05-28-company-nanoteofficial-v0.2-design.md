# company.nanoteofficial.me — v0.2 Design (Real Agents + Telegram + CI/CD)

**Date:** 2026-05-28
**Status:** Approved — ready for implementation plan
**Builds on:** v0.1 (visual MVP, live at https://company.nanoteofficial.me) and the v0.1 spec `2026-05-27-company-nanoteofficial-design.md` §6 (Real Agent Pipeline), which this document supersedes for the backend.

---

## 1. Goal

Turn the five simulated department agents into **real Claude agents that produce genuinely useful work product** on a daily schedule, surface that work in the existing isometric office, and make the whole company **controllable and observable from Telegram** (two-way) — including **CI/CD alerts**.

Success criteria:
- Each agent runs automatically every day (no site visit needed) and writes a real artifact you'd actually read.
- The office UI reflects real agent state/output (not simulated logs), while keeping the ambient pixel movement.
- You can `/status`, `/run`, and `/ask` the agents from Telegram, and you receive daily reports + deploy alerts there.
- ~$0 infrastructure (Vercel Hobby + Upstash free tier); only minimal Claude API usage (~$1–3/mo).

---

## 2. Key decisions (resolved during brainstorming)

| Decision | Choice | Rationale |
|---|---|---|
| What "real" means | **Useful work product** | Each agent produces a real artifact, not themed filler. |
| Plan & cadence | **Vercel Hobby, daily cron** | Hobby caps cron at once/day per job; daily refresh is fine for daily artifacts. ~$0. Structured so a Pro upgrade to sub-daily is a config change. |
| Agent runtime | **Cloud-only (Vercel)** | Agents run as Vercel Cron functions. Nothing runs at home; zero local maintenance. |
| Storage | **Upstash Redis** (Vercel Marketplace) | Vercel KV is deprecated (migrated to Upstash Dec 2024). Free tier, HTTP SDK (`@upstash/redis`), serverless-friendly, auto-injects env vars. |
| Real-time transport | **Polling** (not SSE) | Real outputs change daily; polling Redis every ~8s is simpler/cheaper than holding SSE functions open. |
| Telegram | **Two-way + CI/CD alerts** | Commands (`/run`, `/status`, `/ask`) + outbound daily reports + deploy/build alerts. |
| Ops agent task | **CI/CD reporter** | The original "monitor home LXC" is unreachable from the cloud; Ops instead monitors Vercel + GitHub (fully cloud-reachable). |
| Function duration | **Fluid Compute (≤300s on Hobby)** | Enough for agent runs incl. web search. |

**Explicitly deferred / out of scope for v0.2:**
- LXC sensor for real home-container metrics (option B) — not chosen; can be added later without redesign.
- Triggering production deploys/rollbacks from Telegram — too risky from chat; Telegram only triggers *agent runs* and *questions*.
- Sub-daily cadence (needs Pro).

---

## 3. Architecture & data flow

```
Vercel Cron (5 daily jobs, staggered UTC; CEO last)
   └─> GET /api/cron/run?dept=X   (Authorization: Bearer CRON_SECRET)
          └─> Agent runner(dept)
                 ├─> Claude API (Anthropic SDK)  [+ web search tool for R&D]
                 ├─> external data source (CoinGecko / Vercel API / GitHub API)
                 ├─> Upstash Redis  (status + artifact + feed event)
                 └─> Telegram sendMessage (daily report)

Office UI  ──poll ~8s──>  GET /api/agents , GET /api/feed  ──read──>  Redis
You (Telegram)  ──>  POST /api/telegram (webhook)  ──>  /status · /run · /ask
Vercel deploy events  ──webhook──>  POST /api/webhooks/vercel  ──>  Telegram (CI/CD alert)
```

All components are stateless Vercel functions + Upstash Redis as the single source of truth. The office never talks to Claude directly; it only reads Redis.

---

## 4. The five agents

Each agent is a module in `lib/agents/<dept>.ts` exporting a `run()` that returns a structured result `{ markdown, summary, meta }`. A shared runner (`lib/agents/runner.ts`) wraps each: set status `running` → call `run()` → store artifact + status `done` + push a feed event + send Telegram report; on throw → status `error` + Telegram alert.

| Dept | Real task | Data source | Schedule (UTC) | Extra key |
|---|---|---|---|---|
| **Finance** | Fetch live crypto prices (BTC, ETH, + a small watchlist), compute day-over-day move and a simple ROI brief | CoinGecko free API (`/simple/price`, no key) | `0 11 * * *` | — |
| **R&D** | Produce a short trend/tech research brief | **Claude web-search tool** (server tool) | `0 12 * * *` | — |
| **Marketing** | Draft real X + LinkedIn posts and one blog idea, themed on the user's actual projects (portfolio, finance app, this sim) | LLM, seeded with a static project blurb | `0 13 * * *` | — |
| **Operations** | CI/CD health: deployment state of the 3 nanoteofficial Vercel projects + recent commits/CI runs across repos | Vercel REST API + GitHub API | `0 14 * * *` | VERCEL_TOKEN, GITHUB_TOKEN |
| **CEO** | Standup summary + a few "decisions," synthesizing the other four agents' fresh outputs | reads Redis (others' artifacts) | `0 15 * * *` | — |

CEO is scheduled last so it summarizes the same day's fresh outputs. All schedules are one daily entry each in `vercel.json` (staggered to spread load and respect Hobby's "any time within the hour" behavior).

Agent persona/prompts: each agent has a system prompt defining its role/voice (consistent with the v0.1 department identities). Prompt caching on the system prompt where it helps.

---

## 5. Telegram bot (two-way)

**Webhook:** `POST /api/telegram`
- Verifies the `X-Telegram-Bot-Api-Secret-Token` header against `TELEGRAM_WEBHOOK_SECRET`.
- **Locked to a single chat:** ignores any update whose chat/user id ≠ `TELEGRAM_ALLOWED_CHAT_ID`.
- Parses the command and dispatches.

**Commands:**
| Command | Behavior |
|---|---|
| `/status` | Read Redis, reply with all 5 agents' state + lastRun + one-line last summary. |
| `/run <dept>` | Ack instantly ("▶ running marketing…"), run the agent **asynchronously** via Next `after()` so the webhook returns within Telegram's timeout, then `sendMessage` with the result. |
| `/ask <dept> <question>` | One-off Claude call using that agent's persona; reply with the answer. Not stored as the daily artifact. |
| `/help` | List commands. |

**Outbound notifications:**
- Each daily agent run posts its report (title + summary + link to office).
- Ops posts CI/CD status; deploy webhook posts instant deploy success/failure.

**Setup:** user creates a bot via @BotFather → `TELEGRAM_BOT_TOKEN`; we register the webhook URL with the secret; user provides their `TELEGRAM_ALLOWED_CHAT_ID`.

---

## 6. CI/CD alerts

- **Vercel deploy webhook:** `POST /api/webhooks/vercel` — verify Vercel signature, format `deployment.succeeded` / `deployment.error` events, push to Telegram + a feed event. Configured in the Vercel project's webhook settings.
- **GitHub:** Ops agent pulls recent commits + CI run conclusions via the GitHub API in its daily run (no separate webhook needed for v0.2; can add a `push`/`workflow_run` webhook later).
- Deploy *triggering* from chat is intentionally **not** included (observe + report only).

---

## 7. Backend details

**Redis schema (Upstash):**
| Key | Type | Value |
|---|---|---|
| `agent:<dept>:status` | JSON string | `{ state: 'idle'\|'running'\|'done'\|'error', lastRun: ISO, error?: string, summary?: string }` |
| `agent:<dept>:output` | JSON string | `{ markdown: string, summary: string, ts: ISO, meta?: object }` |
| `feed:events` | List (capped) | `LPUSH` `{ dept, msg, ts }`, `LTRIM 0 49` |

**API routes:**
| Route | Method | Auth | Purpose |
|---|---|---|---|
| `/api/cron/run` | GET | `CRON_SECRET` (Bearer; Vercel cron sends it) | Run one agent (`?dept=`) |
| `/api/agents` | GET | public (read) | All statuses + outputs for the office |
| `/api/feed` | GET | public (read) | Recent feed events |
| `/api/telegram` | POST | Telegram secret + chat allowlist | Bot webhook |
| `/api/webhooks/vercel` | POST | Vercel signature | Deploy → Telegram |

**Cron config:** `vercel.json` `crons[]` — five daily entries (the table in §4), each `{ path: "/api/cron/run?dept=X", schedule: "0 H * * *" }`.

**Libraries:** `@anthropic-ai/sdk`, `@upstash/redis`. Anthropic web-search tool used by R&D. Telegram + Vercel + GitHub via plain `fetch`.

---

## 8. Frontend changes

- **TerminalFeed** → poll `GET /api/feed` (~8s) and render real events with the existing typewriter/scroll style; show a "warming up — agents run daily" state when empty.
- **DepartmentSidebar** → task text from real `agent:<dept>:status`; status dots reflect real state.
- **Artifact viewer panel (new)** → clicking a department opens a panel showing that agent's latest real artifact (`agent:<dept>:output.markdown`), rendered safely (no `dangerouslySetInnerHTML`; use a minimal safe markdown renderer or structured rendering). Includes lastRun timestamp.
- **Ambient layer unchanged** → agents keep walking/speaking for liveliness; speech bubbles may surface real event snippets.
- A subtle "last updated HH:MM" indicator.

---

## 9. Security

- All secrets in Vercel env, never shipped to client: `ANTHROPIC_API_KEY`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_WEBHOOK_SECRET`, `TELEGRAM_ALLOWED_CHAT_ID`, `UPSTASH_REDIS_REST_URL`, `UPSTASH_REDIS_REST_TOKEN` (auto-injected), `VERCEL_TOKEN`, `GITHUB_TOKEN`, `CRON_SECRET`.
- `/api/cron/run` rejects requests without the correct `CRON_SECRET`.
- Telegram webhook: secret-token header + single-chat allowlist.
- Vercel webhook: signature verification.
- Public read routes (`/api/agents`, `/api/feed`) expose only agent-generated, sanitized content (no secrets, no user input).
- Agent outputs sanitized before storing and before rendering; preserve the no-`dangerouslySetInnerHTML` rule from v0.1.
- Keep the existing strict CSP; add only the origins actually needed (`connect-src` for the office is same-origin polling; external calls happen server-side).

---

## 10. Error handling

| Scenario | Handling |
|---|---|
| Agent run throws | status → `error`, store error, Telegram alert `[DEPT] ⚠ failed: reason`, retry on next daily cron |
| Data source down (CoinGecko/Vercel/GitHub) | agent notes "source unavailable," still writes a partial artifact, no crash |
| Claude API rate limit / 5xx | exponential backoff, max 3 retries; then `error` state |
| Web search tool unavailable | R&D falls back to LLM-only synthesis with a note |
| Redis unavailable | cron run logs + Telegram alert; office shows last-known cache / empty state, no crash |
| Telegram unreachable | run still completes and stores to Redis; notification skipped |
| `/run` async work exceeds limits | acked already; on failure send a follow-up error message |

---

## 11. Cost

- Vercel Hobby: $0. Upstash free tier (~10k cmds/day, 256MB): $0 — usage is tiny.
- CoinGecko / GitHub / Vercel APIs: free tiers.
- Claude: 5 daily runs + occasional `/ask`/`/run`; modest token counts → ~$1–3/mo. R&D web search adds a little.

---

## 12. Testing

- **Unit (vitest):** agent runners with mocked Claude + mocked data sources; Redis helper wrappers; Telegram command parser + allowlist; feed builder/cap logic; Ops Vercel/GitHub formatters.
- **Manual:** trigger each agent via `curl /api/cron/run?dept=X` with the secret; verify Redis writes; register the Telegram webhook and exercise `/status`, `/run`, `/ask`; trigger a Vercel deploy and confirm the alert; load the office and confirm real feed/status/artifact + polling.

---

## 13. New environment variables

```
ANTHROPIC_API_KEY            # Claude (reuse pattern from finance project)
UPSTASH_REDIS_REST_URL       # auto-injected by Upstash Vercel integration
UPSTASH_REDIS_REST_TOKEN     # auto-injected
TELEGRAM_BOT_TOKEN           # from @BotFather
TELEGRAM_WEBHOOK_SECRET      # random; set on webhook registration
TELEGRAM_ALLOWED_CHAT_ID     # your Telegram chat/user id
VERCEL_TOKEN                 # for Ops (read deploy status)
GITHUB_TOKEN                 # for Ops (read commits/CI)
CRON_SECRET                  # protects /api/cron/run
VERCEL_WEBHOOK_SECRET        # verify deploy webhook (if signature used)
```

---

## 14. Component / file additions (indicative)

```
src/
  app/api/
    cron/run/route.ts
    agents/route.ts
    feed/route.ts
    telegram/route.ts
    webhooks/vercel/route.ts
  lib/
    agents/
      runner.ts            # shared run wrapper (status, store, notify)
      ceo.ts marketing.ts rnd.ts operations.ts finance.ts
      personas.ts          # system prompts
    claude.ts              # Anthropic client (+ web search helper)
    redis.ts               # Upstash helpers + schema accessors
    telegram.ts            # sendMessage + command parser + allowlist
    sources/
      coingecko.ts vercelApi.ts githubApi.ts
  components/
    ArtifactPanel.tsx       # latest real artifact viewer
    (TerminalFeed.tsx, DepartmentSidebar.tsx updated to poll real data)
vercel.json                 # crons[]
```

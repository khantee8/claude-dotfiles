# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Environment
- **OS**: Ubuntu 24.04 LXC container on Proxmox
- **Working directory**: /project
- **Timezone**: America/New_York
- **User**: root

## Available Tools
- **Languages**: Node.js 22 LTS, Python 3.12, Go (latest), Rust (latest)
- **Package managers**: npm, pip (use --break-system-packages), cargo, go install
- **Docker**: Docker Engine + Compose plugin, running and ready
- **Containers**: Watchtower (auto-updates), Code Server (port 8443)
- **Search tools**: ripgrep (rg), fd-find (fdfind), fzf
- **Databases**: PostgreSQL client (psql), Redis client (redis-cli), SQLite3

## Permissions
All tools are pre-approved — no permission prompts. Bash, Read, Write, Edit, WebFetch, WebSearch, Task, and MCP tools all run without confirmation.

## Agent Teams
Agent teams are enabled. You can spawn parallel teammates for complex tasks:
- Use agent teams for work that benefits from parallel exploration
- Use subagents (Task tool) for quick focused work that reports back
- tmux is installed for split-pane team visualization

## Remote Control
Remote control is enabled for all sessions. Every interactive session is automatically controllable
from claude.ai/code or the Claude mobile app. Use /remote-control or press spacebar to show QR code.

## Docker Usage
Watchtower is already running and will auto-update any containers with `restart: unless-stopped`.
All Docker containers in this LXC need `security_opt: [apparmor=unconfined]`.

Each project in `/project/src/` has its own `docker-compose.yml` co-located inside the project directory. New standalone services should place their compose file in `/docker/<service-name>/docker-compose.yml`.

## Conventions
- Prefer creating files over printing long code blocks
- Use git for version control on all projects in /project/src/
- When installing Python packages, use: pip install --break-system-packages <package>
- Extended thinking is always on — use it for complex architectural decisions
- All Next.js projects use **Next.js 16** — APIs differ from training data. Use `context7` MCP tool or read `node_modules/next/dist/docs/` before writing Next.js-specific code.

## Installed Plugins
- **frontend-design**: Production-grade UI with distinctive aesthetics (auto-activates on frontend tasks)
- **code-review**: Multi-agent PR review with confidence scoring
- **commit-commands**: Git commit, push, and PR workflows (/commit, /push, /pr)
- **github**: GitHub MCP — issues, PRs, repos
- **playwright**: Browser automation and UI testing
- **context7**: Live, version-specific library docs lookup (reduces API hallucinations)
- **webapp-testing**: Playwright-based browser testing for UI verification and debugging
- **telegram**: Telegram bot integration
- **superpowers** (v5.1.0): Development workflow framework — brainstorm → plan → implement with TDD. **Skills-only, no slash commands** (the old `/superpowers:write-plan`-style commands were removed). Invoke via the **Skill tool** by skill name; they also auto-trigger via the plugin's session-start hook (`using-superpowers` bootstrap).
  - `brainstorming` — refine ideas before coding (NOT `/superpowers:brainstorm`)
  - `writing-plans` — create implementation plans (NOT `write-plan`)
  - `executing-plans` / `subagent-driven-development` — execute plans task-by-task (NOT `execute-plan`)
  - Auto-activating skills: `test-driven-development`, `systematic-debugging`, `verification-before-completion`
  - **Enablement note:** superpowers must be enabled in the settings scope that applies to your cwd. Sessions rooted in a nested `src/<project>` repo (no own `.claude/`) resolve plugins from `~/.claude/settings.json` only — so it must be enabled there, not just in `/project/.claude/settings.json`.
- **claude-code-setup**: Claude Code configuration helpers
- **auth0**: Auth0 integration patterns
- **cloudflare**: Cloudflare Workers, Pages, and bindings
- **vercel**: Vercel deployment, env vars, and AI SDK
- **skill-creator**: Create and improve Claude Code skills
- **ui-ux-pro-max**: UI/UX design intelligence (styles, palettes, font pairings, chart types)

All plugins are `@claude-plugins-official` except **ui-ux-pro-max**, which comes from a third-party marketplace (`nextlevelbuilder/ui-ux-pro-max-skill`). That marketplace is registered under `extraKnownMarketplaces` in `.claude/settings.json` and must exist before the plugin can be (re)installed.

---

## Dotfiles Repo Structure

This repo (`khantee8/claude-dotfiles`) is the source of truth for this machine's Claude Code config.

```
.claude/
  settings.json        ← all Claude settings (plugins, env, permissions, theme)
  settings.local.json  ← machine-local overrides, NOT committed
  skills -> ../.agents/skills  ← symlink to custom skills directory

.agents/skills/        ← custom agent skills (tracked in skills-lock.json)
  base-deployment/     ← NaNote Finance deploy workflow
  brainstorming/       ← idea refinement with visual companion
  cybersecurity-analyst/
  finance-expert/
  owasp-security-check/
  security-review/
  stock-analysis/

agents/skills/         ← find-skills only (tracked in agents/.skill-lock.json)
  find-skills/

docs/superpowers/      ← design specs and implementation plans
  specs/               ← feature design documents
  plans/               ← step-by-step implementation plans

skills-lock.json       ← registry for .agents/skills installs
setup.sh               ← restore script for new machines
```

**Key constraint**: `.claude/skills` is a symlink to `../.agents/skills`. Do not change this to point to `agents/skills` — it only contains `find-skills`.

## Updating the Dotfiles

After changing Claude Code settings on this machine:

```bash
cd /project
git add .claude/settings.json
git commit -m "update settings"
git push origin main
```

After installing a new agent skill:

```bash
git add skills-lock.json .agents/skills/
git commit -m "add <skill-name> skill"
git push origin main
```

## Restoring on a New Machine

```bash
git clone https://github.com/khantee8/claude-dotfiles.git
cd claude-dotfiles
chmod +x setup.sh
./setup.sh
```

`setup.sh` copies `.claude/settings.json` to `~/.claude/settings.json`, installs custom skills to `~/.claude/skills/`, and reinstalls plugins via the `claude` CLI. Requires Claude Code and Node.js.

---

## Profile Assets

`/project/Profile/` holds the user's professional assets — not part of any project's build:
- `Saksit-CV-2026-EN.pdf` / `Saksit-CV-2026-TH.pdf` — current CVs (English & Thai)
- `Profile1.JPG` / `Profile2.JPG` — profile photos

These are the source files for the portfolio site's avatar and CV download links.

---

## Projects in /project/src/

> **`src/` is gitignored in this dotfiles repo.** Each project is an independent `khantee8/` git repo nested under `src/`. Commits and pushes from `/project` only ever touch the dotfiles config — to commit project code, `cd` into the project directory first and work in its own repo.

All projects deploy to Vercel Hobby (auto-deploy from `main`). Each `*.nanoteofficial.me` project has a subdomain CNAME in Namecheap pointing to Vercel.

### nanoteofficial.me — Portfolio Site

**Stack**: Next.js 16 (App Router), React 19, TypeScript, Tailwind v4
**Live**: https://nanoteofficial.me

```bash
cd /project/src/nanoteofficial.me
npm run dev        # http://localhost:3000
npm run build
npm run lint
npx tsc --noEmit
```

Multi-subdomain portfolio site — `proxy.ts` rewrites `<sub>.nanoteofficial.me` → `/<sub>` (finance, cyber, kb, art are preview shells). v1.3 adds a "Company" section between About and Experience with a live iframe of `company.nanoteofficial.me`. See `src/nanoteofficial.me/CLAUDE.md` for full architecture (subdomain routing, i18n, theming, component conventions).

---

### finance.nanoteofficial.me — AI Finance Advisor

**Stack**: Next.js 16 (App Router), React 19, TypeScript, Tailwind v4, Auth0 v4
**Live**: https://finance.nanoteofficial.me

```bash
cd /project/src/finance.nanoteofficial.me
npm run dev        # http://localhost:3001
npm run build
npx tsc --noEmit   # verification step — no test runner configured
```

Auth0-gated SPA with role-based views (advisor, client, admin). `proxy.ts` enforces auth. Role is read from the ID token directly (`@auth0/nextjs-auth0` v4 strips custom namespace claims from `session.user`). `AppShell` → `Shell` is the single stateful container; screens receive props and manage local state only. See `src/finance.nanoteofficial.me/CLAUDE.md` for full architecture (auth gate, SPA pattern, view routing).

---

### company.nanoteofficial.me — AI Company Simulator

**Stack**: Next.js 16 (App Router), React 19, TypeScript, Tailwind v4, HTML5 Canvas, Vitest
**Live**: https://company.nanoteofficial.me

```bash
cd /project/src/company.nanoteofficial.me
npm run dev        # http://localhost:3000
npm run build
npm run lint
npm test           # vitest
npx tsc --noEmit
```

Pixel-art two-floor isometric office with 6 AI department agents (CEO, Finance, CyberX, Marketing & Social Media, AI R&D, Operations). v1.4.2 (current) = real, **web-researched + cited** Claude agents running from detailed role specs, a raised executive **2nd-floor mezzanine** (CEO + Finance) over a ground floor (the rest), a public glassmorphism `/dashboard` + per-agent `/dashboard/[dept]`, a private `/admin` console, a bilingual **TH/EN** UI, a bilingual `/doc` operator guide, a published-only `/api/kb` knowledge API, mixed-cadence Vercel Cron, Upstash Redis state, and a two-way Telegram bot.

**Architecture layers**:
- **Isometric engine** (`src/lib/iso/`) — vanilla HTML5 Canvas renderer, no game library; `room.ts` `drawMezzanine()` renders the raised 2nd floor
- **Agent system** (`src/lib/agents/`) — Agent class with state machine, `roles.ts` (loads Thai role specs from `.agents/*.md`) → `personas.ts`, department modules, `runner.ts` orchestrator; artifacts carry `'api'`/`'web'` provenance and `'web'` is never uncited
- **Integrations** (`src/lib/`) — `claude.ts` (Anthropic SDK, `webSearch`), `redis.ts` (Upstash, addressable KB graph), `telegram.ts` (bot API), `dashboard.ts` (read aggregator), `sources/` (CISA KEV, Hacker News, Dev.to, GitHub, Vercel), `i18n/` (TH/EN seam), `doc.ts` (operator guide loader)
- **API routes** — `/api/cron/run?dept=` (CRON_SECRET, mixed per-agent cadence), `/api/dashboard`, `/api/admin/*` (session-cookie-gated run + KB CRUD), `/api/kb` (published-only), `/api/agents`, `/api/feed`, `/api/telegram` (webhook), `/api/webhooks/vercel` (deploy alerts)
- **Components** — NavBar (responsive, LangToggle), OfficeCanvas, DepartmentSidebar, TerminalFeed, TopBar, OfficeApp, ExecDashboard, AgentDetail, KbManager, `charts/` (hand-rolled SVG), `doc/` (guide renderer), Markdown (safe renderer, no `dangerouslySetInnerHTML`)

See `src/company.nanoteofficial.me/CLAUDE.md` for full architecture and env var list.

---

### personal-investment-project — Portfolio Analyzer

**Stack**: Node.js + Express, vanilla HTML/CSS/JS frontend, no build step

```bash
cd /project/src/personal-investment-project
npm run dev    # node --watch server.js — http://localhost:3000
npm start      # production

# Docker
docker compose up -d   # http://localhost:3030 → container :3000
```

No tests. No TypeScript. Single-file server (`server.js`) + static frontend (`public/`). `detectAndParse()` auto-detects XLSX format and dispatches to `parsePersonalStatement()` or `parsePortfolioData()`. `fetchFromUrl()` handles Google Sheets/Drive URLs.

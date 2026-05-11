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
Docker compose files should go in /docker/<service-name>/docker-compose.yml.
Watchtower is already running and will auto-update any containers with `restart: unless-stopped`.
All Docker containers in this LXC need `security_opt: [apparmor=unconfined]`.

## Conventions
- Prefer creating files over printing long code blocks
- Use git for version control on all projects in /project/src/
- When installing Python packages, use: pip install --break-system-packages <package>
- Extended thinking is always on — use it for complex architectural decisions

## Installed Plugins
- **frontend-design**: Production-grade UI with distinctive aesthetics (auto-activates on frontend tasks)
- **code-review**: Multi-agent PR review with confidence scoring
- **commit-commands**: Git commit, push, and PR workflows (/commit, /push, /pr)
- **security-guidance**: Security warnings when editing sensitive files
- **context7**: Live, version-specific library docs lookup (reduces API hallucinations)
- **webapp-testing**: Playwright-based browser testing for UI verification and debugging
- **superpowers**: Development workflow framework — brainstorm → plan → implement with TDD
  - /superpowers:brainstorm — Refine ideas before coding
  - /superpowers:write-plan — Create implementation plans
  - /superpowers:execute-plan — Execute plans in batches via subagents
  - Auto-activating skills: test-driven-development, systematic-debugging, verification-before-completion

---

## Projects in /project/src/

### nanoteofficial.me — Portfolio Site

**Stack**: Next.js 16 (App Router, Turbopack), React 19, TypeScript, Tailwind v4

```bash
cd /project/src/nanoteofficial.me
npm run dev        # http://localhost:3000
npm run build
npm run lint
npx tsc --noEmit   # type check only
```

See `src/nanoteofficial.me/CLAUDE.md` for full architecture notes (subdomain routing, i18n, theming, component conventions). That file is the authoritative guide for working in that repo.

**Key constraint**: This is Next.js 16 — APIs differ from training data. Use the `context7` MCP tool or read `node_modules/next/dist/docs/` before writing Next.js-specific code.

---

### personal-investment-project — Portfolio Analyzer

**Stack**: Node.js + Express, vanilla HTML/CSS/JS frontend, no build step

```bash
cd /project/src/personal-investment-project
npm run dev    # node --watch server.js — http://localhost:3000
npm start      # production
```

No tests. No TypeScript.

**Architecture**: Single-file server (`server.js`) + static frontend (`public/`). All parsing logic lives in `server.js`:

- `detectAndParse()` auto-detects file format by checking if the first cell is `"Personal Statement"`, then dispatches to either `parsePersonalStatement()` (income/investment/expense statement from XLSX) or `parsePortfolioData()` (tabular holdings with symbol/shares/cost/price columns).
- `fetchFromUrl()` handles Google Sheets and Google Drive URLs, converting share links to direct download URLs.

**API routes**:
- `POST /api/upload` — multipart file upload (XLSX or CSV)
- `POST /api/load-url` — load from Google Sheets/Drive URL
- `GET /api/template` — download a sample XLSX template

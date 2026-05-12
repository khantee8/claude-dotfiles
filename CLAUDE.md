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

## Installed Plugins
- **frontend-design**: Production-grade UI with distinctive aesthetics (auto-activates on frontend tasks)
- **code-review**: Multi-agent PR review with confidence scoring
- **commit-commands**: Git commit, push, and PR workflows (/commit, /push, /pr)
- **github**: GitHub MCP — issues, PRs, repos
- **playwright**: Browser automation and UI testing
- **context7**: Live, version-specific library docs lookup (reduces API hallucinations)
- **webapp-testing**: Playwright-based browser testing for UI verification and debugging
- **telegram**: Telegram bot integration
- **superpowers**: Development workflow framework — brainstorm → plan → implement with TDD
  - /superpowers:brainstorm — Refine ideas before coding
  - /superpowers:write-plan — Create implementation plans
  - /superpowers:execute-plan — Execute plans in batches via subagents
  - Auto-activating skills: test-driven-development, systematic-debugging, verification-before-completion
- **claude-code-setup**: Claude Code configuration helpers
- **auth0**: Auth0 integration patterns
- **cloudflare**: Cloudflare Workers, Pages, and bindings
- **vercel**: Vercel deployment, env vars, and AI SDK
- **skill-creator**: Create and improve Claude Code skills

---

## Dotfiles Repo Structure

This repo (`khantee8/claude-dotfiles`) is the source of truth for this machine's Claude Code config.

```
.claude/
  settings.json     ← single source for all Claude settings (plugins, env, permissions, theme)
  settings.local.json  ← machine-local overrides, NOT committed
  skills -> ../.agents/skills  ← symlink to custom skills directory

.agents/skills/     ← custom agent skills (tracked in skills-lock.json)
  brainstorming/
  cybersecurity-analyst/
  finance-expert/
  owasp-security-check/
  security-review/
  stock-analysis/

agents/skills/      ← find-skills only (tracked in agents/.skill-lock.json)
  find-skills/

skills-lock.json    ← registry for .agents/skills installs
setup.sh            ← restore script for new machines
```

**Key constraint**: `.claude/skills` is a symlink to `../.agents/skills`. Do not change this to point to `agents/skills` — it only contains `find-skills`.

## Updating the Dotfiles

After changing Claude Code settings on this machine:

```bash
# Settings are already at .claude/settings.json — just commit
cd /project
git add .claude/settings.json
git commit -m "update settings"
git push origin main
```

After installing a new agent skill:

```bash
cp ~/.agents/.skill-lock.json /project/agents/.skill-lock.json  # not used currently
# skills-lock.json is managed by npx skills — commit it after install
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

`setup.sh` copies `.claude/settings.json` to `~/.claude/settings.json` and reinstalls plugins via the `claude` CLI. Requires Claude Code and Node.js to be installed first.

---

## Profile Assets

`/project/Profile/` holds the user's professional assets — not part of any project's build:
- `Saksit-CV-2026-EN.pdf` / `Saksit-CV-2026-TH.pdf` — current CVs (English & Thai)
- `Profile1.JPG` / `Profile2.JPG` — profile photos

These are the source files for the portfolio site's avatar and CV download links.

---

## Projects in /project/src/

### nanoteofficial.me — Portfolio Site

**Stack**: Next.js 16 (App Router), React 19, TypeScript, Tailwind v4
**Live**: https://nanoteofficial.me (Vercel Hobby, auto-deploys from `main`)

```bash
cd /project/src/nanoteofficial.me
npm run dev        # http://localhost:3000
npm run build
npm run lint
npx tsc --noEmit   # type check only

# Docker (requires npm run build first — container runs next start, not next dev)
docker compose up -d   # http://localhost:3000
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

# Docker (auto-installs deps and runs server.js)
docker compose up -d   # http://localhost:3030 → container :3000
```

No tests. No TypeScript.

**Architecture**: Single-file server (`server.js`) + static frontend (`public/`). All parsing logic lives in `server.js`:

- `detectAndParse()` auto-detects file format by checking if the first cell is `"Personal Statement"`, then dispatches to either `parsePersonalStatement()` (income/investment/expense statement from XLSX) or `parsePortfolioData()` (tabular holdings with symbol/shares/cost/price columns).
- `fetchFromUrl()` handles Google Sheets and Google Drive URLs, converting share links to direct download URLs.

**API routes**:
- `POST /api/upload` — multipart file upload (XLSX or CSV)
- `POST /api/load-url` — load from Google Sheets/Drive URL
- `GET /api/template` — download a sample XLSX template

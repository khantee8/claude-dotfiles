---
name: base-deployment
version: 1.0.0
description: Full NaNote Finance deployment workflow — vibe-code, verify, commit with version bump, confirm Vercel production push.
category: workflow
tags: [nanote, deployment, git, vercel, finance]
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash(*)
  - Agent
  - AskUserQuestion
---

# NaNote Finance — Base Deployment Workflow

End-to-end workflow for the NaNote Finance project at `/project/src/finance.nanoteofficial.me`.

**Invoke with:** `/base-deployment`

Optionally pass a version: `/base-deployment v0.3`

---

## ARGUMENTS

`{{ARGS}}` — optional version string (e.g. `v0.3`, `v1.0`). If omitted, ask the user.

---

## Workflow

You MUST follow these phases in order. Do NOT skip a phase. Complete each fully before moving to the next.

---

### PHASE 1 — Context check

```bash
cd /project/src/finance.nanoteofficial.me
git status
git log --oneline -5
```

Read the output. Identify:
- Which files have uncommitted changes
- What the last version tag/commit message was
- Whether the working tree is clean or dirty

Report a one-line summary to the user before proceeding.

---

### PHASE 2 — Quality gates

Run both checks. Both MUST pass before any commit is made.

```bash
cd /project/src/finance.nanoteofficial.me
npx tsc --noEmit
```

```bash
cd /project/src/finance.nanoteofficial.me
npm run build
```

If either fails:
- Show the errors clearly
- Fix them (you have Write/Edit access)
- Re-run the failing check
- Do NOT proceed until both pass

---

### PHASE 3 — Version

If `{{ARGS}}` contains a version string (e.g. `v0.3`), use it.

Otherwise ask:

> "What version should I tag this release? (e.g. `v0.3`, `v0.3.1`)"

Wait for the user's answer before continuing.

---

### PHASE 4 — Stage and preview diff

```bash
cd /project/src/finance.nanoteofficial.me
git diff --stat HEAD
```

Show the user which files will be committed. Confirm they look right before staging.

Stage all modified tracked files:

```bash
cd /project/src/finance.nanoteofficial.me
git add -u
```

If there are new untracked files that belong to the release, ask the user whether to include them, then `git add <file>` individually (never `git add .` blindly).

---

### PHASE 5 — Commit

Write a commit message in this format:

```
feat: <version> — <short summary of what changed>

<bullet list of key changes, one per line>

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

Example:
```
feat: v0.3 — dark mode, client onboarding flow, scenario comparison

- Dark mode toggle persists via localStorage
- New client onboarding wizard (3 steps)
- Scenario comparison table with delta highlighting

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

Commit using a HEREDOC to preserve formatting:

```bash
cd /project/src/finance.nanoteofficial.me
git commit -m "$(cat <<'EOF'
<message here>
EOF
)"
```

Show the user the commit hash after success.

---

### PHASE 6 — Production push confirmation

**STOP. Ask the user explicitly before pushing:**

> "Ready to push `<version>` to `main`? This will trigger an automatic Vercel production deploy to **finance.nanoteofficial.me**.
>
> Confirm? (yes / no)"

If the user says **no** — stop here. Tell them the commit is local and they can push later with `git push origin main`.

If the user says **yes** — proceed to Phase 7.

---

### PHASE 7 — Push and verify

```bash
cd /project/src/finance.nanoteofficial.me
git push origin main
```

After push succeeds, verify the production endpoint is responding:

```bash
curl -s -o /dev/null -w "%{http_code}" https://finance.nanoteofficial.me
```

Report the result:
- `200` → "✅ finance.nanoteofficial.me is live — Vercel deploy in progress (usually 30–60s)"
- Other → "⚠️ Got HTTP `<code>` — check Vercel dashboard for build errors"

---

## Quick reference

| Gate | Command |
|---|---|
| Type check | `npx tsc --noEmit` |
| Build | `npm run build` |
| Status | `git status` |
| Push | `git push origin main` |
| Production | https://finance.nanoteofficial.me |

## Project conventions (always follow these)

- **No Tailwind utilities** in screen components — use CSS custom properties and classes from `globals.css`
- **No new formatters** — use `DATA.fmt.money()`, `DATA.fmt.pct()` etc.
- **No new chart libraries** — all charts are pure SVG via `components/ui.tsx`
- **Mock data only** — all data changes go in `lib/data.ts`
- **Type-check before every commit** — `npx tsc --noEmit` must be clean
- **AI route is disabled** until v1 — do not re-enable without explicit instruction
- **Three views** — advisor / client / admin. New screens added to the correct nav array in `Shell.tsx` and routed in `app/page.tsx`

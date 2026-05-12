# claude-dotfiles

Personal Claude Code configuration backup — plugins, settings, and agent skills.

## What's included

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Workspace instructions for Claude Code — projects, commands, architecture |
| `claude/settings.json` | Claude Code settings: env vars, permissions, plugins, theme |
| `agents/.skill-lock.json` | Installed agent skills registry |
| `agents/skills/find-skills/SKILL.md` | find-skills agent skill |

## Plugins (re-installed by setup.sh)

- `frontend-design` — Production-grade UI generation
- `code-review` — Multi-agent PR review
- `commit-commands` — Git commit/push/PR workflows
- `security-guidance` — Security warnings for sensitive files
- `context7` — Live library docs lookup
- `webapp-testing` — Playwright browser testing
- `superpowers` — Brainstorm → plan → implement framework

## Restore on a new machine

```bash
# 1. Install Claude Code
#    https://claude.ai/code

# 2. Clone this repo
git clone https://github.com/khantee8/claude-dotfiles.git
cd claude-dotfiles

# 3. Run setup
chmod +x setup.sh
./setup.sh
```

## Update this backup

Run from this repo directory after changing your Claude Code settings:

```bash
cp ~/.claude/settings.json claude/settings.json
cp ~/.agents/.skill-lock.json agents/.skill-lock.json
git add -A && git commit -m "update config" && git push
```

# claude-dotfiles

Personal Claude Code configuration backup — plugins, settings, and agent skills.

## What's included

| File/Dir | Purpose |
|---|---|
| `CLAUDE.md` | Workspace instructions for Claude Code — projects, commands, architecture |
| `.claude/settings.json` | All Claude Code settings: env vars, permissions, plugins, theme |
| `.agents/skills/` | Custom agent skills (brainstorming, cybersecurity, finance, owasp, security-review, stock-analysis) |
| `agents/skills/find-skills/` | find-skills agent skill |
| `skills-lock.json` | Registry for `.agents/skills` installs |
| `setup.sh` | Restore script for new machines |

## Plugins

Managed via `enabledPlugins` in `.claude/settings.json`:

`frontend-design` · `code-review` · `commit-commands` · `github` · `playwright` · `telegram` · `superpowers` · `claude-code-setup` · `auth0` · `cloudflare` · `vercel` · `skill-creator`

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

## Update after changing settings

```bash
cd /project
git add .claude/settings.json skills-lock.json
git commit -m "update config"
git push origin main
```

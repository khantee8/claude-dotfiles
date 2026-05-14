#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
AGENTS_DIR="$HOME/.agents"

echo "Setting up Claude Code config from dotfiles..."

# ── Claude settings ──────────────────────────────────────────────────────────
mkdir -p "$CLAUDE_DIR"
if [ -f "$CLAUDE_DIR/settings.json" ]; then
  cp "$CLAUDE_DIR/settings.json" "$CLAUDE_DIR/settings.json.bak"
  echo "  Backed up existing settings.json → settings.json.bak"
fi
cp "$REPO_DIR/.claude/settings.json" "$CLAUDE_DIR/settings.json"
echo "  ✓ Claude settings installed"

# ── Agent skills ─────────────────────────────────────────────────────────────
mkdir -p "$AGENTS_DIR/skills/find-skills"
cp "$REPO_DIR/agents/.skill-lock.json" "$AGENTS_DIR/.skill-lock.json"
cp "$REPO_DIR/agents/skills/find-skills/SKILL.md" "$AGENTS_DIR/skills/find-skills/SKILL.md"
echo "  ✓ Agent skills installed"

# ── Custom Claude skills → ~/.claude/skills ──────────────────────────────────
mkdir -p "$CLAUDE_DIR/skills"
for skill_dir in "$REPO_DIR/.agents/skills"/*/; do
  skill_name="$(basename "$skill_dir")"
  cp -r "$skill_dir" "$CLAUDE_DIR/skills/$skill_name"
  echo "  ✓ Claude skill installed: $skill_name"
done

# ── Re-install Claude plugins ─────────────────────────────────────────────────
if command -v claude &>/dev/null; then
  echo ""
  echo "Re-installing Claude Code plugins..."
  claude plugin install frontend-design@claude-code-plugins      --yes 2>/dev/null && echo "  ✓ frontend-design"       || echo "  ✗ frontend-design (skipped)"
  claude plugin install code-review@claude-code-plugins          --yes 2>/dev/null && echo "  ✓ code-review"           || echo "  ✗ code-review (skipped)"
  claude plugin install commit-commands@claude-code-plugins       --yes 2>/dev/null && echo "  ✓ commit-commands"       || echo "  ✗ commit-commands (skipped)"
  claude plugin install security-guidance@claude-code-plugins     --yes 2>/dev/null && echo "  ✓ security-guidance"     || echo "  ✗ security-guidance (skipped)"
  claude plugin install context7@claude-plugins-official          --yes 2>/dev/null && echo "  ✓ context7"              || echo "  ✗ context7 (skipped)"
  claude plugin install webapp-testing@anthropic-agent-skills    --yes 2>/dev/null && echo "  ✓ webapp-testing"        || echo "  ✗ webapp-testing (skipped)"
  claude plugin install superpowers@superpowers-marketplace       --yes 2>/dev/null && echo "  ✓ superpowers"           || echo "  ✗ superpowers (skipped)"
else
  echo ""
  echo "  ⚠  'claude' CLI not found — install Claude Code first, then re-run this script."
  echo "     https://claude.ai/code"
fi

# ── Re-install agent skills via npx skills ────────────────────────────────────
if command -v npx &>/dev/null; then
  echo ""
  echo "Re-installing agent skills..."
  npx skills add vercel-labs/skills@find-skills -g -y 2>/dev/null && echo "  ✓ find-skills" || echo "  ✗ find-skills (skipped)"
else
  echo ""
  echo "  ⚠  'npx' not found — install Node.js to restore agent skills."
fi

echo ""
echo "Done! Restart Claude Code to apply the new settings."

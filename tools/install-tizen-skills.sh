#!/usr/bin/env bash
# Install Samsung's tizen-sdk-skills for Claude Code into this project.
#   npm run tizen-skills
#
# Fetches Samsung/tizen-agent-skills at a pinned commit into vendor/, runs
# Samsung's installer with HOME set to a temporary folder (so it cannot touch
# the real ~/.claude), then copies:
#   skills, agents, hook scripts  -> .claude/        (gitignored)
#   hook registration             -> .claude/settings.local.json
#   runner cache                  -> ~/.claude/plugins/cache/tizen-platform/
# The skills find their runner scripts in that cache, so it must be global.
# Needs git, bash, rsync and Node 22+.
set -euo pipefail

REPO=https://github.com/Samsung/tizen-agent-skills.git
REF=6e66798ac8ddbf693ab3d160c790f6f32ca730a2 # plugin version 1.7.0; no upstream tag for it

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/vendor/tizen-agent-skills"
CLAUDE="$ROOT/.claude"

if [ "$(git -C "$SRC" rev-parse HEAD 2>/dev/null || true)" != "$REF" ]; then
  echo "Fetching tizen-agent-skills $REF"
  rm -rf "$SRC"
  git init -q "$SRC"
  git -C "$SRC" fetch -q --depth 1 "$REPO" "$REF"
  git -C "$SRC" checkout -q FETCH_HEAD
fi

TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT
echo "Running Samsung's installer into a temporary HOME"
HOME="$TMP_HOME" bash "$SRC/tizen-sdk-skills/claude/setup/setup.sh" --no-restart >"$TMP_HOME/setup.log" 2>&1 || {
  cat "$TMP_HOME/setup.log" >&2
  exit 1
}
T="$TMP_HOME/.claude"

mkdir -p "$CLAUDE/skills" "$CLAUDE/agents" "$CLAUDE/hooks" "$HOME/.claude/plugins/cache/tizen-platform"
rm -rf "$CLAUDE"/skills/tizen-* "$CLAUDE"/agents/tizen-*.md "$CLAUDE/hooks/tizen-sdk-skills"
cp -R "$T"/skills/tizen-* "$CLAUDE/skills/"
cp "$T"/agents/tizen-*.md "$CLAUDE/agents/"
cp -R "$T/hooks/tizen-sdk-skills" "$CLAUDE/hooks/"
rsync -a --delete "$T/plugins/cache/tizen-platform/tizen-sdk-skills/" "$HOME/.claude/plugins/cache/tizen-platform/tizen-sdk-skills/"

# Register the hooks in settings.local.json, keeping every other setting.
# Each hook exits 0 when its script is missing, so a clone without this
# install is not blocked.
node - "$CLAUDE/settings.local.json" <<'EOF'
const fs = require('fs');
const file = process.argv[2];
const settings = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : {};
const dir = '$CLAUDE_PROJECT_DIR/.claude/hooks/tizen-sdk-skills';
const run = (cmd, script, args = '') => `f="${dir}/${script}"; [ -f "$f" ] || exit 0; ${cmd} "$f"${args}`;
const ours = e => JSON.stringify(e).includes('tizen-sdk-skills');
settings.hooks = settings.hooks || {};
const add = (event, entries) => {
  settings.hooks[event] = (settings.hooks[event] || []).filter(e => !ours(e)).concat(entries);
};
add('PreToolUse', [
  { matcher: 'Bash|PowerShell', hooks: [{ type: 'command', command: run('bash', 'check-tizen-commands.sh') }] },
  { matcher: 'Write|Bash|PowerShell', hooks: [{ type: 'command', command: run('bash', 'check-project-writes.sh') }] },
  { matcher: 'Skill|Agent|Task', hooks: [{ type: 'command', command: run('bash', 'check-skill-routing.sh') }] },
]);
add('SessionStart', [
  {
    matcher: 'startup',
    hooks: [
      {
        type: 'command',
        timeout: 20,
        command: run('node', 'check-update.js', ' --host claude --cache-root "$HOME/.claude/plugins/cache/tizen-platform"'),
      },
    ],
  },
]);
fs.writeFileSync(file, JSON.stringify(settings, null, 2) + '\n');
EOF

echo "Installed $(ls -d "$CLAUDE"/skills/tizen-* | wc -l | tr -d ' ') skills and $(ls "$CLAUDE"/agents/tizen-*.md | wc -l | tr -d ' ') agents. Restart Claude Code to load them."

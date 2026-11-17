#!/usr/bin/env bash
# ccp tests: a stub `claude` stands in for Claude Code, HOME is a temp folder. Run: bash tests/test.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
T="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/ccp-test.XXXXXX")" && pwd -P)"   # real path: macOS /var is a link
trap 'rm -rf "$T"' EXIT
export HOME="$T/home"; mkdir -p "$HOME/.claude/agents" "$T/bin"
unset CCP_PROFILE CLAUDE_CONFIG_DIR CCP_HOME CCP_BASE
echo '{"model":"x"}' > "$HOME/.claude/settings.json"
echo '# mine' > "$HOME/.claude/CLAUDE.md"
echo '{"mcpServers":{"docs":{"command":"docs-mcp"}},"oauthAccount":{"emailAddress":"me@x.com"}}' > "$HOME/.claude.json"
cat > "$T/bin/claude" <<'EOF'
#!/bin/bash
cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
case "$1 ${2:-}" in
  "auth status")
    if [ -f "$cfg/.stub-login" ]; then printf '{"loggedIn": true, "email": "%s@x.com", "subscriptionType": "max", "authMethod": "claude.ai"}\n' "$(basename "${CLAUDE_CONFIG_DIR:-default}")"
    else echo '{"loggedIn": false}'; exit 1; fi ;;
  "auth login") shift 2; echo "$*" > "$cfg/.stub-login" ;;
  "auth logout") rm -f "$cfg/.stub-login"; echo "logout ${CLAUDE_CONFIG_DIR:-default}" >> "$HOME/stub.log" ;;
  *) echo "CONFIG=${CLAUDE_CONFIG_DIR:-unset} ARGS=$*" ;;
esac
EOF
chmod +x "$T/bin/claude"
export CCP_CLAUDE="$T/bin/claude"
ccp() { /bin/bash "$ROOT/ccp" "$@"; }
P="$HOME/.claude-profiles"

pass=0; fail=0
ok() { if eval "$2"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1"; echo "      $2"; fi; }
has() { case "$1" in *"$2"*) return 0 ;; esac; echo "      got: $1" >&2; return 1; }

cd "$HOME"
out="$(ccp ls)"
ok "ls: only the default profile at first" 'has "$out" "* default" && has "$out" "not logged in"'

out="$(ccp add work --email w@x.com)"
ok "add: makes the folder and marker" '[ -f "$P/work/.ccp" ]'
ok "add: shares settings, CLAUDE.md, agents" '[ "$(readlink "$P/work/settings.json")" = "$HOME/.claude/settings.json" ] && [ -L "$P/work/CLAUDE.md" ] && [ -L "$P/work/agents" ]'
ok "add: shares project history (made if missing)" '[ -d "$HOME/.claude/projects" ] && [ "$(readlink "$P/work/projects")" = "$HOME/.claude/projects" ]'
ok "add: no link for what ~/.claude does not have" '[ ! -e "$P/work/skills" ] && [ ! -L "$P/work/skills" ]'
ok "add: copies user MCP servers, not the account" 'grep -q docs-mcp "$P/work/.claude.json" && ! grep -q oauthAccount "$P/work/.claude.json"'
ok "add: signs in with that profile's folder and options" '[ "$(cat "$P/work/.stub-login")" = "--email w@x.com" ]'
ok "add: private folders" '[ "$(ls -ld "$P/work" | cut -c1-10)" = drwx------ ]'

ccp add solo --isolated --no-login >/dev/null
ok "add --isolated: nothing shared" '[ -f "$P/solo/.ccp" ] && [ ! -e "$P/solo/settings.json" ] && [ ! -e "$P/solo/.claude.json" ]'
ok "add: refuses default, bad names, duplicates" '! ccp add default 2>/dev/null && ! ccp add "a b" 2>/dev/null && ! ccp add ../x 2>/dev/null && ! ccp add work --no-login 2>/dev/null'

ok "run: default profile leaves CLAUDE_CONFIG_DIR unset" '[ "$(ccp run -- hi there)" = "CONFIG=unset ARGS=hi there" ]'
ok "run: an inherited CLAUDE_CONFIG_DIR does not leak into default" '[ "$(CLAUDE_CONFIG_DIR=/elsewhere ccp run -- x)" = "CONFIG=unset ARGS=x" ]'
ccp use work >/dev/null
ok "use: default everywhere" '[ "$(ccp run -- x)" = "CONFIG=$P/work ARGS=x" ]'
ok "run -p: one-off profile" '[ "$(ccp run -p solo -- x)" = "CONFIG=$P/solo ARGS=x" ]'
ok "run: unknown profile fails" '! ccp run -p nope -- x 2>/dev/null'

mkdir -p "$HOME/w/a/b" "$HOME/w/x" "$HOME/w2" "$HOME/other"
ccp here solo "$HOME/w" >/dev/null
ccp here default "$HOME/w/a" >/dev/null
ok "here: rule covers the folders in it" '[ "$(cd "$HOME/w/x" && ccp run -- x)" = "CONFIG=$P/solo ARGS=x" ]'
ok "here: the longest rule wins" '[ "$(cd "$HOME/w/a/b" && ccp run -- x)" = "CONFIG=unset ARGS=x" ]'
ok "here: /w does not cover /w2" '[ "$(cd "$HOME/w2" && ccp run -- x)" = "CONFIG=$P/work ARGS=x" ]'
ok "CCP_PROFILE beats rules" '[ "$(cd "$HOME/w/a/b" && CCP_PROFILE=solo ccp run -- x)" = "CONFIG=$P/solo ARGS=x" ]'
ln -s "$HOME/w" "$HOME/wlink"
ok "here: a symlinked path finds the real folder's rule" '[ "$(cd "$HOME/wlink/x" && ccp run -- x)" = "CONFIG=$P/solo ARGS=x" ]'
ccp here solo "$HOME/w" >/dev/null
ok "here: setting a rule again replaces it" '[ "$(grep -c "^$HOME/w	" "$P/rules")" = 1 ]'
out="$(cd "$HOME/w/x" && ccp which)"
ok "which: names the profile and the rule" 'has "$out" "solo  (folder rule $HOME/w)" && has "$out" "config: $P/solo"'

out="$(ccp ls)"
ok "ls: account and plan per profile" 'has "$out" "work@x.com" && has "$out" "max" && has "$out" "(isolated)"'
ok "ls: marks the profile used here" 'has "$out" "* work"'

eval "$(ccp env solo)"
ok "env: pins the shell" '[ "$CLAUDE_CONFIG_DIR" = "$P/solo" ] && [ "$CCP_PROFILE" = solo ]'
unset CLAUDE_CONFIG_DIR CCP_PROFILE
ok "init: defines claude() over ccp run" 'has "$(ccp init zsh)" "claude() { command ccp run -- \"\$@\"; }"'
ok "prompt: empty for default, the name otherwise" '[ "$(cd "$HOME/w/a" && ccp prompt)" = "" ] && [ "$(cd "$HOME/w/x" && ccp prompt)" = solo ]'

ok "rm: needs --yes without a terminal" '! ccp rm work </dev/null 2>/dev/null && [ -d "$P/work" ]'
ccp here work "$HOME/other" >/dev/null
ccp rm work --yes >/dev/null
ok "rm: signs out and deletes the profile" '[ ! -e "$P/work" ] && grep -q "logout $P/work" "$HOME/stub.log"'
ok "rm: shared files stay in ~/.claude" '[ -f "$HOME/.claude/settings.json" ] && [ -f "$HOME/.claude/CLAUDE.md" ] && [ -d "$HOME/.claude/agents" ]'
ok "rm: its rules and default go" '! grep -q "	work$" "$P/rules" && [ ! -e "$P/default" ]'
ok "rm: never the default profile" '! ccp rm default --yes 2>/dev/null'

ok "help and version" 'has "$(ccp help)" "ccp add" && has "$(ccp --version)" "ccp "'

echo "$pass passed, $fail failed"
[ "$fail" = 0 ]

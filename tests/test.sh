#!/usr/bin/env bash
# shellcheck disable=SC2034  # P, out and friends are read inside the ok() checks, which eval their condition
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
[ "${1:-}" = active ] && { echo "ACTIVE=${CCP_ACTIVE:-}"; exit 0; }
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
cfg_of() { ccp run -p "$1" -- x | sed 's/^CONFIG=//; s/ ARGS=x$//'; }   # config folder a profile runs with
order() { tr '\n' ' ' < "$P/order"; }

pass=0; fail=0
ok() { if eval "$2"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1"; echo "      $2"; fi; }
has() { case "$1" in *"$2"*) return 0 ;; esac; echo "      got: $1" >&2; return 1; }

cd "$HOME" || exit 1
out="$(ccp ls)"
ok "ls: only #1, the default profile, at first" 'has "$out" "* 1   -" && has "$out" "not logged in" && has "$out" "default (~/.claude)"'

out="$(ccp add --email w@x.com)"
ok "add: no name needed, goes to the end as #2" 'has "$out" "#2 → $P/acct-2" && [ -f "$P/acct-2/.ccp" ]'
ok "add: shares settings, CLAUDE.md, agents" '[ "$(readlink "$P/acct-2/settings.json")" = "$HOME/.claude/settings.json" ] && [ -L "$P/acct-2/CLAUDE.md" ] && [ -L "$P/acct-2/agents" ]'
ok "add: shares project history (made if missing)" '[ -d "$HOME/.claude/projects" ] && [ "$(readlink "$P/acct-2/projects")" = "$HOME/.claude/projects" ]'
ok "add: no link for what ~/.claude does not have" '[ ! -e "$P/acct-2/skills" ] && [ ! -L "$P/acct-2/skills" ]'
ok "add: copies user MCP servers, not the account" 'grep -q docs-mcp "$P/acct-2/.claude.json" && ! grep -q oauthAccount "$P/acct-2/.claude.json"'
ok "add: signs in with that profile's folder and options" '[ "$(cat "$P/acct-2/.stub-login")" = "--email w@x.com" ]'
ok "add: private folders" '[ "$(ls -ld "$P/acct-2" | cut -c1-10)" = drwx------ ] && [ "$(ls -ld "$P" | cut -c1-10)" = drwx------ ]'

ccp add work --no-login >/dev/null
ccp add --isolated --no-login >/dev/null
ok "add: a name is optional; numbers follow the order" '[ "$(order)" = "default acct-2 work acct-3 " ]'
ok "add --isolated: nothing shared" '[ ! -e "$P/acct-3/settings.json" ] && [ ! -e "$P/acct-3/.claude.json" ]'

out="$(ccp add -2 --no-login)"
ok "add -2: goes in at #2 and the rest move down" 'has "$out" "#2 → $P/acct-4" && [ "$(order)" = "default acct-4 acct-2 work acct-3 " ]'
ok "numbers pick profiles in the new order" '[ "$(cfg_of 2)" = "$P/acct-4" ] && [ "$(cfg_of 3)" = "$P/acct-2" ] && [ "$(cfg_of 5)" = "$P/acct-3" ] && [ "$(cfg_of 1)" = unset ]'
ok "names still work" '[ "$(cfg_of work)" = "$P/work" ]'
ok "folders keep their first name (a login is tied to the path)" '[ -f "$P/acct-2/.stub-login" ]'
ok "add: refuses default, bad names, number-only names, duplicates, position 0" '! ccp add default 2>/dev/null && ! ccp add "a b" 2>/dev/null && ! ccp add ../x 2>/dev/null && ! ccp add 123 --no-login 2>/dev/null && ! ccp add work --no-login 2>/dev/null && ! ccp add -0 --no-login 2>/dev/null'
ok "add: a position past the end means last" 'ccp add -99 --no-login >/dev/null && [ "$(order)" = "default acct-4 acct-2 work acct-3 acct-5 " ]'

ok "run: #1 leaves CLAUDE_CONFIG_DIR unset" '[ "$(ccp run -- hi there)" = "CONFIG=unset ARGS=hi there" ]'
ok "run: an inherited CLAUDE_CONFIG_DIR does not leak into #1" '[ "$(CLAUDE_CONFIG_DIR=/elsewhere ccp run -- x)" = "CONFIG=unset ARGS=x" ]'
ok "run: unknown profile fails and runs nothing" '! ccp run -p 42 -- x 2>/dev/null && ! ccp run -p nope -- x 2>/dev/null && [ -z "$(ccp run -p 42 -- x 2>/dev/null)" ]'

ccp use work >/dev/null
ok "use: default everywhere" '[ "$(ccp run -- x)" = "CONFIG=$P/work ARGS=x" ]'

mkdir -p "$HOME/w/a/b" "$HOME/w/x" "$HOME/w2"
ccp here 3 "$HOME/w" >/dev/null          # #3 is acct-2
ccp here 1 "$HOME/w/a" >/dev/null
ok "here: rule covers the folders in it" '[ "$(cd "$HOME/w/x" && ccp run -- x)" = "CONFIG=$P/acct-2 ARGS=x" ]'
ok "here: the longest rule wins" '[ "$(cd "$HOME/w/a/b" && ccp run -- x)" = "CONFIG=unset ARGS=x" ]'
ok "here: /w does not cover /w2" '[ "$(cd "$HOME/w2" && ccp run -- x)" = "CONFIG=$P/work ARGS=x" ]'
ok "CCP_PROFILE beats rules, by number too" '[ "$(cd "$HOME/w/a/b" && CCP_PROFILE=2 ccp run -- x)" = "CONFIG=$P/acct-4 ARGS=x" ]'
ln -s "$HOME/w" "$HOME/wlink"
ok "here: a symlinked path finds the real folder's rule" '[ "$(cd "$HOME/wlink/x" && ccp run -- x)" = "CONFIG=$P/acct-2 ARGS=x" ]'
ccp here acct-2 "$HOME/w" >/dev/null
ok "here: setting a rule again replaces it" '[ "$(grep -c "^$HOME/w	" "$P/rules")" = 1 ]'

ccp add -1 --no-login >/dev/null         # acct-6 becomes #1; everyone else moves down
ok "rules and the default follow the account, not the number" '[ "$(cd "$HOME/w/x" && ccp run -- x)" = "CONFIG=$P/acct-2 ARGS=x" ] && [ "$(cd "$HOME/w2" && ccp run -- x)" = "CONFIG=$P/work ARGS=x" ]'
ccp mv acct-6 99 >/dev/null
ok "mv: moves a profile to a number" '[ "$(order)" = "default acct-4 acct-2 work acct-3 acct-5 acct-6 " ]'
ccp mv 5 2 >/dev/null
ok "mv: by number" '[ "$(order)" = "default acct-3 acct-4 acct-2 work acct-5 acct-6 " ]'

out="$(cd "$HOME/w/x" && ccp which)"
ok "which: names the number and the rule" 'has "$out" "#4  (folder rule $HOME/w)" && has "$out" "config: $P/acct-2"'
out="$(ccp ls)"
ok "ls: numbered, with account and plan" 'has "$out" "  4   acct-2@x.com" && has "$out" "max" && has "$out" "acct-3 (isolated)"'
ok "ls: marks the profile used here" 'has "$out" "* 5   -"'
ok "ls: rules show the number" 'has "$out" "$HOME/w → #4"'

eval "$(ccp env 3)"
ok "env: pins the shell (by number)" '[ "$CLAUDE_CONFIG_DIR" = "$P/acct-4" ] && [ "$CCP_PROFILE" = acct-4 ]'
unset CLAUDE_CONFIG_DIR CCP_PROFILE
ok "sw: continues the last conversation on another account" '[ "$(ccp sw 3)" = "CONFIG=$P/acct-4 ARGS=--continue" ] && [ "$(ccp sw work -- --resume abc)" = "CONFIG=$P/work ARGS=--resume abc" ]'
ok "run: tells Claude Code which account it runs on" '[ "$(ccp run -p 3 -- active)" = "ACTIVE=acct-4" ] && [ "$(ccp run -p 1 -- active)" = "ACTIVE=default" ]'
ok "prompt: inside Claude Code, the running account (even #1)" '[ "$(CCP_ACTIVE=acct-4 ccp prompt)" = "#3" ] && [ "$(CCP_ACTIVE=default ccp prompt)" = "#1 default" ] && [ "$(CCP_ACTIVE=work ccp prompt)" = "#5 work" ]'
ok "init: defines claude() over ccp run" 'has "$(ccp init zsh)" "claude() { command ccp run -- \"\$@\"; }"'
ok "prompt: empty for #1, the number (and name) otherwise" '[ "$(cd "$HOME/w/a" && ccp prompt)" = "" ] && [ "$(cd "$HOME/w/x" && ccp prompt)" = "#4" ] && [ "$(cd "$HOME/w2" && ccp prompt)" = "#5 work" ]'

ok "rm: needs --yes without a terminal" '! ccp rm 4 </dev/null 2>/dev/null && [ -d "$P/acct-2" ]'
out="$(ccp rm 4 --yes)"
ok "rm: by number; signs out and deletes" 'has "$out" "removed #4" && [ ! -e "$P/acct-2" ] && grep -q "logout $P/acct-2" "$HOME/stub.log"'
ok "rm: the rest move up" '[ "$(order)" = "default acct-3 acct-4 work acct-5 acct-6 " ]'
ok "rm: shared files stay in ~/.claude" '[ -f "$HOME/.claude/settings.json" ] && [ -f "$HOME/.claude/CLAUDE.md" ] && [ -d "$HOME/.claude/agents" ]'
ok "rm: its rules go" '! grep -q "	acct-2$" "$P/rules"'
ccp rm work --yes >/dev/null
ok "rm: the default goes back to #1" '[ ! -e "$P/default" ] && [ "$(cd "$HOME/w2" && ccp run -- x)" = "CONFIG=unset ARGS=x" ]'
ok "rm: never #1" '! ccp rm 1 --yes 2>/dev/null && ! ccp rm default --yes 2>/dev/null'
ccp add --no-login >/dev/null
ok "a removed folder name is never reused" '[ -f "$P/acct-7/.ccp" ] && [ ! -e "$P/acct-2" ]'

# usage: a fake usage endpoint and sign-ins in the files Claude Code uses on Linux (keychain skipped)
PORT_FILE="$T/port"
cat > "$T/srv.py" <<'EOF'
import http.server, json, socketserver, sys
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        tok = self.headers.get("Authorization", "")
        body = {"Bearer tok-1": {"limits": [{"kind": "weekly_all", "percent": 48, "resets_at": "2099-01-01T00:00:00+00:00"},
                                            {"kind": "weekly_scoped", "percent": 0, "resets_at": "2099-01-01T00:00:00+00:00", "scope": {"model": {"display_name": "Fable"}}}],
                                 "five_hour": {"utilization": 91.0, "resets_at": "2099-01-01T00:00:00Z"}},
                "Bearer tok-3": {"seven_day": {"utilization": 12.0, "resets_at": "2099-01-01T00:00:00Z"}}}.get(tok)
        if self.headers.get("anthropic-beta") != "oauth-2025-04-20" or body is None:
            self.send_response(401); self.end_headers(); return
        self.send_response(200); self.end_headers(); self.wfile.write(json.dumps(body).encode())
    def log_message(self, *a): pass
class S(http.server.HTTPServer):
    def server_bind(self):   # skip HTTPServer's getfqdn(): reverse DNS can hang for long on CI Macs
        socketserver.TCPServer.server_bind(self)
        self.server_name, self.server_port = self.server_address[:2]
s = S(("127.0.0.1", 0), H)
open(sys.argv[1], "w").write(str(s.server_port))
s.serve_forever()
EOF
python3 "$T/srv.py" "$PORT_FILE" >"$T/srv.log" 2>&1 &   # a file, not a heredoc on a background job (bash 3.2)
SRV=$!
i=0; while [ ! -s "$PORT_FILE" ] && [ "$i" -lt 100 ]; do sleep 0.2; i=$((i + 1)); done   # a cold python3 can take seconds
[ -s "$PORT_FILE" ] || { echo "fake usage endpoint did not start:"; cat "$T/srv.log"; }
CCP_USAGE_URL="http://127.0.0.1:$(cat "$PORT_FILE")/usage"
export CCP_NO_KEYCHAIN=1 CCP_USAGE_URL
export no_proxy=127.0.0.1,localhost NO_PROXY=127.0.0.1,localhost   # macOS runners: urllib would follow the system proxy
future=$(( ($(date +%s) + 86400) * 1000 ))
echo "{\"claudeAiOauth\":{\"accessToken\":\"tok-1\",\"expiresAt\":$future,\"subscriptionType\":\"max\",\"rateLimitTier\":\"default_claude_max_20x\"}}" > "$HOME/.claude/.credentials.json"
echo '{"oauthAccount":{"emailAddress":"me@x.com"}}' > "$HOME/.claude.json.usage"; cp "$HOME/.claude.json.usage" "$HOME/.claude.json"
echo "{\"claudeAiOauth\":{\"accessToken\":\"tok-3\",\"expiresAt\":$future,\"subscriptionType\":\"pro\"}}" > "$P/acct-4/.credentials.json"
echo '{"oauthAccount":{"emailAddress":"four@x.com"}}' > "$P/acct-4/.claude.json"
echo '{"claudeAiOauth":{"accessToken":"tok-old","expiresAt":1000,"subscriptionType":"pro"}}' > "$P/acct-5/.credentials.json"
echo "{\"claudeAiOauth\":{\"accessToken\":\"tok-bad\",\"expiresAt\":$future}}" > "$P/acct-6/.credentials.json"
out="$(ccp usage)"
ok "usage: limits per account, used and left, 5-hour first" 'has "$out" "me@x.com" && has "$out" "max 20x" && has "$out" "5-hour" && has "$out" " 91%     9%" && has "$out" "week           " && has "$out" " 48%    52%" && has "$out" "week · Fable"'
ok "usage: the older response shape works too" 'has "$out" "four@x.com" && has "$out" " 12%    88%"'
ok "usage: expired and rejected sign-ins say what to do" 'has "$out" "sign-in expired: open #4 once" && has "$out" "sign-in expired: open #5 once"'
ok "usage: accounts without a sign-in" 'has "$out" "not logged in"'
ok "usage: never shows a token" '! has "$out" "tok-" 2>/dev/null'
ok "usage: marks the account used here" 'has "$out" "* 1 "'
js="$(ccp usage --json)"
ok "usage --json: for scripts, still no token" 'has "$js" "\"used\": 48.0" && ! has "$js" "tok-" 2>/dev/null'
ok "top: without a terminal prints once" 'has "$(ccp top </dev/null)" "me@x.com"'
{ kill "$SRV"; wait "$SRV"; } 2>/dev/null

V="$(sed -n 's/^VERSION="\(.*\)"/\1/p' "$ROOT/ccp")"
ok "plugin ships the same ccp, one version everywhere" 'cmp -s "$ROOT/ccp" "$ROOT/plugin/bin/ccp" && grep -q "\"version\": \"$V\"" "$ROOT/plugin/.claude-plugin/plugin.json" && grep -q "version \"$V\"" "$ROOT/Formula/ccp.rb" && grep -q "download/v$V/ccp" "$ROOT/Formula/ccp.rb"'

ok "help and version" 'has "$(ccp help)" "ccp add" && has "$(ccp --version)" "ccp 0.4"'

echo "$pass passed, $fail failed"
[ "$fail" = 0 ]

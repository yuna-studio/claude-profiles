#!/usr/bin/env bash
# shellcheck disable=SC2034  # P, out and friends are read inside the ok() checks, which eval their condition
# ccp tests: a stub `claude` stands in for Claude Code, HOME is a temp folder. Run: bash tests/test.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
T="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/ccp-test.XXXXXX")" && pwd -P)"   # real path: macOS /var is a link
trap 'rm -rf "$T"' EXIT
export HOME="$T/home"; mkdir -p "$HOME/.claude/agents" "$T/bin"
unset CCP_PROFILE CLAUDE_CONFIG_DIR CCP_HOME CCP_BASE CLAUDECODE CCP_RUN CCP_ACTIVE NO_COLOR CLAUDE_JOB_DIR
export CCP_NO_KEYCHAIN=1   # sign-ins in files, never the real keychain: ccp use swaps them
export CCP_LANG=en
echo '{"model":"x"}' > "$HOME/.claude/settings.json"
echo '# mine' > "$HOME/.claude/CLAUDE.md"
echo '{"mcpServers":{"docs":{"command":"docs-mcp"}},"oauthAccount":{"emailAddress":"me@x.com"}}' > "$HOME/.claude.json"
cat > "$T/bin/claude" <<'EOF'
#!/bin/bash
cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
[ "${1:-}" = active ] && { echo "ACTIVE=${CCP_ACTIVE:-}"; exit 0; }
case "${1:-}" in   # background sessions: stop, --bg --resume, agents
  stop) echo "stop $2 CONFIG=${CLAUDE_CONFIG_DIR:-unset}" >> "$HOME/stub.log"; kill "$(cat "$cfg/stub-bg.pid" 2>/dev/null)" 2>/dev/null; exit 0 ;;
  rm) echo "rm $2 CONFIG=${CLAUDE_CONFIG_DIR:-unset}" >> "$HOME/stub.log"; exit 0 ;;
  --bg) case "${CLAUDE_CONFIG_DIR:-}" in *acct-5) echo "Workspace not trusted"; exit 1 ;; esac
        echo "bg-resume $3 CONFIG=${CLAUDE_CONFIG_DIR:-unset} FLAGS=${*:4}" >> "$HOME/stub.log"; echo "${3%%-*}" >> "$cfg/stub-agents"
        echo "backgrounded · ${3%%-*}"; exit 0 ;;
  daemon) echo "daemon ${*:2} CONFIG=${CLAUDE_CONFIG_DIR:-unset}" >> "$HOME/stub.log"
          [ "${2:-}" = status ] && [ -f "$HOME/daemon-up" ] && echo "pid:     4242"; exit 0 ;;
  agents) echo "agents CONFIG=${CLAUDE_CONFIG_DIR:-unset}" >> "$HOME/stub.log"
          [ -f "$cfg/stub-agents.json" ] && { cat "$cfg/stub-agents.json"; exit 0; }   # a test's own list (pid, cwd, kind)
          st='"status": "idle"'; case "${CLAUDE_CONFIG_DIR:-}" in *acct-6) st='"state": "failed"' ;; esac   # acct-6: comes up, then fails
          printf '['; sep=""; [ -f "$cfg/stub-agents" ] && while read -r a; do printf '%s{"id": "%s", %s}' "$sep" "$a" "$st"; sep=","; done < "$cfg/stub-agents"; echo ']'; exit 0 ;;
esac
if [ "${1:-}" = --stay ]; then   # a session that stays open, with the record Claude Code keeps for it, until it is ended
  mkdir -p "$cfg/sessions"
  printf '{"pid": %s, "sessionId": "%s", "status": "%s", "kind": "%s", "cwd": "%s"}\n' "$$" "${STUB_SID:-sid-1}" "${STUB_STATUS:-idle}" "${STUB_KIND:-interactive}" "$PWD" > "$cfg/sessions/$$.json"
  echo "$$" > "$cfg/stub-bg.pid"
  trap 'echo "TERM CONFIG=${CLAUDE_CONFIG_DIR:-unset}"; rm -f "$cfg/sessions/$$.json"; exit 143' TERM
  [ -n "${STUB_RUN:-}" ] && ( sleep 0.3; export CLAUDECODE=1; eval "$STUB_RUN" > "$HOME/stub-run.out" 2>&1 ) &   # a command run inside it
  i=0; while [ "$i" -lt "${STUB_TICKS:-100}" ]; do sleep 0.1; i=$((i + 1)); done
  rm -f "$cfg/sessions/$$.json"; echo "ENDED CONFIG=${CLAUDE_CONFIG_DIR:-unset}"; exit 0
fi
case "$1 ${2:-}" in
  "auth status")
    if [ -f "$cfg/.stub-login" ]; then printf '{"loggedIn": true, "email": "%s@x.com", "subscriptionType": "max", "authMethod": "claude.ai"}\n' "$(basename "${CLAUDE_CONFIG_DIR:-default}")"
    else echo '{"loggedIn": false}'; exit 1; fi ;;
  "auth login") shift 2; echo "$*" > "$cfg/.stub-login" ;;
  "auth logout") rm -f "$cfg/.stub-login"; echo "logout ${CLAUDE_CONFIG_DIR:-default}" >> "$HOME/stub.log" ;;
  "plugin list") cat "$HOME/plugins.txt" 2>/dev/null ;;
  "plugin install") echo "$3" >> "$HOME/plugins.txt" ;;
  "plugin marketplace") if [ "$3" = list ]; then cat "$HOME/markets.txt" 2>/dev/null; else echo "claude-profiles $4" >> "$HOME/markets.txt"; fi ;;
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

echo work > "$P/default"   # what `ccp use` of an older ccp left: that folder for everything
ok "an older ccp's use: that folder for everything" '[ "$(ccp run -- x)" = "CONFIG=$P/work ARGS=x" ]'

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
ok "sw: an account with no sign-in to lend is refused, nothing changes" '! ccp sw 3 2>"$T/err" >/dev/null && has "$(cat "$T/err")" "#3 has no sign-in to lend" && [ "$(cat "$P/default")" = work ] && [ ! -e "$P/slot" ]'
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
        if tok == "Bearer tok-busy":
            self.send_response(429); self.end_headers(); return
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
echo "{\"claudeAiOauth\":{\"accessToken\":\"tok-1\",\"refreshToken\":\"rt-1\",\"expiresAt\":$future,\"subscriptionType\":\"max\",\"rateLimitTier\":\"default_claude_max_20x\"},\"mcpOAuth\":{\"docs\":\"m-1\"}}" > "$HOME/.claude/.credentials.json"
echo '{"oauthAccount":{"emailAddress":"me@x.com"}}' > "$HOME/.claude.json.usage"; cp "$HOME/.claude.json.usage" "$HOME/.claude.json"
echo "{\"claudeAiOauth\":{\"accessToken\":\"tok-3\",\"refreshToken\":\"rt-3\",\"expiresAt\":$future,\"subscriptionType\":\"pro\"}}" > "$P/acct-4/.credentials.json"
echo '{"oauthAccount":{"emailAddress":"four@x.com"}}' > "$P/acct-4/.claude.json"
echo '{"claudeAiOauth":{"accessToken":"tok-old","refreshToken":"rt-5","expiresAt":1000,"subscriptionType":"pro"}}' > "$P/acct-5/.credentials.json"
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

export CCP_NO_NOTIFY=1
out="$(ccp watch --once --at 90)"
ok "watch: a full account hands over to the next one with room, nothing moves" 'has "$out" "#1 me@x.com is at 91% of its 5-hour limit" && has "$out" "Claude Code now uses #3 four@x.com" && has "$out" "sessions stay where they are" && [ "$(cat "$P/slot")" = acct-4 ] && [ "$(cut -f1 "$P/moved")" = default ]'
cred() { python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); print(d.get("claudeAiOauth", {}).get(sys.argv[2], "-"))' "$1" "$2"; }
ok "watch: ~/.claude now holds #3's login, its MCP sign-ins stay" '[ "$(cred "$HOME/.claude/.credentials.json" accessToken)" = tok-3 ] && grep -q "m-1" "$HOME/.claude/.credentials.json"'
ok "watch: #1's own login is kept aside, #3 keeps no copy that renews" '[ "$(cred "$P/stash-default.json" accessToken)" = tok-1 ] && [ "$(cred "$P/acct-4/.credentials.json" refreshToken)" = "" ] && [ "$(ls -l "$P/stash-default.json" | cut -c1-10)" = -rw------- ]'
out="$(ccp usage)"
ok "usage: with #3's login in ~/.claude each account still shows its own numbers, #3 used here" 'has "$out" " 91%     9%" && has "$out" " 12%    88%" && has "$out" "* 3 "'
ok "run: the folder stays ~/.claude, whichever login it holds" '[ "$(ccp run -- x)" = "CONFIG=unset ARGS=x" ] && [ "$(ccp run -p 3 -- x)" = "CONFIG=unset ARGS=x" ]'
ok "watch: lists full accounts for running sessions" 'grep -q "^default	5-hour	91	" "$P/full"'
ok "watch: keeps what it saw for ccp service status" 'grep -q "^default	5-hour 91%, week 48%	5h:91:[0-9]* wk:48:[0-9]*$" "$P/seen" && grep -q "^acct-3	not logged in	$" "$P/seen" && has "$(ccp service status)" "  #1 default: 5-hour 91%, week 48%"'
python3 - "$HOME/.claude/.credentials.json" <<'EOF'   # Claude Code renews #3's login while it is in ~/.claude
import json, sys; d = json.load(open(sys.argv[1])); d["claudeAiOauth"]["refreshToken"] = "rt-3b"; json.dump(d, open(sys.argv[1], "w"))
EOF
out="$(ccp watch --once --at 95)"
ok "watch: goes back once the first account has room" 'has "$out" "#1 me@x.com has room again" && [ ! -e "$P/slot" ] && [ ! -e "$P/moved" ] && [ ! -s "$P/full" ]'
ok "watch: #1's own login comes back, #3 gets its freshest copy" '[ "$(cred "$HOME/.claude/.credentials.json" accessToken)" = tok-1 ] && [ "$(cred "$P/acct-4/.credentials.json" refreshToken)" = rt-3b ] && [ ! -e "$P/stash-default.json" ] && grep -q "m-1" "$HOME/.claude/.credentials.json"'
ok "watch: quiet when nothing changes" '[ -z "$(ccp watch --once --at 95)" ]'
cp "$P/acct-4/.credentials.json" "$T/cred4"
echo "{\"claudeAiOauth\":{\"accessToken\":\"tok-busy\",\"expiresAt\":$future}}" > "$P/acct-4/.credentials.json"
ccp watch --once --at 95 >/dev/null
ok "watch: 'asked too often' keeps the last numbers and asks less often" 'grep -q "^acct-4	week 12%	wk:12:" "$P/seen" && [ "$(cat "$P/backoff")" = 120 ]'
cp "$T/cred4" "$P/acct-4/.credentials.json"; ccp watch --once --at 95 >/dev/null
ok "watch: back to the usual pace once it answers" '[ ! -e "$P/backoff" ]'
ccp watch --once --at 10 >/dev/null
ok "watch: an expired sign-in still has room (Claude Code renews it on start)" '[ "$(cat "$P/slot")" = acct-5 ] && [ "$(cut -f1 "$P/moved")" = default ]'
ccp use 1 >/dev/null
ok "use: your choice clears what watch switched" '[ ! -e "$P/slot" ] && [ ! -e "$P/moved" ] && [ "$(cred "$HOME/.claude/.credentials.json" accessToken)" = tok-1 ] && [ "$(cred "$P/acct-5/.credentials.json" refreshToken)" = rt-5 ]'
ok "use: an account with no sign-in to lend is refused, nothing changes" '! ccp use 2 2>"$T/err" >/dev/null && has "$(cat "$T/err")" "#2 has no sign-in to lend" && [ ! -e "$P/slot" ] && [ "$(cred "$HOME/.claude/.credentials.json" accessToken)" = tok-1 ]'
cp "$HOME/.claude/.credentials.json" "$P/stash-default.json"; cp "$P/acct-4/.credentials.json" "$HOME/.claude/.credentials.json"   # a swap by hand
ok "use: finds a swap made by hand instead of keeping the lent login aside as #1's" 'has "$(ccp use 3)" "already on #3" && [ "$(cat "$P/slot")" = acct-4 ] && [ "$(cred "$P/acct-4/.credentials.json" refreshToken)" = "" ] && [ "$(cred "$P/stash-default.json" accessToken)" = tok-1 ]'
ccp use 1 >/dev/null
ok "use 1: and puts it all back" '[ ! -e "$P/slot" ] && [ "$(cred "$HOME/.claude/.credentials.json" accessToken)" = tok-1 ] && [ "$(cred "$P/acct-4/.credentials.json" refreshToken)" = rt-3b ]'
ok "watch: refuses odd numbers" '! ccp watch --once --at 0 2>/dev/null && ! ccp watch --once --at 101 2>/dev/null && ! ccp watch --once --every 5 2>/dev/null'
{ kill "$SRV"; wait "$SRV"; } 2>/dev/null

# a terminal session that ccp run started reopens in place when another account's login is put in ~/.claude
: > "$P/full"   # a watcher is running, nothing is full yet
started() { i=0; while ! ls "$1"/*.json >/dev/null 2>&1 && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i + 1)); done; }
CCP_TEST_TTY=1 CCP_POLL=0.2 ccp run -- --stay --model m "first prompt" > "$T/sup.out" 2>&1 &
SUP=$!; started "$HOME/.claude/sessions"
ccp use 3 >/dev/null
wait "$SUP"; out="$(cat "$T/sup.out")"
ok "login change: ends the idle terminal session" 'has "$out" "TERM CONFIG=unset"'
ok "login change: reopens the same conversation in place, keeps options, not the prompt" 'has "$out" "ccp: now on #3" && has "$out" "CONFIG=unset ARGS=--model m --resume sid-1"'
STUB_STATUS=busy STUB_TICKS=20 CCP_TEST_TTY=1 CCP_POLL=0.2 ccp run -- --stay > "$T/sup.out" 2>&1 &
SUP=$!; started "$HOME/.claude/sessions"
ccp use 1 >/dev/null
wait "$SUP"; out="$(cat "$T/sup.out")"
ok "login change: never cuts a busy session short" 'has "$out" "ENDED CONFIG=unset" && ! has "$out" "goes on" 2>/dev/null'
ok "login change: -p and print mode are left alone" '[ "$(CCP_TEST_TTY=1 ccp run -p 1 -- x)" = "CONFIG=unset ARGS=x" ] && [ "$(CCP_TEST_TTY=1 ccp run -- -p hi)" = "CONFIG=unset ARGS=-p hi" ]'
ok "login change: off without a terminal" '[ "$(ccp run -- x)" = "CONFIG=unset ARGS=x" ]'

# switching from inside a session (a skill or /ccp:switch runs ccp sw there): the login changes, no session moves
: > "$P/full"
STUB_RUN='/bin/bash "$CCP_SRC" sw 3' CCP_SRC="$ROOT/ccp" CCP_TEST_TTY=1 CCP_POLL=0.2 ccp run -- --stay --model m > "$T/sup.out" 2>&1
out="$(cat "$T/sup.out")"
ok "sw inside: puts #3's login in ~/.claude and says the conversation goes on here" 'has "$(cat "$HOME/stub-run.out")" "Claude Code uses #3" && has "$(cat "$HOME/stub-run.out")" "goes on in this terminal" && [ "$(cat "$P/slot")" = acct-4 ]'
ok "sw inside: the same terminal reopens the conversation in place" 'has "$out" "TERM CONFIG=unset" && has "$out" "CONFIG=unset ARGS=--model m --resume sid-1"'
ok "sw inside: a session started without ccp is told when it takes the login" 'CLAUDECODE=1 ccp sw 1 > "$T/o" && has "$(cat "$T/o")" "keeps the token it holds until it runs out" && [ ! -e "$P/slot" ]'
ok "sw inside: a session on a profile folder of its own keeps that account" 'has "$(CLAUDECODE=1 CLAUDE_CONFIG_DIR="$P/acct-5" ccp sw 3)" "keeps that account" && ccp use 1 >/dev/null'

# background sessions are never stopped or moved: the daemon restarts, leaves them running and hands them the new login
rm -f "$HOME/stub.log" "$HOME/stub-run.out"; touch "$HOME/daemon-up"
STUB_KIND=bg STUB_SID=abcd1234-0000 STUB_TICKS=20 STUB_RUN='export CLAUDE_JOB_DIR=/x/jobs/abcd1234; /bin/bash "$CCP_SRC" sw 3' CCP_SRC="$ROOT/ccp" \
  "$CCP_CLAUDE" --stay > "$T/bg.out" 2>&1
ok "sw inside a background session: the login changes, the session runs on where it is" 'has "$(cat "$HOME/stub-run.out")" "Claude Code uses #3" && has "$(cat "$T/bg.out")" "ENDED" && ! grep -q "^stop \|^bg-resume\|^rm " "$HOME/stub.log"'
ok "readopt: the daemon restarts with its sessions left running, and adopts them again" 'grep -q "^daemon stop --any --keep-workers CONFIG=unset$" "$HOME/stub.log" && grep -q "^agents CONFIG=unset$" "$HOME/stub.log" && has "$(cat "$HOME/stub-run.out")" "new background sessions start with it" && has "$(cat "$HOME/stub-run.out")" "claude respawn abcd1234"'
rm -f "$HOME/daemon-up" "$HOME/stub.log"; ccp use 1 >/dev/null
ok "readopt: no daemon running, nothing to restart" '! grep -q "daemon stop" "$HOME/stub.log" 2>/dev/null'
rm -f "$P/full"

# the status line: every account, its limits and when each resets, as ccp watch last saw them
now=$(date +%s)
printf 'default\tweek 98%%\twk:98:%s\nacct-3\tnot logged in\t\nacct-4\t5-hour 3%%, week 17%%\t5h:3:%s wk:17:%s\nacct-5\tsign-in expired: open #4 once\t\n' \
  $((now + 4 * 86400 + 15 * 3600 + 90)) $((now + 4 * 3600 + 49 * 60 + 20)) $((now + 5 * 86400 + 21 * 3600 + 90)) > "$P/seen"
out="$(NO_COLOR=1 CCP_ACTIVE=default ccp prompt --usage)"
ok "status line: this session's account stands out" 'has "$out" " ▶ #1 this session " && ! has "$out" "▶ #3" 2>/dev/null'
ok "status line: every account and when each limit resets, short for the others when there are many" 'has "$out" "week 98% (resets in 4d 15h)  ┃  #2  signed out  ┃  #3 5h 3%(4h) week 17%(5d)  ┃  #4  checking  ┃  #5  checking  ┃  #6  checking"'
ok "status line: in Korean" 'has "$(NO_COLOR=1 CCP_LANG=ko CCP_ACTIVE=acct-4 ccp prompt --usage)" "#1 주간 98%(4일)  ┃  #2  로그인 필요  ┃   ▶ #3 이 세션   5시간 3% (4시간 49분 뒤 리셋)  주간 17% (5일 21시간 뒤 리셋)"'
mkdir -p "$T/two/acct-2" && echo isolated=0 > "$T/two/acct-2/.ccp" && printf 'default\nacct-2\n' > "$T/two/order"
sed -n "1p;3p" "$P/seen" | sed "s/^acct-4/acct-2/" > "$T/two/seen"
ok "status line: two accounts, both in full" '[ "$(NO_COLOR=1 CCP_HOME="$T/two" CCP_ACTIVE=default ccp prompt --usage)" = " ▶ #1 this session   week 98% (resets in 4d 15h)  ┃  #2  5h 3% (resets in 4h 49m)  week 17% (resets in 5d 21h)" ]'
ok "status line: a Claude Code started without ccp finds its account by its folder" 'has "$(NO_COLOR=1 CLAUDECODE=1 CLAUDE_CONFIG_DIR="$P/acct-4" ccp prompt --usage)" "▶ #3 this session"'
echo acct-4 > "$P/slot"
ok "status line: a session on ~/.claude is on the account whose login ~/.claude holds" 'has "$(NO_COLOR=1 CCP_ACTIVE=default ccp prompt --usage)" "▶ #3 this session" && [ "$(CCP_ACTIVE=default ccp prompt)" = "#3" ]'
rm -f "$P/slot"
ok "status line: colors by how full" 'has "$(CCP_ACTIVE=default ccp prompt --usage)" "$(printf "\033[31m98%%")" && has "$(CCP_ACTIVE=default ccp prompt --usage)" "$(printf "\033[32m17%%")"'
rm -f "$P/full" "$P/seen"
ok "status line: without ccp service, just the accounts" 'has "$(NO_COLOR=1 CCP_ACTIVE=acct-4 ccp prompt --usage)" "#1  ┃  #2  ┃   ▶ #3 this session   ┃  #4"'

# ccp service: a launchd job (launchctl stubbed)
printf '%s\n' '#!/bin/bash' 'echo "$*" >> "$HOME/launchctl.log"' \
  'if [ "$1" = print ]; then [ -f "$HOME/Library/LaunchAgents/ai.yunastudio.ccp.plist" ] && printf "\tpid = 4242\n"; fi' 'exit 0' > "$T/bin/launchctl"
chmod +x "$T/bin/launchctl"
export CCP_LAUNCHCTL="$T/bin/launchctl"
PL="$HOME/Library/LaunchAgents/ai.yunastudio.ccp.plist"
out="$(ccp service start --at 95 --every 120)"
ok "service start: a launchd job that keeps ccp watch running" 'grep -q "<string>watch</string>" "$PL" && grep -q "<string>$ROOT/ccp</string>" "$PL" && grep -q "bootstrap gui/" "$HOME/launchctl.log" && has "$out" "reaches 95%"'
ok "service start: keeps its settings for ccp watch" '[ "$(tr "\n" " " < "$P/auto")" = "at=95 every=120 " ]'
if command -v plutil >/dev/null 2>&1; then ok "service start: a valid plist" 'plutil -lint "$PL" >/dev/null'; fi
ok "service status: running, with its settings" 'has "$(ccp service status)" "running (pid 4242), at 95% · every 120s"'
ccp service stop >/dev/null
ok "service stop: unloads it and turns the switching off" '[ ! -e "$PL" ] && [ ! -e "$P/auto" ] && grep -q "bootout gui/" "$HOME/launchctl.log" && has "$(ccp service status)" "service: off"'
ok "service: refuses odd numbers" '! ccp service start --at 0 2>/dev/null && ! ccp service start --every 5 2>/dev/null'

# ccp setup: everything once per computer, nothing by hand
out="$(SHELL=/bin/zsh CCP_PLUGIN_SOURCE=/src/claude-profiles ccp setup)"
ok "setup: the shell runs ccp init" 'grep -q "^eval \"\$($ROOT/ccp init zsh)\"$" "$HOME/.zshrc" && has "$out" "✓ shell"'
ok "setup: the status line shows every account, other settings stay" 'grep -q "\"command\": \"$ROOT/ccp prompt --usage\"" "$HOME/.claude/settings.json" && grep -q "\"model\": \"x\"" "$HOME/.claude/settings.json"'
ok "setup: installs the Claude Code plugin" 'grep -q "^ccp@claude-profiles$" "$HOME/plugins.txt" && grep -q "/src/claude-profiles" "$HOME/markets.txt"'
ok "setup: starts the service" '[ -f "$PL" ] && has "$out" "✓ service"'
out="$(SHELL=/bin/zsh ccp setup)"
ok "setup: twice changes nothing" '[ "$(grep -c "ccp init" "$HOME/.zshrc")" = 1 ] && [ "$(grep -c ccp@claude-profiles "$HOME/plugins.txt")" = 1 ] && has "$out" "already"'
ccp setup --undo >/dev/null
ok "setup --undo: takes out the shell lines, the status line and the service" '! grep -q ccp "$HOME/.zshrc" && ! grep -q statusLine "$HOME/.claude/settings.json" && [ ! -e "$PL" ]'
echo '{"statusLine": {"type": "command", "command": "my-line"}}' > "$HOME/.claude/settings.json"
ok "setup: a status line of yours stays" 'has "$(SHELL=/bin/zsh ccp setup --no-service)" "yours stays" && grep -q my-line "$HOME/.claude/settings.json"'
echo '{"model":"x"}' > "$HOME/.claude/settings.json"; ccp setup --undo >/dev/null

V="$(sed -n 's/^VERSION="\(.*\)"/\1/p' "$ROOT/ccp")"
ok "plugin ships the same ccp, one version everywhere" 'cmp -s "$ROOT/ccp" "$ROOT/plugin/bin/ccp" && grep -q "\"version\": \"$V\"" "$ROOT/plugin/.claude-plugin/plugin.json" && grep -q "version \"$V\"" "$ROOT/Formula/ccp.rb" && grep -q "download/v$V/ccp" "$ROOT/Formula/ccp.rb"'

ok "help and version" 'has "$(ccp help)" "ccp add" && has "$(ccp --version)" "ccp 0.5"'

echo "$pass passed, $fail failed"
[ "$fail" = 0 ]

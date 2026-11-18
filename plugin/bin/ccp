#!/usr/bin/env bash
# ccp — use several Claude Code accounts on one computer without logging in again.
#
# Each account is a profile: its own Claude Code config folder (CLAUDE_CONFIG_DIR), so its login lives in its own
# keychain item (macOS) or credentials file (Linux). Your settings, CLAUDE.md, agents, commands, skills, plugins and
# project history are shared from ~/.claude unless the profile is --isolated. Profiles are numbered in order (#1 is
# your normal ~/.claude); `ccp add -2` puts a new one at #2 and moves the rest down. Folders keep their first name, since
# Claude Code ties a login to the folder's path; only the numbers move. Which profile a `claude` run uses:
#   CCP_PROFILE  >  the folder rule for the current directory (ccp here)  >  #1 default (~/.claude)
# `ccp use N` does not pick a folder: it puts account N's login in ~/.claude, so every session stays where it is.
#
# Works with bash 3.2 (stock macOS). https://github.com/yuna-studio/claude-profiles  ·  MIT
set -u
VERSION="0.5.0"
CCP_HOME="${CCP_HOME:-$HOME/.claude-profiles}"
BASE="${CCP_BASE:-$HOME/.claude}"   # the default profile's folder: what other profiles share from
TAB="$(printf '\t')"
AGENT="ai.yunastudio.ccp"   # the launchd job `ccp service` runs (macOS)
SHARE="settings.json CLAUDE.md agents commands skills output-styles plugins keybindings.json projects"

say() { printf '%s\n' "$*"; }
die() { printf 'ccp: %s\n' "$*" >&2; exit 1; }

real_claude() {   # the Claude Code binary (never a shell function: functions do not reach this script)
  if [ -n "${CCP_CLAUDE:-}" ]; then echo "$CCP_CLAUDE"; return; fi
  command -v claude 2>/dev/null || die "claude not found in PATH (install Claude Code first, or set CCP_CLAUDE)"
}

valid_name() {   # letters, digits, . _ -; not only digits (numbers are positions)
  case "$1" in ""|.*|*[!A-Za-z0-9._-]*) return 1 ;; *[!0-9]*) ;; *) return 1 ;; esac
  [ "${#1}" -le 40 ]
}

pdir() { echo "$CCP_HOME/$1"; }   # config folder of a profile id

exists() { [ "$1" = default ] || { [ -n "$1" ] && [ -f "$(pdir "$1")/.ccp" ]; }; }

ids() {   # profile ids in order: the order file, then any profile it misses; "default" is always there
  local seen=" " id out="" d
  if [ -f "$CCP_HOME/order" ]; then
    while read -r id; do
      [ -n "$id" ] || continue
      case "$seen" in *" $id "*) continue ;; esac
      exists "$id" || continue
      out="$out$id
"; seen="$seen$id "
    done < "$CCP_HOME/order"
  fi
  case "$seen" in *" default "*) ;; *) out="default
$out"; seen="${seen}default " ;; esac
  if [ -d "$CCP_HOME" ]; then
    for d in "$CCP_HOME"/*/; do
      [ -f "$d.ccp" ] || continue
      id="$(basename "$d")"
      case "$seen" in *" $id "*) continue ;; esac
      out="$out$id
"; seen="$seen$id "
    done
  fi
  printf '%s' "$out"
}

pos_of() { ids | awk -v id="$1" '$0 == id { print NR; exit }'; }   # pos_of <id> -> its number

ref() {   # ref <number|id> -> profile id
  case "$1" in
    "") return 1 ;;
    *[!0-9]*) exists "$1" && echo "$1" ;;
    *) [ "$1" -ge 1 ] 2>/dev/null || return 1
       local id; id="$(ids | sed -n "$1p")"; [ -n "$id" ] && echo "$id" ;;
  esac
}

need() { ref "$1" || die "no profile '$1' (ccp ls lists them; ccp add makes one)"; }   # need <number|id> -> id

label() {   # label <id> -> "#2 work", or "#2" for an unnamed profile
  local n; n="#$(pos_of "$1")"
  case "$1" in acct-[0-9]*) echo "$n" ;; default) echo "$n default" ;; *) echo "$n $1" ;; esac
}

write_order() {   # write_order <id...>
  mkdir -p "$CCP_HOME"
  printf '%s\n' "$@" > "$CCP_HOME/order.$$" && mv "$CCP_HOME/order.$$" "$CCP_HOME/order"
}

place() {   # place <id> <position>: put a profile at that number (past the end: last); the rest move down
  local id="$1" pos="$2" n=0 put=0 x
  set --
  for x in $(ids); do
    [ "$x" = "$id" ] && continue
    if [ "$put" = 0 ] && [ $((n + 1)) -ge "$pos" ]; then set -- "$@" "$id"; n=$((n + 1)); put=1; fi
    set -- "$@" "$x"; n=$((n + 1))
  done
  [ "$put" = 1 ] || set -- "$@" "$id"
  write_order "$@"
}

new_id() {   # acct-N, never reused: Claude Code keys a login by the folder's path
  local n; n="$(cat "$CCP_HOME/next" 2>/dev/null || echo 2)"
  case "$n" in ""|*[!0-9]*) n=2 ;; esac
  while [ -e "$(pdir "acct-$n")" ]; do n=$((n + 1)); done
  echo "$((n + 1))" > "$CCP_HOME/next"
  echo "acct-$n"
}

physical() {   # absolute path with symlinks resolved; the directory must exist
  (cd "$1" 2>/dev/null && pwd -P) || die "no such directory: $1"
}

rule_for() {   # rule_for <physical dir> -> "profile<TAB>rule path" of the longest matching folder rule
  local dir="$1" best="" bestp="" p n
  [ -f "$CCP_HOME/rules" ] || return 1
  while IFS="$TAB" read -r p n; do
    [ -n "$p" ] && [ -n "$n" ] || continue
    case "$dir/" in "$p"/*) [ "${#p}" -gt "${#bestp}" ] && { bestp="$p"; best="$n"; } ;; esac
  done < "$CCP_HOME/rules"
  [ -n "$best" ] && printf '%s\t%s\n' "$best" "$bestp"
}

resolve() {   # resolve [dir] -> "profile<TAB>why"
  local dir r id why h
  h="$(holder)"
  if [ -n "${CCP_PROFILE:-}" ]; then id="$(ref "$CCP_PROFILE" || echo "$CCP_PROFILE")"; why=CCP_PROFILE
  else
    dir="$(physical "${1:-.}")"
    if r="$(rule_for "$dir")"; then id="${r%%$TAB*}"; why="folder rule ${r#*$TAB}"
    elif [ -s "$CCP_HOME/default" ]; then id="$(cat "$CCP_HOME/default")"; why="ccp use (an older ccp: that folder for everything)"
    elif [ "$h" != default ]; then id=default; why="ccp use: $(label "$h")'s login in ~/.claude"
    else id=default; why=built-in; fi
  fi
  if [ "$id" = "$h" ] && [ "$h" != default ]; then id=default; why="$why; its login is in ~/.claude now"; fi   # lent: run there
  printf '%s\t%s\n' "$id" "$why"
}

with_profile() {   # with_profile <name> <command...>: run with that profile's config folder
  local name="$1"; shift
  if [ "$name" = default ]; then (unset CLAUDE_CONFIG_DIR; "$@")
  else CLAUDE_CONFIG_DIR="$(pdir "$name")" "$@"; fi
}

json_field() {   # json_field <key> : read one top-level string/bool field from JSON on stdin (python3, jq or plutil)
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json, sys
try: v = json.load(sys.stdin).get(sys.argv[1], "")
except Exception: v = ""
print("true" if v is True else "false" if v is False else "" if v is None else v)' "$1"
  elif command -v jq >/dev/null 2>&1; then jq -r --arg k "$1" '.[$k] // "" | tostring'
  else sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\{0,1\}\([^\",}]*\).*/\1/p" | head -1; fi
}

account() {   # account <name> -> "email<TAB>plan" or "-<TAB>not logged in"
  local js email plan
  js="$(with_profile "$1" "$(real_claude)" auth status --json 2>/dev/null)"
  if [ "$(printf '%s' "$js" | json_field loggedIn)" != true ]; then printf -- '-\tnot logged in\n'; return; fi
  email="$(printf '%s' "$js" | json_field email)"
  plan="$(printf '%s' "$js" | json_field subscriptionType)"
  [ -n "$plan" ] || plan="$(printf '%s' "$js" | json_field authMethod)"
  printf '%s\t%s\n' "${email:--}" "${plan:--}"
}

share_into() {   # link the shared parts of ~/.claude into a profile folder
  local d="$1" item
  mkdir -p "$BASE/projects"
  for item in $SHARE; do
    [ -e "$BASE/$item" ] || [ -L "$BASE/$item" ] || continue
    [ -e "$d/$item" ] || [ -L "$d/$item" ] || ln -s "$BASE/$item" "$d/$item"
  done
}

copy_mcp() {   # copy user-level MCP servers from ~/.claude.json into a new profile (before its first run)
  local d="$1" src="$HOME/.claude.json"
  [ -f "$src" ] && [ ! -e "$d/.claude.json" ] && command -v python3 >/dev/null 2>&1 || return 0
  python3 - "$src" "$d/.claude.json" <<'EOF' || true
import json, os, sys
try:
    servers = json.load(open(sys.argv[1])).get("mcpServers") or {}
except Exception:
    servers = {}
if servers:
    fd = os.open(sys.argv[2], os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump({"mcpServers": servers}, f, indent=2)
EOF
}

cmd_add() {   # ccp add [name] [-N | --at N] [--isolated] [--no-login] [--email you@x.com]
  local name="" pos="" isolated=0 login=1 mcp=1 a
  local -a largs=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --isolated) isolated=1 ;;
      --no-login) login=0 ;;
      --no-mcp) mcp=0 ;;
      --at) shift; pos="${1:-}" ;;
      -[0-9]*) pos="${1#-}" ;;
      --email|--sso|--console|--claudeai) largs+=("$1"); [ "$1" = --email ] && { shift; largs+=("${1:-}"); } ;;
      -*) die "add: unknown option $1" ;;
      *) [ -z "$name" ] && name="$1" || die "add: one name only" ;;
    esac
    shift
  done
  case "$pos" in ""|*[!0-9]*|0) [ -z "$pos" ] || die "add: position must be a number from 1 (ccp add -2)" ;; esac
  mkdir -p "$CCP_HOME" && chmod 700 "$CCP_HOME"
  if [ -z "$name" ]; then name="$(new_id)"
  else
    valid_name "$name" || die "add: a name is letters, digits, . _ - and not only digits (numbers are positions)"
    [ "$name" != default ] || die "'default' is your normal ~/.claude; pick another name"
    exists "$name" && die "profile '$name' exists (ccp login $name signs in again)"
  fi
  local d; d="$(pdir "$name")"
  [ -e "$d" ] && die "$d is in the way; move it first"
  mkdir -p "$d" && chmod 700 "$d"
  if [ "$isolated" = 1 ]; then echo "isolated=1" > "$d/.ccp"; else echo "isolated=0" > "$d/.ccp"; share_into "$d"; fi
  [ "$mcp" = 1 ] && [ "$isolated" = 0 ] && copy_mcp "$d"
  place "$name" "${pos:-999999}"
  say "$(label "$name") → $d$( [ "$isolated" = 1 ] && echo ' (isolated)' )"
  if [ "$login" = 1 ]; then
    say "signing in: check the account shown in the browser before you approve"
    a="$(real_claude)" || exit 1
    if [ ${#largs[@]} -gt 0 ]; then with_profile "$name" "$a" auth login "${largs[@]}"; else with_profile "$name" "$a" auth login; fi \
      || die "sign-in did not finish; run: ccp login $(pos_of "$name")"
  fi
}

cmd_mv() {   # ccp mv <number|id> <new number>
  local id; id="$(need "${1:-}")" || exit 1
  case "${2:-}" in ""|*[!0-9]*|0) die "usage: ccp mv <number|name> <new number>" ;; esac
  place "$id" "$2"
  say "$(label "$id")"
}

cmd_login() {
  [ -n "${1:-}" ] || die "usage: ccp login <number|name> [claude auth login options]"
  local id; id="$(need "$1")" || exit 1; shift
  with_profile "$id" "$(real_claude)" auth login "$@"
}

cmd_ls() {
  local cur id acc mark name i=0 iso p h
  h="$(holder)"; cur="$(resolve . | cut -f1)"; [ "$cur" = default ] && cur="$h"   # ~/.claude runs on the login it holds
  printf '  %-3s %-34s %-14s %s\n' '#' ACCOUNT PLAN NAME
  for id in $(ids); do
    i=$((i + 1))
    if [ "$id" = default ] && [ "$h" != default ]; then   # its login is kept aside: auth status there shows the lent one
      acc="$(python3 -c 'import json, os
print((json.load(open(os.path.expanduser("~/.claude.json"))).get("oauthAccount") or {}).get("emailAddress") or "-")' 2>/dev/null || echo -)${TAB}kept aside"
    else acc="$(account "$id")"; fi
    mark=" "; [ "$id" = "$cur" ] && mark="*"
    name="$id"; iso=""
    grep -q '^isolated=1' "$(pdir "$id")/.ccp" 2>/dev/null && iso=" (isolated)"
    [ "$id" = default ] && name="default (~/.claude)"
    printf '%s %-3s %-34s %-14s %s\n' "$mark" "$i" "${acc%%$TAB*}" "${acc#*$TAB}" "$name$iso"
  done
  if [ -s "$CCP_HOME/rules" ]; then
    say ""; say "folder rules:"
    while IFS="$TAB" read -r p id; do [ -n "$p" ] && printf '  %s → %s\n' "$p" "$(label "$id")"; done < "$CCP_HOME/rules"
  fi
  [ "$h" != default ] && { say ""; say "~/.claude holds $(label "$h")'s login; #1's own is kept aside (ccp use 1 brings it back)"; }
  say ""; say "* used here ($(resolve . | cut -f2))"
}

cmd_use() {   # ccp use <number|name>: that account's login in ~/.claude; every running session stays where it is and uses it
  [ -n "${1:-}" ] || die "usage: ccp use <number|name>   (ccp use 1 brings #1's own login back)"
  local id; id="$(need "$1")" || exit 1
  swap_login "$id" || exit 1
  rm -f "$CCP_HOME/default" "$CCP_HOME/moved" "$CCP_HOME/stuck"   # your choice: ccp watch does not switch it back
}

# One login at a time, in place. Claude Code reads its login from ~/.claude's keychain item (or .credentials.json); ccp
# puts the chosen account's login there and keeps #1's own aside, so every session stays in its list, its folder and its
# terminal: only the account its tokens come from changes. Meanwhile the lent account keeps no renewable copy of its own
# (two copies renewing one login would sign one of them out); it gets the freshest copy back when it is swapped out.

holder() {   # the account whose login ~/.claude holds now (#1 when none was swapped in)
  local h; h="$(cat "$CCP_HOME/slot" 2>/dev/null)"; exists "$h" || h=default; echo "$h"
}

swap_login() {   # swap_login <id>: put that account's login in ~/.claude; running sessions take it without moving
  local to="$1" from out got changed
  from="$(holder)"
  command -v python3 >/dev/null 2>&1 || die "switching needs python3"
  out="$(CCP_ROWS="$(usage_rows)" CCP_HOME_DIR="$CCP_HOME" CCP_BASE_DIR="$BASE" CCP_SLOT="$from" python3 -c "$LOGIN_PY" "$to")" \
    || return 1
  IFS="$TAB" read -r got changed <<EOF
$out
EOF
  exists "$got" || return 1
  mkdir -p "$CCP_HOME"
  if [ "$got" = default ]; then rm -f "$CCP_HOME/slot"; else echo "$got" > "$CCP_HOME/slot"; fi
  if [ "$changed" = 0 ]; then say "already on $(label "$got")'s login"
  else say "Claude Code uses $(label "$got")'s login now; every session stays where it is"; readopt; fi
  respawn_running
  return 0
}

readopt() {   # Claude Code's daemon reads the login when it starts and gives it to the sessions it starts; `daemon stop
              # --keep-workers` restarts it and leaves the running sessions alone. A running session keeps the token it holds
              # until that runs out (hours at most), then reads ~/.claude again; `claude respawn <id>` restarts one in place now
  local c n; c="$(real_claude 2>/dev/null)" || return 0
  (
    unset CLAUDE_CONFIG_DIR
    "$c" daemon status 2>/dev/null | grep -q '^pid:' || exit 0
    if ! "$c" daemon stop --any --keep-workers >/dev/null 2>&1; then say "background sessions take it when they next renew their sign-in"; exit 0; fi
    "$c" agents --json >/dev/null 2>&1   # starts the daemon again (it comes up a few seconds later) and it adopts the sessions
    n=0; until "$c" daemon status 2>/dev/null | grep -q '^pid:'; do
      n=$((n + 1)); [ "$n" -lt "${CCP_DAEMON_WAIT:-45}" ] || { say "background sessions take it once Claude Code's daemon is back (claude agents starts it)"; exit 0; }
      sleep 1; [ $((n % 10)) = 0 ] && "$c" agents --json >/dev/null 2>&1
    done
    say "new background sessions start with it"
  )
  return 0
}

# A running session holds the token it read and keeps it until it runs out (hours). So that it takes the new login now,
# each background session on ~/.claude restarts in place once it is idle: `claude respawn` keeps its id, its conversation
# and its place in the list. A turn, a tool, a question or work it left running (a build, a shell) is never cut short.

respawn_running() {   # one waiter (_respawn) per running background session on ~/.claude
  local c n=0 pid short lock
  [ -n "${CCP_NO_RESPAWN:-}" ] && return 0
  c="$(real_claude 2>/dev/null)" || return 0
  mkdir -p "$CCP_HOME/respawning"
  while IFS="$TAB" read -r pid short; do
    [ -n "$short" ] || continue
    lock="$CCP_HOME/respawning/$short"
    if ! mkdir "$lock" 2>/dev/null; then   # one is waiting already (it gives up after two hours)
      [ -n "$(find "$lock" -maxdepth 0 -mmin +130 2>/dev/null)" ] || continue
      rmdir "$lock" 2>/dev/null; mkdir "$lock" 2>/dev/null || continue
    fi
    detach "$CCP_HOME/respawn.log" _respawn "$pid" "$short"
    n=$((n + 1))
  done <<EOF
$( (unset CLAUDE_CONFIG_DIR; "$c" agents --json --all 2>/dev/null) | python3 -c 'import json, os, sys
try: rows = json.load(sys.stdin)
except Exception: rows = []
for x in rows if isinstance(rows, list) else []:
    pid, short = x.get("pid"), x.get("id")
    if x.get("kind") not in ("background", "bg") or not pid or not short or x.get("state") in ("failed", "stopped"):
        continue
    try: os.kill(int(pid), 0)
    except Exception: continue
    print("%s\t%s" % (pid, short))' 2>/dev/null)
EOF
  [ "$n" -gt 0 ] && say "$n running background session(s) restart in place once idle (same conversation, same list) and use it from then on"
  return 0
}

cmd__respawn() {   # ccp _respawn <pid> <short id>: wait until that background session is idle, then restart it in place
  local pid="$1" short="$2" n=0 st c
  trap "rmdir $(printf '%q' "$CCP_HOME/respawning/$short") 2>/dev/null" EXIT   # respawn_running's lock
  c="$(real_claude)" || exit 1
  while kill -0 "$pid" 2>/dev/null; do   # the turn ends first, and the work it left running in the background
    st="$(session_info "$BASE/sessions/$pid.json" | cut -f2)"
    case "$st" in ""|idle) job_busy "$BASE" "$short" || break ;; esac
    n=$((n + 1)); [ "$n" -lt 7200 ] || { say "$(date '+%F %T') $short: still busy after two hours; it switches when its token runs out"; return 1; }
    sleep 1
  done
  kill -0 "$pid" 2>/dev/null || return 0   # it ended on its own
  keep_name "$short" "$pid"
  if (unset CLAUDE_CONFIG_DIR; "$c" respawn "$short") >/dev/null 2>&1; then say "$(date '+%F %T') $short: restarted in place on $(label "$(holder)")'s login"
  else say "$(date '+%F %T') $short: claude respawn failed; it switches when its token runs out"; fi
}

keep_name() {   # keep_name <short id> <pid>: claude respawn starts a session from its launch options, so its name goes in them
  python3 - "$BASE/jobs/$1/state.json" "$BASE/sessions/$2.json" "$1" <<'PY' 2>/dev/null || true
import json, os, sys
state, record, short = sys.argv[1:]
d = json.load(open(state))
name = d.get("name")
if not name:
    try:
        r = json.load(open(record))
        name = r.get("name") if r.get("name") and r.get("name") != short else None
    except Exception:
        name = None
flags = list(d.get("respawnFlags") or [])
if not name or "--name" in flags:
    sys.exit(0)
d["respawnFlags"] = flags + ["--name", name]
d.setdefault("name", name)
tmp = state + ".ccp-tmp"
with open(tmp, "w") as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
os.replace(tmp, state)
PY
}

job_busy() {   # job_busy <config folder> <short id>: the background job still runs work it started (a build, a shell); watches
               # that never end on their own (an artifact's comments) do not count
  python3 -c 'import json, sys
try: f = (json.load(open(sys.argv[1])).get("inFlight") or {})
except Exception: sys.exit(1)
work = (f.get("tasks") or 0) - (f.get("drainableMonitors") or 0)
sys.exit(0 if work > 0 or (f.get("queued") or 0) > 0 else 1)' "$1/jobs/$2/state.json" 2>/dev/null
}

detach() {   # detach <log> <ccp command...>: run ccp on its own, outside this session, so it outlives it
  python3 - "$1" "$(self_path)" "${@:2}" <<'PY'
import os, sys
log, me, args = sys.argv[1], sys.argv[2], sys.argv[3:]
if os.fork():
    sys.exit(0)
os.setsid()
if os.fork():
    os._exit(0)
env = {k: v for k, v in os.environ.items() if not k.startswith("CLAUDE") and k not in ("CCP_RUN", "CCP_ACTIVE")}
null = os.open(os.devnull, os.O_RDONLY)
out = os.open(log, os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o600)
os.dup2(null, 0); os.dup2(out, 1); os.dup2(out, 2)
os.execve("/bin/bash", ["/bin/bash", me] + args, env)
PY
}

IFS= read -r -d '' LOGIN_PY <<'PY' || true   # swap_login's keychain (or credentials file) work; tokens never reach a command line
import hashlib, json, os, re, subprocess, sys, unicodedata

HOME_DIR, BASE = os.environ["CCP_HOME_DIR"], os.environ["CCP_BASE_DIR"]
ROWS = [dict(zip(("n", "id", "dir", "label"), l.split("\t"))) for l in os.environ.get("CCP_ROWS", "").splitlines() if l]
DIRS = {r["id"]: r["dir"] for r in ROWS}
NUM = {r["id"]: r["n"] for r in ROWS}
KEYCHAIN = sys.platform == "darwin" and not os.environ.get("CCP_NO_KEYCHAIN")
STASH = "ccp-stash-default"   # #1's own login while another account's is in ~/.claude


def stop(msg):
    print("ccp: " + msg, file=sys.stderr)
    sys.exit(1)


def user():   # the keychain account Claude Code files its login under
    u = os.environ.get("USER") or ""
    if not u:
        try:
            import pwd
            u = pwd.getpwuid(os.getuid()).pw_name
        except Exception:
            u = ""
    return u if re.fullmatch(r"[a-zA-Z0-9._-]+", u) else "claude-code-user"


def service(i):
    if i == STASH:
        return STASH
    d = DIRS[i]
    return "Claude Code-credentials" + ("-" + hashlib.sha256(unicodedata.normalize("NFC", d).encode()).hexdigest()[:8] if d else "")


def path(i):
    return os.path.join(HOME_DIR, "stash-default.json") if i == STASH else os.path.join(DIRS[i] or BASE, ".credentials.json")


def where(i):
    return f"the keychain item {service(i)!r}" if KEYCHAIN else path(i)


def load(i):
    if KEYCHAIN:
        r = subprocess.run(["security", "find-generic-password", "-a", user(), "-s", service(i), "-w"],
                           capture_output=True, text=True, timeout=15)
        if r.returncode == 44:   # no such item
            return None
        if r.returncode:
            stop(f"could not read {where(i)} (is the keychain locked?)")
        v = r.stdout.strip()
    else:
        try:
            with open(path(i)) as f:
                v = f.read().strip()
        except FileNotFoundError:
            return None
    try:
        return json.loads(v) if v else None
    except ValueError:
        stop(f"{where(i)} does not hold JSON; ccp leaves it alone")


def save(i, obj):
    v = json.dumps(obj, separators=(",", ":"))
    if KEYCHAIN:   # -X takes hex, so nothing needs quoting; through stdin when it fits, so it stays off the command line
        hx = v.encode().hex()
        line = f'add-generic-password -U -a "{user()}" -s "{service(i)}" -X "{hx}"\n'
        if len(line) < 4000:
            subprocess.run(["security", "-i"], input=line, capture_output=True, text=True, timeout=15)
        else:
            subprocess.run(["security", "add-generic-password", "-U", "-a", user(), "-s", service(i), "-X", hx],
                           capture_output=True, text=True, timeout=15)
    else:
        tmp = path(i) + ".ccp-tmp"
        fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w") as f:
            f.write(v)
        os.replace(tmp, path(i))
    if load(i) != obj:
        stop(f"could not save the sign-in in {where(i)}")


def drop(i):
    if KEYCHAIN:
        subprocess.run(["security", "delete-generic-password", "-a", user(), "-s", service(i)], capture_output=True, timeout=15)
    else:
        try:
            os.remove(path(i))
        except FileNotFoundError:
            pass


def oauth(o):
    return (o or {}).get("claudeAiOauth") or {}


def same(a, b):   # one login: a token in common, or the same account
    return any(a.get(k) and a.get(k) == b.get(k) for k in ("accessToken", "refreshToken", "accountUuid"))


def lend(i):   # its own copy stops renewing: the one in ~/.claude does that now
    o = load(i)
    if oauth(o).get("refreshToken"):
        o["claudeAiOauth"] = dict(oauth(o), refreshToken="")
        save(i, o)


to = sys.argv[1]
held = os.environ.get("CCP_SLOT") or "default"
held = held if held in DIRS else "default"
slot = load("default") or {}
if held == "default":   # nothing says another account's login is in ~/.claude: make sure (an older ccp, a swap by hand)
    held = next((r["id"] for r in ROWS if r["id"] != "default" and same(oauth(slot), oauth(load(r["id"])))), "default")
if to == held:
    if held != "default":
        lend(held)
    print(f"{held}\t0")
    sys.exit(0)
if to != "default":
    t = load(to)
    if not oauth(t).get("accessToken") or not oauth(t).get("refreshToken"):
        stop(f"#{NUM[to]} has no sign-in to lend (ccp login {NUM[to]})")
# the login in ~/.claude now goes back where it belongs, its freshest copy: Claude Code renews it in ~/.claude
if held == "default":
    if load(STASH) is not None:
        stop(f"#1's own sign-in is already kept aside ({where(STASH)}), yet ~/.claude does not hold another account's; "
             "ccp changes nothing so that neither is lost")
    save(STASH, slot)
else:
    h = load(held) or {}
    h["claudeAiOauth"] = oauth(slot)
    save(held, h)
if to == "default":
    s = load(STASH)
    if not oauth(s).get("accessToken"):
        stop("#1's own sign-in is not kept anywhere; sign #1 in again with: ccp login 1")
    slot["claudeAiOauth"] = oauth(s)   # only the Claude login: MCP sign-ins in ~/.claude stay as they are
    save("default", slot)
    drop(STASH)
else:
    slot["claudeAiOauth"] = oauth(t)
    save("default", slot)
    lend(to)
print(f"{to}\t1")
PY

cmd_here() {   # ccp here <number|name> [dir] | ccp here --rm [dir]
  local id="${1:-}" dir tmp
  [ -n "$id" ] || die "usage: ccp here <number|name> [dir]   ·   ccp here --rm [dir]"
  dir="$(physical "${2:-.}")"; mkdir -p "$CCP_HOME"; touch "$CCP_HOME/rules"
  [ "$id" = --rm ] || id="$(need "$id")" || exit 1
  tmp="$CCP_HOME/rules.$$"
  awk -F '\t' -v p="$dir" '$1 != p' "$CCP_HOME/rules" > "$tmp" && mv "$tmp" "$CCP_HOME/rules"
  if [ "$id" = --rm ]; then say "no rule for $dir"; return; fi
  printf '%s\t%s\n' "$dir" "$id" >> "$CCP_HOME/rules"   # the id, so the rule follows the account when numbers move
  say "$dir and the folders in it → $(label "$id")"
}

cmd_which() {
  local r id
  r="$(resolve "${1:-.}")" || exit 1; id="$(need "${r%%$TAB*}")" || exit 1
  say "$(label "$id")  ($(printf '%s' "$r" | cut -f2))"
  if [ "$id" = default ]; then say "config: $BASE"; else say "config: $(pdir "$id")"; fi
}

cmd_env() {   # eval "$(ccp env [number|name])": pin this shell to a profile
  local id; id="$(need "${1:-$(resolve . | cut -f1)}")" || exit 1
  if [ "$id" = default ]; then say "unset CLAUDE_CONFIG_DIR; export CCP_PROFILE=default"
  else printf 'export CLAUDE_CONFIG_DIR=%q; export CCP_PROFILE=%q\n' "$(pdir "$id")" "$id"; fi
}

cmd_run() {   # ccp run [-p number|name] [--] [claude args...]
  local want="" why="" r
  case "${1:-}" in -p|--profile) want="${2:-}"; [ -n "$want" ] || die "run: -p needs a number or name"; shift 2 ;; esac
  [ "${1:-}" = -- ] && shift
  if [ -z "$want" ]; then r="$(resolve .)" || exit 1; want="${r%%$TAB*}"; why="${r#*$TAB}"; fi
  local id c; id="$(need "$want")" || exit 1; c="$(real_claude)" || exit 1
  [ "$id" = "$(holder)" ] && id=default   # its login is in ~/.claude now; its own folder keeps no renewable copy
  if [ "$id" = default ] && interactive "$@" && { [ -f "$CCP_HOME/auto" ] || watching; }; then   # ccp service is on
    supervise "$c" "$@"; exit $?   # stay beside it: when another login is put in ~/.claude, it reopens in place
  fi
  export CCP_ACTIVE="$id"   # what is running, for `ccp prompt` in Claude Code's status line
  if [ "$id" = default ]; then unset CLAUDE_CONFIG_DIR; exec "$c" "$@"; fi
  CLAUDE_CONFIG_DIR="$(pdir "$id")" exec "$c" "$@"
}

cmd_sw() {   # ccp sw <number|name> [claude args]: that account's login from now on, and the last conversation here goes on
  [ -n "${1:-}" ] || die "usage: ccp sw <number|name> [claude args]   (continues the last conversation in this folder)"
  if [ -n "${CLAUDECODE:-}" ]; then sw_here "$1"; return; fi   # from inside Claude Code: a skill, /ccp:switch, ! ccp sw 2
  local want; want="$(need "$1")" || exit 1; shift
  [ "${1:-}" = -- ] && shift
  [ $# -gt 0 ] || set -- --continue
  swap_login "$want" >&2 || exit 1
  rm -f "$CCP_HOME/default" "$CCP_HOME/moved" "$CCP_HOME/stuck"
  cmd_run -- "$@"
}

# Switching when an account is full. `ccp watch` (run by `ccp service start`) checks every account's usage, writes the
# ones at the limit to $CCP_HOME/full, and lends ~/.claude the login of the next account with room. Nothing moves:
# background sessions take the new login when the daemon adopts them again (readopt), and a terminal session that ccp run
# started reopens the same conversation in place once it is idle (supervise).

watching() { [ -n "$(find "$CCP_HOME/full" -mmin -15 2>/dev/null)" ]; }   # ccp watch wrote it lately (every <= 300 s)

is_full() { watching && grep -q "^$1$TAB" "$CCP_HOME/full" 2>/dev/null; }

interactive() {   # a Claude Code run in a terminal that can be continued elsewhere (not -p, a subcommand or --help)
  { [ -t 0 ] && [ -t 1 ]; } || [ -n "${CCP_TEST_TTY:-}" ] || return 1
  local a
  for a in "$@"; do case "$a" in -p|--print|-h|--help|-v|--version) return 1 ;; esac; done
  case "${1:-}" in
    auth|mcp|plugin|plugins|doctor|update|upgrade|install|setup-token|config|migrate-installer|daemon|agents) return 1 ;;
  esac
  return 0   # no arguments, options, or a first prompt (claude "fix the build")
}

keep_flags() {   # the launch options a continued session keeps, one per line (not the prompt, --continue or --resume)
  while [ $# -gt 0 ]; do
    case "$1" in
      --model|--permission-mode|--add-dir|--agent|--settings|--mcp-config|--effort|--fallback-model|--append-system-prompt)
        [ $# -ge 2 ] && printf '%s\n%s\n' "$1" "$2"; shift ;;
      --model=*|--permission-mode=*|--add-dir=*|--agent=*|--settings=*|--mcp-config=*|--effort=*|--fallback-model=*) printf '%s\n' "$1" ;;
      --dangerously-skip-permissions|--allow-dangerously-skip-permissions|--chrome|--no-chrome|--ide|--verbose|--strict-mcp-config|--debug)
        printf '%s\n' "$1" ;;
    esac
    shift
  done
}

session_info() {   # session_info <file> -> "sessionId<TAB>status" from Claude Code's record of a running session
  python3 -c 'import json, sys
try: d = json.load(open(sys.argv[1]))
except Exception: sys.exit(1)
print("%s\t%s" % (d.get("sessionId") or "", d.get("status") or ""))' "$1" 2>/dev/null
}

sw_here() {   # inside Claude Code: that account's login from now on, for this session and every other one; none moves
  local to; to="$(need "$1")" || exit 1
  swap_login "$to" || exit 1
  rm -f "$CCP_HOME/default" "$CCP_HOME/moved" "$CCP_HOME/stuck"
  if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then
    say "this session runs on a profile folder of its own (a folder rule, -p or CCP_PROFILE), so it keeps that account"
  elif [ -n "${CCP_RUN:-}" ]; then say "this conversation goes on in this terminal with that login once the turn ends"
  elif [ -n "${CLAUDE_JOB_DIR:-}" ]; then
    say "this background session restarts in place once this turn ends (same conversation) and uses it from then on"
  else
    say "a terminal session started without ccp keeps the token it holds until it runs out (/exit, then claude --continue, takes it now)"
  fi
  return 0
}

session_watch() {   # session_watch <run dir> <ccp pid> <login>: beside a terminal session on ~/.claude, end it once it is idle
                    # after another account's login was put in ~/.claude (ccp use, ccp sw, ccp watch)
  local run="$1" me="$2" was="$3" pid="" info sid st n
  while sleep "${CCP_POLL:-1}"; do
    [ -n "$pid" ] || pid="$(cat "$run/pid" 2>/dev/null)"
    [ -n "$pid" ] || continue
    kill -0 "$pid" 2>/dev/null || return 0
    case "$(ps -o stat= -p "$pid" 2>/dev/null)" in T*) kill -TSTP "$me" 2>/dev/null; continue ;; esac   # Ctrl+Z: give your shell the terminal
    [ "$(holder)" != "$was" ] || continue
    info="$(session_info "$BASE/sessions/$pid.json")" || continue
    sid="${info%%$TAB*}"; st="${info#*$TAB}"
    [ -n "$sid" ] || continue
    case "$st" in ""|idle) ;; *) continue ;; esac   # never cut a turn, a tool or a question short
    printf '%s\n' "$sid" > "$run/switch"
    kill -TERM "$pid" 2>/dev/null
    n=0; while kill -0 "$pid" 2>/dev/null && [ "$n" -lt 10 ]; do sleep 1; n=$((n + 1)); done
    kill -KILL "$pid" 2>/dev/null
    return 0
  done
}

supervise() {   # supervise <claude> <args...>: ccp run on ~/.claude while ccp service is on. A terminal session reads its login
                # once, so when another account's login is put in ~/.claude it reopens the same conversation in this terminal
  local c="$1" run rc=0 mon sid l was; shift
  local -a keep=()
  while IFS= read -r l; do [ -n "$l" ] && keep+=("$l"); done <<EOF
$(keep_flags "$@")
EOF
  run="$(mktemp -d "${TMPDIR:-/tmp}/ccp-run.XXXXXX")" || die "run: no temp folder"
  while :; do
    rm -f "$run/pid" "$run/switch"
    was="$(holder)"
    session_watch "$run" "$$" "$was" &
    mon=$!
    # sh writes its pid, then becomes Claude Code: the watcher finds the session record by that pid
    CCP_RUN="$run" CCP_ACTIVE=default env -u CLAUDE_CONFIG_DIR /bin/sh -c 'echo $$ > "$0"; exec "$@"' "$run/pid" "$c" "$@"
    rc=$?
    kill "$mon" 2>/dev/null; wait "$mon" 2>/dev/null
    [ -s "$run/switch" ] || break
    sid="$(cat "$run/switch")"
    [ -t 0 ] && stty sane 2>/dev/null
    printf "\nccp: now on %s's login; this conversation goes on\n\n" "$(label "$(holder)")" >&2
    set -- ${keep[@]+"${keep[@]}"} --resume "$sid"
  done
  rm -rf "$run"
  return "$rc"
}

auto_get() { sed -n "s/^$1=//p" "$CCP_HOME/auto" 2>/dev/null | head -1; }   # a ccp service setting

check_auto() {   # check_auto <at> <every>: the numbers ccp watch takes
  case "$1" in ""|*[!0-9]*) die "--at takes a percent from 1 to 100" ;; esac
  [ "$1" -ge 1 ] && [ "$1" -le 100 ] || die "--at takes a percent from 1 to 100"
  case "$2" in ""|*[!0-9]*) die "--every takes seconds (30 to 300)" ;; esac
  [ "$2" -ge 30 ] && [ "$2" -le 300 ] || die "--every takes seconds (30 to 300)"
}

cmd_watch() {   # ccp watch [--at PERCENT] [--every SECONDS] [--once]: what `ccp service` keeps running
  local at every once=0 b w
  at="$(auto_get at)"; every="$(auto_get every)"
  while [ $# -gt 0 ]; do
    case "$1" in
      --at) shift; at="${1:-}" ;;
      --every) shift; every="${1:-}" ;;
      --once) once=1 ;;
      *) die "usage: ccp watch [--at PERCENT] [--every SECONDS] [--once]" ;;
    esac
    shift
  done
  at="${at:-99}"; every="${every:-60}"
  check_auto "$at" "$every"
  command -v python3 >/dev/null 2>&1 || die "watch needs python3"
  mkdir -p "$CCP_HOME"
  [ "$once" = 1 ] || say "$(date '+%F %T') ccp $VERSION watching every ${every}s: at ${at}%, ~/.claude takes the login of the next account with room"
  while :; do
    CCP_ROWS="$(usage_rows)" CCP_BASE_DIR="$BASE" CCP_VERSION="$VERSION" CCP_HOME_DIR="$CCP_HOME" CCP_AT="$at" CCP_SLOT="$(holder)" \
      python3 -c "$USAGE_PY" watch "$every"
    if [ -s "$CCP_HOME/want" ]; then   # the check picked another account: its login goes in ~/.claude
      w="$(cat "$CCP_HOME/want")"; rm -f "$CCP_HOME/want"
      exists "$w" && swap_login "$w"
    fi
    [ "$once" = 1 ] && return 0
    b="$(cat "$CCP_HOME/backoff" 2>/dev/null)"; case "$b" in ""|*[!0-9]*) b=0 ;; esac
    if [ "$b" -gt "$every" ]; then sleep "$b"; else sleep "$every"; fi   # the usage endpoint asked for less
  done
}

xml() { printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }

cmd_service() {   # ccp service start [--at PERCENT] [--every SECONDS] | stop | status
  local sub="${1:-status}"; [ $# -gt 0 ] && shift
  local plist lc dom self at every pid
  plist="${CCP_AGENTS_DIR:-$HOME/Library/LaunchAgents}/$AGENT.plist"; lc="${CCP_LAUNCHCTL:-launchctl}"; dom="gui/$(id -u)"
  case "$sub" in
    start)
      [ "$(uname -s)" = Darwin ] || [ -n "${CCP_LAUNCHCTL:-}" ] \
        || die "service: macOS only for now; elsewhere keep 'ccp watch' running (systemd --user, tmux)"
      at="$(auto_get at)"; every="$(auto_get every)"; at="${at:-99}"; every="${every:-60}"
      while [ $# -gt 0 ]; do
        case "$1" in
          --at) shift; at="${1:-}" ;;
          --every) shift; every="${1:-}" ;;
          *) die "usage: ccp service start [--at PERCENT] [--every SECONDS]" ;;
        esac
        shift
      done
      check_auto "$at" "$every"
      command -v python3 >/dev/null 2>&1 || die "service needs python3"
      self="$(self_path)"
      mkdir -p "$CCP_HOME" "$(dirname "$plist")"
      printf 'at=%s\nevery=%s\n' "$at" "$every" > "$CCP_HOME/auto"
      cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$AGENT</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>$(xml "$self")</string><string>watch</string></array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>$(xml "$PATH")</string>
    <key>CCP_HOME</key><string>$(xml "$CCP_HOME")</string>
    <key>CCP_BASE</key><string>$(xml "$BASE")</string>
  </dict>
  <key>WorkingDirectory</key><string>$(xml "$HOME")</string>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>30</integer>
  <key>ProcessType</key><string>Background</string>
  <key>StandardOutPath</key><string>$(xml "$CCP_HOME/watch.log")</string>
  <key>StandardErrorPath</key><string>$(xml "$CCP_HOME/watch.log")</string>
</dict>
</plist>
EOF
      "$lc" bootout "$dom/$AGENT" >/dev/null 2>&1 || true
      "$lc" bootstrap "$dom" "$plist" || die "service: launchctl could not load $plist"
      say "ccp watch is running in the background, and starts again at login"
      say "when the account in use reaches ${at}%, ~/.claude takes the login of the next account with room (checked every ${every}s)"
      say "nothing moves: sessions stay where they are and take that account's login"
      say "log: $CCP_HOME/watch.log  ·  ccp service status  ·  ccp service stop"
      ;;
    stop)
      "$lc" bootout "$dom/$AGENT" >/dev/null 2>&1 || true
      rm -f "$plist" "$CCP_HOME/auto" "$CCP_HOME/full" "$CCP_HOME/seen" "$CCP_HOME/moved" "$CCP_HOME/stuck"
      say "stopped; Claude Code keeps using $(label "$(holder)")'s login"
      ;;
    status)
      if pid="$("$lc" print "$dom/$AGENT" 2>/dev/null | sed -n 's/^[[:space:]]*pid = \([0-9]*\).*/\1/p' | head -1)" && [ -n "$pid" ]; then
        say "service: running (pid $pid), at $(auto_get at)% · every $(auto_get every)s"
      elif [ -f "$plist" ]; then say "service: loaded, not running (see $CCP_HOME/watch.log)"
      else say "service: off (ccp service start)"; fi
      say "account in use: $(label "$(holder)") (its login is in ~/.claude)"
      local mv; mv="$(cut -f1 "$CCP_HOME/moved" 2>/dev/null)"
      [ -n "$mv" ] && exists "$mv" && say "switched from $(label "$mv"); goes back when it has room"
      if watching; then
        local fid fname fused freset
        if [ -s "$CCP_HOME/seen" ]; then
          say "last check $(date -r "$CCP_HOME/seen" '+%H:%M:%S' 2>/dev/null || date -d "@$(stat -c %Y "$CCP_HOME/seen")" '+%H:%M:%S'):"
          while IFS="$TAB" read -r fid fname fused; do [ -n "$fid" ] && exists "$fid" && say "  $(label "$fid"): $fname"; done < "$CCP_HOME/seen"
        fi
        while IFS="$TAB" read -r fid fname fused freset; do
          [ -n "$fid" ] && exists "$fid" && say "full: $(label "$fid") at ${fused}% of its $fname limit$( [ "${freset:-0}" -gt 0 ] 2>/dev/null && printf ' until %s' "$(date -r "$freset" '+%m-%d %H:%M' 2>/dev/null || date -d "@$freset" '+%m-%d %H:%M' 2>/dev/null)")"
        done < "$CCP_HOME/full"
      fi
      if [ -s "$CCP_HOME/watch.log" ]; then say ""; say "last log lines:"; tail -n 3 "$CCP_HOME/watch.log" | sed 's/^/  /'; fi
      ;;
    *) die "usage: ccp service start [--at PERCENT] [--every SECONDS] | stop | status" ;;
  esac
}

cmd_rm() {
  local want="" yes=0
  while [ $# -gt 0 ]; do case "$1" in -y|--yes) yes=1 ;; *) want="$1" ;; esac; shift; done
  [ -n "$want" ] || die "usage: ccp rm <number|name> [--yes]"
  local id; id="$(need "$want")" || exit 1
  [ "$id" != default ] || die "the default profile is your ~/.claude; ccp does not remove it"
  local d; d="$(pdir "$id")"
  if [ "$yes" = 0 ]; then
    [ -t 0 ] || die "rm: not a terminal; pass --yes to remove $(label "$id")"
    printf "remove %s: sign it out and delete %s (shared files in %s stay)? [y/N] " "$(label "$id")" "$d" "$BASE"
    local ans; read -r ans || ans=""; case "$ans" in y|Y|yes) ;; *) say "kept"; return ;; esac
  fi
  local was; was="$(label "$id")"
  if [ "$(holder)" = "$id" ]; then swap_login default || die "could not bring #1's own login back; $was stays"; fi
  with_profile "$id" "$(real_claude)" auth logout >/dev/null 2>&1 || true   # drops its keychain item / credentials file
  rm -rf "${d:?}"   # links to shared files go, their targets in ~/.claude stay
  if [ -f "$CCP_HOME/rules" ]; then
    awk -F '\t' -v n="$id" '$2 != n' "$CCP_HOME/rules" > "$CCP_HOME/rules.$$" && mv "$CCP_HOME/rules.$$" "$CCP_HOME/rules"
  fi
  [ "$(cat "$CCP_HOME/default" 2>/dev/null)" = "$id" ] && rm -f "$CCP_HOME/default"
  # shellcheck disable=SC2046  # ids are single words
  write_order $(ids)
  say "removed $was"
}

usage_rows() {   # one line per profile for the usage view: number, id, config folder ("" for #1), label
  local id i=0
  for id in $(ids); do
    i=$((i + 1))
    if [ "$id" = default ]; then printf '%s\t%s\t\t%s\n' "$i" "$id" "$(label "$id")"
    else printf '%s\t%s\t%s\t%s\n' "$i" "$id" "$(pdir "$id")" "$(label "$id")"; fi
  done
}

cmd_usage() {   # ccp usage [--json] · ccp top [--every SECONDS]
  local mode="$1" every=60; shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --json) mode=json ;;
      --every) shift; every="${1:-60}" ;;
      *) die "usage: ccp usage [--json]   ·   ccp top [--every SECONDS]" ;;
    esac
    shift
  done
  case "$every" in ""|*[!0-9]*) die "--every takes seconds" ;; esac
  [ "$every" -ge 30 ] || every=30   # be gentle with the usage endpoint
  command -v python3 >/dev/null 2>&1 || die "usage needs python3"
  local here; here="$(ref "${CCP_ACTIVE:-$(resolve . | cut -f1)}" 2>/dev/null)" || here=""
  [ "$here" = default ] && here="$(holder)"   # ~/.claude runs on the login it holds
  CCP_ROWS="$(usage_rows)" CCP_BASE_DIR="$BASE" CCP_VERSION="$VERSION" CCP_HERE="$here" CCP_HOME_DIR="$CCP_HOME" CCP_SLOT="$(holder)" \
    python3 -c "$USAGE_PY" "$mode" "$every"
}

# The usage view. Each account's sign-in token is read (macOS keychain item or .credentials.json, the same places
# Claude Code keeps it) only to ask Anthropic for that account's usage, the request Claude Code's /usage makes. It is
# never printed, stored or put on a command line.
IFS= read -r -d '' USAGE_PY <<'PY' || true   # read, not $(cat <<…): bash 3.2 misparses quotes in a heredoc inside $()
import datetime, hashlib, json, os, re, select, shutil, subprocess, sys, time, unicodedata, urllib.error, urllib.request

URL = os.environ.get("CCP_USAGE_URL", "https://api.anthropic.com/api/oauth/usage")
BASE = os.environ.get("CCP_BASE_DIR") or os.path.expanduser("~/.claude")
MODE, EVERY = sys.argv[1], int(sys.argv[2])
ROWS = [dict(zip(("n", "id", "dir", "label"), l.split("\t"))) for l in os.environ.get("CCP_ROWS", "").splitlines() if l]
COLOR = sys.stdout.isatty() and not os.environ.get("NO_COLOR")


def keychain_user():
    u = os.environ.get("USER") or ""
    if not u:
        try:
            import pwd
            u = pwd.getpwuid(os.getuid()).pw_name
        except Exception:
            u = ""
    return u if re.fullmatch(r"[a-zA-Z0-9._-]+", u) else "claude-code-user"


def credentials(d):
    """The claudeAiOauth block for a config folder ("" = the default), from where Claude Code keeps it."""
    if sys.platform == "darwin" and not os.environ.get("CCP_NO_KEYCHAIN"):
        svc = "Claude Code-credentials"
        if d:   # Claude Code names a CLAUDE_CONFIG_DIR login after the folder's path
            svc += "-" + hashlib.sha256(unicodedata.normalize("NFC", d).encode()).hexdigest()[:8]
        try:
            r = subprocess.run(["security", "find-generic-password", "-a", keychain_user(), "-s", svc, "-w"],
                               capture_output=True, text=True, timeout=10)
            if r.returncode == 0 and r.stdout.strip():
                return json.loads(r.stdout).get("claudeAiOauth")
        except Exception:
            pass
    try:
        with open(os.path.join(d or BASE, ".credentials.json")) as f:
            return json.load(f).get("claudeAiOauth")
    except Exception:
        return None


SLOT = os.environ.get("CCP_SLOT") or "default"   # the account whose login ~/.claude holds (ccp use)


def stash():
    """#1's own claudeAiOauth while another account's login is in ~/.claude."""
    if sys.platform == "darwin" and not os.environ.get("CCP_NO_KEYCHAIN"):
        try:
            r = subprocess.run(["security", "find-generic-password", "-a", keychain_user(), "-s", "ccp-stash-default", "-w"],
                               capture_output=True, text=True, timeout=10)
            return json.loads(r.stdout).get("claudeAiOauth") if r.returncode == 0 and r.stdout.strip() else None
        except Exception:
            return None
    try:
        with open(os.path.join(os.environ.get("CCP_HOME_DIR") or "", "stash-default.json")) as f:
            return json.load(f).get("claudeAiOauth")
    except Exception:
        return None


def creds(row):
    """Where each account's login is now: the lent one in ~/.claude, #1's own kept aside, the rest in their folders."""
    if SLOT != "default" and row["id"] == SLOT:
        return credentials("")
    if SLOT != "default" and row["id"] == "default":
        return stash()
    return credentials(row["dir"])


def email(d):
    try:
        with open(os.path.join(d, ".claude.json") if d else os.path.expanduser("~/.claude.json")) as f:
            return (json.load(f).get("oauthAccount") or {}).get("emailAddress") or "-"
    except Exception:
        return "-"


def plan(c):
    p = (c or {}).get("subscriptionType") or "-"
    m = re.search(r"(\d+x)", (c or {}).get("rateLimitTier") or "")
    return f"{p} {m.group(1)}" if m else p


def when(s):
    try:
        return datetime.datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()
    except Exception:
        return None


def limits(u):
    out = []
    for l in u.get("limits") or []:
        kind = l.get("kind") or ""
        name = {"session": "5-hour", "five_hour": "5-hour", "weekly_all": "week"}.get(kind, kind.replace("_", " "))
        model = (((l.get("scope") or {}).get("model")) or {}).get("display_name")
        if kind == "weekly_scoped" and model:
            name = "week · " + model
        out.append({"name": name, "used": float(l.get("percent") or 0), "resets": when(l.get("resets_at") or "")})
    names = {x["name"] for x in out}
    for key, name in (("five_hour", "5-hour"), ("seven_day", "week"), ("seven_day_opus", "week · Opus"), ("seven_day_sonnet", "week · Sonnet")):
        w = u.get(key)
        if isinstance(w, dict) and name not in names and w.get("utilization") is not None:
            out.append({"name": name, "used": float(w["utilization"]), "resets": when(w.get("resets_at") or "")})
    order = {"5-hour": 0, "week": 1}
    return sorted(out, key=lambda x: order.get(x["name"], 2))


def fetch(row):
    c = creds(row)
    aside = SLOT != "default" and row["id"] == "default"
    r = {"n": int(row["n"]), "id": row["id"], "label": row["label"], "email": email(row["dir"]), "plan": plan(c), "limits": [], "error": None,
         "lendable": bool((c or {}).get("refreshToken"))}   # its login can go in ~/.claude (or come back there)
    if not c or not c.get("accessToken"):
        r["error"] = "not logged in"
        return r
    if c.get("expiresAt") and c["expiresAt"] / 1000 < time.time():
        r["error"] = "kept aside; numbers when it is back in use" if aside else f"sign-in expired: open #{row['n']} once (ccp run -p {row['n']})"
        return r
    req = urllib.request.Request(URL, headers={"Authorization": "Bearer " + c["accessToken"], "anthropic-beta": "oauth-2025-04-20",
                                               "User-Agent": "ccp/" + os.environ.get("CCP_VERSION", "")})
    try:
        with urllib.request.urlopen(req, timeout=15) as f:
            r["limits"] = limits(json.load(f))
    except urllib.error.HTTPError as e:
        r["error"] = {401: f"sign-in expired: open #{row['n']} once (ccp run -p {row['n']})", 429: "asked too often; next refresh"}.get(e.code, f"usage unavailable (HTTP {e.code})")
    except Exception:
        r["error"] = "offline or usage unavailable"
    return r


def ago(sec):
    if sec is None:
        return ""
    sec = max(0, int(sec))
    d, h, m = sec // 86400, sec % 86400 // 3600, sec % 3600 // 60
    return f"{d}d {h}h" if d else (f"{h}h {m:02d}m" if h else f"{m}m")


def paint(s, used):
    if not COLOR:
        return s
    c = "32" if used < 60 else ("33" if used < 85 else "31")
    return f"\033[{c}m{s}\033[0m"


def lines(results, fetched_at):
    width = shutil.get_terminal_size((110, 30)).columns
    barw = max(10, min(24, width - 92))
    now = time.time()
    out = [f"  {'#':<3} {'ACCOUNT':<30} {'PLAN':<10} {'LIMIT':<14} {'USED':<{barw + 6}} {'LEFT':>5}  RESETS"]
    for r in results:
        mark = "*" if r["id"] == os.environ.get("CCP_HERE") else " "
        head = f"{mark} {r['n']:<3} {r['email'][:30]:<30} {r['plan'][:10]:<10} "
        if r["error"] or not r["limits"]:
            out.append(head + (r["error"] or "no limits reported"))
            continue
        for i, l in enumerate(r["limits"]):
            fill = int(round(barw * min(l["used"], 100) / 100))
            bar = paint("█" * fill, l["used"]) + "░" * (barw - fill)
            left = f"{max(0, 100 - l['used']):.0f}%"
            reset = f"in {ago(l['resets'] - now)}" if l["resets"] else ""
            out.append((head if i == 0 else " " * len(head)) + f"{l['name'][:14]:<14} {bar} {l['used']:>3.0f}%  {left:>5}  {reset}")
    out.append("")
    out.append(f"usage as of {time.strftime('%H:%M:%S', time.localtime(fetched_at))} · * = the account claude uses here")
    return out


def top():
    import termios, tty
    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    tty.setcbreak(fd)
    sys.stdout.write("\033[?25l")
    results, last = [], 0.0
    try:
        while True:
            if time.time() - last >= EVERY:
                results, last = [fetch(r) for r in ROWS], time.time()
            head = f"ccp {os.environ.get('CCP_VERSION', '')} · usage per account · {time.strftime('%H:%M:%S')} · refresh {EVERY}s (next in {max(0, int(EVERY - (time.time() - last)))}s) · r refresh · q quit"
            sys.stdout.write("\033[H\033[2J" + "\n".join([head, ""] + lines(results, last)) + "\n")
            sys.stdout.flush()
            if select.select([sys.stdin], [], [], 1)[0]:
                k = sys.stdin.read(1)
                if k in ("q", "Q", "\x1b"):
                    break
                if k in ("r", "R"):
                    last = 0.0
    except KeyboardInterrupt:
        pass
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)
        sys.stdout.write("\033[?25h")


def watch():
    """One check for `ccp watch`: list full accounts, move the default off a full one, and back when it has room."""
    home, at = os.environ["CCP_HOME_DIR"], float(os.environ.get("CCP_AT") or 99)
    results = [fetch(r) for r in ROWS]
    by = {r["id"]: r for r in results}

    def path(name):
        return os.path.join(home, name)

    def read(name):
        try:
            with open(path(name)) as f:
                return f.read().strip()
        except Exception:
            return ""

    def write(name, text):
        tmp = path(name) + f".{os.getpid()}"
        with open(tmp, "w") as f:
            f.write(text)
        os.replace(tmp, path(name))

    def remove(name):
        try:
            os.remove(path(name))
        except FileNotFoundError:
            pass

    def blocking(r):   # the 5-hour or week limit that stops this account, the one that frees up last
        hit = [l for l in r["limits"] if l["name"] in ("5-hour", "week") and l["used"] >= at] if not r["error"] else []
        return max(hit, key=lambda l: l["resets"] or 0) if hit else None

    full = {r["id"]: blocking(r) for r in results if blocking(r)}
    write("full", "".join(f"{i}\t{l['name']}\t{l['used']:.0f}\t{int(l['resets'] or 0)}\n" for i, l in full.items()))
    before = {}   # the last good line per account: a passing hiccup (asked too often, offline) keeps it
    for line in read("seen").splitlines():
        f = line.split("\t")
        if len(f) >= 3 and f[2]:
            before[f[0]] = line + "\n"
    def transient(r):
        return r["error"] and not r["error"].startswith(("not logged in", "sign-in expired"))
    def seen(r):   # id, what a person reads (ccp service status), then name:used:resets for the status line
        if transient(r) and r["id"] in before:
            return before[r["id"]]
        ls = [l for l in r["limits"] if l["name"] in ("5-hour", "week")]
        ms = [l for l in r["limits"] if l["name"].startswith("week · ")]   # a model's own weekly limit (Fable)
        def key(l):
            return "5h" if l["name"] == "5-hour" else "wk" if l["name"] == "week" else "m." + l["name"][7:].replace(" ", "_")
        text = r["error"] or ", ".join(f"{l['name']} {l['used']:.0f}%" for l in ls) or "no limits reported"
        return f"{r['id']}\t{text}\t" + " ".join(f"{key(l)}:{l['used']:.0f}:{int(l['resets'] or 0)}" for l in ls + ms) + "\n"
    write("seen", "".join(seen(r) for r in results))   # what this check saw
    if any((r["error"] or "").startswith("asked too often") for r in results):   # back off: ask half as often, up to 10 min
        write("backoff", str(min(600, max(int(read("backoff") or 0), EVERY) * 2)))
    else:
        remove("backoff")

    def name(i):
        r = by[i]
        return f"#{r['n']} {r['email']}" if r["email"] != "-" else r["label"]

    def frees(l):
        return f", free in {ago(l['resets'] - time.time())}" if l["resets"] else ""

    def room(r, unknown_ok):   # its login can take over in ~/.claude
        if r["id"] in full or not r["lendable"]:
            return False
        if not r["error"]:
            return True
        return unknown_ok and r["error"].startswith("sign-in expired")   # Claude Code renews it when it starts

    def tell(msg):
        print(time.strftime("%Y-%m-%d %H:%M:%S ") + msg, flush=True)
        if os.environ.get("CCP_NO_NOTIFY"):
            return
        try:
            if sys.platform == "darwin":
                subprocess.run(["osascript", "-e", "on run argv", "-e", 'display notification (item 1 of argv) with title "ccp"',
                                "-e", "end run", msg], capture_output=True, timeout=10)
            elif shutil.which("notify-send"):
                subprocess.run(["notify-send", "ccp", msg], capture_output=True, timeout=10)
        except Exception:
            pass

    def use(i):   # ccp watch puts that account's login in ~/.claude (swap_login) after this check
        write("want", i + "\n")

    cur = SLOT if SLOT in by else "default"
    moved, _, mfree = read("moved").partition("\t")   # the account it first switched from, and when that one frees up
    if cur in full:
        l = full[cur]
        to = next((r["id"] for r in results if r["id"] != cur and room(r, True)), None)
        if to:
            use(to)
            if to == moved:   # back on the account it first switched from
                remove("moved")
            elif moved not in by:   # remember the first one, to go back to it
                write("moved", f"{cur}\t{int(l['resets'] or 0)}\n")
            remove("stuck")
            tell(f"{name(cur)} is at {l['used']:.0f}% of its {l['name']} limit{frees(l)}. Claude Code now uses {name(to)}'s login; sessions stay where they are.")
        elif not os.path.exists(path("stuck")):
            write("stuck", cur + "\n")
            tell(f"Every account is full. {name(cur)} is at {l['used']:.0f}% of its {l['name']} limit{frees(l)}.")
        return
    remove("stuck")
    if moved and moved not in by:
        remove("moved")
    elif moved and moved != cur and (room(by[moved], False) or (by[moved]["lendable"] and by[moved]["error"] and mfree.isdigit()
                                                                and 0 < int(mfree) < time.time())):   # kept aside: its limit reset
        use(moved)
        remove("moved")
        tell(f"{name(moved)} has room again. Claude Code uses its login again; sessions stay where they are.")
    elif moved == cur:
        remove("moved")


if MODE == "watch":
    watch()
elif MODE == "json":
    json.dump([fetch(r) for r in ROWS], sys.stdout, indent=2)
    print()
elif MODE == "top" and sys.stdin.isatty() and sys.stdout.isatty():
    top()
else:
    print("\n".join(lines([fetch(r) for r in ROWS], time.time())))
PY

cmd_init() {   # eval "$(ccp init zsh)" in ~/.zshrc (or bash): plain `claude` picks the profile
  case "${1:-}" in
    zsh|bash|"") cat <<'EOF'
claude() { command ccp run -- "$@"; }
EOF
    ;;
    *) die "init: zsh or bash" ;;
  esac
}

self_path() {   # where this ccp lives; a Homebrew link stays a link, so upgrades keep working
  echo "$(cd "$(dirname "$0")" && pwd -P)/$(basename "$0")"
}

setup_shell() {   # setup_shell <ccp>: the shell start-up file runs `ccp init`, so plain `claude` goes through ccp
  local me="$1" sh rc
  sh="$(basename "${SHELL:-}")"
  case "$sh" in
    zsh) rc="$HOME/.zshrc" ;;
    bash) rc="$HOME/.bashrc"; [ "$(uname -s)" = Darwin ] && rc="$HOME/.bash_profile" ;;
    *) say "· shell: $sh is not zsh or bash; add  eval \"\$(ccp init bash)\"  yourself"; return 0 ;;
  esac
  if grep -q '# >>> ccp >>>' "$rc" 2>/dev/null || grep -q 'ccp init' "$rc" 2>/dev/null; then say "✓ shell: $rc already runs ccp init"; return 0; fi
  {
    printf '\n# >>> ccp >>>  plain `claude` follows ccp (accounts, switching); `ccp setup --undo` removes this\n'
    command -v ccp >/dev/null 2>&1 || printf 'export PATH="%s:$PATH"\n' "$(dirname "$me")"
    printf 'eval "$(%s init %s)"\n' "$me" "$sh"
    printf '# <<< ccp <<<\n'
  } >> "$rc"
  say "✓ shell: $rc runs ccp init (new terminals)"
}

setup_statusline() {   # setup_statusline <ccp>: every account's limits under Claude Code's prompt
  local me="$1"
  case "$me" in "$HOME"/.claude*/plugins/*) me=ccp ;; esac   # a plugin's copy moves with each update
  python3 - "$BASE/settings.json" "$me prompt --usage" <<'PY'
import json, os, sys
path, cmd = sys.argv[1], sys.argv[2]
try:
    with open(path) as f:
        s = json.load(f)
except FileNotFoundError:
    s = {}
cur = (s.get("statusLine") or {}).get("command", "")
if cur and "ccp prompt" not in cur:
    print("· status line: yours stays (" + cur + "); add $(ccp prompt --usage) to it if you like")
    sys.exit(0)
if cur == cmd:
    print("✓ status line: already shows every account's limits")
    sys.exit(0)
s["statusLine"] = {"type": "command", "command": cmd}
tmp = path + ".ccp-tmp"
with open(tmp, "w") as f:
    json.dump(s, f, indent=2, ensure_ascii=False)
    f.write("\n")
os.replace(tmp, path)
print("✓ status line: every account's limits under the prompt")
PY
}

setup_plugin() {   # the Claude Code plugin: /ccp:switch, /ccp:usage
  local c src="${CCP_PLUGIN_SOURCE:-yuna-studio/claude-profiles}"
  c="$(real_claude 2>/dev/null)" || { say "· plugin: Claude Code not found"; return 0; }
  if "$c" plugin list 2>/dev/null | grep -q 'ccp@claude-profiles'; then say "✓ plugin: ccp is installed"; return 0; fi
  "$c" plugin marketplace list 2>/dev/null | grep -q 'claude-profiles' || "$c" plugin marketplace add "$src" >/dev/null 2>&1 \
    || { say "· plugin: could not add the marketplace $src"; return 0; }
  if "$c" plugin install ccp@claude-profiles >/dev/null 2>&1; then say "✓ plugin: ccp installed (new Claude Code sessions)"
  else say "· plugin: install failed; try  claude plugin install ccp@claude-profiles"; fi
}

setup_undo() {   # ccp setup --undo: take out what setup put in (the plugin and your profiles stay)
  local rc
  for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile"; do
    [ -f "$rc" ] && grep -q '# >>> ccp >>>' "$rc" || continue
    awk '/^# >>> ccp >>>/{skip=1} !skip{print} /^# <<< ccp <<</{skip=0}' "$rc" > "$rc.ccp-tmp" && mv "$rc.ccp-tmp" "$rc"
    say "✓ shell: removed from $rc"
  done
  python3 - "$BASE/settings.json" <<'PY'
import json, os, sys
path = sys.argv[1]
try:
    s = json.load(open(path))
except Exception:
    sys.exit(0)
if "ccp prompt" in (s.get("statusLine") or {}).get("command", ""):
    del s["statusLine"]
    with open(path + ".ccp-tmp", "w") as f:
        json.dump(s, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.replace(path + ".ccp-tmp", path)
    print("✓ status line: removed")
PY
  [ -f "${CCP_AGENTS_DIR:-$HOME/Library/LaunchAgents}/$AGENT.plist" ] && cmd_service stop >/dev/null && say "✓ service: stopped"
  return 0
}

cmd_setup() {   # ccp setup [--undo] [--no-shell] [--no-statusline] [--no-plugin] [--no-service]: everything, once per computer
  local shell=1 line=1 plugin=1 service=1 me
  while [ $# -gt 0 ]; do
    case "$1" in
      --undo) setup_undo; return ;;
      --no-shell) shell=0 ;;
      --no-statusline) line=0 ;;
      --no-plugin) plugin=0 ;;
      --no-service) service=0 ;;
      *) die "usage: ccp setup [--undo] [--no-shell] [--no-statusline] [--no-plugin] [--no-service]" ;;
    esac
    shift
  done
  command -v python3 >/dev/null 2>&1 || die "setup needs python3"
  me="$(self_path)"
  [ "$shell" = 1 ] && setup_shell "$me"
  [ "$line" = 1 ] && setup_statusline "$me"
  [ "$plugin" = 1 ] && setup_plugin
  if [ "$service" = 1 ]; then
    if [ "$(uname -s)" = Darwin ] || [ -n "${CCP_LAUNCHCTL:-}" ]; then cmd_service start >/dev/null && say "✓ service: running (ccp service status)"
    else say "· service: macOS only; keep 'ccp watch' running (systemd --user, tmux)"; fi
  fi
  say ""
  say "next: ccp add (sign in another account once) · open a new terminal · ccp ls"
}

status_line() {   # status_line <id of this session>: a column per account, a row per limit (bar, percent, time to reset),
                  # as ccp watch last saw them
  local fresh=0 ko=0
  [ -n "$(find "$CCP_HOME/seen" -mmin -15 2>/dev/null)" ] && fresh=1
  case "${CCP_LANG:-${LC_ALL:-${LANG:-}}}" in ko*) ko=1 ;; esac
  CCP_ROWS="$(usage_rows)" CCP_THIS="${1:-}" CCP_FRESH="$fresh" CCP_SEEN="$CCP_HOME/seen" CCP_KO="$ko" python3 -c "$STATUS_PY"
}

IFS= read -r -d '' STATUS_PY <<'PY' || true
import os, re, time, unicodedata

ROWS = [dict(zip(("n", "id", "dir", "label"), l.split("\t"))) for l in os.environ.get("CCP_ROWS", "").splitlines() if l]
THIS, KO, COLOR = os.environ.get("CCP_THIS", ""), os.environ.get("CCP_KO") == "1", not os.environ.get("NO_COLOR")
W = {"this": "이 세션", "wait": "확인 중", "out": "로그인 필요"} if KO else {"this": "this session", "wait": "checking", "out": "signed out"}
NOW = time.time()
SEEN = {}
if os.environ.get("CCP_FRESH") == "1":
    try:
        for line in open(os.environ["CCP_SEEN"]):
            f = line.rstrip("\n").split("\t")
            if f[0]:
                SEEN[f[0]] = (f[1] if len(f) > 1 else "", f[2] if len(f) > 2 else "")
    except OSError:
        pass


def paint(code, text):
    return f"\033[{code}m{text}\033[0m" if COLOR else text


def width(text):   # what the terminal shows: escapes take no room, Korean takes two
    text = re.sub(r"\033\[[0-9;]*m", "", text)
    return sum(0 if unicodedata.combining(ch) else 2 if unicodedata.east_asian_width(ch) in "WF" else 1 for ch in text)


def tone(used):   # soft green, orange, red
    return "38;5;167" if used >= 90 else "38;5;179" if used >= 70 else "38;5;108"


def bar(used, cells=10):   # eighths of a cell: 80 steps
    used = max(0.0, min(100.0, used))
    full, part = divmod(round(used / 100 * cells * 8), 8)
    filled = "█" * full + ("▏▎▍▌▋▊▉"[part - 1] if part else "")
    if not COLOR:
        return filled + "░" * (cells - len(filled))
    return f"\033[{tone(used)};48;5;237m{filled}{' ' * (cells - len(filled))}\033[0m"


def left(ts):   # 5d2h, 4h49m, 9m
    sec = max(0, int(ts - NOW))
    d, rest = divmod(sec, 86400)
    h, m = rest // 3600, rest % 3600 // 60
    return f"{d}d{h}h" if d else f"{h}h{m}m" if h else f"{m}m"


def parse(i):   # {"5h": (used, resets), "wk": …, "m.Fable": …} as ccp watch last saw it
    out = {}
    for tok in SEEN.get(i, ("", ""))[1].split():
        key, used, ts = (tok.split(":") + ["0", "0"])[:3]
        try:
            out[key] = (float(used or 0), int(ts) if ts.isdigit() else 0)
        except ValueError:
            pass
    return out


def label(key):
    return {"5h": "5h", "wk": "week"}.get(key, key[2:].replace("_", " ") if key.startswith("m.") else key)


data = {r["id"]: parse(r["id"]) for r in ROWS}
kinds = ["5h", "wk"] + sorted({k for d in data.values() for k in d if k.startswith("m.")})
kinds = [k for k in kinds if any(k in d for d in data.values())]   # one row per limit, the same row in every column
pad = max((len(label(k)) for k in kinds), default=4)


def column(row):
    n, i = row["n"], row["id"]
    name = f"#{n}" if i == "default" or i.startswith("acct-") else f"#{n} {i}"
    lines = [paint("1;7", f" ▶ {name} {W['this']} ") if i == THIS else paint("1", name)]
    d, text = data[i], SEEN.get(i, ("", ""))[0]
    if not d:
        if text == "not logged in":
            lines.append(paint("2", W["out"]))
        elif SEEN or text:
            lines.append(paint("2", W["wait"]))
        return lines
    for k in kinds:
        if k not in d:
            lines.append([paint("2", f"{label(k):<{pad}} {'·' * 10}    -"), ""])
            continue
        used, ts = d[k]
        lines.append([f"{label(k):<{pad}} {bar(used)} {paint(tone(used), f'{used:>3.0f}%')}", paint("38;5;245", left(ts) if ts else "")])
    return lines


cols = [column(r) for r in ROWS]
for c in cols:   # time left lines up on the right of each column
    rows = [l for l in c if isinstance(l, list)]
    wl = max((width(l[0]) for l in rows), default=0)
    wr = max((width(l[1]) for l in rows), default=0)
    for k, l in enumerate(c):
        if isinstance(l, list):
            c[k] = l[0] + " " * (wl - width(l[0]) + 2) + " " * (wr - width(l[1])) + l[1]
widths = [max(width(l) for l in c) for c in cols]
sep = paint("38;5;240", "│")
out = []
for k in range(max(len(c) for c in cols)):
    cells = [(c[k] if k < len(c) else "") for c in cols]
    out.append(f"  {sep}  ".join(cell + " " * (w - width(cell)) for cell, w in zip(cells, widths)).rstrip())
print("\n".join(out), end="")
PY

cmd_prompt() {   # ccp prompt [--usage]: inside Claude Code the account it runs on ("#2 work"), in a shell the one `claude` would use
                 # here; --usage lists every account with its limits, for Claude Code's status line
  local id="" inside=0
  if [ -n "${CCP_ACTIVE:-}" ]; then id="$(ref "$CCP_ACTIVE" 2>/dev/null)"; inside=1
  elif [ -n "${CLAUDECODE:-}" ]; then   # a Claude Code started without ccp: its config folder says which account
    inside=1
    case "${CLAUDE_CONFIG_DIR:-}" in "") id=default ;; "$CCP_HOME"/*) id="$(ref "$(basename "$CLAUDE_CONFIG_DIR")" 2>/dev/null)" ;; esac
  else id="$(resolve . 2>/dev/null | cut -f1)"; id="$(ref "$id" 2>/dev/null)"; fi
  [ "$id" = default ] && id="$(holder)"
  if [ "${1:-}" = --usage ]; then status_line "$id"; return 0; fi
  [ -n "$id" ] || return 0
  if [ "$inside" = 1 ] || [ "$id" != default ]; then printf '%s' "$(label "$id")"; fi   # a shell prompt stays quiet on #1
}

usage() {
  cat <<EOF
ccp $VERSION — several Claude Code accounts on one computer, no logging in again

  ccp setup                     once per computer: shell, status line, Claude Code plugin, service   (--undo)

  ccp add [name] [-N]           new profile at the end, or at number N (the rest move down); signs in once
                                [--isolated] [--no-login] [--email you@x.com] [--sso] [--console]
  ccp ls                        profiles by number, their accounts and plans, folder rules
  ccp usage [--json]            each account's limits: used, left, when they reset
  ccp top [--every 60]          the same, live in the terminal (r refresh, q quit)
  ccp use <n|name>              that account's login in ~/.claude: every session stays put and uses it (ccp use 1: #1's own)
  ccp here <n|name> [dir]       this folder and everything in it uses that profile   (ccp here --rm [dir])
  ccp mv <n|name> <N>           move a profile to number N
  ccp which [dir]               which profile a claude run here would use, and why
  ccp run [-p n|name] [-- args] run Claude Code with the profile for here (or -p)
  ccp sw <n|name>               ccp use n, then the last conversation here goes on
  ccp service start [--at 99]   in the background: when the account in use is full, ~/.claude takes the login of the
                                next one with room; sessions stay where they are   (stop · status)
  ccp watch [--at 99]           the same in this terminal
  ccp env [n|name]              eval "\$(ccp env 2)": pin this shell to a profile
  ccp login <n|name>            sign a profile in again
  ccp rm <n|name> [--yes]       sign out and delete a profile
  ccp init zsh|bash             add  eval "\$(ccp init zsh)"  to ~/.zshrc: plain \`claude\` follows the rules
  ccp prompt [--usage]          "#2 work" for your shell prompt; --usage: every account's limits for Claude Code's status line
  inside Claude Code: ccp sw 2 (or /ccp:switch 2) puts #2's login in ~/.claude: this session and every other one keep
  running where they are (background sessions at once; a terminal that runs claude through ccp reopens in place)

#1 is your normal ~/.claude. Folder: CCP_PROFILE > folder rule > ~/.claude. Profiles live in $CCP_HOME.
EOF
}

main() {
  local c="${1:-help}"; [ $# -gt 0 ] && shift
  case "$c" in
    add) cmd_add "$@" ;;
    mv|move) cmd_mv "$@" ;;
    login) cmd_login "$@" ;;
    ls|list) cmd_ls ;;
    use) cmd_use "$@" ;;
    here) cmd_here "$@" ;;
    which) cmd_which "$@" ;;
    env) cmd_env "$@" ;;
    run) cmd_run "$@" ;;
    sw|switch) cmd_sw "$@" ;;
    _respawn) cmd__respawn "$@" ;;
    watch) cmd_watch "$@" ;;
    service) cmd_service "$@" ;;
    usage) cmd_usage once "$@" ;;
    top) cmd_usage top "$@" ;;
    rm|remove) cmd_rm "$@" ;;
    init) cmd_init "$@" ;;
    setup) cmd_setup "$@" ;;
    prompt) cmd_prompt "$@" ;;
    -v|--version|version) say "ccp $VERSION" ;;
    -h|--help|help) usage ;;
    *) usage >&2; exit 2 ;;
  esac
}

main "$@"

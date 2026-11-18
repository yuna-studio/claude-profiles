#!/usr/bin/env bash
# ccp — use several Claude Code accounts on one computer without logging in again.
#
# Each account is a profile: its own Claude Code config folder (CLAUDE_CONFIG_DIR), so its login lives in its own
# keychain item (macOS) or credentials file (Linux). Your settings, CLAUDE.md, agents, commands, skills, plugins and
# project history are shared from ~/.claude unless the profile is --isolated. Profiles are numbered in order (#1 is
# your normal ~/.claude); `ccp add -2` puts a new one at #2 and moves the rest down. Folders keep their first name, since
# Claude Code ties a login to the folder's path; only the numbers move. Which profile a `claude` run uses:
#   CCP_PROFILE  >  the folder rule for the current directory (ccp here)  >  the default (ccp use)  >  #1 default (~/.claude)
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
  local dir r
  if [ -n "${CCP_PROFILE:-}" ]; then printf '%s\tCCP_PROFILE\n' "$(ref "$CCP_PROFILE" || echo "$CCP_PROFILE")"; return; fi
  dir="$(physical "${1:-.}")"
  if r="$(rule_for "$dir")"; then printf '%s\tfolder rule %s\n' "${r%%$TAB*}" "${r#*$TAB}"; return; fi
  if [ -s "$CCP_HOME/default" ]; then printf '%s\tccp use\n' "$(cat "$CCP_HOME/default")"; return; fi
  printf 'default\tbuilt-in\n'
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
  local cur id acc mark name i=0 iso p
  cur="$(resolve . | cut -f1)"
  printf '  %-3s %-34s %-14s %s\n' '#' ACCOUNT PLAN NAME
  for id in $(ids); do
    i=$((i + 1))
    acc="$(account "$id")"
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
  say ""; say "* used here ($(resolve . | cut -f2))"
}

cmd_use() {   # ccp use <number|name>: the account Claude Code uses; running sessions that follow it move there too
  [ -n "${1:-}" ] || die "usage: ccp use <number|name>   (ccp use 1, or ccp use default, goes back to ~/.claude)"
  local id n; id="$(need "$1")" || exit 1
  set_default "$id"
  say "default profile: $(label "$id")"
  n="$(follow_default)"
  [ "${n:-0}" -gt 0 ] 2>/dev/null && say "$n running session(s) move to $(label "$id") when their turn ends (ccp attach opens one)"
  return 0
}

set_default() {   # set_default <id>: what Claude Code uses from now on; your choice, so ccp watch no longer moves it back
  mkdir -p "$CCP_HOME"
  if [ "$1" = default ]; then rm -f "$CCP_HOME/default"; else echo "$1" > "$CCP_HOME/default"; fi
  rm -f "$CCP_HOME/moved" "$CCP_HOME/stuck"
}

current() {   # the account in use: ccp use, or where ccp watch moved it (#1 when neither)
  local to; to="$(cat "$CCP_HOME/default" 2>/dev/null)"; exists "$to" || to=default; echo "$to"
}

# One account at a time: sessions follow the account in use. A background session on another account moves there once
# its turn ends (the same conversation, via _move); a folder rule (ccp here) keeps a session on its own account.

follow_default() {   # start moving every background session on another account to the one in use; prints how many started
  local to from c n=0 pid sid short cwd dir
  to="$(current)"; c="$(real_claude 2>/dev/null)" || { echo 0; return 0; }
  for from in $(ids); do
    [ "$from" = "$to" ] && continue
    while IFS="$TAB" read -r pid sid short cwd; do
      [ -n "$sid" ] || continue
      if dir="$(cd "$cwd" 2>/dev/null && pwd -P)" && rule_for "$dir" >/dev/null; then continue; fi
      start_move "$from" "$to" "$pid" "$sid" "$short" "$cwd" follow && n=$((n + 1))
    done <<EOF
$(bg_sessions "$from" "$c")
EOF
  done
  echo "$n"
}

bg_sessions() {   # bg_sessions <id> <claude>: "pid<TAB>sessionId<TAB>short id<TAB>cwd" of each background session running there
  with_profile "$1" "$2" agents --json --all 2>/dev/null | python3 -c 'import json, os, sys
try: rows = json.load(sys.stdin)
except Exception: rows = []
for x in rows if isinstance(rows, list) else []:
    pid, sid = x.get("pid"), x.get("sessionId")
    if x.get("kind") not in ("background", "bg") or not pid or not sid or x.get("state") in ("failed", "stopped"):
        continue
    try: os.kill(int(pid), 0)
    except Exception: continue
    print("\t".join([str(pid), sid, x.get("id") or sid[:8], x.get("cwd") or ""]))' 2>/dev/null
}

start_move() {   # start_move <from> <to> <pid> <sessionId> <short id> <cwd> [follow]: one _move per session, outside this one
  local lock="$CCP_HOME/moving/$5"
  mkdir -p "$CCP_HOME/moving"
  if ! mkdir "$lock" 2>/dev/null; then   # one is on its way already (it gives up after an hour)
    [ -n "$(find "$lock" -maxdepth 0 -mmin +70 2>/dev/null)" ] || return 1
    rmdir "$lock" 2>/dev/null; mkdir "$lock" 2>/dev/null || return 1
  fi
  detach "$CCP_HOME/move.log" _move "$@"
}

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
  if interactive "$@" && { [ -f "$CCP_HOME/auto" ] || watching; }; then   # ccp service is on: stay beside the session
    local auto=0   # only a session that follows the default moves when its account is full; rules, -p and CCP_PROFILE stay
    case "$why" in "ccp use"|built-in) auto=1 ;; esac
    supervise "$id" "$auto" "$c" "$@"; exit $?
  fi
  export CCP_ACTIVE="$id"   # what is running, for `ccp prompt` in Claude Code's status line
  if [ "$id" = default ]; then unset CLAUDE_CONFIG_DIR; exec "$c" "$@"; fi
  CLAUDE_CONFIG_DIR="$(pdir "$id")" exec "$c" "$@"
}

cmd_sw() {   # ccp sw <number|name> [claude args]: the same conversation, now on that account
  [ -n "${1:-}" ] || die "usage: ccp sw <number|name> [claude args]   (continues the last conversation in this folder)"
  if [ -n "${CLAUDECODE:-}" ]; then sw_here "$1"; return; fi   # from inside Claude Code: a skill, /ccp:switch, ! ccp sw 2
  local want n; want="$(need "$1")" || exit 1; shift
  [ "${1:-}" = -- ] && shift
  [ $# -gt 0 ] || set -- --continue
  set_default "$want"   # one account: this conversation, new ones and the running ones all go there
  n="$(follow_default)"
  [ "${n:-0}" -gt 0 ] 2>/dev/null && say "ccp: $n running session(s) move to $(label "$want") when their turn ends" >&2
  if rule_for "$(physical .)" >/dev/null; then cmd_run -p "$want" -- "$@"; else cmd_run -- "$@"; fi   # a folder rule here: still this one
}

# Switching when an account is full. `ccp watch` (run by `ccp service start`) checks every account's usage, writes the
# ones at the limit to $CCP_HOME/full, and moves the account in use to the next one with room. Sessions follow it: one
# `ccp run` started on the default ends once it is idle (Claude Code stops a turn when the limit hits) and continues the
# same conversation there; a background session moves there the same way (follow_default).

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

under() {   # under <pid>: this command runs inside that Claude Code session, not in a background job it started
  local p=$$ n=0 cfg="${CLAUDE_CONFIG_DIR:-$BASE}"
  while [ -n "$p" ] && [ "$p" -gt 1 ] 2>/dev/null && [ "$n" -lt 40 ]; do
    [ "$p" = "$1" ] && return 0
    [ -f "$cfg/sessions/$p.json" ] && return 1   # another session (a background job) in between
    p="$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')"; n=$((n + 1))
  done
  return 1
}

sw_here() {   # sw_here <number|name>: this account from now on; this session reopens there when its turn ends, and the
              # other running sessions follow
  local to run="${CCP_RUN:-}" pid; to="$(need "$1")" || exit 1
  if [ -n "$run" ] && [ -d "$run" ] && pid="$(cat "$run/pid" 2>/dev/null)" && kill -0 "$pid" 2>/dev/null && under "$pid"; then
    set_default "$to"; sw_others "$to"
    if [ "$to" = "${CCP_ACTIVE:-}" ]; then say "already on $(label "$to")"; return 0; fi
    echo "$to" > "$run/request"
    say "switching to $(label "$to"): when this turn ends, this conversation reopens on that account in this terminal"
    return 0
  fi
  local info from bpid sid short cwd
  if info="$(bg_here)"; then   # a background session (claude --bg, agent view): move it to that account's background
    IFS="$TAB" read -r bpid sid short cwd <<EOF
$info
EOF
    from="$(account_of_dir "${CLAUDE_CONFIG_DIR:-}")" || die "this session runs on a config folder ccp does not know"
    set_default "$to"
    if [ "$to" = "$from" ]; then say "already on $(label "$to")"; sw_others "$to"; return 0; fi
    start_move "$from" "$to" "$bpid" "$sid" "$short" "$cwd" || true   # first, so following the others leaves it to this one
    sw_others "$to"
    say "moving this session to $(label "$to"): when this turn ends it continues there, the same conversation"
    say "a terminal that runs claude through ccp follows it; otherwise open it with: ccp attach"
    return 0
  fi
  die "this session was not started with ccp run while ccp service is on, so it cannot switch in place. Type /exit, then run: ccp sw $1"
}

sw_others() {   # sw_others <id>: the other running sessions follow, and say so
  local n; n="$(follow_default)"
  [ "${n:-0}" -gt 0 ] 2>/dev/null && say "$n other running session(s) move to $(label "$1") when their turn ends"
  return 0
}

account_of_dir() {   # account_of_dir <CLAUDE_CONFIG_DIR value> -> profile id ("" is #1)
  case "$1" in "") echo default ;; "$CCP_HOME"/*) ref "$(basename "$1")" ;; *) return 1 ;; esac
}

bg_here() {   # inside a background session: "pid<TAB>sessionId<TAB>short id<TAB>cwd" of that session
  [ -n "${CLAUDE_JOB_DIR:-}" ] || return 1
  local p=$$ n=0 cfg="${CLAUDE_CONFIG_DIR:-$BASE}"
  while [ -n "$p" ] && [ "$p" -gt 1 ] 2>/dev/null && [ "$n" -lt 40 ]; do
    if [ -f "$cfg/sessions/$p.json" ]; then
      python3 - "$cfg/sessions/$p.json" "$(basename "$CLAUDE_JOB_DIR")" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
if d.get("kind") not in ("bg", "background") or not d.get("sessionId"):
    sys.exit(1)
print("\t".join([str(d.get("pid") or ""), d["sessionId"], sys.argv[2] or d["sessionId"][:8], d.get("cwd") or ""]))
PY
      return
    fi
    p="$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')"; n=$((n + 1))
  done
  return 1
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

notify() {   # a desktop notification, where there is one
  [ -n "${CCP_NO_NOTIFY:-}" ] && return 0
  if [ "$(uname -s)" = Darwin ]; then
    osascript -e 'on run argv' -e 'display notification (item 1 of argv) with title "ccp"' -e 'end run' "$1" >/dev/null 2>&1
  elif command -v notify-send >/dev/null 2>&1; then notify-send ccp "$1" >/dev/null 2>&1; fi
  return 0
}

trust_dir() {   # trust_dir <from> <to> <dir>: if <from> trusts the folder (or one above it) and <to> does not, <to> trusts it too
  local a b
  if [ "$1" = default ]; then a="$HOME/.claude.json"; else a="$(pdir "$1")/.claude.json"; fi
  if [ "$2" = default ]; then b="$HOME/.claude.json"; else b="$(pdir "$2")/.claude.json"; fi
  python3 - "$a" "$b" "$3" <<'PY'
import json, os, sys
src, dst, d = sys.argv[1:]
def trusted(path):
    try:
        pr = json.load(open(path)).get("projects") or {}
    except Exception:
        return None, {}
    p = d
    while True:
        if (pr.get(p) or {}).get("hasTrustDialogAccepted"):
            return p, pr
        if p in ("/", ""):
            return None, pr
        p = os.path.dirname(p)
have, _ = trusted(dst)
want, _ = trusted(src)
if have or not want:
    sys.exit(0)
try:
    s = json.load(open(dst))
except FileNotFoundError:
    s = {}
s.setdefault("projects", {}).setdefault(want, {})["hasTrustDialogAccepted"] = True
tmp = dst + ".ccp-tmp"
fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
with os.fdopen(fd, "w") as f:
    json.dump(s, f, indent=2, ensure_ascii=False)
os.replace(tmp, dst)
PY
}

cmd__move() {   # ccp _move <from> <to> <pid> <sessionId> <short id> <cwd> [follow]: what `ccp sw` (or following the account
                # in use) starts for a background session
  local from="$1" to="$2" pid="$3" sid="$4" short="$5" cwd="$6" why="${7:-}" c cfg st n=0 out
  trap 'rmdir "$CCP_HOME/moving/$short" 2>/dev/null' EXIT   # start_move's lock: the next follow may try again
  c="$(real_claude)" || exit 1
  cfg="$BASE"; [ "$from" = default ] || cfg="$(pdir "$from")"
  say "$(date '+%F %T') move $short: $(label "$from") → $(label "$to")"
  while kill -0 "$pid" 2>/dev/null; do   # the turn has to end first, and the work it left running in the background
    st="$(session_info "$cfg/sessions/$pid.json" | cut -f2)"
    case "$st" in ""|idle) job_busy "$cfg" "$short" || break ;; esac
    n=$((n + 1)); [ "$n" -lt 3600 ] || { say "  still busy after an hour; left it on $(label "$from")"; return 1; }
    sleep 1
  done
  kill -0 "$pid" 2>/dev/null || { say "  it ended on its own; nothing to move"; return 1; }   # never start a closed one again
  if [ "$why" = follow ] && [ "$(current)" != "$to" ]; then
    say "  the account in use changed meanwhile; left it on $(label "$from")"; return 1
  fi
  if ! ls "$BASE"/projects/*/"$sid".jsonl >/dev/null 2>&1; then   # nothing saved yet: there is no conversation to continue
    say "  no conversation saved yet; nothing to move"; return 1
  fi
  trust_dir "$from" "$to" "$cwd"
  cd "$cwd" 2>/dev/null || cd "$HOME" || exit 1
  with_profile "$from" "$c" stop "$short" >/dev/null 2>&1
  n=0; while kill -0 "$pid" 2>/dev/null && [ "$n" -lt 20 ]; do sleep 1; n=$((n + 1)); done
  if kill -0 "$pid" 2>/dev/null; then say "  could not stop it; left it on $(label "$from")"; return 1; fi   # never two copies
  # no launch flags: with flags Claude Code starts a copy under a new id instead of continuing this one
  if out="$(with_profile "$to" "$c" --bg --resume "$sid" 2>&1)" && printf '%s' "$out" | grep -q 'backgrounded' \
     && started_on "$to" "$short"; then
    printf '%s\t%s\t%s\n' "$to" "$short" "$(date +%s)" > "$CCP_HOME/attach.$$" && mv "$CCP_HOME/attach.$$" "$CCP_HOME/attach"
    with_profile "$from" "$c" rm "$short" >/dev/null 2>&1   # the old account's agent view would start it again there
    say "  now on $(label "$to")"
    notify "Session $short moved to $(label "$to"). Open it: ccp attach"
    return 0
  fi
  say "  could not start it on $(label "$to"): $(printf '%s' "$out" | tail -1); back on $(label "$from")"
  with_profile "$from" "$c" --bg --resume "$sid" >/dev/null 2>&1
  notify "Could not move session $short to $(label "$to"); it stays on $(label "$from")"
  return 1
}

job_busy() {   # job_busy <config folder> <short id>: the background job still runs tasks it started (a build, a monitor)
  python3 -c 'import json, sys
try: f = (json.load(open(sys.argv[1])).get("inFlight") or {})
except Exception: sys.exit(1)
sys.exit(0 if (f.get("tasks") or 0) > 0 or (f.get("queued") or 0) > 0 else 1)' "$1/jobs/$2/state.json" 2>/dev/null
}

started_on() {   # started_on <id> <short id>: the session came up on that account (Claude Code says "backgrounded" first)
  local n=0 st c; c="$(real_claude)" || return 1
  while [ "$n" -lt 30 ]; do
    st="$(with_profile "$1" "$c" agents --json --all 2>/dev/null | python3 -c 'import json, sys
try: rows = json.load(sys.stdin)
except Exception: rows = []
for x in rows:
    if x.get("id") == sys.argv[1]:
        print("failed" if x.get("state") == "failed" else (x.get("status") or "")); break' "$2")"
    case "$st" in failed) return 1 ;; ?*) return 0 ;; esac
    sleep 1; n=$((n + 1))
  done
  return 1
}

claim_attach() {   # claim_attach <id> <run dir>: a background session moved lately to another account; this terminal shows it
  [ -s "$2/attach" ] && return 0
  [ -n "$(find "$CCP_HOME/attach" -mmin -2 2>/dev/null)" ] || return 1
  local to; to="$(cut -f1 "$CCP_HOME/attach" 2>/dev/null)"
  { exists "$to" && [ "$to" != "$1" ]; } || return 1
  mv "$CCP_HOME/attach" "$2/attach" 2>/dev/null   # one terminal takes it
}

cmd_attach() {   # ccp attach [id]: open a background session on whichever account runs it (no id: the one moved last)
  local short="${1:-}" to="" id
  if [ -z "$short" ]; then
    [ -s "$CCP_HOME/attach" ] || die "no session moved lately; ccp attach <id> (claude agents lists them)"
    IFS="$TAB" read -r to short _ < "$CCP_HOME/attach"
    rm -f "$CCP_HOME/attach"
  else
    for id in $(ids); do
      if with_profile "$id" "$(real_claude)" agents --json 2>/dev/null | grep -q "\"id\": *\"$short"; then to="$id"; break; fi
    done
    [ -n "$to" ] || die "no background session $short on any account"
  fi
  cmd_run -p "$to" -- attach "$short"
}

session_watch() {   # session_watch <id> <auto 0|1> <run dir> <ccp pid>: beside a supervised session, end it once it is idle and
                    # a switch was asked for (ccp sw inside it), or its account is full (auto)
  local id="$1" auto="$2" run="$3" me="$4" pid="" cfg info sid st to why n
  cfg="$BASE"; [ "$id" = default ] || cfg="$(pdir "$id")"
  while sleep "${CCP_POLL:-1}"; do
    [ -n "$pid" ] || pid="$(cat "$run/pid" 2>/dev/null)"
    [ -n "$pid" ] || continue
    kill -0 "$pid" 2>/dev/null || return 0
    case "$(ps -o stat= -p "$pid" 2>/dev/null)" in T*) kill -TSTP "$me" 2>/dev/null; continue ;; esac   # Ctrl+Z: give your shell the terminal
    if [ -s "$run/request" ]; then
      to="$(cat "$run/request")"; why=asked
      { exists "$to" && [ "$to" != "$id" ]; } || { rm -f "$run/request"; continue; }
    elif claim_attach "$id" "$run"; then   # a background session moved to another account: show it there
      IFS="$TAB" read -r to sid n < "$run/attach"; why=attach
    elif [ "$auto" = 1 ] && to="$(current)" && [ "$to" != "$id" ]; then   # the account in use changed: follow it
      is_full "$to" && continue
      if is_full "$id"; then why=full; else why=follow; fi
    else continue; fi
    if info="$(session_info "$cfg/sessions/$pid.json")"; then
      st="${info#*$TAB}"
      [ "$why" = attach ] || sid="${info%%$TAB*}"
    else
      st=""; [ "$why" = attach ] || continue
    fi
    [ -n "$sid" ] || continue
    case "$st" in ""|idle) ;; *) continue ;; esac   # never cut a turn, a tool or a question short
    printf '%s\t%s\t%s\n' "$to" "$sid" "$why" > "$run/switch"
    kill -TERM "$pid" 2>/dev/null
    n=0; while kill -0 "$pid" 2>/dev/null && [ "$n" -lt 10 ]; do sleep 1; n=$((n + 1)); done
    kill -KILL "$pid" 2>/dev/null
    return 0
  done
}

supervise() {   # supervise <id> <auto 0|1> <claude> <args...>: ccp run while ccp service is on; reopens the conversation on
                # another account when asked from inside, or when the account in use changes (ccp use, or full)
  local id="$1" auto="$2" c="$3" run rc=0 mon to sid why l; shift 3
  local -a keep=()
  while IFS= read -r l; do [ -n "$l" ] && keep+=("$l"); done <<EOF
$(keep_flags "$@")
EOF
  run="$(mktemp -d "${TMPDIR:-/tmp}/ccp-run.XXXXXX")" || die "run: no temp folder"
  while :; do
    rm -f "$run/pid" "$run/switch" "$run/request"
    session_watch "$id" "$auto" "$run" "$$" &
    mon=$!
    # sh writes its pid, then becomes Claude Code: the watcher finds the session record by that pid
    if [ "$id" = default ]; then CCP_RUN="$run" CCP_ACTIVE="$id" env -u CLAUDE_CONFIG_DIR /bin/sh -c 'echo $$ > "$0"; exec "$@"' "$run/pid" "$c" "$@"
    else CCP_RUN="$run" CCP_ACTIVE="$id" CLAUDE_CONFIG_DIR="$(pdir "$id")" /bin/sh -c 'echo $$ > "$0"; exec "$@"' "$run/pid" "$c" "$@"; fi
    rc=$?
    kill "$mon" 2>/dev/null; wait "$mon" 2>/dev/null
    [ -s "$run/switch" ] || break
    IFS="$TAB" read -r to sid why < "$run/switch"
    [ -t 0 ] && stty sane 2>/dev/null
    if [ "$why" = attach ]; then   # the background session it showed now runs on that account: open it there
      printf '\nccp: opening session %s on %s\n\n' "$sid" "$(label "$to")" >&2
      id="$to"; rm -f "$run/attach"
      set -- attach "$sid"
      continue
    fi
    if [ "$why" = full ]; then printf '\nccp: %s is full; continuing this conversation on %s\n\n' "$(label "$id")" "$(label "$to")" >&2
    else printf '\nccp: continuing this conversation on %s\n\n' "$(label "$to")" >&2; fi
    id="$to"
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
  local at every once=0 b
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
  at="${at:-100}"; every="${every:-60}"
  check_auto "$at" "$every"
  command -v python3 >/dev/null 2>&1 || die "watch needs python3"
  mkdir -p "$CCP_HOME"
  [ "$once" = 1 ] || say "$(date '+%F %T') ccp $VERSION watching every ${every}s: at ${at}%, sessions move to the next account with room"
  while :; do
    CCP_ROWS="$(usage_rows)" CCP_BASE_DIR="$BASE" CCP_VERSION="$VERSION" CCP_HOME_DIR="$CCP_HOME" CCP_AT="$at" \
      python3 -c "$USAGE_PY" watch "$every"
    follow_default >/dev/null   # background sessions on another account move to the one in use (move.log)
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
      at="$(auto_get at)"; every="$(auto_get every)"; at="${at:-100}"; every="${every:-60}"
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
      say "when the account in use reaches ${at}%, the next account with room takes over (checked every ${every}s)"
      say "running sessions follow it: each continues there, the same conversation, once its turn ends"
      say "log: $CCP_HOME/watch.log  ·  ccp service status  ·  ccp service stop"
      ;;
    stop)
      "$lc" bootout "$dom/$AGENT" >/dev/null 2>&1 || true
      rm -f "$plist" "$CCP_HOME/auto" "$CCP_HOME/full" "$CCP_HOME/seen" "$CCP_HOME/moved" "$CCP_HOME/stuck"
      say "stopped; Claude Code keeps using $(label "$(ref "$(cat "$CCP_HOME/default" 2>/dev/null || echo default)" || echo default)")"
      ;;
    status)
      if pid="$("$lc" print "$dom/$AGENT" 2>/dev/null | sed -n 's/^[[:space:]]*pid = \([0-9]*\).*/\1/p' | head -1)" && [ -n "$pid" ]; then
        say "service: running (pid $pid), at $(auto_get at)% · every $(auto_get every)s"
      elif [ -f "$plist" ]; then say "service: loaded, not running (see $CCP_HOME/watch.log)"
      else say "service: off (ccp service start)"; fi
      say "account in use: $(label "$(ref "$(cat "$CCP_HOME/default" 2>/dev/null || echo default)" || echo default)")"
      [ -s "$CCP_HOME/moved" ] && exists "$(cat "$CCP_HOME/moved")" && say "moved from $(label "$(cat "$CCP_HOME/moved")"); goes back when it has room"
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
  local here; here="$(ref "$(resolve . | cut -f1)" 2>/dev/null)" || here=""
  CCP_ROWS="$(usage_rows)" CCP_BASE_DIR="$BASE" CCP_VERSION="$VERSION" CCP_HERE="${CCP_ACTIVE:-$here}" \
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
    c = credentials(row["dir"])
    r = {"n": int(row["n"]), "id": row["id"], "label": row["label"], "email": email(row["dir"]), "plan": plan(c), "limits": [], "error": None}
    if not c or not c.get("accessToken"):
        r["error"] = "not logged in"
        return r
    if c.get("expiresAt") and c["expiresAt"] / 1000 < time.time():
        r["error"] = f"sign-in expired: open #{row['n']} once (ccp run -p {row['n']})"
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
    home, at = os.environ["CCP_HOME_DIR"], float(os.environ.get("CCP_AT") or 100)
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
        text = r["error"] or ", ".join(f"{l['name']} {l['used']:.0f}%" for l in ls) or "no limits reported"
        return f"{r['id']}\t{text}\t" + " ".join(f"{'5h' if l['name'] == '5-hour' else 'wk'}:{l['used']:.0f}:{int(l['resets'] or 0)}" for l in ls) + "\n"
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

    def room(r, unknown_ok):   # a new session can start there
        if r["id"] in full:
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

    def use(i):
        if i == "default":
            remove("default")
        else:
            write("default", i + "\n")

    cur = read("default") or "default"
    cur = cur if cur in by else "default"
    moved = read("moved")
    if cur in full:
        l = full[cur]
        to = next((r["id"] for r in results if r["id"] != cur and room(r, True)), None)
        if to:
            use(to)
            if to == moved:   # back on the account it first moved from
                remove("moved")
            elif moved not in by:   # remember the first one, to go back to it
                write("moved", cur + "\n")
            remove("stuck")
            tell(f"{name(cur)} is at {l['used']:.0f}% of its {l['name']} limit{frees(l)}. Claude Code now uses {name(to)}; running sessions follow.")
        elif not os.path.exists(path("stuck")):
            write("stuck", cur + "\n")
            tell(f"Every account is full. {name(cur)} is at {l['used']:.0f}% of its {l['name']} limit{frees(l)}.")
        return
    remove("stuck")
    if moved and moved not in by:
        remove("moved")
    elif moved and moved != cur and room(by[moved], False):
        use(moved)
        remove("moved")
        tell(f"{name(moved)} has room again. Claude Code uses it again; running sessions follow.")
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

dur() {   # dur <seconds>: "4d 15h", "4h 49m", "12m" (or 4일 15시간 … in Korean)
  local s="$1" d h m
  [ "$s" -gt 0 ] 2>/dev/null || s=0
  d=$((s / 86400)); h=$((s % 86400 / 3600)); m=$((s % 3600 / 60))
  if [ "${3:-}" = short ]; then   # the largest unit only: 5일, 4h, 39분
    if [ "${2:-}" = ko ]; then
      if [ "$d" -gt 0 ]; then printf '%s일' "$d"; elif [ "$h" -gt 0 ]; then printf '%s시간' "$h"; else printf '%s분' "$m"; fi
    elif [ "$d" -gt 0 ]; then printf '%sd' "$d"; elif [ "$h" -gt 0 ]; then printf '%sh' "$h"; else printf '%sm' "$m"; fi
  elif [ "${2:-}" = ko ]; then
    if [ "$d" -gt 0 ]; then printf '%s일 %s시간' "$d" "$h"; elif [ "$h" -gt 0 ]; then printf '%s시간 %s분' "$h" "$m"; else printf '%s분' "$m"; fi
  else
    if [ "$d" -gt 0 ]; then printf '%sd %sh' "$d" "$h"; elif [ "$h" -gt 0 ]; then printf '%sh %sm' "$h" "$m"; else printf '%sm' "$m"; fi
  fi
}

status_line() {   # status_line <id of this session>: every account with its limits and resets as ccp watch last saw them
  local lang=en now fresh=0 id i=0 out="" seg line text detail tok name rest used reset short=0
  local on="" off="" bold="" dim="" red="" yellow="" green="" w_this="this session" w_5h="5h" w_wk="week"
  local w_wait="checking" w_out="signed out"
  case "${CCP_LANG:-${LC_ALL:-${LANG:-}}}" in ko*) lang=ko; w_this="이 세션"; w_5h="5시간"; w_wk="주간"; w_wait="확인 중"; w_out="로그인 필요" ;; esac
  if [ -z "${NO_COLOR:-}" ]; then
    on="$(printf '\033[1;7m')"; off="$(printf '\033[0m')"; bold="$(printf '\033[1m')"; dim="$(printf '\033[2m')"
    red="$(printf '\033[31m')"; yellow="$(printf '\033[33m')"; green="$(printf '\033[32m')"
  fi
  now="$(date +%s)"
  [ -n "$(find "$CCP_HOME/seen" -mmin -15 2>/dev/null)" ] && fresh=1
  [ "$(ids | wc -l | tr -d ' ')" -ge 3 ] && short=1   # 3+ accounts: the others get one short line each
  for id in $(ids); do
    i=$((i + 1)); text=""; detail=""
    if [ "$fresh" = 1 ]; then
      line="$(awk -F '\t' -v id="$id" '$1 == id { print $2 "\t" $3; exit }' "$CCP_HOME/seen")"
      if [ -n "$line" ]; then text="${line%%"$TAB"*}"; detail="${line#*"$TAB"}"; fi
    fi
    if [ "$id" = "$1" ]; then seg="${on} ▶ #${i} ${w_this} ${off}"; else seg="${bold}#${i}${off}"; fi
    if [ -n "$detail" ]; then
      for tok in $detail; do   # 5h:3:1795012345
        name="${tok%%:*}"; rest="${tok#*:}"; used="${rest%%:*}"; reset="${rest#*:}"
        case "${name}" in 5h) name="${w_5h}" ;; *) name="${w_wk}" ;; esac
        if [ "${used}" -ge 90 ] 2>/dev/null; then used="${red}${used}%${off}"
        elif [ "${used}" -ge 70 ] 2>/dev/null; then used="${yellow}${used}%${off}"
        else used="${green}${used}%${off}"; fi
        if [ "$short" = 1 ] && [ "$id" != "$1" ]; then seg="${seg} ${name} ${used}"; else seg="${seg}  ${name} ${used}"; fi
        if [ "${reset:-0}" -gt 0 ] 2>/dev/null; then
          if [ "$short" = 1 ] && [ "$id" != "$1" ]; then seg="${seg}${dim}($(dur $((reset - now)) "$lang" short))${off}"
          elif [ "$lang" = ko ]; then seg="${seg} ${dim}($(dur $((reset - now)) ko) 뒤 리셋)${off}"
          else seg="${seg} ${dim}(resets in $(dur $((reset - now))))${off}"; fi
        fi
      done
    else
      case "$text" in   # no numbers yet: a new account, or the usage endpoint asked to wait
        "not logged in") seg="${seg}  ${dim}${w_out}${off}" ;;
        "sign-in expired"*|"") [ "$fresh" = 1 ] && seg="${seg}  ${dim}${w_wait}${off}" ;;
        *) seg="${seg}  ${dim}${w_wait}${off}" ;;
      esac
    fi
    out="${out}${out:+  ${dim}┃${off}  }${seg}"
  done
  printf '%s' "${out}"   # no "new sessions →": a session follows the account in use, so there is only one
}

cmd_prompt() {   # ccp prompt [--usage]: inside Claude Code the account it runs on ("#2 work"), in a shell the one `claude` would use
                 # here; --usage lists every account with its limits, for Claude Code's status line
  local id="" inside=0
  if [ -n "${CCP_ACTIVE:-}" ]; then id="$(ref "$CCP_ACTIVE" 2>/dev/null)"; inside=1
  elif [ -n "${CLAUDECODE:-}" ]; then   # a Claude Code started without ccp: its config folder says which account
    inside=1
    case "${CLAUDE_CONFIG_DIR:-}" in "") id=default ;; "$CCP_HOME"/*) id="$(ref "$(basename "$CLAUDE_CONFIG_DIR")" 2>/dev/null)" ;; esac
  else id="$(resolve . 2>/dev/null | cut -f1)"; id="$(ref "$id" 2>/dev/null)"; fi
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
  ccp use <n|name>              the account everywhere; running sessions follow (ccp use 1: back to ~/.claude)
  ccp here <n|name> [dir]       this folder and everything in it uses that profile   (ccp here --rm [dir])
  ccp mv <n|name> <N>           move a profile to number N
  ccp which [dir]               which profile a claude run here would use, and why
  ccp run [-p n|name] [-- args] run Claude Code with the profile for here (or -p)
  ccp sw <n|name>               switch: account n from now on, and the last conversation here continues there
  ccp attach [id]               open a background session on whichever account runs it (no id: the one moved last)
  ccp service start [--at 100]  in the background: when the account in use is full, sessions move to the next one
                                with room, and sessions started with ccp run continue there   (stop · status)
  ccp watch [--at 100]          the same in this terminal
  ccp env [n|name]              eval "\$(ccp env 2)": pin this shell to a profile
  ccp login <n|name>            sign a profile in again
  ccp rm <n|name> [--yes]       sign out and delete a profile
  ccp init zsh|bash             add  eval "\$(ccp init zsh)"  to ~/.zshrc: plain \`claude\` follows the rules
  ccp prompt [--usage]          "#2 work" for your shell prompt; --usage: every account's limits for Claude Code's status line
  inside Claude Code: ccp sw 2 (or /ccp:switch 2) moves this conversation to #2 when the turn ends; a background session
  moves to #2's background, and a terminal that runs claude through ccp (ccp setup) follows it

#1 is your normal ~/.claude. Order: CCP_PROFILE > folder rule > ccp use > #1. Profiles live in $CCP_HOME.
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
    attach) cmd_attach "$@" ;;
    _move) cmd__move "$@" ;;
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

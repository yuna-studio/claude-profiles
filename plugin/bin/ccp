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

cmd_use() {
  [ -n "${1:-}" ] || die "usage: ccp use <number|name>   (ccp use 1, or ccp use default, goes back to ~/.claude)"
  local id; id="$(need "$1")" || exit 1; mkdir -p "$CCP_HOME"
  if [ "$id" = default ]; then rm -f "$CCP_HOME/default"; else echo "$id" > "$CCP_HOME/default"; fi
  rm -f "$CCP_HOME/moved" "$CCP_HOME/stuck"   # your choice now; ccp watch no longer moves it back
  say "default profile: $(label "$id")"
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
  local want="$1"; shift
  [ "${1:-}" = -- ] && shift
  [ $# -gt 0 ] || set -- --continue
  cmd_run -p "$want" -- "$@"
}

# Switching when an account is full. `ccp watch` (run by `ccp service start`) checks every account's usage, writes the
# ones at the limit to $CCP_HOME/full, and moves the default (what new sessions use) to the next account with room.
# A session `ccp run` starts on the default is watched while it runs: once the watcher lists its account and the session
# is idle (Claude Code stops a turn when the limit hits), it ends and continues the same conversation on the new default.

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

sw_here() {   # sw_here <number|name>: ask the ccp run around this session to reopen it on that account when the turn ends
  local to run="${CCP_RUN:-}" pid; to="$(need "$1")" || exit 1
  if [ -n "$run" ] && [ -d "$run" ] && pid="$(cat "$run/pid" 2>/dev/null)" && kill -0 "$pid" 2>/dev/null && under "$pid"; then
    if [ "$to" = "${CCP_ACTIVE:-}" ]; then say "already on $(label "$to")"; return 0; fi
    echo "$to" > "$run/request"
    say "switching to $(label "$to"): when this turn ends, this conversation reopens on that account in this terminal"
    return 0
  fi
  die "this session was not started with ccp run while ccp service is on, so it cannot switch in place. Type /exit, then run: ccp sw $1"
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
    elif [ "$auto" = 1 ] && is_full "$id"; then
      to="$(cat "$CCP_HOME/default" 2>/dev/null)"; exists "$to" || to=default; why=full
      [ "$to" != "$id" ] || continue   # every account is full: stay
      is_full "$to" && continue
    else continue; fi
    info="$(session_info "$cfg/sessions/$pid.json")" || continue
    sid="${info%%$TAB*}"; st="${info#*$TAB}"
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
                # another account when asked from inside, or when the account is full
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
  local at every once=0
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
  [ "$once" = 1 ] || say "$(date '+%F %T') ccp $VERSION watching every ${every}s: at ${at}%, new sessions move to the next account with room"
  while :; do
    CCP_ROWS="$(usage_rows)" CCP_BASE_DIR="$BASE" CCP_VERSION="$VERSION" CCP_HOME_DIR="$CCP_HOME" CCP_AT="$at" \
      python3 -c "$USAGE_PY" watch "$every"
    [ "$once" = 1 ] && return 0
    sleep "$every"
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
      self="$(cd "$(dirname "$0")" && pwd -P)/$(basename "$0")"   # a Homebrew link stays a link: upgrades keep working
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
      say "when the account new sessions use reaches ${at}%, they move to the next account with room (checked every ${every}s)"
      say "a session you start with ccp run (or claude, after ccp init) continues there once it stops at the limit"
      say "log: $CCP_HOME/watch.log  ·  ccp service status  ·  ccp service stop"
      ;;
    stop)
      "$lc" bootout "$dom/$AGENT" >/dev/null 2>&1 || true
      rm -f "$plist" "$CCP_HOME/auto" "$CCP_HOME/full" "$CCP_HOME/seen" "$CCP_HOME/moved" "$CCP_HOME/stuck"
      say "stopped; new sessions keep using $(label "$(ref "$(cat "$CCP_HOME/default" 2>/dev/null || echo default)" || echo default)")"
      ;;
    status)
      if pid="$("$lc" print "$dom/$AGENT" 2>/dev/null | sed -n 's/^[[:space:]]*pid = \([0-9]*\).*/\1/p' | head -1)" && [ -n "$pid" ]; then
        say "service: running (pid $pid), at $(auto_get at)% · every $(auto_get every)s"
      elif [ -f "$plist" ]; then say "service: loaded, not running (see $CCP_HOME/watch.log)"
      else say "service: off (ccp service start)"; fi
      say "new sessions use: $(label "$(ref "$(cat "$CCP_HOME/default" 2>/dev/null || echo default)" || echo default)")"
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
    def seen(r):   # id, what a person reads (ccp service status), then name:used:resets for the status line
        ls = [l for l in r["limits"] if l["name"] in ("5-hour", "week")]
        text = r["error"] or ", ".join(f"{l['name']} {l['used']:.0f}%" for l in ls) or "no limits reported"
        return f"{r['id']}\t{text}\t" + " ".join(f"{'5h' if l['name'] == '5-hour' else 'wk'}:{l['used']:.0f}:{int(l['resets'] or 0)}" for l in ls) + "\n"
    write("seen", "".join(seen(r) for r in results))   # what this check saw

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
            tell(f"{name(cur)} is at {l['used']:.0f}% of its {l['name']} limit{frees(l)}. New Claude Code sessions use {name(to)}.")
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
        tell(f"{name(moved)} has room again. New Claude Code sessions use it again.")
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

dur() {   # dur <seconds>: "4d 15h", "4h 49m", "12m" (or 4일 15시간 … in Korean)
  local s="$1" d h m
  [ "$s" -gt 0 ] 2>/dev/null || s=0
  d=$((s / 86400)); h=$((s % 86400 / 3600)); m=$((s % 3600 / 60))
  if [ "${2:-}" = ko ]; then
    if [ "$d" -gt 0 ]; then printf '%s일 %s시간' "$d" "$h"; elif [ "$h" -gt 0 ]; then printf '%s시간 %s분' "$h" "$m"; else printf '%s분' "$m"; fi
  else
    if [ "$d" -gt 0 ]; then printf '%sd %sh' "$d" "$h"; elif [ "$h" -gt 0 ]; then printf '%sh %sm' "$h" "$m"; else printf '%sm' "$m"; fi
  fi
}

status_line() {   # status_line <id of this session>: every account with its limits and resets as ccp watch last saw them
  local lang=en now fresh=0 id i=0 out="" seg line text detail tok name rest used reset to
  local on="" off="" bold="" dim="" red="" yellow="" green="" w_this="this session" w_5h="5h" w_wk="week" w_new="new sessions →"
  case "${CCP_LANG:-${LC_ALL:-${LANG:-}}}" in ko*) lang=ko; w_this="이 세션"; w_5h="5시간"; w_wk="주간"; w_new="새 세션 →" ;; esac
  if [ -z "${NO_COLOR:-}" ]; then
    on="$(printf '\033[1;7m')"; off="$(printf '\033[0m')"; bold="$(printf '\033[1m')"; dim="$(printf '\033[2m')"
    red="$(printf '\033[31m')"; yellow="$(printf '\033[33m')"; green="$(printf '\033[32m')"
  fi
  now="$(date +%s)"
  [ -n "$(find "$CCP_HOME/seen" -mmin -15 2>/dev/null)" ] && fresh=1
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
        seg="${seg}  ${name} ${used}"
        if [ "${reset:-0}" -gt 0 ] 2>/dev/null; then
          if [ "$lang" = ko ]; then seg="${seg} ${dim}($(dur $((reset - now)) ko) 뒤 리셋)${off}"
          else seg="${seg} ${dim}(resets in $(dur $((reset - now))))${off}"; fi
        fi
      done
    else
      case "$text" in
        "") ;;
        "sign-in expired"*) seg="${seg}  ${dim}sign-in expired${off}" ;;
        "not logged in") seg="${seg}  ${dim}not logged in${off}" ;;
        *) seg="${seg}  ${dim}?${off}" ;;
      esac
    fi
    out="${out}${out:+  ${dim}┃${off}  }${seg}"
  done
  if [ -n "$1" ]; then   # where a new session starts, when that is another account
    to="$(cat "$CCP_HOME/default" 2>/dev/null)"; exists "$to" || to=default
    [ "$to" = "$1" ] || out="${out}  ${dim}┃${off}  ${w_new} ${bold}#$(pos_of "$to")${off}"
  fi
  printf '%s' "${out}"
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

  ccp add [name] [-N]           new profile at the end, or at number N (the rest move down); signs in once
                                [--isolated] [--no-login] [--email you@x.com] [--sso] [--console]
  ccp ls                        profiles by number, their accounts and plans, folder rules
  ccp usage [--json]            each account's limits: used, left, when they reset
  ccp top [--every 60]          the same, live in the terminal (r refresh, q quit)
  ccp use <n|name>              default profile everywhere (ccp use 1: back to ~/.claude)
  ccp here <n|name> [dir]       this folder and everything in it uses that profile   (ccp here --rm [dir])
  ccp mv <n|name> <N>           move a profile to number N
  ccp which [dir]               which profile a claude run here would use, and why
  ccp run [-p n|name] [-- args] run Claude Code with the profile for here (or -p)
  ccp sw <n|name>               switch: continue the last conversation in this folder on account n (after /exit)
  ccp service start [--at 100]  in the background: when the account in use is full, new sessions use the next one
                                with room, and sessions started with ccp run continue there   (stop · status)
  ccp watch [--at 100]          the same in this terminal
  ccp env [n|name]              eval "\$(ccp env 2)": pin this shell to a profile
  ccp login <n|name>            sign a profile in again
  ccp rm <n|name> [--yes]       sign out and delete a profile
  ccp init zsh|bash             add  eval "\$(ccp init zsh)"  to ~/.zshrc: plain \`claude\` follows the rules
  ccp prompt [--usage]          "#2 work" for your shell prompt; --usage: every account's limits for Claude Code's status line
  inside Claude Code, while ccp service is on: ccp sw 2 (or /ccp:switch 2) reopens this conversation on #2 in place

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
    watch) cmd_watch "$@" ;;
    service) cmd_service "$@" ;;
    usage) cmd_usage once "$@" ;;
    top) cmd_usage top "$@" ;;
    rm|remove) cmd_rm "$@" ;;
    init) cmd_init "$@" ;;
    prompt) cmd_prompt "$@" ;;
    -v|--version|version) say "ccp $VERSION" ;;
    -h|--help|help) usage ;;
    *) usage >&2; exit 2 ;;
  esac
}

main "$@"

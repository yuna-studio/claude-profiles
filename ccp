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
VERSION="0.2.0"
CCP_HOME="${CCP_HOME:-$HOME/.claude-profiles}"
BASE="${CCP_BASE:-$HOME/.claude}"   # the default profile's folder: what other profiles share from
TAB="$(printf '\t')"
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
  local want=""
  case "${1:-}" in -p|--profile) want="${2:-}"; [ -n "$want" ] || die "run: -p needs a number or name"; shift 2 ;; esac
  [ "${1:-}" = -- ] && shift
  [ -n "$want" ] || want="$(resolve . | cut -f1)"
  local id c; id="$(need "$want")" || exit 1; c="$(real_claude)" || exit 1
  if [ "$id" = default ]; then unset CLAUDE_CONFIG_DIR; exec "$c" "$@"; fi
  CLAUDE_CONFIG_DIR="$(pdir "$id")" exec "$c" "$@"
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

cmd_init() {   # eval "$(ccp init zsh)" in ~/.zshrc (or bash): plain `claude` picks the profile
  case "${1:-}" in
    zsh|bash|"") cat <<'EOF'
claude() { command ccp run -- "$@"; }
EOF
    ;;
    *) die "init: zsh or bash" ;;
  esac
}

cmd_prompt() {   # profile for a prompt or status line ("#2" or "#2 work"); empty for the default profile
  local id; id="$(resolve . 2>/dev/null | cut -f1)"; id="$(ref "$id" 2>/dev/null)" || return 0
  [ "$id" = default ] || printf '%s' "$(label "$id")"
}

usage() {
  cat <<EOF
ccp $VERSION — several Claude Code accounts on one computer, no logging in again

  ccp add [name] [-N]           new profile at the end, or at number N (the rest move down); signs in once
                                [--isolated] [--no-login] [--email you@x.com] [--sso] [--console]
  ccp ls                        profiles by number, their accounts and plans, folder rules
  ccp use <n|name>              default profile everywhere (ccp use 1: back to ~/.claude)
  ccp here <n|name> [dir]       this folder and everything in it uses that profile   (ccp here --rm [dir])
  ccp mv <n|name> <N>           move a profile to number N
  ccp which [dir]               which profile a claude run here would use, and why
  ccp run [-p n|name] [-- args] run Claude Code with the profile for here (or -p)
  ccp env [n|name]              eval "\$(ccp env 2)": pin this shell to a profile
  ccp login <n|name>            sign a profile in again
  ccp rm <n|name> [--yes]       sign out and delete a profile
  ccp init zsh|bash             add  eval "\$(ccp init zsh)"  to ~/.zshrc: plain \`claude\` follows the rules
  ccp prompt                    "#2" for a prompt or status line (empty for the default profile)

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
    rm|remove) cmd_rm "$@" ;;
    init) cmd_init "$@" ;;
    prompt) cmd_prompt ;;
    -v|--version|version) say "ccp $VERSION" ;;
    -h|--help|help) usage ;;
    *) usage >&2; exit 2 ;;
  esac
}

main "$@"

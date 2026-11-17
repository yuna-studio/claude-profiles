#!/usr/bin/env bash
# ccp — use several Claude Code accounts on one computer without logging in again.
#
# Each account is a profile: its own Claude Code config folder (CLAUDE_CONFIG_DIR), so its login lives in its own
# keychain item (macOS) or credentials file (Linux). Your settings, CLAUDE.md, agents, commands, skills, plugins and
# project history are shared from ~/.claude unless the profile is --isolated. Which profile a `claude` run uses:
#   CCP_PROFILE  >  the folder rule for the current directory (ccp here)  >  the default (ccp use)  >  "default" (~/.claude)
#
# Works with bash 3.2 (stock macOS). https://github.com/yuna-studio/claude-profiles  ·  MIT
set -u
VERSION="0.1.0"
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

valid_name() {
  case "$1" in ""|.*|*[!A-Za-z0-9._-]*) return 1 ;; esac
  [ "${#1}" -le 40 ]
}

pdir() { echo "$CCP_HOME/$1"; }   # config folder of a named profile

exists() { [ "$1" = default ] || [ -f "$(pdir "$1")/.ccp" ]; }

need() { exists "$1" || die "no profile '$1' (ccp ls lists them, ccp add $1 makes it)"; }

physical() {   # absolute path with symlinks resolved; the directory must exist
  (cd "$1" 2>/dev/null && pwd -P) || die "no such directory: $1"
}

profiles() {   # default first, then the named ones
  echo default
  [ -d "$CCP_HOME" ] || return 0
  for d in "$CCP_HOME"/*/; do [ -f "$d.ccp" ] && basename "$d"; done
  return 0
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
  if [ -n "${CCP_PROFILE:-}" ]; then printf '%s\t%s\n' "$CCP_PROFILE" "CCP_PROFILE"; return; fi
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

cmd_add() {
  local name="" isolated=0 login=1 mcp=1 a
  local -a largs=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --isolated) isolated=1 ;;
      --no-login) login=0 ;;
      --no-mcp) mcp=0 ;;
      --email|--sso|--console|--claudeai) largs+=("$1"); [ "$1" = --email ] && { shift; largs+=("${1:-}"); } ;;
      -*) die "add: unknown option $1" ;;
      *) [ -z "$name" ] && name="$1" || die "add: one name only" ;;
    esac
    shift
  done
  valid_name "$name" || die "usage: ccp add <name> [--isolated] [--no-login] [--email you@x.com]  (name: letters, digits, . _ -)"
  [ "$name" != default ] || die "'default' is your normal ~/.claude; pick another name"
  exists "$name" && die "profile '$name' exists (ccp login $name signs in again)"
  local d; d="$(pdir "$name")"
  [ -e "$d" ] && die "$d is in the way; move it first"
  mkdir -p "$d" && chmod 700 "$CCP_HOME" "$d"
  if [ "$isolated" = 1 ]; then echo "isolated=1" > "$d/.ccp"; else echo "isolated=0" > "$d/.ccp"; share_into "$d"; fi
  [ "$mcp" = 1 ] && [ "$isolated" = 0 ] && copy_mcp "$d"
  say "profile '$name' → $d$( [ "$isolated" = 1 ] && echo ' (isolated)' )"
  if [ "$login" = 1 ]; then
    say "signing in — pick the account for '$name' in the browser"
    a="$(real_claude)"
    if [ ${#largs[@]} -gt 0 ]; then with_profile "$name" "$a" auth login "${largs[@]}"; else with_profile "$name" "$a" auth login; fi \
      || die "sign-in did not finish; run: ccp login $name"
  fi
}

cmd_login() {
  local name="${1:-}"; [ -n "$name" ] || die "usage: ccp login <name> [claude auth login options]"
  need "$name"; shift
  with_profile "$name" "$(real_claude)" auth login "$@"
}

cmd_ls() {
  local cur n acc mark kind
  cur="$(resolve . | cut -f1)"
  printf '  %-14s %-34s %-14s %s\n' PROFILE ACCOUNT PLAN FOLDER
  for n in $(profiles); do
    acc="$(account "$n")"
    mark=" "; [ "$n" = "$cur" ] && mark="*"
    kind="$BASE"; [ "$n" = default ] || kind="$(pdir "$n")"
    grep -q '^isolated=1' "$(pdir "$n")/.ccp" 2>/dev/null && kind="$kind (isolated)"
    printf '%s %-14s %-34s %-14s %s\n' "$mark" "$n" "${acc%%$TAB*}" "${acc#*$TAB}" "$kind"
  done
  if [ -s "$CCP_HOME/rules" ]; then
    say ""; say "folder rules:"
    while IFS="$TAB" read -r p n; do [ -n "$p" ] && printf '  %s → %s\n' "$p" "$n"; done < "$CCP_HOME/rules"
  fi
  say ""; say "* used here ($(resolve . | cut -f2))"
}

cmd_use() {
  local name="${1:-}"; [ -n "$name" ] || die "usage: ccp use <name>   (ccp use default goes back to ~/.claude)"
  need "$name"; mkdir -p "$CCP_HOME"
  if [ "$name" = default ]; then rm -f "$CCP_HOME/default"; else echo "$name" > "$CCP_HOME/default"; fi
  say "default profile: $name"
}

cmd_here() {   # ccp here <name> [dir] | ccp here --rm [dir]
  local name="${1:-}" dir tmp
  [ -n "$name" ] || die "usage: ccp here <name> [dir]   ·   ccp here --rm [dir]"
  dir="$(physical "${2:-.}")"; mkdir -p "$CCP_HOME"; touch "$CCP_HOME/rules"
  [ "$name" = --rm ] || need "$name"
  tmp="$CCP_HOME/rules.$$"
  awk -F '\t' -v p="$dir" '$1 != p' "$CCP_HOME/rules" > "$tmp" && mv "$tmp" "$CCP_HOME/rules"
  if [ "$name" = --rm ]; then say "no rule for $dir"; return; fi
  printf '%s\t%s\n' "$dir" "$name" >> "$CCP_HOME/rules"
  say "$dir and the folders in it → $name"
}

cmd_which() {
  local r name
  r="$(resolve "${1:-.}")"; name="${r%%$TAB*}"
  need "$name"
  say "$name  ($(printf '%s' "$r" | cut -f2))"
  if [ "$name" = default ]; then say "config: $BASE"; else say "config: $(pdir "$name")"; fi
}

cmd_env() {   # eval "$(ccp env [name])": pin this shell to a profile
  local name="${1:-$(resolve . | cut -f1)}"
  need "$name"
  if [ "$name" = default ]; then say "unset CLAUDE_CONFIG_DIR; export CCP_PROFILE=default"
  else printf 'export CLAUDE_CONFIG_DIR=%q; export CCP_PROFILE=%q\n' "$(pdir "$name")" "$name"; fi
}

cmd_run() {   # ccp run [-p name] [--] [claude args...]
  local name=""
  case "${1:-}" in -p|--profile) name="${2:-}"; [ -n "$name" ] || die "run: -p needs a name"; shift 2 ;; esac
  [ "${1:-}" = -- ] && shift
  [ -n "$name" ] || name="$(resolve . | cut -f1)"
  need "$name"
  local c; c="$(real_claude)"
  if [ "$name" = default ]; then unset CLAUDE_CONFIG_DIR; exec "$c" "$@"; fi
  CLAUDE_CONFIG_DIR="$(pdir "$name")" exec "$c" "$@"
}

cmd_rm() {
  local name="" yes=0
  while [ $# -gt 0 ]; do case "$1" in -y|--yes) yes=1 ;; *) name="$1" ;; esac; shift; done
  [ -n "$name" ] || die "usage: ccp rm <name> [--yes]"
  [ "$name" != default ] || die "the default profile is your ~/.claude; ccp does not remove it"
  need "$name"
  local d; d="$(pdir "$name")"
  if [ "$yes" = 0 ]; then
    [ -t 0 ] || die "rm: not a terminal; pass --yes to remove '$name'"
    printf "remove profile '%s': sign it out and delete %s (shared files in %s stay)? [y/N] " "$name" "$d" "$BASE"
    local ans; read -r ans || ans=""; case "$ans" in y|Y|yes) ;; *) say "kept"; return ;; esac
  fi
  with_profile "$name" "$(real_claude)" auth logout >/dev/null 2>&1 || true   # drops its keychain item / credentials file
  rm -rf "${d:?}"   # links to shared files go, their targets in ~/.claude stay
  if [ -f "$CCP_HOME/rules" ]; then
    awk -F '\t' -v n="$name" '$2 != n' "$CCP_HOME/rules" > "$CCP_HOME/rules.$$" && mv "$CCP_HOME/rules.$$" "$CCP_HOME/rules"
  fi
  [ "$(cat "$CCP_HOME/default" 2>/dev/null)" = "$name" ] && rm -f "$CCP_HOME/default"
  say "removed '$name'"
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

cmd_prompt() {   # short name for a prompt or status line; empty for the default profile
  local n; n="$(resolve . 2>/dev/null | cut -f1)"
  [ "$n" = default ] || printf '%s' "$n"
}

usage() {
  cat <<EOF
ccp $VERSION — several Claude Code accounts on one computer, no logging in again

  ccp add <name> [--isolated] [--email you@x.com]   new profile; signs in once (shares ~/.claude settings and history)
  ccp ls                                            profiles, their accounts and plans, folder rules
  ccp use <name>                                    default profile everywhere (ccp use default: back to ~/.claude)
  ccp here <name> [dir]                             this folder and everything in it uses <name>   (ccp here --rm)
  ccp which [dir]                                   which profile a claude run here would use, and why
  ccp run [-p name] [-- claude args]                run Claude Code with the profile for here (or -p)
  ccp env [name]                                    eval "\$(ccp env work)": pin this shell to a profile
  ccp login <name>                                  sign a profile in again
  ccp rm <name> [--yes]                             sign out and delete a profile
  ccp init zsh|bash                                 add  eval "\$(ccp init zsh)"  to ~/.zshrc: plain \`claude\` follows the rules
  ccp prompt                                        profile name for a prompt/status line (empty for default)

Order: CCP_PROFILE > folder rule > ccp use > default (~/.claude). Profiles live in $CCP_HOME.
EOF
}

main() {
  local c="${1:-help}"; [ $# -gt 0 ] && shift
  case "$c" in
    add) cmd_add "$@" ;;
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

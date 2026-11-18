# claude-profiles (`ccp`)

Use several Claude Code accounts on one computer without logging out and in again.
Sign in once per account; accounts are numbered, you pick one by number, by command, or by the folder you are in,
and `ccp top` shows every account's usage limits live.

[한국어](README.ko.md)

```
$ ccp ls
  #   ACCOUNT                            PLAN           NAME
* 1   me@gmail.com                       max            default (~/.claude)
  2   me@company.com                     team           work
  3   me@client.io                       pro            acct-3

folder rules:
  /Users/me/work → #2 work
  /Users/me/client-x → #3
```

```
$ ccp top
ccp 0.4.0 · usage per account · 14:08:04 · refresh 60s (next in 57s) · r refresh · q quit

  #   ACCOUNT                        PLAN       LIMIT          USED                      LEFT  RESETS
* 1   me@gmail.com                   max 20x    5-hour         ████████████████░░  91%     9%  in 1h 12m
                                                week           █████████░░░░░░░░░  48%    52%  in 5d 21h
  2   me@company.com                 team       week           ██░░░░░░░░░░░░░░░░  12%    88%  in 3d 2h
  3   me@client.io                   pro        sign-in expired: open #3 once (ccp run -p 3)
```

## Install

One command per computer after installing: `ccp setup` (the script installer runs it for you). It adds the shell
line that sends `claude` through `ccp`, the status line with every account's limits, the Claude Code plugin and the
background service; `ccp setup --undo` takes them out again.

Homebrew:

```sh
brew tap yuna-studio/claude-profiles https://github.com/yuna-studio/claude-profiles
brew install ccp
```

As a Claude Code plugin (adds `/ccp:usage`, `/ccp:accounts`, `/ccp:use`, `/ccp:switch`, and `ccp` inside Claude Code):

```
/plugin install ccp --marketplace yuna-studio/claude-profiles
```

Or the script alone:

```sh
curl -fsSL https://raw.githubusercontent.com/yuna-studio/claude-profiles/main/install.sh | sh
```

One bash script (bash 3.2+, macOS and Linux); the usage view also needs `python3`. Nothing else besides Claude Code.

## Use

```sh
ccp add                           # #2: the browser opens to sign in with that account (once)
ccp add                           # #3
ccp add -2                        # a new one at #2; the old #2 and #3 become #3 and #4
ccp add work --email me@company.com   # a name is optional; numbers always work

ccp use 2                         # ~/.claude takes #2's login; sessions stay where they are
ccp here 3 ~/client-x             # ~/client-x and everything in it uses #3
ccp mv 4 2                        # reorder
ccp which                         # which account a run here would use, and why
ccp usage                         # every account's limits once; ccp top keeps them live

ccp run                           # start Claude Code with the account for this folder
ccp service start                 # optional: move on when an account is full (below)
ccp run -p 2 -- -c                # or a given one, with any claude arguments

echo 'eval "$(ccp init zsh)"' >> ~/.zshrc   # optional: plain `claude` follows your profiles
```

`#1` is your normal `~/.claude`. Which folder a run uses: `CCP_PROFILE` (number or name) › the longest folder rule that
covers the current folder › `~/.claude`. `ccp use` picks no folder: it changes the login `~/.claude` holds (below).
Rules and `ccp use` remember the account, not the number, so they keep pointing at the same account when you insert or
move profiles.

| command | does |
|---|---|
| `ccp add [name] [-N] [--isolated] [--email …] [--sso] [--console]` | new profile at the end, or at number N (the rest move down); signs in once |
| `ccp ls` | profiles by number, their account and plan, folder rules |
| `ccp usage [--json]` | each account's limits: used, left, when they reset |
| `ccp top [--every 60]` | the same, live in the terminal (`r` refresh, `q` quit) |
| `ccp use <n\|name>` | that account's login in `~/.claude`; every session stays where it is and uses it (`ccp use 1`: #1's own) |
| `ccp here <n\|name> [dir]` · `ccp here --rm [dir]` | folder rule |
| `ccp mv <n\|name> <N>` | move a profile to number N |
| `ccp which [dir]` | profile for a folder, and why |
| `ccp run [-p n\|name] [-- claude args]` | run Claude Code with a profile |
| `ccp sw <n\|name> [-- claude args]` | `ccp use n`, then the last conversation here goes on (`--continue`) |
| `ccp service start [--at 100] [--every 60]` · `stop` · `status` | in the background: the next account's login when the one in use is full |
| `ccp watch [--at 100] [--every 60]` | the same in this terminal |
| `ccp env [n\|name]` | `eval "$(ccp env 2)"` pins the current shell |
| `ccp login <n\|name>` | sign a profile in again |
| `ccp rm <n\|name> [--yes]` | sign out and delete a profile; the rest move up |
| `ccp init zsh\|bash` | shell function so `claude` uses `ccp run` |
| `ccp prompt` | `#2 work`: the account a session runs on, for Claude Code's status line or your prompt |

## Switch accounts while you work

```sh
ccp use 2             # ~/.claude takes account #2's login; every session stays where it is and uses it
ccp use 1             # #1's own login back
ccp sw 2              # ccp use 2, then the last conversation in this folder goes on (--continue)
```

Inside Claude Code: ask Claude to switch accounts (the plugin's `switch-account` skill), type `/ccp:switch 2`, or
`! ccp sw 2`.

**Nothing moves.** Claude Code reads its login from `~/.claude`'s keychain item (`.credentials.json` on Linux). `ccp use`
puts the chosen account's login there and keeps #1's own aside (keychain item `ccp-stash-default`), so every session
stays in its list, its folder and its terminal; only the account its tokens come from changes. MCP sign-ins in
`~/.claude` stay as they are. Meanwhile the lent account keeps no renewable copy in its own folder (two copies renewing
one login would sign one of them out); it gets the freshest copy back when you switch away from it.

- **Background sessions** (`claude --bg`, the agent view): a running one keeps the token it holds until that runs out
  (a few hours at most), then reads `~/.claude` again and goes on with the new login. `claude respawn <id>` restarts one
  in place now (same id, same conversation, same list). `ccp use` also restarts Claude Code's daemon with
  `claude daemon stop --keep-workers` (sessions keep running), so new background sessions start with the new login.
- **A terminal session** started with `ccp run` (or `claude` after `ccp init`) while `ccp service` is on reopens the same
  conversation in the same terminal once it is idle (`claude --resume`, options such as `--model` kept). A terminal
  that started `claude` without `ccp` keeps its token until it runs out (`/exit`, `claude --continue` takes it now).
- A session on a folder rule (`ccp here`), `-p` or `CCP_PROFILE` keeps its own account's folder and login.

To see every account's limits under the prompt, put `ccp prompt --usage` in Claude Code's status line (`~/.claude/settings.json`):

```json
{ "statusLine": { "type": "command", "command": "ccp prompt --usage" } }
```

```
▶ #2 this session  5h 3% (resets in 4h 49m)  week 17% (resets in 5d 21h)  ┃  #1  week 98% (resets in 4d 15h)
```

`▶` marks the account this session runs on (on `~/.claude`: the account whose login it holds); the numbers are what `ccp service` saw in its last check (no service: just the
accounts). Plain `ccp prompt` prints `#2 work`, for a shell prompt or a status line script you already have.

## Move on when an account is full

Opt in, for accounts that are yours:

```sh
ccp service start              # macOS: a launchd job that starts again at login
ccp service start --at 95      # switch a little before the limit
ccp service status             # running?, the account in use, full accounts, last log lines
ccp service stop
```

Every minute it reads each account's usage (as `ccp top` does). When the account in use (the one whose login `~/.claude`
holds) reaches 100% of its 5-hour or weekly limit, `~/.claude` takes the login of the next account with room, as with
`ccp use`, and it shows a notification. When the first account has room again (or, kept aside, its limit has reset),
its login goes back. Sessions stay where they are, as above; a busy one (a turn, a tool, a question) is never cut short.

Elsewhere (Linux), keep `ccp watch` running under systemd `--user` or tmux. The log is `~/.claude-profiles/watch.log`.

## How it works

Claude Code keeps everything in one config folder, `~/.claude`, or the folder in `CLAUDE_CONFIG_DIR`.
When `CLAUDE_CONFIG_DIR` is set, Claude Code also stores the login under its own name: a separate macOS keychain
item (`Claude Code-credentials-<hash of the folder>`), or `.credentials.json` inside that folder on Linux.
So a profile is just a folder in `~/.claude-profiles/<name>` (`acct-N` when unnamed), and `ccp` runs `claude` with
`CLAUDE_CONFIG_DIR` pointing at it. Because the login is tied to the folder's path, folders never get renamed: the
numbers come from a separate order file, and a removed folder name is never reused.

Each profile links back to the shared parts of `~/.claude`: `settings.json`, `CLAUDE.md`, `agents`, `commands`,
`skills`, `output-styles`, `plugins`, `keybindings.json` and `projects` (session history and memory, so `claude --resume`
sees the same sessions under every account). User-level MCP servers are copied from `~/.claude.json` when the profile is made.
The account, its login and its `.claude.json` stay per profile. `--isolated` shares nothing.

`ccp` signs in and out only through `claude auth login` / `claude auth logout`. For `ccp usage` and `ccp top` it reads
each account's sign-in token from where Claude Code keeps it (the keychain item, or `.credentials.json`) and sends it
only to Anthropic's usage endpoint, the same request Claude Code's `/usage` makes. The token is never printed, stored,
or put on a command line. An expired token is not refreshed: open that account once and Claude Code renews it.

## Notes

- If Claude Code rewrites a shared single file (for example `settings.json` after you change a setting inside a profile),
  that profile may end up with its own copy. Shared folders are not affected.
- The desktop app and IDE extensions keep using `~/.claude`; `ccp` changes only what you start from a terminal.
- **What it is not:** `ccp` is not meant for sharing accounts. Moving on when an account is full is off unless you
  start it. Use accounts that are yours (personal, work, client) and follow Anthropic's terms for each.

## Test

```sh
bash tests/test.sh     # a stub stands in for claude; nothing touches your real config
```

MIT © 2026 Yuna Studio

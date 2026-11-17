# claude-profiles (`ccp`)

Use several Claude Code accounts on one computer without logging out and in again.
Sign in once per account; accounts are numbered, and you pick one by number, by command, or by the folder you are in.

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

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/yuna-studio/claude-profiles/main/install.sh | sh
```

One bash script (bash 3.2+, macOS and Linux), no dependencies besides Claude Code itself. Or copy `ccp` anywhere on your `PATH`.

## Use

```sh
ccp add                           # #2: the browser opens to sign in with that account (once)
ccp add                           # #3
ccp add -2                        # a new one at #2; the old #2 and #3 become #3 and #4
ccp add work --email me@company.com   # a name is optional; numbers always work

ccp use 2                         # account #2 everywhere
ccp here 3 ~/client-x             # ~/client-x and everything in it uses #3
ccp mv 4 2                        # reorder
ccp which                         # which account a run here would use, and why

ccp run                           # start Claude Code with the account for this folder
ccp run -p 2 -- -c                # or a given one, with any claude arguments

echo 'eval "$(ccp init zsh)"' >> ~/.zshrc   # optional: plain `claude` follows your profiles
```

`#1` is your normal `~/.claude`, untouched. Which account a run uses: `CCP_PROFILE` (number or name) › the longest
folder rule that covers the current folder › `ccp use` › `#1`. Rules and `ccp use` remember the account, not the number,
so they keep pointing at the same account when you insert or move profiles.

| command | does |
|---|---|
| `ccp add [name] [-N] [--isolated] [--email …] [--sso] [--console]` | new profile at the end, or at number N (the rest move down); signs in once |
| `ccp ls` | profiles by number, their account and plan, folder rules |
| `ccp use <n\|name>` | default profile (`ccp use 1` goes back to `~/.claude`) |
| `ccp here <n\|name> [dir]` · `ccp here --rm [dir]` | folder rule |
| `ccp mv <n\|name> <N>` | move a profile to number N |
| `ccp which [dir]` | profile for a folder, and why |
| `ccp run [-p n\|name] [-- claude args]` | run Claude Code with a profile |
| `ccp sw <n\|name> [-- claude args]` | continue the last conversation here on another account (`--continue`) |
| `ccp env [n\|name]` | `eval "$(ccp env 2)"` pins the current shell |
| `ccp login <n\|name>` | sign a profile in again |
| `ccp rm <n\|name> [--yes]` | sign out and delete a profile; the rest move up |
| `ccp init zsh\|bash` | shell function so `claude` uses `ccp run` |
| `ccp prompt` | `#2 work`: the account a session runs on, for Claude Code's status line or your prompt |

## Switch accounts while you work

A running Claude Code stays on the account it started with. To move to another one, leave and come back on it:

```sh
/exit                 # in Claude Code
ccp sw 2              # the same conversation (the last one in this folder) continues on account #2
ccp sw work -- --resume   # or pick a conversation
```

Nothing is lost: conversation history is shared between profiles. Inside Claude Code, `! ccp ls` shows the accounts and
`! ccp use 2` makes the next start use #2.

To always see which account you are on, put `ccp prompt` in Claude Code's status line (`~/.claude/settings.json`):

```json
{ "statusLine": { "type": "command", "command": "ccp prompt" } }
```

It prints `#2 work` for the account the session runs on, or add `$(ccp prompt)` to a status line script you already have.

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

`ccp` never reads or copies a token; signing in and out is done by `claude auth login` / `claude auth logout`.

## Notes

- If Claude Code rewrites a shared single file (for example `settings.json` after you change a setting inside a profile),
  that profile may end up with its own copy. Shared folders are not affected.
- The desktop app and IDE extensions keep using `~/.claude`; `ccp` changes only what you start from a terminal.
- **What it is not:** `ccp` does not move to another account when one reaches its usage limit, and it is not meant for
  sharing accounts. Use accounts that are yours (personal, work, client) and follow Anthropic's terms for each.

## Test

```sh
bash tests/test.sh     # a stub stands in for claude; nothing touches your real config
```

MIT © 2026 Yuna Studio

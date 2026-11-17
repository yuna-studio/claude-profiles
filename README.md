# claude-profiles (`ccp`)

Use several Claude Code accounts on one computer without logging out and in again.
Sign in once per account, then pick one with a command or let the folder you are in pick it.

[한국어](README.ko.md)

```
$ ccp ls
  PROFILE        ACCOUNT                            PLAN           FOLDER
* default        me@gmail.com                       max            /Users/me/.claude
  work           me@company.com                     team           /Users/me/.claude-profiles/work
  client         me@client.io                       pro            /Users/me/.claude-profiles/client

folder rules:
  /Users/me/work → work
  /Users/me/client-x → client
```

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/yuna-studio/claude-profiles/main/install.sh | sh
```

One bash script (bash 3.2+, macOS and Linux), no dependencies besides Claude Code itself. Or copy `ccp` anywhere on your `PATH`.

## Use

```sh
ccp add work                      # new profile; the browser opens to sign in with that account (once)
ccp add client --email me@client.io

ccp here work ~/work              # ~/work and everything in it uses "work"
ccp use client                    # or: one profile everywhere else
ccp which                         # which profile a run here would use, and why

ccp run                           # start Claude Code with the profile for this folder
ccp run -p work -- -c             # or a given profile, with any claude arguments

echo 'eval "$(ccp init zsh)"' >> ~/.zshrc   # optional: plain `claude` follows your profiles
```

Which profile a run uses: `CCP_PROFILE` › the longest folder rule that covers the current folder › `ccp use` › `default`.
`default` is your normal `~/.claude`, untouched.

| command | does |
|---|---|
| `ccp add <name> [--isolated] [--email …] [--sso] [--console]` | new profile, signs in once |
| `ccp ls` | profiles, their account and plan, folder rules |
| `ccp use <name>` | default profile (`ccp use default` goes back to `~/.claude`) |
| `ccp here <name> [dir]` · `ccp here --rm [dir]` | folder rule |
| `ccp which [dir]` | profile for a folder, and why |
| `ccp run [-p name] [-- claude args]` | run Claude Code with a profile |
| `ccp env [name]` | `eval "$(ccp env work)"` pins the current shell |
| `ccp login <name>` | sign a profile in again |
| `ccp rm <name> [--yes]` | sign out and delete a profile |
| `ccp init zsh\|bash` | shell function so `claude` uses `ccp run` |
| `ccp prompt` | profile name for your prompt or status line |

## How it works

Claude Code keeps everything in one config folder, `~/.claude`, or the folder in `CLAUDE_CONFIG_DIR`.
When `CLAUDE_CONFIG_DIR` is set, Claude Code also stores the login under its own name: a separate macOS keychain
item (`Claude Code-credentials-<hash of the folder>`), or `.credentials.json` inside that folder on Linux.
So a profile is just a folder in `~/.claude-profiles/<name>`, and `ccp` runs `claude` with `CLAUDE_CONFIG_DIR` pointing at it.

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

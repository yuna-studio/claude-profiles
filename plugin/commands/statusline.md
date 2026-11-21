---
description: Every account's usage under Claude Code's prompt - turn the status line on or off, or say whether it is on (ccp statusline)
argument-hint: "[on | off]"
allowed-tools: Bash(ccp statusline:*)
---

Run `ccp statusline $ARGUMENTS` with the Bash tool (no arguments: whether it is on). If the argument says on or off in
other words (show, hide, 켜, 꺼), pass `on` or `off`. Tell the user what it says in one or two short lines, in their
language. After on or off, add one line: it takes effect when Claude Code reads settings.json again; running sessions
reload it on their own when the file changes, and a new session always starts with it. Off is remembered, so `ccp setup`
leaves the status line out until `ccp statusline on`. A status line of the user's own is never changed.

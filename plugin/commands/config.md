---
description: ccp settings - when to switch accounts, whether sessions restart in place, whether a cut-off one goes on (ccp config)
argument-hint: "[at <percent> | respawn on|off | continue on|off]"
allowed-tools: Bash(ccp config:*)
---

Run `ccp config $ARGUMENTS` with the Bash tool. With no arguments, show its lines in a code block and say in one short line
what each does: at = the percent of a 5-hour or weekly limit at which the next account's login takes over; respawn = after a
switch, running background sessions restart in place (same conversation) so they use the new login; continue = a session
the limit cut off goes on by itself after that restart. All are on by default. With arguments, say in one line what changed.

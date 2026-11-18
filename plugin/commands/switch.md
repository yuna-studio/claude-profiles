---
description: Move this conversation to another account in place (ccp sw)
argument-hint: <number|name>
allowed-tools: Bash(ccp:*)
---

!`ccp sw $ARGUMENTS 2>&1`

Tell the user what the line above says in one short sentence, then end your turn right away without doing anything else.
If it says "switching", this conversation reopens on that account in this terminal as soon as the turn ends. If it says
the session cannot switch in place, give the two steps it names (/exit, then ccp sw).

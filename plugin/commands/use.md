---
description: Use account N's login from now on; every session stays where it is (ccp use)
argument-hint: <number|name>
allowed-tools: Bash(ccp use:*)
---

Run `ccp use $ARGUMENTS` with the Bash tool and show its output.
Then add one short line: no session moves; each running session, this one included, restarts in place (same
conversation) once its turn ends and uses that account's login (a session on a folder rule from ccp here keeps its own).

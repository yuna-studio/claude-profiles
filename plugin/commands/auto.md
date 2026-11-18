---
description: Automatic switching: at what percent of the limit the next account's login takes over (ccp service start --at)
argument-hint: "[percent, e.g. 95 | off]"
allowed-tools: Bash(ccp service:*)
---

If "$ARGUMENTS" is empty, run `ccp service status` with the Bash tool and tell the user, in one or two short lines, whether
automatic switching is on and at what percent.
If it is a number from 1 to 100, run `ccp service start --at $ARGUMENTS` and say that from now on, when the account in use
reaches that percent of its 5-hour or weekly limit, ~/.claude takes the next account's login (sessions stay where they are).
If it is "off", run `ccp service stop` and say automatic switching is off.

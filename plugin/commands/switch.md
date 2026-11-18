---
description: Use another account's login for this conversation and every other one, in place (ccp sw)
argument-hint: <number|name>
allowed-tools: Bash(ccp:*)
---

!`ccp sw $ARGUMENTS 2>&1`

Tell the user what the lines above say in one short sentence, then end your turn right away without doing anything else.
Nothing moves: ~/.claude now holds that account's login, so this session and the others keep running where they are and
their tokens come from that account (a running background session once the token it holds runs out, or now with
`claude respawn <id>` from another terminal; a terminal started through ccp reopens in place once the turn ends).

---
name: switch-account
description: Move this Claude Code conversation to another of the user's ccp accounts in place, in the same terminal. Use when the user asks to change, switch or move to another account ("switch to account 2", "2번 계정으로 바꿔", "다른 계정으로 넘겨"), or when ccp says this account is full and the user wants to go on elsewhere.
allowed-tools: Bash(ccp:*)
---

# Switch account in place

1. If the user did not say which account, run `ccp usage` and pick the first other account with room; say which one.
2. Run `ccp sw <number or name>` with the Bash tool.
3. Tell the user its one-line answer in one short sentence, in their language, and end your turn at once. Do nothing else
   in this turn: the switch waits for the turn to end, then ccp reopens this same conversation on that account in this
   terminal (a couple of seconds; no sign-in).
4. If it answers that this session cannot switch in place, pass on its two steps: type `/exit`, then run `ccp sw <n>`.
   In-place switching works for sessions started with `ccp run` (or `claude` after `eval "$(ccp init zsh)"`) while
   `ccp service` is on.

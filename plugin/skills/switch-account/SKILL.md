---
name: switch-account
description: Switch this Claude Code conversation, and every other running one, to another of the user's ccp accounts in place, without moving any session. Use when the user asks to change, switch or move to another account ("switch to account 2", "2번 계정으로 바꿔", "다른 계정으로 넘겨", "토큰을 2번 걸로"), or when ccp says this account is full and the user wants to go on elsewhere.
allowed-tools: Bash(ccp:*)
---

# Switch account in place

1. If the user did not say which account, run `ccp usage` and pick the first other account with room; say which one.
2. Run `ccp sw <number or name>` with the Bash tool.
3. Tell the user its answer in one short sentence, in their language, and end your turn. Nothing moves: `~/.claude` now
   holds that account's login, so this session and every other one stay in their list, folder and terminal, and their
   tokens come from that account. Each running background session, this one included, restarts in place once its turn
   ends (`claude respawn`: same id, same conversation, same list) and uses the new login from then on; a terminal started
   through `ccp run` reopens this same conversation in place the same way. Busy work is never cut short.
4. `ccp use 1` brings #1's own login back.

---
name: toggle-statusline
description: Turn ccp's usage display under Claude Code's prompt (the status line with every account's limits) on or off, or say whether it is on. Use when the user asks to hide, remove, show or bring back the usage bar, the limits under the prompt or the status line ("사용량 표시 꺼줘", "하단 사용량 켜줘", "상태 줄 꺼", "입력창 아래 한도 안 보이게", "hide the usage status line", "turn the status line back on").
allowed-tools: Bash(ccp statusline:*)
---

# Usage status line on or off

1. To hide it ("꺼줘", hide, remove), run `ccp statusline off`; to show it ("켜줘", show, bring back), `ccp statusline on`;
   when the user only asks whether it is on, `ccp statusline`.
2. Tell the user its answer in one or two short sentences, in their language, and end your turn.
3. Add, after on or off: it takes effect when Claude Code reads `~/.claude/settings.json` again. Running sessions reload
   it on their own when the file changes, and a new session always starts with it.
4. Off is remembered: `ccp setup` leaves the status line out until `ccp statusline on`. ccp changes only its own status
   line; if the user has one of their own, it stays and ccp says so.

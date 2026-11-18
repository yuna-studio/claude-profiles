---
description: Add another Claude Code account to ccp and sign it in (ccp add)
argument-hint: "[name] [--email you@x.com]"
allowed-tools: Bash(ccp add:*), Bash(ccp ls:*)
---

Tell the user in one short line: a browser opens to sign the new account in; check the account it shows before
approving (a browser already signed in to another account approves that one; `--email` picks the account).
Then run `ccp add $ARGUMENTS` with the Bash tool, with a 10-minute timeout, and wait for it.
When it finishes, run `ccp ls` and show the table in a code block. If the sign-in did not finish, say they can run
`ccp login <number>` later.

# claude-profiles (`ccp`)

컴퓨터 한 대에서 Claude Code 계정 여러 개를 로그아웃 · 로그인 없이 바꿔 써요.
계정마다 한 번만 로그인해 두면, 명령 하나로 고르거나 지금 있는 폴더를 보고 알아서 골라요.

[English](README.md)

```
$ ccp ls
  PROFILE        ACCOUNT                            PLAN           FOLDER
* default        me@gmail.com                       max            /Users/me/.claude
  work           me@company.com                     team           /Users/me/.claude-profiles/work
  client         me@client.io                       pro            /Users/me/.claude-profiles/client
```

## 설치

```sh
curl -fsSL https://raw.githubusercontent.com/yuna-studio/claude-profiles/main/install.sh | sh
```

bash 스크립트 하나예요(bash 3.2 이상, macOS · Linux). Claude Code 말고 따로 필요한 건 없어요.

## 쓰기

```sh
ccp add work                      # 새 프로필: 브라우저가 열리면 그 계정으로 한 번 로그인
ccp here work ~/work              # ~/work 와 그 안 폴더는 모두 work 계정
ccp use client                    # 나머지 곳의 기본 계정
ccp which                         # 여기서 어느 계정으로 열리는지, 왜 그런지
ccp run                           # 이 폴더에 맞는 계정으로 Claude Code 실행

echo 'eval "$(ccp init zsh)"' >> ~/.zshrc   # 선택: 그냥 `claude` 를 쳐도 규칙대로 열림
```

고르는 순서: `CCP_PROFILE` › 지금 폴더를 덮는 가장 긴 폴더 규칙 › `ccp use` › `default`(원래 쓰던 `~/.claude`, 손대지 않음).

## 어떻게 되나

Claude Code 는 설정 폴더(`~/.claude`, 또는 `CLAUDE_CONFIG_DIR`)를 하나 써요. `CLAUDE_CONFIG_DIR` 를 주면 로그인도 따로
저장해요(macOS 는 폴더마다 다른 키체인 항목, Linux 는 그 폴더 안 `.credentials.json`). 그래서 프로필은
`~/.claude-profiles/<이름>` 폴더 하나이고, `ccp` 는 그 폴더를 `CLAUDE_CONFIG_DIR` 로 주고 `claude` 를 띄워요.

설정 · CLAUDE.md · 에이전트 · 명령 · 스킬 · 플러그인 · 대화 기록(projects)은 `~/.claude` 것을 함께 써서, 어느 계정으로 열어도
같은 환경이고 `claude --resume` 도 같은 대화를 보여요. 계정 · 로그인만 프로필마다 따로예요. `--isolated` 는 아무것도 나누지 않아요.
`ccp` 는 토큰을 읽거나 옮기지 않아요. 로그인 · 로그아웃은 `claude auth login` / `logout` 이 해요.

## 알아 둘 것

- 사용 한도가 찼을 때 다른 계정으로 알아서 넘어가는 기능은 없어요. 계정 공유용도 아니에요. 개인 · 회사 · 고객사처럼 내 계정을,
  각 계정의 Anthropic 약관대로 쓰세요.
- 데스크톱 앱 · IDE 확장은 계속 `~/.claude` 를 써요. `ccp` 는 터미널에서 띄우는 것만 바꿔요.

MIT © 2026 Yuna Studio

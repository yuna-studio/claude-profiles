# claude-profiles (`ccp`)

컴퓨터 한 대에서 Claude Code 계정 여러 개를 로그아웃 · 로그인 없이 바꿔 써요.
계정마다 한 번만 로그인해 두면 번호가 붙고, 번호 · 명령 · 지금 있는 폴더로 골라 써요.

[English](README.md)

```
$ ccp ls
  #   ACCOUNT                            PLAN           NAME
* 1   me@gmail.com                       max            default (~/.claude)
  2   me@company.com                     team           work
  3   me@client.io                       pro            acct-3
```

## 설치

```sh
curl -fsSL https://raw.githubusercontent.com/yuna-studio/claude-profiles/main/install.sh | sh
```

bash 스크립트 하나예요(bash 3.2 이상, macOS · Linux). Claude Code 말고 따로 필요한 건 없어요.

## 쓰기

```sh
ccp add                           # 2번: 브라우저가 열리면 그 계정으로 한 번 로그인
ccp add                           # 3번
ccp add -2                        # 2번 자리에 끼워 넣기: 원래 2 · 3번은 3 · 4번으로 밀림
ccp add work                      # 이름은 붙여도 되고 안 붙여도 돼요(번호는 늘 됨)

ccp use 2                         # 어디서나 2번 계정
ccp here 3 ~/client-x             # ~/client-x 와 그 안 폴더는 3번 계정
ccp mv 4 2                        # 순서 바꾸기
ccp which                         # 여기서 몇 번으로 열리는지, 왜 그런지
ccp run                           # 이 폴더에 맞는 계정으로 Claude Code 실행

echo 'eval "$(ccp init zsh)"' >> ~/.zshrc   # 선택: 그냥 `claude` 를 쳐도 규칙대로 열림
```

1번은 원래 쓰던 `~/.claude`(손대지 않음). 고르는 순서: `CCP_PROFILE`(번호나 이름) › 지금 폴더를 덮는 가장 긴 폴더 규칙 › `ccp use` › 1번.
폴더 규칙과 `ccp use` 는 번호가 아니라 계정을 기억해서, 끼워 넣거나 순서를 바꿔도 같은 계정을 가리켜요.

## 어떻게 되나

Claude Code 는 설정 폴더(`~/.claude`, 또는 `CLAUDE_CONFIG_DIR`)를 하나 써요. `CLAUDE_CONFIG_DIR` 를 주면 로그인도 따로
저장해요(macOS 는 폴더마다 다른 키체인 항목, Linux 는 그 폴더 안 `.credentials.json`). 그래서 프로필은
`~/.claude-profiles/<이름>`(이름 없으면 `acct-N`) 폴더 하나이고, `ccp` 는 그 폴더를 `CLAUDE_CONFIG_DIR` 로 주고 `claude` 를 띄워요.
로그인이 폴더 경로에 묶여 있어서 폴더 이름은 절대 바꾸지 않아요. 번호는 따로 둔 순서표에서 매기고, 지운 폴더 이름은 다시 쓰지 않아요.

설정 · CLAUDE.md · 에이전트 · 명령 · 스킬 · 플러그인 · 대화 기록(projects)은 `~/.claude` 것을 함께 써서, 어느 계정으로 열어도
같은 환경이고 `claude --resume` 도 같은 대화를 보여요. 계정 · 로그인만 프로필마다 따로예요. `--isolated` 는 아무것도 나누지 않아요.
`ccp` 는 토큰을 읽거나 옮기지 않아요. 로그인 · 로그아웃은 `claude auth login` / `logout` 이 해요.

## 알아 둘 것

- 사용 한도가 찼을 때 다른 계정으로 알아서 넘어가는 기능은 없어요. 계정 공유용도 아니에요. 개인 · 회사 · 고객사처럼 내 계정을,
  각 계정의 Anthropic 약관대로 쓰세요.
- 데스크톱 앱 · IDE 확장은 계속 `~/.claude` 를 써요. `ccp` 는 터미널에서 띄우는 것만 바꿔요.

MIT © 2026 Yuna Studio

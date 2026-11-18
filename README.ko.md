# claude-profiles (`ccp`)

컴퓨터 한 대에서 Claude Code 계정 여러 개를 로그아웃 · 로그인 없이 바꿔 써요.
계정마다 한 번만 로그인해 두면 번호가 붙고, 번호 · 명령 · 지금 있는 폴더로 골라 써요.
`ccp top` 은 계정마다 사용 한도가 얼마나 남았는지 실시간으로 보여 줘요.

[English](README.md)

```
$ ccp ls
  #   ACCOUNT                            PLAN           NAME
* 1   me@gmail.com                       max            default (~/.claude)
  2   me@company.com                     team           work
  3   me@client.io                       pro            acct-3
```

```
$ ccp top
ccp 0.4.0 · usage per account · 14:08:04 · refresh 60s (next in 57s) · r refresh · q quit

  #   ACCOUNT                        PLAN       LIMIT          USED                      LEFT  RESETS
* 1   me@gmail.com                   max 20x    5-hour         ████████████████░░  91%     9%  in 1h 12m
                                                week           █████████░░░░░░░░░  48%    52%  in 5d 21h
  2   me@company.com                 team       week           ██░░░░░░░░░░░░░░░░  12%    88%  in 3d 2h
  3   me@client.io                   pro        sign-in expired: open #3 once (ccp run -p 3)
```

## 설치

Homebrew:

```sh
brew tap yuna-studio/claude-profiles https://github.com/yuna-studio/claude-profiles
brew install ccp
```

Claude Code 플러그인(Claude 안에서 `/ccp:usage` · `/ccp:accounts` · `/ccp:use` · `/ccp:switch`, 그리고 `ccp` 명령):

```
/plugin install ccp --marketplace yuna-studio/claude-profiles
```

스크립트만:

```sh
curl -fsSL https://raw.githubusercontent.com/yuna-studio/claude-profiles/main/install.sh | sh
```

bash 스크립트 하나예요(bash 3.2 이상, macOS · Linux). 한도 화면만 `python3` 가 더 필요해요.

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
ccp usage                         # 계정마다 한도: 쓴 양 · 남은 양 · 초기화까지 (ccp top 은 실시간)
ccp run                           # 이 폴더에 맞는 계정으로 Claude Code 실행
ccp service start                 # 선택: 한도가 차면 다음 계정으로 (아래)

echo 'eval "$(ccp init zsh)"' >> ~/.zshrc   # 선택: 그냥 `claude` 를 쳐도 규칙대로 열림
```

1번은 원래 쓰던 `~/.claude`(손대지 않음). 고르는 순서: `CCP_PROFILE`(번호나 이름) › 지금 폴더를 덮는 가장 긴 폴더 규칙 › `ccp use` › 1번.
폴더 규칙과 `ccp use` 는 번호가 아니라 계정을 기억해서, 끼워 넣거나 순서를 바꿔도 같은 계정을 가리켜요.

## 쓰는 중에 계정 바꾸기

실행 중인 Claude Code 는 시작할 때 계정으로 고정돼요. 다른 계정으로 바꾸려면 나왔다가 그 계정으로 다시 들어가요.

```sh
/exit                 # Claude Code 안에서
ccp sw 2              # 이 폴더의 마지막 대화가 2번 계정으로 그대로 이어져요
ccp sw work -- --resume   # 다른 대화를 골라 이어도 돼요
```

대화 기록은 계정끼리 같이 써서 잃는 게 없어요. Claude Code 안에서 `! ccp ls` 로 계정 목록을 보고, `! ccp use 2` 로 다음 시작을 2번으로 정할 수 있어요.

**그 자리에서 바꾸기**: `ccp service` 가 켜져 있고 `ccp run`(또는 `ccp init` 뒤의 `claude`)으로 띄운 세션이면, Claude 에게
「2번 계정으로 바꿔」라고 하거나(플러그인의 `switch-account` 스킬) `/ccp:switch 2` · `! ccp sw 2` 를 쳐요. 그 답이 끝나면
같은 터미널에서 같은 대화가 2번 계정으로 다시 열려요(몇 초, 로그인 없음).

입력창 아래에 계정마다 한도를 띄우려면 `~/.claude/settings.json` 상태 줄에 `ccp prompt --usage` 를 넣어요.

```json
{ "statusLine": { "type": "command", "command": "ccp prompt --usage" } }
```

```
▶ #1 wk 98%  ·  #2 5h 3% wk 17%
```

`▶` 가 이 세션의 계정이고, 숫자는 `ccp service` 가 마지막으로 본 사용량이에요(서비스가 꺼져 있으면 계정 번호만). 그냥 `ccp prompt` 는 `#2 work` 만 찍어요.

## 한도가 차면 다음 계정으로

켜야 돌아요. 내 계정들에만 쓰세요.

```sh
ccp service start              # macOS: 백그라운드 서비스(launchd), 로그인하면 다시 켜져요
ccp service start --at 95      # 한도 조금 전에 넘기기
ccp service status             # 도는지 · 새 세션이 쓸 계정 · 찬 계정 · 마지막 기록
ccp service stop
```

1분마다 계정별 사용량을 봐요(`ccp top` 과 같은 요청). 새 세션이 쓰는 계정(`ccp use`, 없으면 1번)이 5시간이나 주간 한도
100%에 닿으면, 여유 있는 다음 계정을 기본으로 바꾸고 알림을 띄워요. 처음 계정에 여유가 다시 생기면 새 세션은 그 계정으로 돌아가요.

`ccp run`(또는 `ccp init` 뒤의 그냥 `claude`)으로 띄워 기본 계정을 따르는 세션도 함께 넘어가요. Claude Code 가 한도에 걸려
멈추고 세션이 쉬고 있으면, 그 세션을 끝내고 같은 대화를 새 계정에서 이어 열어요(`claude --resume <그 세션>`, `--model` 같은 옵션은
그대로). 일하는 중인 세션(답하는 중 · 도구 실행 중 · 질문 중)은 끊지 않아요. 폴더 규칙 · `-p` · `CCP_PROFILE` 로 연 세션,
서비스를 켜기 전에 연 세션, 이미 돌고 있는 백그라운드 작업, 데스크톱 앱은 그대로 둬요.

Linux 에서는 `ccp watch` 를 systemd `--user` 나 tmux 로 띄워 두세요. 기록은 `~/.claude-profiles/watch.log` 에 남아요.

## 어떻게 되나

Claude Code 는 설정 폴더(`~/.claude`, 또는 `CLAUDE_CONFIG_DIR`)를 하나 써요. `CLAUDE_CONFIG_DIR` 를 주면 로그인도 따로
저장해요(macOS 는 폴더마다 다른 키체인 항목, Linux 는 그 폴더 안 `.credentials.json`). 그래서 프로필은
`~/.claude-profiles/<이름>`(이름 없으면 `acct-N`) 폴더 하나이고, `ccp` 는 그 폴더를 `CLAUDE_CONFIG_DIR` 로 주고 `claude` 를 띄워요.
로그인이 폴더 경로에 묶여 있어서 폴더 이름은 절대 바꾸지 않아요. 번호는 따로 둔 순서표에서 매기고, 지운 폴더 이름은 다시 쓰지 않아요.

설정 · CLAUDE.md · 에이전트 · 명령 · 스킬 · 플러그인 · 대화 기록(projects)은 `~/.claude` 것을 함께 써서, 어느 계정으로 열어도
같은 환경이고 `claude --resume` 도 같은 대화를 보여요. 계정 · 로그인만 프로필마다 따로예요. `--isolated` 는 아무것도 나누지 않아요.
로그인 · 로그아웃은 `claude auth login` / `logout` 이 해요. `ccp usage` · `ccp top` 은 계정마다 Claude Code 가 둔 로그인 토큰(키체인 · `.credentials.json`)을 읽어
Anthropic 사용량 주소(Claude 안의 `/usage` 와 같은 요청)에만 보내요. 토큰은 화면 · 파일 · 명령줄에 남기지 않고, 만료되면 그 계정으로 한 번 열면 Claude Code 가 갱신해요.

## 알아 둘 것

- 계정 공유용이 아니에요. 한도가 차면 넘기는 기능은 직접 켜야 돌아요. 개인 · 회사 · 고객사처럼 내 계정을,
  각 계정의 Anthropic 약관대로 쓰세요.
- 데스크톱 앱 · IDE 확장은 계속 `~/.claude` 를 써요. `ccp` 는 터미널에서 띄우는 것만 바꿔요.

MIT © 2026 Yuna Studio

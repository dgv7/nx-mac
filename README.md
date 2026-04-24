# nx-mac

> **바람의나라 on macOS.** 더블클릭에서 로그인 창까지 **7.3초**. 상주 프로세스 0.

[한국어](./README.md) · [English](./README.en.md)

![바람의나라 일월마을 on macOS](docs/screenshots/baram-ingame.png)

---

바람의나라를 macOS에서 원클릭으로 실행하는 오픈소스 런처입니다. Wine 설정을 직접 건드리지 않아도 됩니다 — 빌더가 검증된 설정 한 벌을 자동으로 얹고, 이후에는 `.app` 더블클릭만 남습니다.

기반은 Sikarugir Wine wrapper(CX 24.0.7). 넥슨 게임 전용 **자동 빌더 + AppleScript URL router + SwiftUI splash**로 실행 체인을 자동화했습니다. 직접 Wine 엔진을 튜닝하는 대신, 공식 무료 백엔드 위에 **검증된 설정 한 벌**을 자동 적용하는 데 집중했습니다.

## 주요 지표

| Metric | Value |
|---|---|
| Cold-start (클릭 → Plug 로그인 창) | **7.3초** 실측 (Apple Silicon) |
| Warm reuse | 2~3초 |
| 상주 프로세스 | **0** (종료 시 wine 트리 전체 teardown) |
| 한글 IME 조합 | 정상 |
| GameGuard (NGS) 통과 | 필드 진입까지 확인 |
| 라이선스 비용 | $0 |

## 지원 게임

| Game | Status | Notes |
|---|---|---|
| 바람의나라 | end-to-end 검증 | v0.1 배포 대상 |

다른 넥슨 게임은 실측 전. 예측 호환성은 [Compatibility](#compatibility) 참조.

---

# Install

**요구사항**: macOS 14+ · Apple Silicon · 약 25GB 여유 디스크

두 가지 경로 중 선택하세요.

## 1. 원라이너 (권장)

터미널에 한 줄 붙여넣기. Xcode CLT → Homebrew → Sikarugir → 프로젝트 다운로드 → 빌더 실행까지 자동으로 이어집니다. 중간에 Sikarugir Creator에서 wrapper를 만드는 GUI 단계 한 번만 직접 클릭하면 됩니다.

```bash
curl -fsSL https://raw.githubusercontent.com/dgv7/nx-mac/main/install.sh | bash
```

스크립트가 안내하는 대로 따라가면 `~/Applications/Sikarugir/NX Launcher.app`이 설치됩니다. 이후 [gulim.ttc 배치](#3-gulimttc-배치-한글-폰트)와 [첫 실행](#4-첫-실행) 섹션으로 이동하세요.

> **중단돼도 안전** — 이미 완료된 단계는 건너뛰므로 같은 명령을 다시 실행하면 이어집니다.

## 2. 따라 설치 (수동)

원라이너 대신 한 단계씩 진행하고 싶다면:

### 0. 사전 준비

<details>
<summary><b>Xcode Command Line Tools / Homebrew / Git 없다면</b> (클릭해서 펼치기)</summary>

```bash
# Xcode Command Line Tools — git/clang/codesign 포함
xcode-select --install

# Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# (Apple Silicon만) brew PATH 적용
eval "$(/opt/homebrew/bin/brew shellenv)"
```

</details>

### 1. Sikarugir Creator 설치 & wrapper 생성

```bash
brew tap Sikarugir-App/sikarugir
brew install --cask sikarugir
open -a "Sikarugir Creator"
```

Sikarugir Creator → **New Blank Wrapper** 클릭 → 다음 설정:

| Setting | Value |
|---|---|
| Name | `Baram` |
| Engine | `WS12WineCX24.0.7` |
| OS | `Windows 10` |

엔진은 반드시 **CX 24.0.7**. 다른 버전에서는 한글 IME가 재현되지 않습니다.

생성되면 `~/Applications/Sikarugir/Baram.app`이 만들어집니다.

### 2. nx-mac 빌더 실행

```bash
git clone https://github.com/dgv7/nx-mac
cd nx-mac
./scripts/build-baram-app.sh
```

빌더가 자동 처리:

- libinotify dylib 심링크 (`wine/lib/` + `SharedSupport/` 양쪽)
- `dosdevices/c:` 절대경로 교정
- winetricks 한글 환경 (`corefonts → cjkfonts → vcrun2019`)
- NexonPlug 설치
- **`Nexon Launcher` Windows 서비스 disabled** ← cold-start 50→7초의 핵심
- exit-watcher 배치
- `NX Launcher.app` 생성 + `nexonplug://` URL handler 등록
- SwiftUI Splash 컴파일 + 번들

> **첫 실행은 10~20분 걸립니다** — `cjkfonts` 다운로드 단계에서 터미널이 조용해져도 종료하지 마세요. 수 GB 폰트 패키지를 내려받는 중입니다.

### 3. gulim.ttc 배치 (한글 폰트)

본인 Windows PC의 `C:\Windows\Fonts\gulim.ttc`를 아래 경로에 복사하세요:

```
~/Applications/Sikarugir/Baram.app/Contents/SharedSupport/prefix/drive_c/windows/Fonts/gulim.ttc
```

<details>
<summary><b>Windows PC가 없다면</b></summary>

- **친구나 PC방 Windows에서 USB로 복사** — 가장 현실적
- **부모/지인의 회사 PC** — 대부분의 사무용 Windows에 기본 포함
- **Parallels Desktop / UTM 체험판**: Windows 설치 후 `C:\Windows\Fonts\gulim.ttc` 추출
- **중고 Windows 노트북** 일회성으로 빌려서 복사 후 반납

폰트가 없어도 게임은 실행됩니다. 단 **한글이 네모(□)로 표시**됩니다. MS 저작권 폰트라 이 저장소에는 포함할 수 없습니다.

</details>

### 4. 첫 실행

`~/Applications/Sikarugir/NX Launcher.app`을 더블클릭하세요.

> **"확인되지 않은 개발자" 경고가 뜨면**
>
> 앱이 ad-hoc 서명이라 macOS Gatekeeper가 처음에 막습니다.
> - **해결 1**: `NX Launcher.app`을 **우클릭** → **열기** → 경고창에서 다시 **열기** 클릭 (한 번만)
> - **해결 2**: 시스템 설정 → 개인정보 보호 및 보안 → 하단의 "`NX Launcher`이(가) 차단되었습니다" 옆 **"그래도 열기"** 클릭

Splash가 즉시 뜨고 단계별 상태 텍스트가 흐르면서 Plug 로그인 창 출현 시 자동 소멸합니다.

> **"게임 실행에 실패했습니다" 팝업은 무시하세요**
>
> Plug에서 `게임시작`을 누르면 아래 팝업이 잠깐 뜨지만, **실제로는 게임이 정상 실행된다**. `확인`을 클릭해 닫으면 OTP 입력 창 또는 게임 창이 뒤이어 올라옵니다.
>
> ![plug false-error popup](docs/screenshots/plug-false-error.png)
>
> Plug이 Mac Wine 환경에서 게임 프로세스의 exit code를 오해석해 띄우는 false alarm. 자동 dismiss는 의도적으로 구현하지 않았습니다 — OTP나 공지처럼 실제로 읽어야 할 팝업까지 같이 닫힐 위험이 있어서.

---

# 자주 겪는 문제

<details>
<summary><b>Splash 창이 사라지지 않아요</b></summary>

Plug 로그인 창이 떠도 Splash가 남아있다면:

1. `ESC` 키 또는 Splash의 `취소` 버튼 클릭 (Wine 트리 전체 종료)
2. 터미널에서 `pkill -f "NX Splash"` 로 강제 종료
3. 30초 이상 같은 상태 텍스트에 머물러 있다면 Wine이 멈춘 것일 수 있음 → `ESC`로 종료 후 `NX Launcher.app` 재실행

</details>

<details>
<summary><b>게임을 어떻게 정상 종료하나요?</b></summary>

가장 안전한 순서:

1. **게임 내에서 로그아웃** (캐릭터 선택 창까지 돌아가기)
2. **Plug 창의 X 버튼**으로 Plug 닫기
3. 이후 `baram-exit-watcher`가 자동으로 wine 트리 전체를 teardown

강제 종료가 필요하면:
```bash
pkill -9 -f 'NexonPlug|wine/bin|gamer.exe'
```

다음 실행은 항상 cold-start입니다 (상주 0 정책).

</details>

<details>
<summary><b>Cold-start가 60초 넘게 걸려요</b></summary>

`build-baram-app.sh`가 `Nexon Launcher` Windows 서비스를 disabled 했는지 확인:

```bash
~/Applications/Sikarugir/Baram.app/Contents/SharedSupport/wine/bin/wine \
  sc query "Nexon Launcher"
```

`STATE: STOPPED` 또는 에러가 정상. `RUNNING`이면 빌더를 재실행하세요:

```bash
cd ~/nx-mac && ./scripts/build-baram-app.sh
```

(빌더는 idempotent라 재실행해도 안전합니다.)

</details>

<details>
<summary><b>Sikarugir Creator에서 Refresh 후 설정이 리셋됐어요</b></summary>

Creator의 Refresh 기능은 libinotify 심링크와 `Nexon Launcher` 서비스 설정을 날립니다. 빌더 재실행으로 복구:

```bash
cd ~/nx-mac && ./scripts/build-baram-app.sh
```

</details>

<details>
<summary><b>한글이 네모(□)로 표시돼요</b></summary>

`gulim.ttc`가 없거나 경로가 틀립니다. [3. gulim.ttc 배치](#3-gulimttc-배치-한글-폰트) 섹션을 다시 확인하세요.

</details>

<details>
<summary><b>완전히 삭제하고 싶어요</b></summary>

```bash
# NX Launcher + Sikarugir wrapper 삭제
rm -rf ~/Applications/Sikarugir/NX\ Launcher.app
rm -rf ~/Applications/Sikarugir/Baram.app

# Sikarugir Creator 제거 (다른 wrapper 사용 안 하면)
brew uninstall --cask sikarugir

# nx-mac 프로젝트 제거
rm -rf ~/nx-mac

# URL handler 정리
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister \
  -kill -domain local -domain system -domain user
```

</details>

막히는 문제가 여기 없으면 [Issues](https://github.com/dgv7/nx-mac/issues)에 올려주세요.

---

# How it works

```
더블클릭
  │
  └─ NX Launcher.app (AppleScript Router)
      │
      ├─ NX Splash.app (SwiftUI, 상태 파일 구독 → 자동 dismiss)
      └─ shell cmd (cleanup → symlink 검증 → wine spawn)
          │
          └─ Baram.app (Sikarugir wrapper, WS12WineCX24.0.7)
              │
              └─ NexonPlug.exe (브라우저 없이 자체 로그인)
                  │
                  └─ gamer.exe (바람의나라)
```

URL handler(`nexonplug://`, `ngm://`)도 함께 등록되므로 `baram.nexon.com` 브라우저 로그인 경로도 동일한 router로 수렴합니다.

# Design notes

### 50s → 7s: cold-start 병목의 정체

초기 측정치 50초에서 **phase profiling**으로 구간별 시간을 재자, 실제 병목은 wine이 아니라 Plug이 호출하는 **`Nexon Launcher` Windows 서비스의 auto-start timeout 40초**였습니다. 서비스를 disabled로 두고 Plug이 필요한 시점에 on-demand로 spawn하게 두자 **7.3초**로 떨어졌습니다. 기능 손실 0.

### 한글 IME: 엔진 선택 문제

Wine 10 + macOS Mac driver 조합은 한글 IME pre-edit을 IMM32로 전달하지 않아 모든 채팅 입력이 막힙니다. **CX 24.0.7 엔진 교체로 해결**. 단 CX24는 libinotify rpath가 기존 `wine/lib/`에 더해 `SharedSupport/`도 필요해 빌더가 양쪽 모두 심링크합니다.

### Splash UX: 시간 표시 없음

Cold-start 편차가 큽니다 — M-series 7초, 오래된 Intel 30초+. **고정 예상 시간은 어느 쪽에서든 거짓말**이므로 제거했습니다.

- AppleScript shell이 `/tmp/nx-launcher-status`에 단계 마커 작성 (`cleanup` → `symlink` → `spawn` → `waiting`)
- SwiftUI splash가 마커를 읽어 상태 텍스트만 업데이트 (숫자 없음)
- `CGWindowListCopyWindowInfo`로 Plug 창 감지 → 자동 dismiss
- 한 단계가 15초 넘게 지속되면 subtle hint 페이드인 (ESC 취소 안내)

스피너 = "살아있음" 신호, 텍스트 = "현재 상태" 신호. 둘을 섞지 않습니다.

### 상주 0 정책

Plug 또는 `gamer.exe` 종료 시 `baram-exit-watcher.sh`가 wine 트리 전체를 teardown합니다. 백그라운드 상주 없음 — 매 실행이 cold-start. 의도적 선택입니다. 상주 프로세스는 macOS의 "앱은 명시적으로 연다/닫는다" 멘탈 모델과 충돌하고, 넥슨 서버 측 세션 추적을 혼란시킬 수 있습니다.

### Router가 `.app`인 이유

macOS LaunchServices는 `nexonplug://` / `ngm://` 같은 URL scheme을 오직 `.app` bundle에만 바인딩합니다. CLI 바이너리로는 브라우저 경로를 가로챌 수 없습니다. AppleScript applet은 `osacompile`로 빌드 가능해 Swift 툴체인 없이도 URL handler를 만들 수 있어 채택했습니다.

## Compatibility

다른 넥슨 게임 실행 가능성 예측 (실측 전):

| 예측 등급 | 게임 (대표) |
|---|---|
| 가능성 높음 (2D · 약한 NGS) | 크레이지아케이드, 카트라이더 러쉬플러스 |
| 가능성 중간 | 마비노기 영웅전 구버전 |
| 가능성 낮음 (NGS 강화) | 마비노기 현행 |
| 거의 불가능 (이중 보호) | 메이플스토리 현행, 던전앤파이터 |
| 불가능 (hardcore anti-cheat) | 서든어택, FC온라인 |

**구조 재사용률 ~30%, 게임별 실측 ~70%**. Plug / wine / router 레이어는 공통이지만 각 게임의 anti-cheat, 패처, 실행 파라미터 패턴은 독립 실험이 필요합니다. v0.2+에서 `scripts/presets/` 디렉토리로 게임별 설정 분리 예정. 실측 결과 공유는 [Issues](https://github.com/dgv7/nx-mac/issues) 환영.

## Trade-offs

의식적으로 내린 선택과 받아들인 한계:

- **gulim.ttc 자가 배치**: MS 저작권. 대체 폰트로는 UI 렌더링이 어색해짐.
- **"실행 실패" 팝업** ([첫 실행 참조](#4-첫-실행)) — Plug의 false alarm. `확인` 클릭 후 게임 정상 진행. 자동 dismiss는 OTP/공지 오탐 위험으로 포기.
- **NGS 룰 변경 리스크**: 2026-04 기준 검증. Nexon이 anti-cheat 규칙을 강화하면 예고 없이 차단될 수 있음.
- **Sikarugir Creator Refresh 시 설정 소실**: 빌더가 idempotent 설계이므로 재실행으로 복구.
- **x86_64 Wine 엔진**: Apple Game Porting Toolkit 기반 ARM 네이티브 경로는 Chromium-in-Plug 호환성이 CX24보다 약함. Plan B에서 재평가.

## Project layout

```
nx-mac/
├── install.sh                    # 원라이너 installer
├── scripts/
│   ├── build-baram-app.sh        # 빈 wrapper → 완성 상태 자동 변환
│   ├── baram-router.applescript  # URL handler + splash 스폰
│   ├── baram-exit-watcher.sh     # 상주 금지 watcher
│   └── nx-splash/
│       ├── NXSplash.swift        # SwiftUI borderless splash
│       └── build-splash.sh       # universal binary 빌드
├── ROADMAP.md                    # Plan A / B / C 전략
├── STATUS.md                     # 누적 진행 상황
└── SMOKE_TEST.md                 # 스모크 체크리스트
```

## References

- [Sikarugir](https://github.com/Sikarugir-App/Sikarugir) · [Creator](https://github.com/Sikarugir-App/Creator)
- [Apple Game Porting Toolkit 2.1](https://developer.apple.com/games/game-porting-toolkit/)
- [넥슨플러그](https://nexonplug.nexon.com/)
- [nProtect GameGuard](https://gameguard.nprotect.com/kr/index.html)

## License

MIT — 스크립트 · AppleScript · Swift · 문서. 게임 바이너리, 폰트, Wine 엔진, Sikarugir는 각 저작권자 소유.

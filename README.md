# nx-mac

> **바람의나라 on macOS.** 더블클릭에서 로그인 창까지 **7.3초**. 상주 프로세스 0.

[한국어](./README.md) · [English](./README.en.md)

![바람의나라 일월마을 on macOS](docs/screenshots/baram-ingame.png)

---

## 결과만 먼저

설치는 **명령어 한 줄 + 폰트 한 개 + 더블클릭 한 번**입니다.

```bash
curl -fsSL https://raw.githubusercontent.com/dgv7/nx-mac/main/install.sh | bash
```

설치가 끝나면 두 가지만 더 하면 됩니다:

1. **`gulim.ttc`** 한 번 복사 — 본인 Windows의 `C:\Windows\Fonts\gulim.ttc`를 `~/Applications/Sikarugir/Baram.app/Contents/SharedSupport/prefix/drive_c/windows/Fonts/`에 붙여넣기 ([대체 경로](#gulimttc-구하는-법))
2. **`NX Launcher.app` 우클릭 → 열기** — 첫 실행 1회만 (Gatekeeper)

이게 전부입니다. 이후는 `.app` 더블클릭 → 7.3초 후 로그인 창.

| Metric | Value |
|---|---|
| Cold-start (클릭 → Plug 로그인 창) | **7.3초** 실측 (Apple Silicon) |
| Warm reuse | 2~3초 |
| 상주 프로세스 | **0** (종료 시 wine 트리 전체 teardown) |
| 한글 IME 조합 | 정상 |
| GameGuard (NGS) 통과 | 필드 진입까지 확인 |
| 라이선스 비용 | $0 |

**요구사항**: macOS 14+ · Apple Silicon · 약 25GB 여유 디스크
**지원 게임**: 바람의나라 (v0.1) · 다른 넥슨 게임은 [Compatibility](#compatibility) 참조

> 원라이너는 중단돼도 안전합니다. 이미 완료된 단계는 건너뛰므로 같은 명령으로 재개됩니다.

---

## 한 줄 설치가 가능해지기까지

처음부터 한 줄이 아니었습니다. **3일 12시간, 16개 블로커**를 뚫고 나서야 한 줄이 됐습니다.

| 세션 | 핵심 돌파 |
|---|---|
| Day 1 | Sikarugir + Wine 10 풀 체인 가동, Chromium 검은화면(VizDisplayCompositor flag), AppleScript URL handler, NexonLauncher pre-spawn 트릭 |
| Day 2 | **한글 IME 조합 버그** — Wine 10 Mac driver가 IMM32에 pre-edit을 안 흘림 → CX 24.0.7 엔진 교체로 해결. libinotify rpath가 `SharedSupport/`에도 필요한 것 발견 |
| Day 3 | **Cold-start 50초의 정체** — phase profiling으로 `Nexon Launcher` Windows 서비스의 auto-start 40초 timeout이 범인. disabled로 두자 **50s → 7.3s** |

뚫어야 했던 것들 (요약):

1. macOS Tahoe libinotify rpath — Frameworks dylib 94개 심링크
2. Wine 드라이브 Free Space 0 Byte — `dosdevices` 절대경로
3. winetricks 한글 환경 (`corefonts → cjkfonts → vcrun2019` 순서)
4. NexonPlug self-update race — NGM smallpatch 단독 실행
5. Mac LSF URL 스킴 경쟁 — Mac Plug.app unregister + Router Viewer role
6. Plug Wine crash — Windows 서비스 disabled로 우회
7. Chromium GPU 검은화면 — `--disable-features=VizDisplayCompositor --in-process-gpu`
8. 한글 IME pre-edit — Wine 10 → **CX 24.0.7** 엔진 교체
9. Cold-start 50초 — `Nexon Launcher` 서비스 disabled
10. 18.22GB 게임 다운로드 — NGM 자동
11. exit 시 wine 트리 잔존 — exit-watcher 강화 (상주 0)
12. ... GameGuard 통과 / OTP / 캐릭터 선택 / 필드 진입까지

기록 전체: [STATUS.md](STATUS.md) · 전략 분기와 폐기 기준: [ROADMAP.md](ROADMAP.md) · 스모크 체크리스트: [SMOKE_TEST.md](SMOKE_TEST.md)

지금은 이 모든 것이 [`build-baram-app.sh`](scripts/build-baram-app.sh) 안에 자동화돼 있어, 사용자가 신경 쓸 일은 위의 **세 단계**뿐입니다.

---

## 한 줄 대신 직접 따라가고 싶다면

<details>
<summary><b>수동 설치 (5단계)</b></summary>

### 0. 사전 준비

```bash
# Xcode Command Line Tools — git/clang/codesign 포함
xcode-select --install

# Homebrew (없다면)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
```

### 1. Sikarugir Creator 설치 & wrapper 생성

```bash
brew tap Sikarugir-App/sikarugir
brew install --cask sikarugir
open -a "Sikarugir Creator"
```

Sikarugir Creator → **New Blank Wrapper** → 다음 설정:

| Setting | Value |
|---|---|
| Name | `Baram` |
| Engine | `WS12WineCX24.0.7` |
| OS | `Windows 10` |

엔진은 반드시 **CX 24.0.7**. 다른 버전에서는 한글 IME가 재현되지 않습니다.

### 2. nx-mac 빌더 실행

```bash
git clone https://github.com/dgv7/nx-mac
cd nx-mac
./scripts/build-baram-app.sh
```

빌더가 자동 처리하는 것:

- libinotify dylib 심링크 (`wine/lib/` + `SharedSupport/` 양쪽)
- `dosdevices/c:` 절대경로 교정
- winetricks 한글 환경 (`corefonts → cjkfonts → vcrun2019`)
- NexonPlug 설치
- **`Nexon Launcher` Windows 서비스 disabled** ← cold-start 50→7초의 핵심
- exit-watcher 배치
- `NX Launcher.app` 생성 + `nexonplug://` URL handler 등록
- SwiftUI Splash 컴파일 + 번들

> 첫 실행은 10~20분 걸립니다 — `cjkfonts` 단계에서 터미널이 조용해져도 종료하지 마세요. 수 GB 폰트 패키지 다운로드 중입니다.

### 3. gulim.ttc 배치

본인 Windows의 `C:\Windows\Fonts\gulim.ttc`를 다음 경로에 복사:

```
~/Applications/Sikarugir/Baram.app/Contents/SharedSupport/prefix/drive_c/windows/Fonts/gulim.ttc
```

#### gulim.ttc 구하는 법

Windows PC가 없다면:

- **친구 PC / PC방** — USB로 복사. 가장 현실적
- **부모/지인의 회사 PC** — 대부분 사무용 Windows에 기본 포함
- **Parallels Desktop / UTM 체험판** — VM에서 추출
- **중고 Windows 노트북** 일회성 대여

폰트 없이도 게임은 실행되지만 **한글이 네모(□)로 표시**됩니다. MS 저작권 폰트라 본 저장소에 포함할 수 없습니다.

### 4. 첫 실행

`~/Applications/Sikarugir/NX Launcher.app`을 더블클릭.

> "확인되지 않은 개발자" 경고가 뜨면:
> - **우클릭 → 열기 → 다시 열기** 클릭 (한 번만)
> - 또는 시스템 설정 → 개인정보 보호 및 보안 → "그래도 열기"

Splash가 즉시 뜨고 단계별 텍스트가 흐르며, Plug 로그인 창이 나타나면 자동 소멸합니다.

> **"게임 실행에 실패했습니다" 팝업은 무시하세요** — Plug에서 `게임시작` 누르면 잠깐 뜨지만 실제로는 정상 실행됩니다. `확인` 클릭하면 OTP 입력 창 또는 게임 창이 뒤이어 올라옵니다.
>
> ![plug false-error popup](docs/screenshots/plug-false-error.png)
>
> Plug이 Mac Wine 환경에서 게임 프로세스의 exit code를 오해석해 띄우는 false alarm. OTP/공지처럼 진짜 읽어야 할 팝업과 다이얼로그 스타일이 같아 자동 dismiss는 의도적으로 구현하지 않았습니다.

</details>

---

## 자주 겪는 문제

<details>
<summary><b>Splash가 사라지지 않아요</b></summary>

Plug 로그인 창이 떴는데도 Splash가 남아있다면:

1. `ESC` 키 또는 Splash의 `취소` 버튼 (Wine 트리 전체 종료)
2. `pkill -f "NX Splash"` 강제 종료
3. 30초 이상 같은 텍스트면 Wine hang — `ESC`로 종료 후 재실행

</details>

<details>
<summary><b>게임을 어떻게 정상 종료하나요?</b></summary>

가장 안전한 순서:

1. 게임 내에서 로그아웃 (캐릭터 선택 창까지)
2. Plug 창의 X 버튼으로 Plug 닫기
3. `baram-exit-watcher`가 자동으로 wine 트리 teardown

강제 종료가 필요하면:

```bash
pkill -9 -f 'NexonPlug|wine/bin|gamer.exe'
```

다음 실행은 항상 cold-start입니다 (상주 0 정책).

</details>

<details>
<summary><b>Cold-start가 60초 넘게 걸려요</b></summary>

`Nexon Launcher` 서비스가 살아있을 가능성:

```bash
~/Applications/Sikarugir/Baram.app/Contents/SharedSupport/wine/bin/wine \
  sc query "Nexon Launcher"
```

`STATE: STOPPED` 또는 에러가 정상. `RUNNING`이면 빌더 재실행 (idempotent):

```bash
cd ~/nx-mac && ./scripts/build-baram-app.sh
```

</details>

<details>
<summary><b>Sikarugir Creator에서 Refresh 후 설정이 리셋됐어요</b></summary>

Creator의 Refresh는 libinotify 심링크와 `Nexon Launcher` 서비스 설정을 날립니다. 빌더 재실행으로 복구:

```bash
cd ~/nx-mac && ./scripts/build-baram-app.sh
```

</details>

<details>
<summary><b>한글이 네모(□)로 표시돼요</b></summary>

`gulim.ttc`가 없거나 경로가 틀립니다. [gulim.ttc 배치](#3-gulimttc-배치)를 다시 확인하세요.

</details>

<details>
<summary><b>완전히 삭제하고 싶어요</b></summary>

```bash
rm -rf ~/Applications/Sikarugir/NX\ Launcher.app
rm -rf ~/Applications/Sikarugir/Baram.app
brew uninstall --cask sikarugir         # 다른 wrapper 안 쓰면
rm -rf ~/nx-mac

# URL handler 캐시 재구축
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister \
  -kill -domain local -domain system -domain user
```

</details>

여기 없는 문제는 [Issues](https://github.com/dgv7/nx-mac/issues)에 올려주세요.

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

초기 측정치 50초에서 phase profiling으로 구간별 시간을 재자, 실제 병목은 wine이 아니라 Plug이 호출하는 **`Nexon Launcher` Windows 서비스의 auto-start timeout 40초**였습니다. 서비스를 disabled로 두고 Plug이 필요한 시점에 on-demand로 spawn하게 두자 7.3초로 떨어졌습니다. 기능 손실 0.

### 한글 IME: 엔진 선택 문제

Wine 10 + macOS Mac driver 조합은 한글 IME pre-edit을 IMM32로 전달하지 않아 모든 채팅 입력이 막힙니다. **CX 24.0.7 엔진 교체로 해결**. CX24는 libinotify rpath가 기존 `wine/lib/`에 더해 `SharedSupport/`도 필요해 빌더가 양쪽 모두 심링크합니다.

### Splash UX: 시간 표시 없음

Cold-start 편차가 큽니다 — M-series 7초, 오래된 Intel 30초+. 고정 예상 시간은 어느 쪽에서든 거짓말이므로 제거했습니다.

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
- **"실행 실패" 팝업**: Plug의 false alarm. `확인` 클릭 후 게임 정상 진행. 자동 dismiss는 OTP/공지 오탐 위험으로 포기.
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

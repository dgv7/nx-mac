# nx-mac

> **바람의나라 on macOS.** 더블클릭에서 로그인 창까지 **7.3초**. 상주 프로세스 0.

[한국어](./README.md) · [English](./README.en.md)

---

Sikarugir Wine wrapper(CX 24.0.7) 기반. 넥슨 게임 전용 **자동 빌더 + AppleScript URL router + SwiftUI splash**로 실행 체인을 구성한다. 직접 Wine을 튜닝하는 대신, 공식 무료 백엔드 위에 **검증된 설정 한 벌**을 자동 적용하는 데 집중했다.

macOS에서 넥슨 게임을 돌리는 기존 경로는 수동 wine prefix + 수십 번의 시행착오를 요구한다. 이 프로젝트는 그 과정을 `build-baram-app.sh` 한 번의 실행으로 압축한다. 이후로는 `.app` 더블클릭만 남는다.

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

## How it works

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

URL handler(`nexonplug://`, `ngm://`)도 함께 등록되므로 `baram.nexon.com` 브라우저 로그인 경로도 동일한 router로 수렴한다.

## Install

**요구사항**: macOS 14+ · Apple Silicon · 약 25GB 여유 디스크.

### 1. 빈 wrapper 준비

```bash
brew tap Sikarugir-App/sikarugir
brew install --cask sikarugir
```

Sikarugir Creator → **New Blank Wrapper**:

| Setting | Value |
|---|---|
| Name | `Baram` |
| Engine | `WS12WineCX24.0.7` |
| OS | `Windows 10` |

엔진은 반드시 CX 24.0.7. 다른 버전에서는 한글 IME 재현 안 됨.

### 2. 빌더 실행

```bash
git clone https://github.com/dgv7/nx-mac
cd nx-mac
./scripts/build-baram-app.sh
```

빌더가 자동 처리:

- libinotify dylib 심링크 (`wine/lib/` + `SharedSupport/` 양쪽)
- `dosdevices/c:` 절대경로 교정
- winetricks 한글 환경 (`corefonts → cjkfonts → vcrun2019`)
- NexonPlug 설치 (smallpatch 트릭)
- **`Nexon Launcher` Windows 서비스 disabled** ← cold-start 50→7초 핵심
- exit-watcher 배치
- `NX Launcher.app` 생성 + `nexonplug://` URL handler 등록
- SwiftUI Splash 컴파일 + 번들
- Cold-start 시간 자동 측정

첫 실행 시 `cjkfonts` 단계에서 10~20분 소요.

### 3. gulim.ttc 배치

본인 Windows PC의 `C:\Windows\Fonts\gulim.ttc`를 아래 경로에 복사:

```
~/Applications/Sikarugir/Baram.app/Contents/SharedSupport/prefix/drive_c/windows/Fonts/gulim.ttc
```

MS 저작권 폰트 — 의도적 미번들. 대체 폰트(Source Han, Nanum)로는 게임 UI 폰트 매칭 실패.

### 4. 실행

`~/Applications/Sikarugir/NX Launcher.app` 더블클릭. Splash가 즉시 뜨고 단계별 상태 텍스트가 흐르면서 Plug 로그인 창 출현 시 자동 소멸한다.

## Design notes

### 50s → 7s: cold-start 병목의 정체

초기 측정치 50초에서 **phase profiling**으로 구간별 시간을 재자, 실제 병목은 wine이 아니라 Plug이 호출하는 **`Nexon Launcher` Windows 서비스의 auto-start timeout 40초**였다. 서비스를 disabled로 두고 Plug이 필요한 시점에 on-demand로 spawn하게 두자 **7.3초**로 떨어졌다. 기능 손실 0.

### 한글 IME: 엔진 선택 문제

Wine 10 + macOS Mac driver 조합은 한글 IME pre-edit을 IMM32로 전달하지 않아 모든 채팅 입력이 막힌다. **CX 24.0.7 엔진 교체로 해결**. 단 CX24는 libinotify rpath가 기존 `wine/lib/`에 더해 `SharedSupport/`도 필요해 빌더가 양쪽 모두 심링크한다.

### Splash UX: 시간 표시 없음

Cold-start 편차가 크다 — M-series 7초, 오래된 Intel 30초+. **고정 예상 시간은 어느 쪽에서든 거짓말**이므로 제거했다.

- AppleScript shell이 `/tmp/nx-launcher-status`에 단계 마커 작성 (`cleanup` → `symlink` → `spawn` → `waiting`)
- SwiftUI splash가 마커를 읽어 상태 텍스트만 업데이트 (숫자 없음)
- `CGWindowListCopyWindowInfo`로 Plug 창 감지 → 자동 dismiss
- 한 단계가 15초 넘게 지속되면 subtle hint 페이드인 (ESC 취소 안내)

스피너 = "살아있음" 신호, 텍스트 = "현재 상태" 신호. 둘을 섞지 않는다.

### 상주 0 정책

Plug 또는 `gamer.exe` 종료 시 `baram-exit-watcher.sh`가 wine 트리 전체를 teardown한다. 백그라운드 상주 없음 — 매 실행이 cold-start. 의도적 선택이다. 상주 프로세스는 macOS의 "앱은 명시적으로 연다/닫는다" 멘탈 모델과 충돌하고, 넥슨 서버 측 세션 추적을 혼란시킬 수 있다.

### Router가 `.app`인 이유

macOS LaunchServices는 `nexonplug://` / `ngm://` 같은 URL scheme을 오직 `.app` bundle에만 바인딩한다. CLI 바이너리로는 브라우저 경로를 가로챌 수 없다. AppleScript applet은 `osacompile`로 빌드 가능해 Swift 툴체인 없이도 URL handler를 만들 수 있어 채택했다.

## Compatibility

다른 넥슨 게임 실행 가능성 예측 (실측 전):

| 예측 등급 | 게임 (대표) |
|---|---|
| 가능성 높음 (2D · 약한 NGS) | 크레이지아케이드, 카트라이더 러쉬플러스 |
| 가능성 중간 | 마비노기 영웅전 구버전 |
| 가능성 낮음 (NGS 강화) | 마비노기 현행 |
| 거의 불가능 (이중 보호) | 메이플스토리 현행, 던전앤파이터 |
| 불가능 (hardcore anti-cheat) | 서든어택, FC온라인 |

**구조 재사용률 ~30%, 게임별 실측 ~70%**. Plug / wine / router 레이어는 공통이지만 각 게임의 anti-cheat, 패처, 실행 파라미터 패턴은 독립 실험이 필요하다. v0.2+에서 `scripts/presets/` 디렉토리로 게임별 설정 분리 예정. 실측 결과 공유는 [Issues](https://github.com/dgv7/nx-mac/issues) 환영.

## Trade-offs

의식적으로 내린 선택과 받아들인 한계:

- **gulim.ttc 자가 배치**: MS 저작권. 대체 폰트로는 UI 렌더링이 어색해짐.
- **OTP "실행 실패" 팝업**: 실제 오류가 아닌 Nexon 2FA 트리거. 사용자가 확인 클릭. 자동 dismiss는 중요 공지 오탐 위험으로 포기.
- **NGS 룰 변경 리스크**: 2026-04 기준 검증. Nexon이 anti-cheat 규칙을 강화하면 예고 없이 차단될 수 있음.
- **Sikarugir Creator Refresh 시 설정 소실**: 빌더가 idempotent 설계이므로 재실행으로 복구.
- **x86_64 Wine 엔진**: Apple Game Porting Toolkit 기반 ARM 네이티브 경로는 Chromium-in-Plug 호환성이 CX24보다 약함. Plan B에서 재평가.

## Project layout

```
nx-mac/
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

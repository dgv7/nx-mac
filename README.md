# nx-mac

macOS(Apple Silicon)에서 **Nexon 온라인 게임**을 한 번의 더블클릭으로 실행하는 개인용 오픈소스 런처.

Wine 기반 래퍼(Sikarugir)에 Nexon 게임 전용 프리셋을 얹어 `.app`으로 번들링합니다. 직접 Wine을 쌓고 튜닝하는 대신, 공식 무료 백엔드 위에서 **"검증된 설정 한 벌"을 자동 적용**하는 게 이 프로젝트의 핵심입니다.

## 지원 게임 (v0.1)

| 게임 | 상태 | 비고 |
|---|---|---|
| **바람의나라** | ✓ 완주 검증 | 캐릭터 선택 · 필드 진입 · 한글 IME · GameGuard 통과 실측 |

현재 v0.1은 **바람의나라 전용**입니다. 다른 Nexon 게임 확장 로드맵은 아래 참조.

## 특징

- **Cold-start 7~10초** (기존 Wine 래퍼 통상 30~60초). Nexon Launcher Windows 서비스의 자동 시작 timeout 40초를 제거한 결과
- **한글 IME 조합 정상** (Wine SikarugirCX 24.0.7 엔진 선택 + 한글 폰트 세팅)
- **GameGuard 통과** 실측 확인 (필드 진입까지)
- **브라우저 없이 런처 자체에서 로그인 가능**
- **백그라운드 상주 없음**: 앱 닫으면 wine 트리 전체 정리

## 요구 조건

- macOS 14+ (실측: macOS Tahoe 26.4.1)
- Apple Silicon (Rosetta 2 자동 설치)
- 약 25GB 디스크 여유 (게임 리소스 18GB + wine + prefix)
- 본인 소유 Windows PC에서 추출한 **MS gulim.ttc** (한글 폰트, 저작권상 번들 포함 불가)

## 설치

### 1. Sikarugir Creator로 빈 wrapper 생성

```bash
# Homebrew 설치 (이미 있으면 skip)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Sikarugir Creator 설치
brew tap Sikarugir-App/sikarugir
brew install --cask sikarugir
```

`/Applications/Sikarugir.app` 실행 → **New Blank Wrapper** 클릭 → 아래 설정으로 생성:

- **Name**: `Baram`
- **Engine**: `WS12WineCX24.0.7` (한글 IME 해결분 필수)
- **OS**: `Windows 10`

생성된 wrapper 경로: `~/Applications/Sikarugir/Baram.app`

### 2. 빌더 스크립트 실행

```bash
git clone https://github.com/<your-fork>/nx-mac
cd nx-mac
./scripts/build-baram-app.sh
```

스크립트가 자동으로 처리하는 것:
- libinotify dylib 심링크 (wine/lib/ + SharedSupport/ 두 경로 모두)
- `dosdevices/c:` 절대경로 교정
- winetricks 한글 환경 (win10 → corefonts → cjkfonts → vcrun2019)
- NexonPlug installer 다운로드 + 설치
- **Nexon Launcher Windows 서비스 disabled** ← cold-start 단축 핵심
- exit-watcher 배치
- `NX Launcher.app` 생성 + `nexonplug://` URL handler 등록
- cold-start 시간 자동 측정 (정상 7~10초)

최초 실행 시 `cjkfonts` 단계에서 10~20분 소요됩니다.

### 3. gulim.ttc 배치 (한글 렌더링 필수)

본인 Windows PC의 `C:\Windows\Fonts\gulim.ttc`를 복사해서 아래 경로에 배치:

```
~/Applications/Sikarugir/Baram.app/Contents/SharedSupport/prefix/drive_c/windows/Fonts/gulim.ttc
```

MS 저작권 폰트라 이 저장소는 포함하지 않습니다.

### 4. 실행

`~/Applications/Sikarugir/NX Launcher.app` 더블클릭:

1. 7~10초 후 Plug 로그인 창
2. 넥슨 ID/비밀번호 입력
3. "게임 시작" → 최초 1회만 게임 리소스 18GB 다운로드
4. OTP 인증 → 필드 진입

브라우저 경로도 계속 지원됩니다: `baram.nexon.com` 로그인 → 게임 시작 → `nexonplug://` URL이 런처로 라우팅.

## 다른 Nexon 게임 지원은?

이 런처 **내부 구조**(Plug / wine / Router 레이어)는 모든 Nexon 게임에 공통으로 적용되지만, 실제 실행 여부는 **게임별 anti-cheat 설정**에 크게 의존합니다.

| 예측 등급 | 게임 (대표) |
|---|---|
| **가능성 높음** (2D · 약한 NGS) | 크레이지아케이드, 카트라이더 러쉬플러스 같은 레거시 2D |
| **가능성 중간** | 마비노기 영웅전 구버전 |
| **가능성 낮음** (NGS 강화) | 마비노기 현행 |
| **거의 불가능** (이중 보호) | 메이플스토리 현행, 던전앤파이터 (XignCode3 + NGS) |
| **불가능** (hardcore anti-cheat) | 서든어택, FC온라인 |

확장은 v0.2+ 로드맵에 있으며, 각 게임마다 **독립 실측**이 필요합니다. 구조 재사용률은 ~30%, 게임별 실험이 ~70%입니다.

fork 하셔서 `scripts/build-baram-app.sh`의 `WRAPPER_PATH` 및 game ID(Plug 내부의 nxplug 스킴 파라미터)만 바꿔 시도해볼 수 있지만, 공식 지원은 실측 성공 후에만 업데이트됩니다. 결과 공유는 Issues 환영.

## 알려진 제약

- **MS gulim.ttc**: 사용자 본인 라이선스. 대체 폰트(Source Han Sans, NanumGothic 등)로는 바람의나라 폰트 매칭 실패.
- **한글 IME**: CX24 엔진에서 해결됐지만, 엔진을 다른 걸로 바꾸면 재발 가능.
- **"실행 실패" 팝업**: OTP 인증 UX의 일부로 Nexon이 의도적으로 띄움. 자동 dismiss 안 함(계정 공지 등 중요 팝업까지 닫는 위험 회피).
- **NGS 서버 업데이트로 차단 가능성**: Nexon의 GameGuard 탐지 규칙이 강화되면 갑자기 차단될 수 있음. 현재 동작은 2026-04 기준 검증.

## 구조

```
nx-mac/
├── scripts/
│   ├── build-baram-app.sh        # 자동 빌더 (wrapper → 완성 상태)
│   ├── baram-router.applescript  # Router 소스 (on run / on open location)
│   └── baram-exit-watcher.sh     # 게임/Plug 종료 감지 → wine 정리
├── CLAUDE.md       # 프로젝트 성격·정책
├── ROADMAP.md      # 3-Plan 전략
├── STATUS.md       # 현재 진행 상황
├── SMOKE_TEST.md   # 스모크 테스트 체크리스트
└── README.md
```

## 참고 자료

- [Sikarugir](https://github.com/Sikarugir-App/Sikarugir) / [Creator](https://github.com/Sikarugir-App/Creator)
- [넥슨 플러그](https://nexonplug.nexon.com/)

## 라이선스

MIT (스크립트 · AppleScript · 문서). 게임 바이너리 · 폰트 · Wine 엔진은 각 저작권 보유자 소유.

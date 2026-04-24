# Roadmap — 순차 대체 개발 전략

## 진행 원칙
- **Plan A → B → C** 순서로 하나씩 개발·실사용 테스트.
- 각 플랜은 **`.app` 원클릭 배포**(Windows와 동일한 2클릭 UX)를 공통 목표로 둔다.
- 문제가 발생하면 **"수정 가능한 실패"** 와 **"폐기 기준"** 을 먼저 분류한다.
  - 수정 가능 → 현재 플랜 안에서 패치.
  - 폐기 기준 도달 → 현재 플랜의 모든 산출물·지식은 GitHub에 기록으로 남기고 다음 플랜으로 이동.
- 제약: 무료 백엔드만. CrossOver·Parallels Pro 등 유료 경로는 본 프로젝트 매트릭스에서 제외(필요 시 README 부록에 참고 경로로만 언급).
- 테스트 기기: M3 Pro / macOS (Sequoia 15.x 또는 Tahoe 26.x).

## 실행 체인 제약 (모든 플랜 공통)

바람의나라(2026)는 **웹 기반 런칭**이다. 단순 Game.exe 실행 불가.

```
브라우저(UA 체크) → baram.nexon.com 로그인 → nxplug:// → 넥슨플러그 → Game.exe → GameGuard
```

**두 게이트:**
1. **UA 게이트** — Mac 브라우저로 접근하면 "Windows에서만 실행 가능" 표시됨
2. **프로토콜 게이트** — `nxplug://` URL 스킴이 macOS엔 등록돼 있지 않음

### 구현 경로 3가지
- **경로 1 (기본 채택)** — Wine prefix 안에 **Windows 브라우저 + 넥슨플러그 + 클라이언트 전부** 포함. `.app` 더블클릭 → Wine 안의 브라우저 자동 기동 → 유저가 로그인·게임시작 클릭 → 모든 체인이 Wine 안에서 완결. 변수 최소, GameGuard 일관성 높음.
- **경로 2 (제외)** — 로그인 토큰 리버스 엔지니어링해서 Game.exe에 직접 전달. 넥슨 업데이트에 깨짐, 유지보수 불가.
- **경로 3 (경로 1 검증 후 증분 개선)** — `CFBundleURLTypes`에 `nxplug://` 등록 → Mac 브라우저 + macOS가 URL을 `.app`으로 라우팅 → Wine 내부 Plug으로 forward. Mac 네이티브 UX 회복.

**각 플랜은 "경로 1로 먼저 동작 확인 → 경로 3으로 UX 개선" 순서.**

---

## Plan A — Sikarugir 기반 자동 래퍼 빌더 (1순위)

### 왜 이것부터
- Sikarugir는 2026-04 현재 **가장 활발히 유지**되는 무료 Wine 래퍼 툴킷이다(Creator v1.0.1, 2026-01 릴리즈).
- **D3DMetal / DXVK / DXMT** 세 그래픽 백엔드를 토글 가능 → GameGuard 회피 가능 조합을 매트릭스로 돌릴 수 있다.
- Homebrew Cask 배포 경로가 있어 Gatekeeper quarantine을 자동 해제한다.
- 바람의나라는 2D 엔진이라 D3DMetal만으로도 렌더링 요구치를 충족할 가능성이 높다.

### 구현 단계
1. **스모크 테스트** (SMOKE_TEST.md): 수동으로 Sikarugir 래퍼에 Firefox + 넥슨플러그 + 바람의나라 설치, **풀 체인(웹 로그인 → Plug → 필드 진입)** 성공 확인.
2. **`build-baram-app.sh` 작성** (경로 1 기반):
   - Sikarugir Engine(Wine 10) 자동 다운로드·캐시.
   - Wine prefix 생성 → `winecfg` Windows 10 고정.
   - `winetricks corefonts cjkfonts vcrun2019` 자동 실행(이 순서).
   - Locale `ko_KR.UTF-8`, 한글 폰트 레지스트리 프리셋 주입.
   - **Windows Firefox-ESR 설치** (Wine 내부 브라우저).
   - **넥슨플러그 설치**, `nxplug://` 프로토콜 핸들러 등록 확인.
   - launcher 스크립트: `.app` 더블클릭 시 Wine 내부 Firefox를 `baram.nexon.com`으로 자동 오픈.
   - 바람의나라 클라이언트는 **Plug이 자동 다운로드**(setup.exe 번들 불필요, 넥슨 약관 리스크 회피).
   - 완성된 prefix를 `바람의나라.app` 템플릿에 복사 → ad-hoc 서명 → DMG 번들.
3. **배포**: DMG + Homebrew Cask (저장소는 본 GitHub repo 또는 tap 분리).
4. **경로 3 증분 개선**: `Info.plist`에 `CFBundleURLTypes`로 `nxplug://` 등록 → Mac 브라우저에서 로그인하고 URL 받아 Wine 내부 Plug으로 forward하는 bridge 스크립트 추가. UX 향상.
5. **(선택) 런처 UI v0.2**: 업데이트 체크, 에러 코드 114/360/380 자동 복구, Wine 로그 수집.

### 수정 가능한 실패(Plan A 유지)
- 특정 해상도·DPI에서 크래시 → 레지스트리 preset 조정.
- 한글 IME 미작동 → `fakekorean` 추가, Windows IME DLL 복사.
- 5분 이후 크래시 → 백엔드 토글(D3DMetal ↔ DXVK ↔ DXMT).
- 넥슨 런처/Plug 업데이트 후 깨짐 → `winetricks corefonts` 재실행, DLL override 재설정, Plug 재설치.
- 설치 스크립트가 Rosetta 2 미설치 기기에서 실패 → 전제 조건 스크립트 추가.
- **Wine 내부 Firefox 렌더링 깨짐** → 다른 브라우저(Chrome Windows 빌드 / Edge Windows)로 교체.
- **`nxplug://` 핸들러 미등록** → Plug 재설치 또는 레지스트리 수동 등록 스크립트 추가.
- **UA 스푸핑 필요** (Wine Firefox인데도 사이트가 인식 실패) → Firefox 설정 `general.useragent.override`로 강제.

### 폐기 기준(Plan B로 이동)
- 3가지 백엔드 모두에서 **GameGuard가 필드 진입 차단**, 2주 이상 대응해도 돌파 실패.
- Sikarugir 레포가 6개월 이상 커밋 없음(Whisky 전철). Engines 업데이트 중단으로 macOS 신버전에서 못 돌아가는 상황.

---

## Plan B — Apple GPTK 2.1 + Wine 11 자체 빌드 래퍼 (2순위)

### 왜 이것이 Plan B
- Apple **Game Porting Toolkit 2.1**은 Apple이 직접 배포하는 Metal 번역 레이어로, Sikarugir가 쓰는 D3DMetal 구버전보다 **Metal 최적화가 한 세대 앞서 있다**.
- **Wine 11 기반**. Sikarugir가 Wine 11 지원을 "not planned"로 닫았기 때문에([Sikarugir issue #180](https://github.com/Sikarugir-App/Sikarugir/issues/180)) 이 gap을 직접 메운다. Wine 11은 GameGuard의 Wine 감지 시그니처가 Wine 10과 다를 수 있어 **우회 가능성**이 새로 열린다.
- 의존성이 **Apple 공식 배포 + WineHQ mainline** 이라 장기 유지보수 위험이 가장 낮다.

### 구현 단계
1. GPTK 2.1 설치, Homebrew로 Wine 11 소스 빌드(`--HEAD` 또는 11.0 tag pin).
2. **커스텀 `.app` 번들 템플릿** 작성: `wineskinlauncher` 의존 제거, 자체 bash launcher로 엔진·prefix 로드.
3. 한글 preset / winetricks 레시피 / **Firefox + 넥슨플러그 설치 레시피**는 Plan A 스크립트에서 재사용(백엔드만 다름).
4. 경로 1 먼저 구현 → 동작 확인 후 경로 3 증분 추가.
5. 번들 크기 최적화 결정:
   - **정적 번들**(Wine+GPTK 전부 `.app` 안에) → 크기 ~2GB, 유저 설치 1회로 끝.
   - **동적 설치**(런처가 최초 실행 시 Homebrew로 의존성 설치) → `.app` 수 MB, 최초 실행 수 분.
   - → 정적 번들을 기본, 동적을 고급 옵션으로.
6. 서명 + DMG + README에 xattr quarantine 제거 안내.

### 수정 가능한 실패(Plan B 유지)
- Wine 11 빌드 실패 → 특정 commit pin, 필요 시 community patch 적용(winehq-staging 참고).
- Metal 렌더링 이슈 → MoltenVK fallback 레이어를 선택지로 추가.
- GPTK 2.1 릴리즈 후 Apple의 호환성 파라미터 변경 → `GPTK_HUD=0` 등 환경변수 튜닝.
- 번들 크기 불만 → dmg 내부 압축 + 최초 실행 시 압축 해제.

### 폐기 기준(Plan C로 이동)
- GPTK 2.1 + Wine 11 조합에서도 GameGuard가 실행 차단(에러 114/360/380 지속 재현).
- Apple이 GPTK 3.x에서 아키텍처·라이선스 정책을 바꿔 오픈소스 재배포가 불가능해짐.

---

## Plan C — Whisky 아카이브 fork + 엔진 swap (3순위, 최후 수단)

### 왜 마지막
- Whisky는 **2025-04 개발 중단**됐지만 소스는 MIT/GPL로 공개, 커뮤니티 레시피가 풍부하다.
- 기반이 **GPTK 1.x + Wine 8/9 계열**이라 Plan B(GPTK 2.1 + Wine 11)와 **다른 스택**이다 → Plan A·B 실패 원인이 "특정 Wine 버전에 박힌 GameGuard 감지"일 경우 교차 검증 가치.
- Swift로 작성된 네이티브 macOS 앱이라 UI가 Plan A·B보다 완성도 높은 상태로 시작 가능(유지보수 없는 스냅샷이지만 당장 돌아감).

### 구현 단계
1. Whisky 마지막 릴리즈(2025-04) fork → 빌드 환경 최신 Xcode에 맞춰 복구.
2. 엔진을 **Sikarugir Engines 또는 GPTK 2.1**로 swap(Whisky 내부 엔진 로더 수정).
3. Plan A의 prefix 스크립트·한글 preset·**Firefox + Plug 설치 레시피** 그대로 이식.
4. 경로 1 먼저 구현 → 동작 확인 후 경로 3 증분 추가.
5. 번들 출력 포맷은 Whisky의 내장 export 기능 활용.

### 수정 가능한 실패(Plan C 유지)
- Swift/SwiftUI API deprecation → 최소 패치로 빌드 복구.
- 엔진 swap 호환성 → Wine prefix 버전 롤백, magic bytes 체크 우회.

### 폐기 기준(프로젝트 종료)
- 세 Plan 모두 GameGuard 차단 재현.
- 결론: **현재 macOS Wine 스택으로는 바람의나라 구동 불가**. CLAUDE.md·README에 실패 로그를 공개 기록으로 남기고 레포는 아카이브. 다음 세대 macOS·Wine·GPTK 메이저 버전이 나오면 재시도.

---

## 단계별 산출물 체크리스트

| 단계 | 산출물 | 성공 판정 |
|---|---|---|
| A.1 스모크 | SMOKE_TEST.md 체크리스트 기록 | **웹 로그인 → Plug → 필드 진입 + 5분 안정** |
| A.2 빌더 | `build-baram-app.sh`, 템플릿 `.app` (경로 1) | 클린 Mac에서 스크립트 1회 실행 → 즉시 실행 가능한 `.app` 생성 |
| A.3 배포 | DMG, Homebrew Cask, README | 타인 Mac에서 다운로드 → 더블클릭 → Wine 안 Firefox로 로그인 → 필드 진입 |
| A.4 경로 3 브릿지 | `CFBundleURLTypes` + URL forward 스크립트 | Mac 브라우저로 로그인했을 때 Wine 내부 Plug으로 `nxplug://` 전달 성공 |
| B.1 GPTK 빌드 | Wine 11 + GPTK 2.1 빌드 스크립트 | 로컬에서 `wine --version` = 11.x |
| B.2 번들 | 자체 `.app` 템플릿 + launcher + Plug 레시피 | Plan A.3와 동일 판정 |
| B.3 경로 3 브릿지 | Plan A.4와 동일 구조 | Plan A.4와 동일 판정 |
| C.1 Whisky fork | 최신 Xcode에서 빌드되는 Whisky fork | 기본 UI 기동 |
| C.2 엔진 swap | 커스텀 엔진 로더 + Plug 레시피 | 엔진 교체 후 Plan A.1 스모크 통과 |

## Plan A.1 스모크 완주 결과 (2026-04-22)

**결과**: 기술적 타당성 입증 완료. 전체 체인 동작 확인 (상세 기록은 [STATUS.md](STATUS.md)).

**뚫은 블로커 9개**:
1. Sikarugir + Wine 10 설치 및 wrapper 생성
2. macOS Tahoe libinotify rpath (Frameworks dylib 94개 심링크)
3. Wine 드라이브 Free Space 0 Byte (dosdevices 절대경로)
4. winetricks 한글 환경 (corefonts/cjkfonts/vcrun2019)
5. NexonPlug 설치 + self-update race (NGM smallpatch 단독 실행)
6. Mac LSF URL 스킴 경쟁 (AppleScript Router Viewer role + Mac Plug.app unregister)
7. Plug Wine crash (NexonLauncher64 선행 기동)
8. Chromium GPU 검은 화면 (`--disable-features=VizDisplayCompositor --in-process-gpu`)
9. 한글 폰트 (MS 공식 gulim.ttc 사용, 저작권상 유저 별도 준비)

**미해결 한계**:
- **한글 IME 조합 버그**: Wine 10의 macOS Mac Driver → IMM32 pre-edit 전달 실패. 바람의나라 채팅이 핵심 기능이라 심각. WS12WineCX24 엔진 교체도 Tahoe 호환 실패. **Plan B(Wine 11 기반)에서 재해결 예정**.
- **MS gulim.ttc 라이선스**: repo 포함 불가. README 안내만.

**라이프사이클 관리 추가**:
- **NX Launcher.app** (Router): AppleScript 기반 `nexonplug:`/`ngm:` 핸들러. Router가 매 URL 호출 시 전체 시스템 상태 검증(심링크/dosdevices) + 사전 프로세스 cleanup + Launcher 선행 기동 + Plug 실행 + exit-watcher spawn
- **baram-exit-watcher.sh**: `gamer.exe` 종료 감지 후 3초 grace + Plug hang 강제 cleanup. 키 입력 없음 (중요 팝업 자동 submit 위험 회피).

## 현재 상태

**Plan A**: ✓ 기술 검증 완료. A.2(빌더 스크립트)·A.3(배포)·A.4(경로 3 브릿지)로 진행 가능. 한글 IME 제약 있음.
**Plan B**: 준비 중. Wine 11 기반 엔진에서 IME 버그 재검증이 주 동기.
**Plan C**: 미착수. Plan B 결과에 따라 판단.

## 참고 링크
- [Sikarugir](https://github.com/Sikarugir-App/Sikarugir) / [Creator releases](https://github.com/Sikarugir-App/Creator/releases) / [Engines releases](https://github.com/Sikarugir-App/Engines/releases)
- [Sikarugir Wine 11 거부 이슈 #180](https://github.com/Sikarugir-App/Sikarugir/issues/180)
- [Apple Game Porting Toolkit](https://developer.apple.com/games/game-porting-toolkit/)
- [Whisky 아카이브 발표](https://www.macrumors.com/2025/04/23/whisky-ends-mac-gaming-tool-crossover/)
- [nProtect GameGuard 에러 코드 FAQ](https://gameguardfaq.nprotect.com/)
- [넥슨플러그 공식](https://nexonplug.nexon.com/)

# nx-mac

## 프로젝트 목적
macOS(Apple Silicon)에서 **Nexon 온라인 게임**을 원클릭으로 실행하는 런처.
"패러럴즈를 직접 만든다"가 아니라 기존 Wine wrapper 위에 Nexon 게임 전용 프리셋을 얹어 `.app`으로 번들링한다.

**현재 범위**: v0.1은 **바람의나라 전용**. 다른 Nexon 게임은 Plug/wine 인프라 공유하지만 게임별 anti-cheat 설정이 달라 v0.2+ 실험 브랜치에서 확장 예정.
**배포 앱명**: `NX Launcher` (Bundle ID `com.saeroon.nx-launcher`)

## 프로젝트 성격
- **개인 사용 + 오픈소스**. 본인이 Mac에서 바람의나라를 플레이하려고 만들고 GitHub에 공개한다.
- **사업성/상업성 고려 없음**. 안정성·재현성이 최우선 기준.
- **무료 백엔드만 사용**. CrossOver·Parallels Pro 등 유료 의존성은 코어 경로에서 배제(README 참고 경로로만 언급 가능).
- UX 목표: Windows와 동일한 2클릭 플레이 체감. `.app` 더블클릭 → 웹 로그인 → 필드 진입.

## 왜 "전용" 런처인가
- 게임 하나에만 최적화 → 호환성 테스트 범위 좁음
- 바람의나라는 오래된 2D 엔진 → DirectX 요구사항 낮음, GPU 튜닝 최소
- 한글 폰트/코드페이지/레지스트리/해상도 프리셋 고정
- 웹 로그인 + 넥슨플러그 + 클라이언트 패치를 Wine prefix 안에 전부 포함해 자동화

## 2026-04 현재 Mac 생태계 (참고)
- **Sikarugir** (2026-01 Creator v1.0.1): 무료, D3DMetal/DXVK/DXMT 토글, Apple Silicon Metal 최적화, Wine 10. **본 프로젝트 1순위 백엔드**.
- **Apple Game Porting Toolkit 2.1**: Apple 공식 Metal 번역 레이어, Wine 11 직접 빌드 조합 가능. **2순위**.
- **Whisky**: 2025-04 개발 중단됐지만 소스 공개. **3순위(최후 수단)**.
- **CrossOver 26** (2026-02): Wine 11 + D3DMetal 3.0, GameGuard 상당 부분 돌파. $74/년이라 **본 프로젝트 코어 경로에서 제외**. README 부록 참고용.
- **Parallels Desktop 20.2+**: 부팅 2~7분으로 게임용 부적합, 제외.

## 핵심 블로커

### 1. 실행 체인 (웹 기반 런칭)
바람의나라는 2026년 현재 웹 기반 런칭이다. 단순 exe 실행으로는 세션 티켓이 없어 안 돌아간다.

```
브라우저(UA 체크) → baram.nexon.com 로그인 → nxplug:// → 넥슨플러그 → Game.exe → GameGuard
```

→ 래퍼 안에 **Windows 브라우저 + 넥슨플러그 + 클라이언트**를 전부 포함해야 한다. 자세한 경로는 ROADMAP.md.

### 2. 넥슨 NGS(nProtect GameGuard)
Wine 환경을 감지해서 차단할 수 있음. 실측으로 확인 필요. Wine 버전·엔진 조합(Wine 10/11, D3DMetal/DXVK/DXMT)을 바꿔가며 우회 가능 조합을 찾는다.

## 로드맵 (요약)

상세는 [ROADMAP.md](ROADMAP.md) 참조. 요약:

- **Plan A — Sikarugir 기반 자동 래퍼 빌더** (1순위, 현재 진행)
- **Plan B — Apple GPTK 2.1 + Wine 11 자체 빌드** (A 폐기 시)
- **Plan C — Whisky fork + 엔진 swap** (B 폐기 시, 최후 수단)

각 플랜은 `.app` 원클릭 배포를 공통 목표로, 실패 시 "수정 가능한 실패"와 "폐기 기준"을 분리해 판단.

**현재 상태** (2026-04-22 세션 종료 기준):
- **Plan A.1 스모크 완주** ✓ — 전체 체인 동작 확인, 9개 블로커 돌파, 캐릭터 선택·필드 진입까지 검증. 상세: [STATUS.md](STATUS.md)
- **Plan A.2 빌더** 대기 중 — `build-baram-app.sh` 자동화 필요
- **알려진 한계**: 한글 IME 조합 버그 (Wine 10 Mac Driver 레벨). Plan B로 이월.

다음 액션: Plan A.2 빌더 작성 → Plan A.3 GitHub 배포 → Plan B 시도 (Wine 11 기반으로 IME 재검증).

## 기술 결정 대기 중
- 런처 UI 프레임워크: SwiftUI vs Electron vs (v0.1은 UI 없이 `.app` 번들만)
- 배포 형태: DMG vs Homebrew Cask (둘 다 가능, 우선 DMG + Cask 병행)
- 바람의나라 클라이언트 재배포 가능 여부 — 넥슨 약관상 클라이언트 바이너리를 번들에 포함할 수 없으면, 래퍼 `.app`은 빈 상태로 배포하고 최초 실행 시 **Wine 내부 Plug이 공식 서버에서 받도록** 설계(법적 리스크 회피 + 항상 최신 패치 보장).

## 참고 자료
- [Sikarugir](https://github.com/Sikarugir-App/Sikarugir) / [Creator](https://github.com/Sikarugir-App/Creator) / [Engines](https://github.com/Sikarugir-App/Engines)
- [Apple Game Porting Toolkit](https://developer.apple.com/games/game-porting-toolkit/)
- [Whisky 개발 중단 발표](https://www.macrumors.com/2025/04/23/whisky-ends-mac-gaming-tool-crossover/)
- [CrossOver 26 Anti-Cheat Breakthrough](https://wineformac.org/news/blog-crossover-26-anti-cheat-2026.html) (유료 경로, 참고용)
- [nProtect GameGuard 공식](https://gameguard.nprotect.com/kr/index.html)
- [넥슨플러그](https://nexonplug.nexon.com/)

## 세션 맥락
이 프로젝트는 saeroon-project 세션(2026-04-22)에서 분리되어 시작됨.
원 논의: "패러럴즈 같은 걸 바람의나라 특화로 간단히 만들 수 있을까?"

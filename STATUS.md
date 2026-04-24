# nx-mac v0.1 진행 상황 (2026-04-24 기준)

## 결론: **Plan A 완주 + 배포 준비 완료 (바람의나라 전용)**

3일에 걸친 세 세션으로 **nx-mac v0.1 (바람의나라 전용)** 이 배포 가능한 상태에 도달했습니다. 프로젝트 브랜딩은 `nx-mac` / 배포 앱명 `NX Launcher` (다른 Nexon 게임 확장 가능성 대비).

| 세션 | 성과 |
|---|---|
| 2026-04-22 | Plan A.1 스모크 완주 (Sikarugir 10). 전 체인 실증. 한글 IME는 Plan B로 이월. |
| 2026-04-23 | 엔진을 **SikarugirCX 24.0.7**로 전환해 **한글 IME 조합 버그 해결**. libinotify rpath 차이 + AppleScript SIGHUP 회피 패턴 확정. |
| 2026-04-24 | 세분화 phase profiling으로 `Nexon Launcher` 서비스 timeout 40초 병목 발견. 서비스 disabled로 **cold-start 50s → 7s**. Plug 단독 실행(브라우저 우회) 확인. 배포 스크립트 완성. |

## 현재 상태

### 검증된 핵심 지표 (실측)

| 지표 | 값 |
|---|---|
| Cold-start (URL dispatch → Plug UI visible) | **7.3초** |
| Warm-reuse (기존 Plug 살아있을 때) | 2~3초 |
| 한글 IME 조합 | 정상 |
| GameGuard (NGS) 통과 | 필드 진입 완료 |
| 상주 정책 | 앱 종료 시 wine 트리 전체 정리 (상주 0) |

### 검증된 체인 (누적)

| # | 단계 | 2026-04-22 해결 | 2026-04-23~24 추가 |
|---|---|---|---|
| 1 | Sikarugir + Wine 기동 | Wine 10 | CX 24.0.7로 엔진 교체 |
| 2 | libinotify dylib rpath | `wine/lib/` 심링크 | CX24는 `SharedSupport/`도 필요 (양쪽 심링크) |
| 3 | 한글 환경 | `corefonts → cjkfonts → vcrun2019` | 동일 |
| 4 | NexonPlug 설치 | smallpatch 트릭 | 동일 |
| 5 | URL 라우팅 | Baram-URL-Router.app | `on run` 추가로 단독 실행 지원 → **NX Launcher.app로 rename** (04-24) |
| 6 | Plug crash 우회 | NexonLauncher64 pre-spawn | **Windows 서비스 disabled로 대체** |
| 7 | Chromium 검은화면 | VizDisplayCompositor flag | 동일 |
| 8 | Free Space 0 Byte | dosdevices 절대경로 | 동일 |
| 9 | 18.22GB 게임 다운로드 | NGM 자동 | 동일 |
| 10 | 한글 폰트 | MS gulim.ttc | 동일 (유저 준비) |
| 11 | OTP + 필드 진입 | Nexon UX | 동일 |
| 12 | GameGuard 통과 | Wine 10 | CX24에서도 통과 |
| 13 | exit cleanup | watcher | **Plug 종료 시도 전체 teardown** 강화 |
| 14 | 상주 금지 | — | 정책 엄격 만족 |
| 15 | 한글 IME 조합 | Plan B 이월 | **CX24 엔진으로 해결** |
| 16 | Cold-start 7초화 | — | **Nexon Launcher 서비스 disabled** |

## 프로젝트 레포 구조

```
nx-mac/
├── scripts/
│   ├── build-baram-app.sh        # ★ 자동 빌더 (빈 wrapper → 완성 상태, 바람 전용)
│   ├── baram-router.applescript  # Router 소스 (on run + on open location)
│   └── baram-exit-watcher.sh     # 상주 금지 watcher
├── CLAUDE.md                     # 프로젝트 성격·정책
├── ROADMAP.md                    # 3-Plan 전략
├── STATUS.md                     # 본 문서
├── SMOKE_TEST.md                 # 스모크 테스트 체크리스트
├── README.md                     # 설치 가이드
└── .gitignore                    # gulim.ttc / downloads/ / logs/ 제외
```

배포 앱명: **NX Launcher** (Info.plist `CFBundleName`, Bundle ID `com.saeroon.nx-launcher`)
내부 script/prefix 경로는 `baram-*` 유지 — 현재 지원 게임이 바람의나라이므로 정확한 네이밍.

## 알려진 제약 (2026-04-24 현재)

### MS gulim.ttc 라이선스 (해결 불가)
사용자가 본인 Windows PC에서 추출해서 prefix 안에 배치해야 함. 오픈소스 repo에 포함 불가.

### OTP "실행 실패" 팝업 (의도된 UX)
Nexon의 2FA 트리거 패턴. 사용자가 직접 확인 눌러야 함. 자동 dismiss는 중요 팝업 오탐 위험으로 포기.

### Sikarugir Creator Refresh 시 설정 리셋 가능성
Creator GUI로 wrapper를 Refresh 하면 libinotify 심링크 + `Nexon Launcher` 서비스 설정이 날아갈 수 있음. 이 경우 `build-baram-app.sh` 재실행으로 복구 (idempotent 설계).

## 다음 단계

### 즉시 (이번 세션)
- [x] 프로젝트 폴더 rename: `~/projects/baram-mac` → `~/projects/nx-mac`
- [x] 현 환경에 설치된 `Baram-URL-Router.app`을 새 `NX Launcher.app`으로 교체 (2026-04-24 완료, ad-hoc 재서명 + LSF 재등록)
- [ ] git init + 초기 commit
- [ ] GitHub public repo `nx-mac` 생성 + push

### 단기 (오픈소스 공개)
- DMG 빌드 스크립트 (선택, 코드 서명 없이 ad-hoc)
- Homebrew Cask formula (선택)
- 이슈 템플릿 + Contribution 가이드

### v0.2 로드맵 — 다른 Nexon 게임 확장 (실험)
- `scripts/presets/` 디렉토리 도입: 게임별 preset (game ID, 권장 디스크, anti-cheat 주의사항)
- 첫 후보: 크레이지아케이드 (2D 캐주얼, NGS 약할 것으로 추정)
- 각 게임 실측 성공 후 공식 지원 명단 추가
- 실패 사례도 README에 "known incompatible" 섹션으로 기록

### 장기 (Plan B는 우선순위 하향)
- Wine 11 기반 Plan B는 Plan A가 모든 블로커를 해결해서 **실행 유인 없음**. 다만 엔진 의존성 분산을 위한 fallback으로 문서화만 유지.

## 세션 3회 누적 통계

- **총 세션 시간**: 약 12시간
- **뚫은 블로커**: 16개
- **코드 산출물**: AppleScript Router, exit-watcher, 빌더 스크립트
- **결정적 breakthrough**:
  - 1일차: VizDisplayCompositor flag, AppleScript URL handler, NexonLauncher pre-spawn, MS gulim.ttc
  - 2일차: CX24 libinotify rpath 발견 + IME 해결, nohup subshell SIGHUP 회피
  - 3일차: **phase profiling으로 Nexon Launcher 서비스 timeout 발견 → 서비스 disabled로 cold-start 7배 단축**

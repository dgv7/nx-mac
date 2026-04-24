# Smoke Test — 풀 체인 실행 검증

**목적**: Plan A(Sikarugir)로 바람의나라가 macOS에서 **웹 로그인부터 필드 진입까지** 전 체인을 타고 돌아가는지 확인.
**소요**: 60~90분 (다운로드·설치 포함)
**판정**: 필드 진입 성공 + 5분 플레이 안정

> 이 문서는 ROADMAP.md Plan A.1 단계. Plan A 폐기 기준에 도달하면 Plan B로 이동, Phase 번호는 플랜 내부 단계로만 사용.

## 사전 확인
- [ ] Mac 모델/칩 확인 (Apple Silicon M1~M5 중 어느 세대인지 기록)
- [ ] macOS 버전 확인 (Sequoia 15.x 또는 Tahoe 26.x)
- [ ] 빈 디스크 공간 20GB+ 확보
- [ ] 바람의나라 넥슨 계정 준비
- [ ] Rosetta 2 설치: `/usr/sbin/softwareupdate --install-rosetta --agree-to-license`

---

## Step 1 — Sikarugir 설치

**권장(Gatekeeper 자동 해제):**
```bash
brew install --cask Sikarugir-App/sikarugir/sikarugir
```

**DMG 직접 설치 시:**
- https://github.com/Sikarugir-App/Creator/releases (최신 v1.0.1, 2026-01)
- 설치 후 quarantine 제거:
  ```bash
  xattr -dr com.apple.quarantine /Applications/Sikarugir.app
  ```
- 또는 시스템 설정 → 개인정보 보호 및 보안 → "확인 없이 열기"

## Step 2 — 바람의나라 래퍼 생성

- Sikarugir Creator 실행 → "New Blank Wrapper"
- 이름: `Baram`
- Wine engine: **Wine 10** (Sikarugir Engines 최신, D3DMetal 백엔드 활성화)
- Windows 버전: **Windows 10 (먼저 고정)**

## Step 3 — 한글 환경 준비 (순서 중요)

wrapper 우클릭 → "Show Package Contents" → `Contents/Wineskin.app` 실행 → Advanced → Tools → Winetricks.

**설치 순서 (반드시 이 순서):**
1. `corefonts` — MS 웹 폰트(영문 UI fallback)
2. `cjkfonts` — 한/중/일 폰트 팩 (`gulim`/`gothic` 단독 verb는 winetricks에 없음. 실패 시 Windows의 `gulim.ttc`를 `drive_c/windows/Fonts/`에 수동 복사)
3. `vcrun2019` — VC++ 2015~2019 통합 (마지막, Windows 10 고정 상태에서 설치해야 올바른 재배포판 받음)

**Locale 설정:**
- Config Utility → Locale = `ko_KR.UTF-8`
- 레지스트리 `HKCU/Control Panel/International/Locale` 확인
- (선택) `winetricks fakekorean` — 한글 폰트 치환이 안 되면 추가

## Step 4 — Windows 브라우저 + 넥슨플러그 설치 ★ 핵심

바람의나라는 웹 로그인 → `nxplug://` → 넥슨플러그 → Game.exe 체인이라 **브라우저·Plug도 Wine 안에 넣어야 한다**.

1. Wine prefix 안에 Windows Firefox 설치 (Firefox-ESR Windows 빌드 권장, 가벼움)
   - `firefox-esr-win64.exe` 다운로드 후 wrapper 안에서 실행
2. 넥슨플러그 Windows 설치판 다운로드 → wrapper 안에서 실행
   - https://nexonplug.nexon.com/
3. 설치 후 Wine prefix 레지스트리에 `nxplug://` 프로토콜 핸들러가 등록됐는지 확인:
   ```
   HKCR/nxplug/shell/open/command
   ```

## Step 5 — 바람의나라 클라이언트 수신

**setup.exe 직접 다운로드 불필요** — Plug이 웹 세션 기반으로 자동 다운로드·패치한다.

1. Wrapper 안의 Firefox 실행 → `baram.nexon.com` 접속
   - **확인 포인트**: "Windows에서만 실행" 메시지가 **안 떠야 함** (Wine 안의 Firefox는 Windows로 인식됨)
2. 넥슨 계정 로그인
3. "게임 시작" 버튼 클릭
   - **확인 포인트**: `nxplug://` URL이 발동되어 **Wine 안의 넥슨플러그가 뜸**
4. Plug이 바람의나라 클라이언트 자동 다운로드·설치·패치
5. 설치 경로 기록: `drive_c/Program Files/...`

## Step 6 — 실행 테스트

- Plug에서 게임 자동 실행
- 캐릭터 선택
- **필드 진입 (판정 지점)**
- 5분 플레이 (GameGuard가 런타임에 뒤늦게 감지하는 경우 대비)

---

## 기록할 것

| 체크 | 결과 |
|---|---|
| Step 1 Sikarugir 설치·기동 | 성공 / 실패 |
| Step 4 Firefox 설치 후 baram.nexon.com 렌더링 | 정상 / 깨짐(상세 기록) |
| Step 4 UA 게이트 통과 (Windows 인식) | 통과 / 차단 |
| Step 4 넥슨플러그 설치 | 성공 / 실패 |
| Step 5 Plug이 `nxplug://` 수신 후 기동 | 성공 / 실패 |
| Step 5 클라이언트 자동 다운로드·패치 | 성공 / 실패 |
| Step 6 런처·로그인 단계 진입 | 성공 / 실패(에러코드) |
| Step 6 캐릭터 선택 | 성공 / 실패 |
| Step 6 **필드 진입** | 성공 / 실패 |
| Step 6 5분 플레이 | 안정 / 크래시(시점) |
| GameGuard 에러 코드 | 114 / 360 / 380 / 기타 / 없음 |
| Wine 로그 | `Contents/logs/` 경로 또는 터미널 출력 |
| 사용 조합 | Wine 10 / D3DMetal·DXVK·DXMT 중 어떤 백엔드 |

---

## 판정 기준

- **필드 진입 성공 + 5분 안정** → Plan A.2로 진행 (빌더 스크립트 작성).
- **특정 단계 실패 (수정 가능한 실패)** → ROADMAP.md "Plan A 수정 가능한 실패" 목록에 따라 대응 후 재시도:
  - UA 체크 실패 → Firefox UA 설정 조정 / Chrome Windows 빌드 시도
  - `nxplug://` 미수신 → Wine registry 확인 / Plug 재설치
  - 특정 백엔드에서만 크래시 → D3DMetal ↔ DXVK ↔ DXMT 토글 테스트
  - 5분 이후 크래시 → Wine 로그 + GameGuard 에러 코드 수집 후 검색
- **3가지 백엔드 모두에서 실패 + 2주 이상 우회 실패** → Plan A 폐기, ROADMAP.md Plan B 착수.

## 참고
- [ROADMAP.md](ROADMAP.md) — 3-플랜 전체 전략
- [넥슨플러그 공식](https://nexonplug.nexon.com/)
- [nProtect GameGuard 에러 코드 FAQ](https://gameguardfaq.nprotect.com/)
- [Sikarugir](https://github.com/Sikarugir-App/Sikarugir)

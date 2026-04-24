#!/bin/bash
# nx-mac installer — 사전 준비를 자동화하고 build-baram-app.sh까지 이어서 실행한다.
# Usage: curl -fsSL https://raw.githubusercontent.com/dgv7/nx-mac/main/install.sh | bash
#
# 자동 처리:
#   1. Xcode Command Line Tools
#   2. Homebrew
#   3. Sikarugir Creator (brew cask)
#   4. nx-mac 프로젝트 clone
#   5. Sikarugir Creator에서 wrapper 생성 안내 (자동 감지)
#   6. build-baram-app.sh 실행
#
# 중복 실행 안전: 각 단계는 이미 완료됐으면 건너뜀.

set -euo pipefail

# $'...' stores actual ESC chars so the codes render in both printf and cat <<EOF
BLUE=$'\033[34m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'
RESET=$'\033[0m'; BOLD=$'\033[1m'

info()   { printf "${BLUE}[*]${RESET} %s\n" "$*"; }
ok()     { printf "${GREEN}[✓]${RESET} %s\n" "$*"; }
warn()   { printf "${YELLOW}[!]${RESET} %s\n" "$*"; }
err()    { printf "${RED}[x]${RESET} %s\n" "$*" >&2; }
header() { printf "\n${BOLD}━━━ %s ━━━${RESET}\n\n" "$*"; }

trap 'err "중단됨. 완료된 단계는 건너뛰므로 재실행하면 이어집니다: curl -fsSL https://raw.githubusercontent.com/dgv7/nx-mac/main/install.sh | bash"' ERR

[ "$(uname)" = "Darwin" ] || { err "macOS 전용"; exit 1; }
if [ "$(uname -m)" != "arm64" ]; then
  warn "Apple Silicon 권장 — Intel Mac은 cold-start가 30초 이상일 수 있습니다."
fi

INSTALL_DIR="${NX_MAC_DIR:-$HOME/nx-mac}"
WRAPPER_PATH="$HOME/Applications/Sikarugir/Baram.app"

header "nx-mac installer"
cat <<EOF
자동 설치 내역:
  1. Xcode Command Line Tools  (없으면)
  2. Homebrew                  (없으면)
  3. Sikarugir Creator         (없으면)
  4. nx-mac 프로젝트           → ${INSTALL_DIR}
  5. build-baram-app.sh 실행

수동 단계는 한 번: Sikarugir Creator에서 Baram wrapper 생성 (안내 출력됨).

EOF
sleep 2

# ─── 1. Xcode CLT ───
header "1/5 · Xcode Command Line Tools"
# 전체 Xcode 또는 CLT 중 하나라도 있고 git/clang 접근 가능하면 OK
if xcode-select -p >/dev/null 2>&1 && xcrun --find git >/dev/null 2>&1 && xcrun --find clang >/dev/null 2>&1; then
  ok "이미 설치됨 ($(xcode-select -p))"
else
  info "시스템 설치 dialog 호출 중. 팝업에서 '설치'를 클릭하세요."
  xcode-select --install 2>/dev/null || true
  echo -n "설치 완료 대기 중"
  until xcrun --find git >/dev/null 2>&1 && xcrun --find clang >/dev/null 2>&1; do
    printf "."
    sleep 5
  done
  echo
  ok "설치 완료"
fi

# ─── 2. Homebrew ───
header "2/5 · Homebrew"
if command -v brew >/dev/null 2>&1; then
  ok "이미 설치됨 ($(brew --version | head -1))"
else
  info "Homebrew 공식 설치 스크립트 실행 (관리자 암호 요구할 수 있음)"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  command -v brew >/dev/null || { err "brew 설치 후 PATH 인식 실패. 터미널을 재시작한 뒤 다시 실행하세요."; exit 1; }
  ok "설치 완료"
fi

# ─── 3. Sikarugir Creator ───
header "3/5 · Sikarugir Creator"
SIKARUGIR_APP="/Applications/Sikarugir Creator.app"
if [ -d "$SIKARUGIR_APP" ]; then
  ok "이미 설치됨 ($SIKARUGIR_APP)"
else
  info "brew tap Sikarugir-App/sikarugir"
  brew tap Sikarugir-App/sikarugir >/dev/null
  info "brew install --cask sikarugir (다운로드 수 분)"
  brew install --cask sikarugir
  ok "설치 완료"
fi

# ─── 4. nx-mac repo ───
header "4/5 · nx-mac 프로젝트 다운로드"
if [ -d "$INSTALL_DIR/.git" ]; then
  info "기존 설치 감지 → git pull"
  git -C "$INSTALL_DIR" pull --ff-only
  ok "최신 버전 동기화"
else
  info "git clone → $INSTALL_DIR"
  git clone --depth=1 https://github.com/dgv7/nx-mac "$INSTALL_DIR"
  ok "다운로드 완료"
fi

# ─── 5. Wrapper 생성 (사용자 GUI) ───
header "5/5 · Baram wrapper 생성 (수동 단계 1회)"
if [ -d "$WRAPPER_PATH" ]; then
  ok "이미 존재: $WRAPPER_PATH"
else
  cat <<EOF
${BOLD}Sikarugir Creator에서 직접 클릭해야 하는 유일한 단계입니다.${RESET}

잠시 후 Sikarugir Creator가 자동으로 열립니다. 아래를 입력하세요:

  1. 'New Blank Wrapper' 클릭
  2. Name:    ${BOLD}Baram${RESET}
  3. Engine:  ${BOLD}WS12WineCX24.0.7${RESET}   ${YELLOW}(반드시 CX 24.0.7 — 한글 IME 해결분)${RESET}
  4. OS:      Windows 10
  5. 'Create' 또는 'Save' 클릭
  6. 이 터미널로 돌아오세요 (Sikarugir는 그대로 열어둬도 됩니다)

생성을 자동 감지합니다 (최대 30분 대기).

EOF
  open "$SIKARUGIR_APP" 2>/dev/null || open -a "Sikarugir Creator" 2>/dev/null || true
  echo -n "대기 중"
  for i in $(seq 1 1800); do
    if [ -d "$WRAPPER_PATH" ]; then
      echo
      ok "Wrapper 감지: $WRAPPER_PATH"
      break
    fi
    sleep 1
    if [ $((i % 30)) -eq 0 ]; then
      printf " %dm" $((i / 60))
    else
      printf "."
    fi
  done
  if [ ! -d "$WRAPPER_PATH" ]; then
    echo
    err "30분 경과 — wrapper 미감지"
    echo "수동으로 wrapper 생성 후 아래 명령 실행:"
    echo "  cd $INSTALL_DIR && ./scripts/build-baram-app.sh"
    exit 1
  fi
fi

# ─── 6. Builder ───
header "빌더 실행"
warn "첫 실행 시 'cjkfonts' 단계에서 10~20분 소요됩니다. 터미널을 종료하지 마세요."
cd "$INSTALL_DIR"
./scripts/build-baram-app.sh

# ─── Done ───
header "✓ 설치 완료"
cat <<EOF
남은 단계:

  ${BOLD}1. MS gulim.ttc 배치${RESET}
     Windows PC의 C:\\Windows\\Fonts\\gulim.ttc를 아래 경로에 복사:
       $HOME/Applications/Sikarugir/Baram.app/Contents/SharedSupport/prefix/drive_c/windows/Fonts/

     Windows PC가 없다면: 친구 PC / PC방 / Parallels·UTM 체험판에서 추출.
     없으면 한글이 네모(□)로 표시됩니다.

  ${BOLD}2. 첫 실행${RESET}
     open "$HOME/Applications/Sikarugir/NX Launcher.app"

     macOS가 "확인되지 않은 개발자" 경고를 띄우면:
       → 우클릭 → '열기' → 다시 '열기' 클릭 (이후로는 안 뜸)

문서: https://github.com/dgv7/nx-mac
문제: https://github.com/dgv7/nx-mac/issues

EOF

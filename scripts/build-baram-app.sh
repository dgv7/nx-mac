#!/bin/bash
# build-baram-app.sh — nx-mac v0.1 (바람의나라 전용) 빌더
# 빈 Sikarugir wrapper → Plug 단독 실행 가능한 완성 상태로 자동 설정
# Reference: plan_a_cx24_complete.md (2026-04-24 breakthrough)

set -euo pipefail

# ─────────────────────────── config ───────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

WRAPPER_PATH="${1:-$HOME/Applications/Sikarugir/Baram.app}"
ROUTER_APP_NAME="${ROUTER_APP_NAME:-NX Launcher}"
ROUTER_PATH="$(dirname "$WRAPPER_PATH")/${ROUTER_APP_NAME}.app"
BUNDLE_ID="com.saeroon.nx-launcher"

PLUG_INSTALLER_URL="https://platform.nexon.com/NexonPlug/Install/LocalInstaller/NexonPlug.exe"
PLUG_INSTALLER_LOCAL="$PROJECT_DIR/downloads/NexonPlug.exe"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"

# ─────────────────────────── logging ──────────────────────────
info() { printf "\033[34m[*]\033[0m %s\n" "$*"; }
ok()   { printf "\033[32m[✓]\033[0m %s\n" "$*"; }
warn() { printf "\033[33m[!]\033[0m %s\n" "$*"; }
err()  { printf "\033[31m[✗]\033[0m %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

# ─────────────────────────── steps ────────────────────────────

step1_check_prerequisites() {
  info "[1/10] prerequisites 확인"
  command -v brew >/dev/null || die "Homebrew 필요: https://brew.sh"
  command -v osacompile >/dev/null || die "Xcode CLT 필요: xcode-select --install"
  command -v /usr/libexec/PlistBuddy >/dev/null || die "PlistBuddy 필요"

  if ! command -v winetricks >/dev/null; then
    warn "winetricks 설치"
    brew install winetricks
  fi

  if [ ! -d "/Applications/Sikarugir.app" ]; then
    warn "Sikarugir Creator 설치"
    brew tap Sikarugir-App/sikarugir
    brew install --cask sikarugir
  fi

  if ! /usr/bin/pgrep -q oahd 2>/dev/null; then
    warn "Rosetta 2 설치 시도"
    softwareupdate --install-rosetta --agree-to-license || true
  fi
  ok "prerequisites OK"
}

step2_check_wrapper() {
  info "[2/10] wrapper 확인"
  if [ ! -d "$WRAPPER_PATH" ]; then
    die "Wrapper 없음: $WRAPPER_PATH

Sikarugir Creator로 먼저 만들어주세요:
  1. /Applications/Sikarugir.app 실행
  2. New Blank Wrapper 클릭
  3. Name: Baram
  4. Engine: WS12WineCX24.0.7 (한글 IME 해결분)
  5. OS: Windows 10
  6. Create 누르고 완료되면 이 스크립트 재실행"
  fi
  local version
  version=$("$WRAPPER_PATH/Contents/SharedSupport/wine/bin/wine" --version 2>&1 | head -1 || true)
  info "  엔진: $version"
  if ! echo "$version" | grep -q 'CX 24'; then
    warn "권장 엔진(SikarugirCX 24.0.7) 아님. 한글 IME 조합 버그 재발 가능성."
  fi
  ok "wrapper OK"
}

step3_libinotify_symlinks() {
  info "[3/10] libinotify dylib 심링크 (wine/lib/ + SharedSupport/)"
  local lib="$WRAPPER_PATH/Contents/SharedSupport/wine/lib"
  local ss="$WRAPPER_PATH/Contents/SharedSupport"
  local fw="$WRAPPER_PATH/Contents/Frameworks"
  [ -d "$fw" ] || die "Frameworks 디렉토리 없음: $fw"

  local count=0
  for target in "$lib" "$ss"; do
    for f in "$fw"/*.dylib; do
      [ -e "$f" ] || continue
      ln -sf "$f" "$target/$(basename "$f")" 2>/dev/null && count=$((count+1)) || true
    done
  done
  ok "심링크 $count 개 생성/갱신"
}

step4_dosdevices_abs_path() {
  info "[4/10] dosdevices/c: 절대경로"
  local prefix="$WRAPPER_PATH/Contents/SharedSupport/prefix"
  local c_link="$prefix/dosdevices/c:"
  if [ -L "$c_link" ] && [ "$(readlink "$c_link")" = "../drive_c" ]; then
    rm "$c_link"
    ln -s "$prefix/drive_c" "$c_link"
    ok "상대 → 절대경로 변경"
  else
    ok "이미 절대경로"
  fi
}

step5_install_korean_env() {
  info "[5/10] winetricks 한글 환경 (최초 10~20분 소요 가능)"
  export WINEPREFIX="$WRAPPER_PATH/Contents/SharedSupport/prefix"
  export PATH="$WRAPPER_PATH/Contents/SharedSupport/wine/bin:$PATH"
  local fonts_dir="$WINEPREFIX/drive_c/windows/Fonts"

  # 순서 중요: Win10 → corefonts → cjkfonts → vcrun2019
  if [ ! -f "$fonts_dir/times.ttf" ]; then
    info "  winetricks: win10 + corefonts..."
    winetricks -q win10 corefonts
  else
    info "  corefonts 이미 설치"
  fi

  if [ ! -f "$fonts_dir/sourcehansans.ttc" ]; then
    info "  winetricks: cjkfonts..."
    winetricks -q cjkfonts
  else
    info "  cjkfonts 이미 설치"
  fi

  if [ ! -f "$WINEPREFIX/drive_c/windows/system32/msvcp140.dll" ]; then
    info "  winetricks: vcrun2019..."
    winetricks -q vcrun2019
  else
    info "  vcrun2019 이미 설치"
  fi
  ok "한글 환경 구성 완료"
}

step6_install_plug() {
  info "[6/10] NexonPlug 설치"
  export WINEPREFIX="$WRAPPER_PATH/Contents/SharedSupport/prefix"
  local plug_exe="$WINEPREFIX/drive_c/Nexon/NexonPlug/NexonPlug.exe"

  if [ -f "$plug_exe" ]; then
    ok "이미 설치됨"
    return
  fi

  mkdir -p "$PROJECT_DIR/downloads"
  if [ ! -f "$PLUG_INSTALLER_LOCAL" ]; then
    info "  installer 다운로드 (87MB)..."
    curl -fL "$PLUG_INSTALLER_URL" -o "$PLUG_INSTALLER_LOCAL"
  fi

  info "  wine으로 installer 실행..."
  "$WRAPPER_PATH/Contents/SharedSupport/wine/bin/wine" "$PLUG_INSTALLER_LOCAL" /S || \
    warn "silent 설치 실패 가능 → GUI 창에서 계속 진행"

  # self-update race 방지: 설치 직후 Plug 종료
  pkill -9 -f NexonPlug 2>/dev/null || true
  sleep 2
  ok "NexonPlug 설치 완료"
}

step7_disable_nexon_launcher_service() {
  info "[7/10] Nexon Launcher Windows 서비스 disabled (★ cold-start 50s→7s 핵심)"
  export WINEPREFIX="$WRAPPER_PATH/Contents/SharedSupport/prefix"
  local wine="$WRAPPER_PATH/Contents/SharedSupport/wine/bin/wine"

  "$wine" reg add 'HKLM\SYSTEM\CurrentControlSet\Services\Nexon Launcher' \
    /v Start /t REG_DWORD /d 4 /f >/dev/null 2>&1 || true

  # registry 변경 즉시 flush (wineserver가 메모리에만 들고 있을 수 있음)
  "$WRAPPER_PATH/Contents/SharedSupport/wine/bin/wineserver" -k 2>/dev/null || true
  sleep 1

  ok "Start=0x4 (disabled) — services.exe가 이 서비스 skip"
}

step8_install_exit_watcher() {
  info "[8/10] exit-watcher 배치 (상주 금지 정책)"
  cp "$SCRIPT_DIR/baram-exit-watcher.sh" \
     "$WRAPPER_PATH/Contents/Resources/baram-exit-watcher.sh"
  chmod +x "$WRAPPER_PATH/Contents/Resources/baram-exit-watcher.sh"
  ok "exit-watcher 설치"
}

step9_build_router_app() {
  info "[9/10] Router .app 빌드: ${ROUTER_APP_NAME}.app"
  [ -d "$ROUTER_PATH" ] && rm -rf "$ROUTER_PATH"

  osacompile -o "$ROUTER_PATH" "$SCRIPT_DIR/baram-router.applescript"

  local plist="$ROUTER_PATH/Contents/Info.plist"
  /usr/libexec/PlistBuddy \
    -c "Add :CFBundleURLTypes array" \
    -c "Add :CFBundleURLTypes:0 dict" \
    -c "Add :CFBundleURLTypes:0:CFBundleURLName string 'Nexon Plug Protocol'" \
    -c "Add :CFBundleURLTypes:0:CFBundleTypeRole string Viewer" \
    -c "Add :CFBundleURLTypes:0:LSHandlerRank string Default" \
    -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" \
    -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string nexonplug" \
    -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:1 string ngm" \
    "$plist" 2>/dev/null || warn "URLTypes 이미 존재"

  # osacompile output may lack CFBundleIdentifier — Add first, fall back to Set
  /usr/libexec/PlistBuddy \
    -c "Add :CFBundleIdentifier string $BUNDLE_ID" "$plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$plist"
  /usr/libexec/PlistBuddy \
    -c "Set :CFBundleName '$ROUTER_APP_NAME'" "$plist" 2>/dev/null || true

  # Build + nest splash .app
  local splash_src="$SCRIPT_DIR/nx-splash/build-splash.sh"
  local splash_target="$ROUTER_PATH/Contents/Resources/NX Splash.app"
  if [ -x "$splash_src" ] && command -v swiftc >/dev/null 2>&1; then
    info "  splash 빌드/번들링"
    "$splash_src" "$splash_target" >/dev/null
    ok "  splash: $splash_target"
  else
    warn "  swiftc 또는 build-splash.sh 없음 — splash 생략 (notification fallback으로 동작)"
  fi

  # Ad-hoc re-sign the whole bundle after nesting splash + Info.plist edits
  codesign --force --deep --sign - "$ROUTER_PATH" 2>&1 | tail -2 || true

  # Mac NexonPlug.app이 시스템에 있으면 scheme 경합 가능 → 우리 Router만 핸들러로
  if [ -d "/Library/Application Support/Nexon/Plug/NexonPlug.app" ]; then
    "$LSREGISTER" -u "/Library/Application Support/Nexon/Plug/NexonPlug.app" 2>/dev/null || true
  fi

  "$LSREGISTER" -f "$ROUTER_PATH"
  ok "Router 앱 생성 + splash 번들 + LSF 등록"
}

step10_verify() {
  info "[10/10] 검증 (cold-start 측정)"

  pkill -9 -f 'wine/bin|winedevice|plugplay|services.exe|explorer.exe' 2>/dev/null || true
  pkill -9 -f 'NexonPlug|NexonLauncher|gamer.exe|BaramMedia' 2>/dev/null || true
  pkill -9 -f baram-exit-watcher 2>/dev/null || true
  "$WRAPPER_PATH/Contents/SharedSupport/wine/bin/wineserver" -k9 2>/dev/null || true
  sleep 3

  local T0 t_ui
  T0=$(date +%s)
  open "$ROUTER_PATH"

  while [ $(( $(date +%s) - T0 )) -lt 30 ]; do
    if [ "$(ps auxww | grep 'NexonPlug.exe' | grep -v grep | grep -c 'type=')" -ge 3 ]; then
      break
    fi
    sleep 1
  done
  t_ui=$(( $(date +%s) - T0 ))

  if [ "$t_ui" -le 12 ]; then
    ok "cold-start ${t_ui}s — 정상"
  elif [ "$t_ui" -le 30 ]; then
    warn "cold-start ${t_ui}s — Nexon Launcher 서비스 disabled 재확인 필요"
  else
    warn "Plug UI 30s 안에 안 뜸. 로그: /tmp/baram-url-router.log"
  fi
}

# ─────────────────────────── main ─────────────────────────────
main() {
  echo
  info "nx-mac v0.1 빌더 (바람의나라 전용)"
  info "  Wrapper: $WRAPPER_PATH"
  info "  Router:  $ROUTER_PATH"
  echo

  step1_check_prerequisites
  step2_check_wrapper
  step3_libinotify_symlinks
  step4_dosdevices_abs_path
  step5_install_korean_env
  step6_install_plug
  step7_disable_nexon_launcher_service
  step8_install_exit_watcher
  step9_build_router_app
  step10_verify

  echo
  ok "빌드 완료"
  echo
  cat <<EOF
다음 단계:
  1. MS gulim.ttc (13.5MB)를 본인 Windows PC에서 복사해서 아래 경로에 배치:
     $WRAPPER_PATH/Contents/SharedSupport/prefix/drive_c/windows/Fonts/gulim.ttc

  2. '${ROUTER_APP_NAME}.app' 더블클릭 → 넥슨 로그인 → 게임 시작
     또는 브라우저에서 baram.nexon.com 로그인 → 게임 시작 (URL handler)

  3. 최초 실행 시 Plug이 NGM 및 게임 리소스 자동 다운로드 (18GB, 20~60분)
EOF
}

main "$@"

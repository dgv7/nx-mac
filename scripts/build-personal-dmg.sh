#!/bin/bash
# build-personal-dmg.sh — 개인용 DMG 빌더
#
# ⚠ 결과물 DMG는 본인 사용 전용. 절대 공개 배포 금지.
#   포함되는 자산 중 다음은 재배포 라이선스 없음:
#     - MS gulim.ttc           (Microsoft EULA)
#     - NexonPlug              (Nexon TOS)
#     - 바람의나라 클라이언트  (Nexon TOS)
#     - Sikarugir Wine 엔진    (CrossOver 베이스)
#
#   .gitignore에 dist/ + *.dmg가 포함되어 있어 산출물이 repo로 올라가지 않습니다.
#
# 시나리오: 본인이 셋업한 NX Launcher 환경을 다른 본인 Mac으로 옮기거나 백업.
#
# 사용:
#   ./scripts/build-personal-dmg.sh
#
# 환경 변수:
#   WRAPPER  Baram.app 경로 (default: ~/Applications/Sikarugir/Baram.app)
#   ROUTER   NX Launcher.app 경로 (default: ~/Applications/Sikarugir/NX Launcher.app)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

WRAPPER="${WRAPPER:-$HOME/Applications/Sikarugir/Baram.app}"
ROUTER="${ROUTER:-$HOME/Applications/Sikarugir/NX Launcher.app}"

DIST_DIR="$PROJECT_DIR/dist"
STAGE_DIR="$PROJECT_DIR/build/dmg-stage"
DMG_NAME="NX-Launcher-Personal-$(date +%Y%m%d).dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"
VOLUME_NAME="NX Launcher"

info() { printf "\033[34m[*]\033[0m %s\n" "$*"; }
ok()   { printf "\033[32m[✓]\033[0m %s\n" "$*"; }
warn() { printf "\033[33m[!]\033[0m %s\n" "$*"; }
err()  { printf "\033[31m[x]\033[0m %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

# ─── 1. 사전 검증 ───
[ "$(uname)" = "Darwin" ] || die "macOS 전용"
command -v hdiutil >/dev/null || die "hdiutil 필요"
command -v ditto >/dev/null   || die "ditto 필요"

[ -d "$WRAPPER" ] || die "Wrapper 없음: $WRAPPER
build-baram-app.sh를 먼저 실행해서 환경을 완성하세요."
[ -d "$ROUTER" ]  || die "Router 없음: $ROUTER"

# 개인용 DMG는 gulim.ttc + Plug + 게임이 모두 들어있어야 의미가 있음
GULIM="$WRAPPER/Contents/SharedSupport/prefix/drive_c/windows/Fonts/gulim.ttc"
[ -f "$GULIM" ] || die "gulim.ttc 없음: $GULIM
Windows에서 가져온 gulim.ttc를 wrapper에 배치한 뒤 재실행하세요."

PLUG="$WRAPPER/Contents/SharedSupport/prefix/drive_c/Nexon/NexonPlug/NexonPlug.exe"
[ -f "$PLUG" ] || warn "NexonPlug 없음 — 첫 실행 시 새로 다운로드됩니다."

GAME_DIR="$WRAPPER/Contents/SharedSupport/prefix/drive_c/Nexon/Baram"
if [ ! -d "$GAME_DIR" ]; then
  warn "게임 데이터 없음 — 새 Mac에서 18GB 다시 받아야 합니다."
fi

# ─── 2. 스테이징 ───
info "스테이징 디렉토리 준비"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR" "$DIST_DIR"

# ─── 3. 앱 복사 (메타데이터/심링크 보존) ───
WRAPPER_SIZE=$(du -sh "$WRAPPER" | cut -f1)
info "Baram.app 복사 ($WRAPPER_SIZE — 수 분 소요)"
ditto "$WRAPPER" "$STAGE_DIR/Baram.app"
ok "Baram.app 복사 완료"

info "NX Launcher.app 복사"
ditto "$ROUTER" "$STAGE_DIR/NX Launcher.app"

# ─── 4. Install.command (post-install fixup) ───
info "Install.command 생성"
cat > "$STAGE_DIR/Install.command" <<'INSTALLER'
#!/bin/bash
# DMG 안에서 더블클릭 → ~/Applications/Sikarugir/로 복사 + 경로 fixup
set -e

DEST="$HOME/Applications/Sikarugir"
SRC="$(cd "$(dirname "$0")" && pwd)"

echo
echo "━━━ NX Launcher 개인용 설치 ━━━"
echo
echo "[*] 설치 위치: $DEST"
mkdir -p "$DEST"

echo "[*] Baram.app 복사 (~19GB, 수 분 소요)..."
rm -rf "$DEST/Baram.app"
ditto "$SRC/Baram.app" "$DEST/Baram.app"

echo "[*] NX Launcher.app 복사..."
rm -rf "$DEST/NX Launcher.app"
ditto "$SRC/NX Launcher.app" "$DEST/NX Launcher.app"

# 경로 fixup: dosdevices/c: 를 새 위치 기준 절대경로로 재설정
PREFIX="$DEST/Baram.app/Contents/SharedSupport/prefix"
C_LINK="$PREFIX/dosdevices/c:"
if [ -L "$C_LINK" ]; then
  rm "$C_LINK"
  ln -s "$PREFIX/drive_c" "$C_LINK"
  echo "[✓] dosdevices/c: 절대경로 재설정"
fi

# libinotify 심링크 재설정 (Frameworks → wine/lib + SharedSupport)
FW="$DEST/Baram.app/Contents/Frameworks"
LIB="$DEST/Baram.app/Contents/SharedSupport/wine/lib"
SS="$DEST/Baram.app/Contents/SharedSupport"
if [ -d "$FW" ]; then
  for target in "$LIB" "$SS"; do
    for f in "$FW"/*.dylib; do
      [ -e "$f" ] || continue
      ln -sf "$f" "$target/$(basename "$f")" 2>/dev/null || true
    done
  done
  echo "[✓] libinotify 심링크 재설정"
fi

# Quarantine 속성 제거 (DMG에서 받은 앱은 자동으로 격리됨)
xattr -dr com.apple.quarantine "$DEST/Baram.app" 2>/dev/null || true
xattr -dr com.apple.quarantine "$DEST/NX Launcher.app" 2>/dev/null || true

# LaunchServices 재등록 — nexonplug:// 핸들러 갱신
LSREG="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
"$LSREG" -f "$DEST/NX Launcher.app" 2>/dev/null || true
echo "[✓] URL handler 등록"

echo
echo "[✓] 설치 완료"
echo
echo "    실행:  open '$DEST/NX Launcher.app'"
echo "    또는:  Finder에서 $DEST 더블클릭"
echo
read -n 1 -s -r -p "아무 키나 눌러 종료..."
echo
INSTALLER
chmod +x "$STAGE_DIR/Install.command"

# ─── 5. README.txt ───
cat > "$STAGE_DIR/README.txt" <<'README'
NX Launcher (개인용 DMG)
========================

⚠ 개인 사용 전용. 절대 재배포 금지.
   MS gulim.ttc / NexonPlug / 바람 클라이언트 / CrossOver 베이스 Wine 엔진 포함.

설치 방법
---------
  1. 'Install.command' 더블클릭
     → 보안 경고 시: 우클릭 → '열기' → 다시 '열기'
  2. Terminal 창에 "아무 키나 눌러 종료" 메시지 나오면 완료
  3. ~/Applications/Sikarugir/NX Launcher.app 실행

문제 발생 시
------------
  https://github.com/dgv7/nx-mac/issues
README

# ─── 6. DMG 생성 ───
info "DMG 생성 (압축 — 시간 소요)"
[ -f "$DMG_PATH" ] && rm "$DMG_PATH"

# UDZO: 압축 read-only. 개인 백업/이동용으로 적합.
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDZO \
  -fs HFS+ \
  "$DMG_PATH" >/dev/null

# ─── 7. 정리 ───
rm -rf "$STAGE_DIR"

echo
ok "DMG 생성 완료"
echo "    경로: $DMG_PATH"
echo "    크기: $(du -h "$DMG_PATH" | cut -f1)"
echo
warn "이 DMG는 개인 백업/이동용입니다. 공개 업로드 금지."

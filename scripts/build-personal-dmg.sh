#!/bin/bash
# build-personal-dmg.sh — 개인용 DMG 빌더 (게임 데이터 제외)
#
# 설계:
#   DMG에는 Plug + Wine 엔진 + 한글 폰트(gulim.ttc + cjkfonts) + 한글 환경(vcrun2019 등)만 포함.
#   바람의나라 클라이언트는 첫 실행 시 NexonPlug이 공식 서버에서 최신 버전으로 다운로드.
#   → DMG ~3GB로 슬림화 + 항상 최신 클라이언트 + Nexon 클라이언트 재배포 이슈 0.
#
# ⚠ 결과물 DMG 자체는 본인 사용 전용. 공개 배포 금지.
#   (MS gulim.ttc — Microsoft EULA / Sikarugir CX24 Wine 엔진 — CrossOver 베이스)
#   .gitignore의 dist/ + *.dmg로 산출물이 repo로 올라가지 않습니다.
#
# 시나리오: 본인 셋업을 다른 본인 Mac으로 옮기거나 재설치 백업.
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

# DMG에서 제외할 게임 데이터 (prefix 내부 상대경로)
EXCLUDE_PATHS=(
  "Contents/SharedSupport/prefix/drive_c/Nexon/Baram"
  "Contents/SharedSupport/prefix/drive_c/Nexon/Kingdom of the Winds"
  "Contents/SharedSupport/prefix/drive_c/Nexon/Download"
)

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

# 필수 자산 확인 — 이 셋이 DMG의 핵심
GULIM="$WRAPPER/Contents/SharedSupport/prefix/drive_c/windows/Fonts/gulim.ttc"
[ -f "$GULIM" ] || die "gulim.ttc 없음: $GULIM
Windows에서 가져온 gulim.ttc를 wrapper에 배치한 뒤 재실행하세요."

PLUG="$WRAPPER/Contents/SharedSupport/prefix/drive_c/Nexon/NexonPlug/NexonPlug.exe"
[ -f "$PLUG" ] || die "NexonPlug 없음: $PLUG
build-baram-app.sh의 step6를 먼저 실행해서 Plug을 설치하세요."

# ─── 2. 스테이징 ───
info "스테이징 디렉토리 준비"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR" "$DIST_DIR"

# ─── 3. Wrapper 복사 (APFS clone으로 즉시 + 게임 데이터 삭제) ───
info "Baram.app 복사 (APFS clone)"
# -c: clonefile (APFS 인스턴트 clone, 추가 디스크 사용 0)
# -R: 재귀
# -p: 권한/시간/EA 보존
cp -Rcp "$WRAPPER" "$STAGE_DIR/Baram.app"

info "게임 데이터 제외 (Plug이 첫 실행 시 최신 버전 다운로드)"
SAVED_BYTES=0
for rel in "${EXCLUDE_PATHS[@]}"; do
  target="$STAGE_DIR/Baram.app/$rel"
  if [ -d "$target" ]; then
    size=$(du -sh "$target" | cut -f1)
    rm -rf "$target"
    info "  - 제외: $rel ($size)"
  fi
done
ok "Wrapper 슬림화 완료"

info "NX Launcher.app 복사"
cp -Rcp "$ROUTER" "$STAGE_DIR/NX Launcher.app"

# ─── 4. Install.command (post-install fixup) ───
info "Install.command 생성"
cat > "$STAGE_DIR/Install.command" <<'INSTALLER'
#!/bin/bash
# DMG 안에서 더블클릭 → ~/Applications/Sikarugir/로 복사 + 경로 fixup
# 기존 게임 데이터는 보존 (이미 받아둔 18GB를 다시 받지 않도록)
set -e

DEST="$HOME/Applications/Sikarugir"
SRC="$(cd "$(dirname "$0")" && pwd)"
EXISTING_NEXON="$DEST/Baram.app/Contents/SharedSupport/prefix/drive_c/Nexon"

echo
echo "━━━ NX Launcher 개인용 설치 ━━━"
echo
echo "[*] 설치 위치: $DEST"
mkdir -p "$DEST"

# 기존 게임 데이터 백업 (있으면)
TMP_BACKUP=""
if [ -d "$EXISTING_NEXON/Baram" ] || [ -d "$EXISTING_NEXON/Kingdom of the Winds" ]; then
  TMP_BACKUP="$(mktemp -d)"
  echo "[*] 기존 게임 데이터 임시 보존: $TMP_BACKUP"
  [ -d "$EXISTING_NEXON/Baram" ] && mv "$EXISTING_NEXON/Baram" "$TMP_BACKUP/" && echo "    + Baram"
  [ -d "$EXISTING_NEXON/Kingdom of the Winds" ] && mv "$EXISTING_NEXON/Kingdom of the Winds" "$TMP_BACKUP/" && echo "    + Kingdom of the Winds"
fi

echo "[*] Baram.app 복사..."
rm -rf "$DEST/Baram.app"
ditto "$SRC/Baram.app" "$DEST/Baram.app"

echo "[*] NX Launcher.app 복사..."
rm -rf "$DEST/NX Launcher.app"
ditto "$SRC/NX Launcher.app" "$DEST/NX Launcher.app"

# 게임 데이터 복원
if [ -n "$TMP_BACKUP" ]; then
  echo "[*] 게임 데이터 복원..."
  NEW_NEXON="$DEST/Baram.app/Contents/SharedSupport/prefix/drive_c/Nexon"
  mkdir -p "$NEW_NEXON"
  [ -d "$TMP_BACKUP/Baram" ] && mv "$TMP_BACKUP/Baram" "$NEW_NEXON/" && echo "    + Baram"
  [ -d "$TMP_BACKUP/Kingdom of the Winds" ] && mv "$TMP_BACKUP/Kingdom of the Winds" "$NEW_NEXON/" && echo "    + Kingdom of the Winds"
  rmdir "$TMP_BACKUP" 2>/dev/null || true
  echo "[✓] 게임 데이터 보존 완료 (재다운로드 없음)"
fi

# dosdevices/c: 절대경로 재설정 (다른 Mac에서도 동작)
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
echo
echo "    첫 실행 시 NexonPlug이 게임 클라이언트(~18GB)를 자동 다운로드합니다."
echo
read -n 1 -s -r -p "아무 키나 눌러 종료..."
echo
INSTALLER
chmod +x "$STAGE_DIR/Install.command"

# ─── 5. README.txt ───
cat > "$STAGE_DIR/README.txt" <<'README'
NX Launcher (개인용 DMG)
========================

⚠ 개인 사용 전용. 재배포 금지.
   (MS gulim.ttc / CrossOver 베이스 Wine 엔진 포함)

DMG 내용물
----------
  · NexonPlug + Wine 환경 + 한글 폰트(gulim.ttc + cjkfonts)
  · 게임 클라이언트는 미포함 — 첫 실행 시 Plug이 최신 버전 자동 다운로드

설치
----
  1. 'Install.command' 더블클릭
     → 보안 경고 시: 우클릭 → '열기' → 다시 '열기'
  2. Terminal 창에 "아무 키나 눌러 종료" 메시지 나오면 완료
  3. ~/Applications/Sikarugir/NX Launcher.app 실행
     → 첫 실행 시 NexonPlug이 게임 클라이언트를 다운로드 (~18GB)
     → 기존 설치가 있으면 게임 데이터는 보존됨 (재다운로드 X)

문제 발생 시
------------
  https://github.com/dgv7/nx-mac/issues
README

# ─── 6. DMG 생성 ───
info "DMG 생성 (UDZO 압축)"
[ -f "$DMG_PATH" ] && rm "$DMG_PATH"

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

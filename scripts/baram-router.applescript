-- NX Launcher (nx-mac v0.1 — 바람의나라 전용)
-- Double-click (on run) -> NexonPlug standalone (browser-free, self-login)
-- Browser nexonplug:// URL (on open location) -> legacy web path, same launch logic

on run
	launchBaram("")
end run

on open location this_URL
	launchBaram(this_URL)
end open location

on launchBaram(this_URL)
	-- Splash .app path (nested under this applet's Resources)
	set selfPath to POSIX path of (path to me)
	set splashApp to selfPath & "Contents/Resources/NX Splash.app"

	-- Warm-reuse shortcut: if Plug is already alive, skip splash entirely.
	set plugAlive to false
	try
		do shell script "pgrep -f 'NexonPlug\\.exe' >/dev/null 2>&1 && pgrep -f 'wineserver' >/dev/null 2>&1"
		set plugAlive to true
	end try

	-- Show splash (cold-start path only)
	if not plugAlive then
		try
			-- Reset status file, then fire splash in background.
			do shell script "echo 'booting' > /tmp/nx-launcher-status"
			do shell script "open -a " & quoted form of splashApp
		on error errMsg
			-- Fallback: notification if splash can't launch
			display notification "바람의나라 로딩 중 (약 50초)" with title "NX Launcher" subtitle "Plug 초기화 중"
		end try
	end if

	set logFile to "/tmp/baram-url-router.log"
	set statusFile to "/tmp/nx-launcher-status"
	set wrapperPath to "/Users/eggxoxo/Applications/Sikarugir/Baram.app"
	set wineBin to wrapperPath & "/Contents/SharedSupport/wine/bin"
	set winePrefix to wrapperPath & "/Contents/SharedSupport/prefix"
	set frameworksPath to wrapperPath & "/Contents/Frameworks"
	set libPath to wrapperPath & "/Contents/SharedSupport/wine/lib"
	set sharedSupportPath to wrapperPath & "/Contents/SharedSupport"
	set dosDev to winePrefix & "/dosdevices"
	set driveC to winePrefix & "/drive_c"
	set exitWatcher to wrapperPath & "/Contents/Resources/baram-exit-watcher.sh"

	set plugFlags to " --disable-features=VizDisplayCompositor,UseBrowserCompositor,HardwareMediaKeyHandling --in-process-gpu --disable-gpu-compositing --disable-gpu-rasterization --disable-accelerated-2d-canvas --disable-software-rasterizer --num-raster-threads=1 --disable-gpu-sandbox --no-first-run --disable-component-update --disable-breakpad --disable-sync --disable-translate --disable-default-apps --no-pings --disable-hang-monitor --disable-prompt-on-repost"

	-- URL argv (empty for standalone launch)
	set urlArg to ""
	if this_URL is not "" then
		set urlArg to " " & quoted form of this_URL
	end if

	-- Entry tag for log (standalone vs url-forwarded)
	set entryTag to "standalone"
	if this_URL is not "" then set entryTag to "url"

	set cmd to "set -e; " & ¬
		"export WINEPREFIX=" & quoted form of winePrefix & "; " & ¬
		"export PATH=" & quoted form of wineBin & ":$PATH; " & ¬
		"echo '[' $(date) '] ENTRY=" & entryTag & " URL=' " & quoted form of this_URL & " >> " & quoted form of logFile & "; " & ¬
		"if pgrep -f 'NexonPlug\\.exe' >/dev/null 2>&1 && pgrep -f 'wineserver' >/dev/null 2>&1; then " & ¬
		"echo '[warm-reuse] forwarding to running Plug' >> " & quoted form of logFile & "; " & ¬
		"( nohup " & quoted form of (wineBin & "/wine") & " 'C:\\Nexon\\NexonPlug\\NexonPlug.exe'" & urlArg & plugFlags & " < /dev/null >> " & quoted form of logFile & " 2>&1 & ); " & ¬
		"exit 0; " & ¬
		"fi; " & ¬
		"echo cleanup > " & quoted form of statusFile & "; " & ¬
		"echo '[cold-start] purging prior wine tree' >> " & quoted form of logFile & "; " & ¬
		"pkill -9 -f 'wine/bin|winedevice|plugplay|services.exe|explorer.exe|conhost|svchost' 2>/dev/null || true; " & ¬
		"pkill -9 -f 'NexonPlug|PlugRender|NGM64|NexonLauncher|gamer.exe|BaramMedia|Kingdom of the' 2>/dev/null || true; " & ¬
		"pkill -9 -f baram-exit-watcher 2>/dev/null || true; " & ¬
		quoted form of (wineBin & "/wineserver") & " -k9 2>/dev/null || true; " & ¬
		"for i in 1 2 3 4 5 6 7 8; do pgrep -f wineserver >/dev/null 2>&1 || break; sleep 0.25; done; " & ¬
		"echo symlink > " & quoted form of statusFile & "; " & ¬
		"if [ ! -L " & quoted form of (libPath & "/libinotify.0.dylib") & " ] || [ ! -L " & quoted form of (sharedSupportPath & "/libinotify.0.dylib") & " ]; then " & ¬
		"for f in " & quoted form of frameworksPath & "/*.dylib; do " & ¬
		"[ -e \"$f\" ] || continue; " & ¬
		"base=\"$(basename \"$f\")\"; " & ¬
		"ln -sf \"$f\" " & quoted form of libPath & "/\"$base\" 2>/dev/null || true; " & ¬
		"ln -sf \"$f\" " & quoted form of sharedSupportPath & "/\"$base\" 2>/dev/null || true; " & ¬
		"done; " & ¬
		"fi; " & ¬
		"if [ -L " & quoted form of (dosDev & "/c:") & " ] && [ \"$(readlink " & quoted form of (dosDev & "/c:") & ")\" = \"../drive_c\" ]; then " & ¬
		"rm " & quoted form of (dosDev & "/c:") & "; " & ¬
		"ln -s " & quoted form of driveC & " " & quoted form of (dosDev & "/c:") & "; " & ¬
		"fi; " & ¬
		"echo spawn > " & quoted form of statusFile & "; " & ¬
		"( nohup " & quoted form of (wineBin & "/wine") & " 'C:\\Nexon\\NexonPlug\\NexonPlug.exe'" & urlArg & plugFlags & " < /dev/null >> " & quoted form of logFile & " 2>&1 & ); " & ¬
		"echo waiting > " & quoted form of statusFile & "; " & ¬
		"( nohup " & quoted form of exitWatcher & " < /dev/null >> " & quoted form of logFile & " 2>&1 & )"
	do shell script cmd
end launchBaram

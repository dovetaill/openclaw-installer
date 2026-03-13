!ifndef OPENCLAW_LAYOUT_NSH
!define OPENCLAW_LAYOUT_NSH

!define PRODUCT_NAME "OpenClaw"
!define PRODUCT_PUBLISHER "OpenClaw"
!ifndef PRODUCT_VERSION
!define PRODUCT_VERSION "0.1.0"
!endif
!define PRODUCT_UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\OpenClaw"

!define APP_SUBDIR "app"
!define DATA_SUBDIR "data"
!define BUNDLES_SUBDIR "app\bundles"
!define START_MENU_DIR "$SMPROGRAMS\OpenClaw"
!define DESKTOP_SHORTCUT "$DESKTOP\OpenClaw Launcher.lnk"
!define START_MENU_SHORTCUT "$SMPROGRAMS\OpenClaw\OpenClaw Launcher.lnk"
!define START_MENU_UNINSTALL_SHORTCUT "$SMPROGRAMS\OpenClaw\Uninstall OpenClaw.lnk"

!define LAUNCHER_EXE "OpenClaw Launcher.exe"
!define UNINSTALL_EXE "uninstall.exe"

Var StageDir
Var KeepData
Var FullRemove

!endif

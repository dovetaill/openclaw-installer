!ifndef OPENCLAW_LAYOUT_NSH
!define OPENCLAW_LAYOUT_NSH

!define PRODUCT_NAME "OpenClaw"
!define PRODUCT_PUBLISHER "kitlabs.app"
!ifndef PRODUCT_VERSION
!define PRODUCT_VERSION "0.1.0"
!endif
!ifndef PRODUCT_RUNTIME_VERSION
!define PRODUCT_RUNTIME_VERSION "${PRODUCT_VERSION}"
!endif
!ifndef PRODUCT_RUNTIME_DISPLAY_VERSION
!define PRODUCT_RUNTIME_DISPLAY_VERSION "OpenClaw"
!endif
!ifndef INSTALLER_REPOSITORY_URL
!define INSTALLER_REPOSITORY_URL "https://github.com/kitlabs-app/openclaw-installer"
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

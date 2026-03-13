Unicode true
RequestExecutionLevel user

!include "MUI2.nsh"
!include "FileFunc.nsh"
!include "LogicLib.nsh"
!include "include/layout.nsh"
!include "include/uninstall.nsh"

!ifndef STAGE_DIR
!define STAGE_DIR "payload"
!endif

!ifndef OUTPUT_FILE
!define OUTPUT_FILE "OpenClaw-Setup.exe"
!endif

Name "${PRODUCT_NAME}"
OutFile "${OUTPUT_FILE}"
InstallDir "$LOCALAPPDATA\OpenClaw"
InstallDirRegKey HKCU "${PRODUCT_UNINSTALL_KEY}" "InstallLocation"
ShowInstDetails show
ShowUninstDetails show

!define MUI_ABORTWARNING
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "SimpChinese"

Function .onInit
  StrCpy $StageDir "${STAGE_DIR}"
  StrCpy $KeepData "1"
  StrCpy $FullRemove "0"
FunctionEnd

Section "Install"
  SetOutPath "$INSTDIR"
  CreateDirectory "$INSTDIR"
  CreateDirectory "$INSTDIR\${APP_SUBDIR}"
  CreateDirectory "$INSTDIR\${DATA_SUBDIR}"

  File "${STAGE_DIR}/${LAUNCHER_EXE}"
  File "${STAGE_DIR}/manifest.json"
  SetOutPath "$INSTDIR\${APP_SUBDIR}"
  File /r "${STAGE_DIR}/${APP_SUBDIR}/*.*"
  SetOutPath "$INSTDIR\${DATA_SUBDIR}"
  File /r "${STAGE_DIR}/${DATA_SUBDIR}/*.*"
  SetOutPath "$INSTDIR"

  !insertmacro OpenClaw_WriteUninstaller
  !insertmacro OpenClaw_RegisterUninstall

  CreateDirectory "${START_MENU_DIR}"
  CreateShortCut "${DESKTOP_SHORTCUT}" "$INSTDIR\${LAUNCHER_EXE}"
  CreateShortCut "${START_MENU_SHORTCUT}" "$INSTDIR\${LAUNCHER_EXE}"
  CreateShortCut "${START_MENU_UNINSTALL_SHORTCUT}" "$INSTDIR\${UNINSTALL_EXE}"
SectionEnd

Section "Uninstall"
  MessageBox MB_YESNO|MB_ICONQUESTION "是否同时删除 data 目录中的配置、workspace 与日志？" IDYES full_remove IDNO standard_remove

standard_remove:
  StrCpy $FullRemove "0"
  Goto do_uninstall

full_remove:
  StrCpy $FullRemove "1"

do_uninstall:
  ${If} $FullRemove == "1"
    !insertmacro OpenClaw_PerformFullUninstall
  ${Else}
    !insertmacro OpenClaw_PerformStandardUninstall
  ${EndIf}
SectionEnd

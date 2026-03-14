!ifndef OPENCLAW_UNINSTALL_NSH
!define OPENCLAW_UNINSTALL_NSH

!macro OpenClaw_RegisterUninstall
  WriteRegStr HKCU "${PRODUCT_UNINSTALL_KEY}" "DisplayName" "${PRODUCT_NAME}"
  WriteRegStr HKCU "${PRODUCT_UNINSTALL_KEY}" "DisplayVersion" "${PRODUCT_RUNTIME_VERSION}"
  WriteRegStr HKCU "${PRODUCT_UNINSTALL_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
  WriteRegStr HKCU "${PRODUCT_UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${PRODUCT_UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\${UNINSTALL_EXE}"'
  WriteRegStr HKCU "${PRODUCT_UNINSTALL_KEY}" "QuietUninstallString" '"$INSTDIR\${UNINSTALL_EXE}" /S'
  WriteRegDWORD HKCU "${PRODUCT_UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${PRODUCT_UNINSTALL_KEY}" "NoRepair" 1
!macroend

!macro OpenClaw_WriteUninstaller
  WriteUninstaller "$INSTDIR\${UNINSTALL_EXE}"
!macroend

!macro OpenClaw_PerformStandardUninstall
  Delete "$INSTDIR\${LAUNCHER_EXE}"
  Delete "$INSTDIR\manifest.json"
  Delete "$INSTDIR\${UNINSTALL_EXE}"
  RMDir /r "$INSTDIR\${APP_SUBDIR}"
  Delete "${DESKTOP_SHORTCUT}"
  Delete "${START_MENU_SHORTCUT}"
  Delete "${START_MENU_UNINSTALL_SHORTCUT}"
  RMDir "${START_MENU_DIR}"
  DeleteRegKey HKCU "${PRODUCT_UNINSTALL_KEY}"
!macroend

!macro OpenClaw_PerformFullUninstall
  !insertmacro OpenClaw_PerformStandardUninstall
  RMDir /r "$INSTDIR\${DATA_SUBDIR}"
  RMDir "$INSTDIR"
!macroend

!endif

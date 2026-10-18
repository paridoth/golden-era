; Golden Era's per-user Windows self-extracting launcher.
; Build inputs are supplied by scripts/package-installer.py. This script never
; removes the data directory: saves, settings and the downloaded engine belong
; to start.bat and live outside the versioned application directory.

Unicode true
!include "LogicLib.nsh"
!include "x64.nsh"

!ifndef GE_VERSION
  !error "GE_VERSION is required"
!endif
!ifndef GE_PAYLOAD_DIR
  !error "GE_PAYLOAD_DIR is required"
!endif
!ifndef GE_OUTPUT
  !error "GE_OUTPUT is required"
!endif
!ifndef GE_INSTALLER_SUPPORT
  !error "GE_INSTALLER_SUPPORT is required"
!endif

Name "Golden Era Playtest ${GE_VERSION}"
Caption "Installing Golden Era Playtest ${GE_VERSION}"
OutFile "${GE_OUTPUT}"
InstallDir "$LOCALAPPDATA\GoldenEraPlaytest\app\${GE_VERSION}"
RequestExecutionLevel user
ManifestDPIAware true
ManifestSupportedOS all
SetCompressor /FINAL zlib
CRCCheck on
ShowInstDetails hide
AutoCloseWindow true
BrandingText "Golden Era - Factory Playtest"

; Opening the EXE shows extraction progress, then launches the game. /S performs
; the same installation without opening windows or starting the game.
SilentInstall normal
Page instfiles

Var InstallerMutex

Function .onInit
  SetShellVarContext current
  ${IfNot} ${RunningX64}
    MessageBox MB_OK|MB_ICONSTOP "Golden Era Playtest requires 64-bit Windows." /SD IDOK
    SetErrorLevel 1
    Abort
  ${EndIf}

  ; Hold this handle for the installer's lifetime. Windows releases it even if
  ; extraction is cancelled. A second installer must not write the same files.
  System::Call 'kernel32::CreateMutexW(p 0, i 0, w "Local\GoldenEraPlaytestInstaller") p .r0 ?e'
  Pop $1
  StrCpy $InstallerMutex $0
  ${If} $InstallerMutex = 0
    MessageBox MB_OK|MB_ICONSTOP "Golden Era could not prepare its installer. Please run it again." /SD IDOK
    SetErrorLevel 1
    Abort
  ${EndIf}
  ${If} $1 = 183
    MessageBox MB_OK|MB_ICONINFORMATION "Golden Era is already being installed. Please wait for that installation to finish." /SD IDOK
    SetErrorLevel 1
    Abort
  ${EndIf}
FunctionEnd

Section "Install"
  ; Always use this fixed per-user application location, including for /S.
  ; Extraction never targets the parent directory containing the player's data.
  StrCpy $INSTDIR "$LOCALAPPDATA\GoldenEraPlaytest\app\${GE_VERSION}"
  SetOverwrite on
  ClearErrors
  SetOutPath "$INSTDIR"
  IfErrors install_failed
  File /r "${GE_PAYLOAD_DIR}/*"
  IfErrors install_failed
  SetOutPath "$INSTDIR\installer-support"
  IfErrors install_failed
  File /r "${GE_INSTALLER_SUPPORT}/*"
  IfErrors install_failed

  ; Shell links accept a batch file as their target. Passing the path directly
  ; avoids constructing a cmd.exe command from a Windows user-profile path.
  SetOutPath "$INSTDIR"
  IfErrors install_failed
  ClearErrors
  CreateShortCut "$DESKTOP\Golden Era Playtest.lnk" "$INSTDIR\start.bat"
  IfErrors 0 +2
    DetailPrint "The desktop shortcut could not be created."
  ClearErrors
  CreateShortCut "$SMPROGRAMS\Golden Era Playtest.lnk" "$INSTDIR\start.bat"
  IfErrors 0 +2
    DetailPrint "The Start Menu shortcut could not be created."
  ClearErrors
  SetErrorLevel 0
  Goto install_done

install_failed:
  SetErrorLevel 1
  MessageBox MB_OK|MB_ICONSTOP "Golden Era could not finish extracting its game files. Please run this installer again. Your saves and settings are kept separately." /SD IDOK
  Abort
install_done:
SectionEnd

Function .onInstSuccess
  IfSilent launch_done
  ClearErrors
  ExecShell "open" "$INSTDIR\start.bat" "" SW_SHOWNORMAL
  IfErrors 0 launch_done
    MessageBox MB_OK|MB_ICONINFORMATION "Golden Era is installed. Open the Golden Era Playtest shortcut on your desktop or in the Start Menu to play." /SD IDOK
launch_done:
FunctionEnd

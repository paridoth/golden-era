; Golden Era's per-user Windows self-extracting launcher.
; Build inputs are supplied by scripts/package-installer.py. This script never
; removes the data directory: saves, settings and the downloaded engine belong
; to start.bat and live outside the versioned application directory. Only older
; app\<version> folders are removed after a successful install.

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
  Call RemoveOldVersions
  SetErrorLevel 0
  Goto install_done

install_failed:
  SetErrorLevel 1
  MessageBox MB_OK|MB_ICONSTOP "Golden Era could not finish extracting its game files. Please run this installer again. Your saves and settings are kept separately." /SD IDOK
  Abort
install_done:
SectionEnd

; Older app\<version> folders are only game files; saves live in the parent
; folder. A folder is removed only when it has the launcher and game, holds no
; worlds or settings, and can be renamed, which Windows refuses while the old
; version has files open. Nothing is removed while the game is running.
Function RemoveOldVersions
  StrCpy $5 "$LOCALAPPDATA\GoldenEraPlaytest"
  ${If} ${FileExists} "$5\engine-5.17.0\bin\luanti.exe"
    ClearErrors
    FileOpen $4 "$5\engine-5.17.0\bin\luanti.exe" a
    ${If} ${Errors}
      DetailPrint "Golden Era is running; older versions are kept for now."
      Return
    ${EndIf}
    FileClose $4
  ${EndIf}
  FindFirst $0 $1 "$5\app\*"
  ${DoWhile} $1 != ""
    StrCpy $2 "$5\app\$1"
    StrCpy $3 $1 10
    ${If} $3 == ".removing-"
      ; Left over from an earlier removal that could not finish.
      RMDir /r "$2"
    ${ElseIf} $1 != "."
    ${AndIf} $1 != ".."
    ${AndIf} $1 != "${GE_VERSION}"
    ${AndIf} ${FileExists} "$2\start.bat"
    ${AndIf} ${FileExists} "$2\games\golden_era_playtest\game.conf"
    ${AndIfNot} ${FileExists} "$2\worlds\*.*"
    ${AndIfNot} ${FileExists} "$2\settings.conf"
      ClearErrors
      Rename "$2" "$5\app\.removing-$1"
      ${IfNot} ${Errors}
        RMDir /r "$5\app\.removing-$1"
        DetailPrint "Removed the older Golden Era $1 files."
      ${EndIf}
    ${EndIf}
    FindNext $0 $1
  ${Loop}
  FindClose $0
  ClearErrors
FunctionEnd

Function .onInstSuccess
  IfSilent launch_done
  ClearErrors
  ExecShell "open" "$INSTDIR\start.bat" "" SW_SHOWNORMAL
  IfErrors 0 launch_done
    MessageBox MB_OK|MB_ICONINFORMATION "Golden Era is installed. Open the Golden Era Playtest shortcut on your desktop or in the Start Menu to play." /SD IDOK
launch_done:
FunctionEnd

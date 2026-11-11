Reimagined UI - add-on for Deus Ex
UI concept after Tanit Mesa's "Deus Ex 2000: Reimagined - UX/UI" (ArtStation).
=================================================================

HOW TO BUILD AND PLAY
  1. Run Mods\ReimaginedUI\Build_ReimaginedUI.cmd   (compiles ReimaginedUI.u)
  2. Run System\Play_ReimaginedUI.cmd               (starts AE with the new UI)
  GMDX_AE.exe / GMDX_AE.cmd still launch plain AE, untouched.

LAYOUT
  Source\ReimaginedUI\Classes\   UnrealScript (edit here)
  Source\ReimaginedUI\Textures\  8-bit PCX textures imported at build time
  System\ReimaginedUI.u          compiled add-on (created by the build)
  System\DeusEx.ini              copy of AE's ini; Root= points at RIRootWindow
  System\RIBuild.ini             ini used only for compiling
  Art\                           original key art and logo
  AE_Source_Reference\           read-only export of AE's code, for reference

HOW IT WORKS
  RIRootWindow replaces the root window and remaps AE screens to new ones in
  PushWindow. Reimagined screens subclass AE's, so AE behaviour is kept.
  Done: main menu (RIMenuMain, RIMenuButton). Next: settings, load game,
  persona screens, HUD.

NOTES
  Saves are shared with AE (SavePath ..\GMDX_AE\Save) and so is User.ini.
  Display/renderer settings changed while playing with this launcher are
  stored in Mods\ReimaginedUI\System\DeusEx.ini, separate from AE's.

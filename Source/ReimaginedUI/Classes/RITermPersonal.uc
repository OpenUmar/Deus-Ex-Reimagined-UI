//=============================================================================
// RITermPersonal
// AE's NetworkTerminalPersonal (personal computers) with the rebuilt code-notes panel. Everything
// else is AE's; RITerminalSkin restyles the screens (Sleek only).
//=============================================================================
class RITermPersonal extends NetworkTerminalPersonal;

function AddNotesWindow()
{
	Class'RIBase'.static.AddTerminalNotes(Self);
}

defaultproperties
{
}

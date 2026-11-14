//=============================================================================
// RITermPublic
// AE's NetworkTerminalPublic (public terminals) with the rebuilt code-notes panel. Everything
// else is AE's; RITerminalSkin restyles the screens (Sleek only).
//=============================================================================
class RITermPublic extends NetworkTerminalPublic;

function AddNotesWindow()
{
	Class'RIBase'.static.AddTerminalNotes(Self);
}

defaultproperties
{
}

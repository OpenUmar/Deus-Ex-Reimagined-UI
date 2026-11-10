//=============================================================================
// RITermATM
// AE's ATMWindow (ATMs) with the rebuilt code-notes panel. Everything
// else is AE's; RITerminalSkin restyles the screens (Sleek only).
//=============================================================================
class RITermATM extends ATMWindow;

function AddNotesWindow()
{
	Class'RINotesPanel'.static.AddTerminalNotes(Self);
}

defaultproperties
{
}

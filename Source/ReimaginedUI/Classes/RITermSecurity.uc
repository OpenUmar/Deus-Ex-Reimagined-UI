//=============================================================================
// RITermSecurity
// AE's NetworkTerminalSecurity (security computers) with the rebuilt code-notes panel. Everything
// else is AE's; RITerminalSkin restyles the screens (Sleek only).
//=============================================================================
class RITermSecurity extends NetworkTerminalSecurity;

function AddNotesWindow()
{
	Class'RIBase'.static.AddTerminalNotes(Self);
}

defaultproperties
{
}

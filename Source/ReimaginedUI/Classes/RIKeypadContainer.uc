//=============================================================================
// RIKeypadContainer
// AE's keypad holder (keypad + code notes side by side), with the rebuilt
// keypad inside it. Keypad.uc keeps its HUDKeypadContainerWindow pointer, so
// every AE path (autofill from notes, instant hack success, Escape) still works.
//=============================================================================
class RIKeypadContainer extends HUDKeypadContainerWindow;

function InitKeypadWindow(Keypad owner, DeusExPlayer user, bool instantSuccess)
{
	keypadwindow = HUDKeypadWindow(NewChild(Class'RIKeypadWindow'));
	if (keypadwindow != None)
	{
		keypadWindow.keypadOwner = owner;
		keypadWindow.player = user;
		keypadWindow.bInstantSuccess = instantSuccess;
		keypadWindow.InitData();
		keypadWindow.StyleChanged();
	}
}

// AE's conditions for showing the notes, unchanged; the panel is the rebuilt
// one, and the keypad and notes are centred together as a pair
function AddNotesWindow(DeusExPlayer player, DeusExNote codeNote, bool fakeDisplay)
{
	local float s, rw, rh, nw, gap, x0;

	if (!player.bShowCodeNotes)
		return;
	if (fakeDisplay && (!player.bHardcoreMode || player.bGMDXDebug) && (player.iNoKeypadCheese == 0))
		codeNote = None;
	if (((codeNote == None) && (!player.bHardcoreMode || player.bGMDXDebug) && (player.iNoKeypadCheese == 0))
		|| !player.HasAnyNotes() || (keypadWindow == None) || keypadWindow.bInstantSuccess)
		return;

	rw = GetRootWindow().width;
	rh = GetRootWindow().height;
	s = rh / 1080.0;
	nw = 600 * s;
	gap = 28 * s;
	x0 = (rw - (keypadwindow.width + gap + nw)) * 0.5;
	keypadwindow.SetWindowAlignments(HALIGN_Left, VALIGN_Center, x0);

	winNotes = HUDKeypadNotesWindow(NewChild(Class'RINotesPanel'));
	winNotes.SetEditable(false);
	winNotes.SetPos(x0 + keypadwindow.width + gap, (rh - keypadwindow.height) * 0.5);
	winNotes.Resize(nw, keypadwindow.height);
	winNotes.AddNote(codeNote);
	winNotes.CreateNotesList();
	winNotes.StyleChanged();
	winNotes.SetParentWindow(self);
}

defaultproperties
{
}

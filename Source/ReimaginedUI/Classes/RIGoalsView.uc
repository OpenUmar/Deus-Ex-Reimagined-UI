//=============================================================================
// RIGoalsView
// Goals / Notes, drawn to the Goals artboard in amber.
// Goals: primary and secondary, completed ones struck through (optional).
// Notes: pinned first, then the rest, filtered like AE (regular / mine /
// markers). Add a note or a map marker, pin, delete (press twice), and edit
// by typing (your own notes, or any note when editing is allowed).
// Everything goes through DeusExPlayer's note / marker functions, the same
// ones AE's screen calls.
//=============================================================================
class RIGoalsView extends RIPersonaView;

const MAXNOTES = 128;

// Hot-region ids
const HOT_NOTE      = 300;   // + note index
const HOT_ADD       = 40;
const HOT_MARKER    = 41;
const HOT_PIN       = 42;
const HOT_DELETE    = 43;
const HOT_EDIT      = 44;
const HOT_COMPLETED = 60;
const HOT_ONSCREEN  = 61;
const HOT_FREGULAR  = 62;
const HOT_FMINE     = 63;
const HOT_FMARKERS  = 64;
const HOT_SHOWMARK  = 65;
const HOT_ALLOWEDIT = 66;

var DeusExNote Notes[128];
var int   NumNotes;
var int   NoteSel;
var bool  bEditing;
var bool  bFreshEdit;         // a new note: the first key replaces its placeholder
var bool  bDeleteArmed;
var float ArmT;
var float NoteScroll, NoteScrollTarget, NotesH;

var localized string GoalsTitle, NotesTitle, PrimaryLabel, SecondaryLabel, NoGoalsLabel, CompletedTag;
var localized string ShowCompletedLabel, OnScreenLabel;
var localized string AddLabel, MarkerLabel, PinLabel, UnpinLabel, DeleteLabel, ConfirmDeleteLabel, EditLabel, DoneLabel;
var localized string FilterLabel, FRegular, FMine, FMarkers, ShowMarkersLabel, AllowEditLabel;
var localized string SrcPinned, SrcMarker, SrcMine, SrcGame;
var localized string NewNoteText, NoNotesLabel, HintText;

function PersonaScreenGoals Goals()
{
	return PersonaScreenGoals(Screen);
}

function ScreenAttached()
{
	ActiveTab = TAB_GOALS;
	Class'RIPersonaView'.default.JournalLast = TAB_GOALS;
	NoteSel = -1;
	RebuildNotes();
}

// ----------------------------------------------------------------------
// Notes
// ----------------------------------------------------------------------

function bool NoteShown(DeusExNote N)
{
	if (NB(N, "bHidden"))
		return False;
	// Note filters, pins and markers are base features (GMDX AE); without
	// them every note shows, as in the original game
	if (!Extras())
		return True;
	if (!PB("bShowRegularNotes") && !N.bUserNote)
		return False;
	if (!PB("bShowUserNotes") && N.bUserNote && !NB(N, "bMarkerNote"))
		return False;
	if (!PB("bShowMarkerNotes") && N.bUserNote && NB(N, "bMarkerNote"))
		return False;
	return True;
}

function bool Extras()
{
	return Class'RIBase'.static.Has("NoteExtras");
}

function bool PB(string N)
{
	return Class'RIUtil'.static.PBool(Player, N);
}

function bool NB(DeusExNote N, string P)
{
	return Class'RIUtil'.static.PBool(N, P);
}

function RebuildNotes()
{
	local DeusExNote N, Keep;
	local int pass;

	if ((NoteSel >= 0) && (NoteSel < NumNotes))
		Keep = Notes[NoteSel];
	NumNotes = 0;
	for (pass = 0; pass < 2; pass++)
		for (N = Player.FirstNote; (N != None) && (NumNotes < MAXNOTES); N = N.next)
			if (NoteShown(N) && (NB(N, "bPinned") == (pass == 0)))
				Notes[NumNotes++] = N;

	NoteSel = -1;
	if (Keep != None)
		for (pass = 0; pass < NumNotes; pass++)
			if (Notes[pass] == Keep)
				NoteSel = pass;
	if (NoteSel < 0)
		bEditing = False;
}

function DeusExNote CurNote()
{
	if ((NoteSel < 0) || (NoteSel >= NumNotes))
		return None;
	return Notes[NoteSel];
}

function bool CanEdit(DeusExNote N)
{
	return (N != None) && (N.bUserNote || PB("bAllowNoteEditing"));
}

function SelectNote(int i)
{
	if (i == NoteSel)
		return;
	FinishEdit();
	NoteSel = i;
	bDeleteArmed = False;
	PlaySound(Sound'Menu_Focus', 0.2);
}

function AddNote(bool bMarker)
{
	local DeusExNote N;

	FinishEdit();
	N = Player.AddNote(NewNoteText, True);
	if (N == None)
		return;
	if (bMarker)
		Class'RIBase'.static.MakeMarker(Player, N);
	PlaySound(Sound'Menu_Press', 0.25);
	RebuildNotes();
	for (NoteSel = 0; NoteSel < NumNotes; NoteSel++)
		if (Notes[NoteSel] == N)
			break;
	if (NoteSel >= NumNotes)
		NoteSel = -1;
	bEditing = (NoteSel >= 0);
	bFreshEdit = bEditing;
	NoteScrollTarget = 0;
}

function TogglePin()
{
	local DeusExNote N;

	N = CurNote();
	if (N == None)
		return;
	FinishEdit();
	Class'RIBase'.static.PinNote(Player, N);
	PlaySound(Sound'Menu_Press', 0.25);
	RebuildNotes();
}

function DeleteCurrent()
{
	local DeusExNote N;

	N = CurNote();
	if (N == None)
		return;
	// First press arms, second press (within 3s) deletes; off if AE's confirm is off
	if (Player.bConfirmNoteDeletes && !bDeleteArmed)
	{
		bDeleteArmed = True;
		ArmT = 3.0;
		PlaySound(Sound'Menu_Focus', 0.25);
		return;
	}
	bDeleteArmed = False;
	bEditing = False;
	Player.DeleteNote(N);
	PlaySound(Sound'Menu_Press', 0.25);
	NoteSel = -1;
	RebuildNotes();
}

function StartEdit()
{
	if (!CanEdit(CurNote()))
		return;
	bEditing = True;
	bFreshEdit = False;
	PlaySound(Sound'Menu_Press', 0.2);
}

function FinishEdit()
{
	bEditing = False;
	bFreshEdit = False;
}

function TypeChar(string C)
{
	local DeusExNote N;

	N = CurNote();
	if (!bEditing || (N == None) || (Asc(C) < 32))
		return;
	if (bFreshEdit)
	{
		N.text = "";
		bFreshEdit = False;
	}
	if (Len(N.text) < 1000)
		N.text = N.text $ C;
}

function Backspace(bool bWord)
{
	local DeusExNote N;

	N = CurNote();
	if (!bEditing || (N == None))
		return;
	if (bFreshEdit)
	{
		N.text = "";
		bFreshEdit = False;
		return;
	}
	if (bWord)
	{
		while ((N.text != "") && (Right(N.text, 1) == " "))
			N.text = Left(N.text, Len(N.text) - 1);
		while ((N.text != "") && (Right(N.text, 1) != " "))
			N.text = Left(N.text, Len(N.text) - 1);
	}
	else if (N.text != "")
		N.text = Left(N.text, Len(N.text) - 1);
}

// ----------------------------------------------------------------------
// Toggles
// ----------------------------------------------------------------------

function bool ShowCompleted()
{
	if (Goals().chkShowCompletedGoals != None)
		return Goals().chkShowCompletedGoals.GetToggle();
	return Goals().bDisplayCompletedGoals;
}

function Toggle(int Id)
{
	local bool b;

	PlaySound(Sound'Menu_Press', 0.2);
	if (Id == HOT_COMPLETED)
	{
		b = !ShowCompleted();
		Goals().bDisplayCompletedGoals = b;
		if (Goals().chkShowCompletedGoals != None)
			Goals().chkShowCompletedGoals.SetToggle(b);
	}
	else if (Id == HOT_ONSCREEN)
	{
		Class'RIBase'.static.SetGoalsOnScreen(Goals(), Player, !PB("bShowGoalsOnScreen"));
	}
	else if (Id == HOT_FREGULAR)
		Class'RIUtil'.static.PToggle(Player, "bShowRegularNotes");
	else if (Id == HOT_FMINE)
		Class'RIUtil'.static.PToggle(Player, "bShowUserNotes");
	else if (Id == HOT_FMARKERS)
		Class'RIUtil'.static.PToggle(Player, "bShowMarkerNotes");
	else if (Id == HOT_SHOWMARK)
		Class'RIBase'.static.SetShowMarkers(Player, !PB("bShowMarkers"));
	else if (Id == HOT_ALLOWEDIT)
		Class'RIUtil'.static.PToggle(Player, "bAllowNoteEditing");
	RebuildNotes();
}

// ----------------------------------------------------------------------
// Input
// ----------------------------------------------------------------------

function bool PageKey(EInputKey key, bool bRepeat)
{
	if (bEditing)
	{
		if ((key == IK_Enter) || (key == IK_Escape))
		{
			FinishEdit();
			PlaySound(Sound'Menu_Press', 0.2);
			return True;
		}
		if (key == IK_Backspace)
		{
			Backspace(IsKeyDown(IK_Ctrl));
			return True;
		}
		// Letters arrive through KeyPressed; let the key event pass
		return (key == IK_Up) || (key == IK_Down) || (key == IK_Delete);
	}
	if ((key == IK_Up) || (key == IK_Down))
	{
		if (NumNotes > 0)
		{
			if (key == IK_Up)
				SelectNote(Max(0, NoteSel - 1));
			else
				SelectNote(Min(NumNotes - 1, NoteSel + 1));
		}
		return True;
	}
	if (key == IK_MouseWheelUp)
	{
		NoteScrollTarget -= 120 * S;
		return True;
	}
	if (key == IK_MouseWheelDown)
	{
		NoteScrollTarget += 120 * S;
		return True;
	}
	if ((key == IK_Enter) && !bRepeat)
	{
		StartEdit();
		return True;
	}
	if (key == IK_Delete)
	{
		DeleteCurrent();
		return True;
	}
	return False;
}

function bool IsTyping()
{
	return bEditing;
}

event bool VirtualKeyPressed(EInputKey key, bool bRepeat)
{
	// While typing, Escape ends the edit instead of closing the screen
	if (bEditing && (key == IK_Escape))
	{
		FinishEdit();
		return True;
	}
	return Super.VirtualKeyPressed(key, bRepeat);
}

event bool KeyPressed(string key)
{
	if (!bEditing || IsKeyDown(IK_Ctrl) || IsKeyDown(IK_Alt))
		return False;
	TypeChar(key);
	return True;
}

function PageClick(int Id, EInputKey button, int numClicks)
{
	if (button != IK_LeftMouse)
		return;
	if (Id >= HOT_NOTE)
	{
		if ((numClicks >= 2) && (Id - HOT_NOTE == NoteSel))
			StartEdit();
		else
			SelectNote(Id - HOT_NOTE);
	}
	else if (Id == HOT_ADD)
		AddNote(False);
	else if (Id == HOT_MARKER)
		AddNote(True);
	else if (Id == HOT_PIN)
		TogglePin();
	else if (Id == HOT_DELETE)
		DeleteCurrent();
	else if (Id == HOT_EDIT)
	{
		if (bEditing)
			FinishEdit();
		else
			StartEdit();
	}
	else if ((Id >= HOT_COMPLETED) && (Id <= HOT_ALLOWEDIT))
		Toggle(Id);
	else if (bEditing)
		FinishEdit();
}

function PageTick(float deltaSeconds)
{
	local float maxS;

	if (bDeleteArmed)
	{
		ArmT -= deltaSeconds;
		if (ArmT <= 0)
			bDeleteArmed = False;
	}
	maxS = FMax(0, NotesH);
	NoteScrollTarget = FClamp(NoteScrollTarget, 0, maxS);
	NoteScroll += (NoteScrollTarget - NoteScroll) * FMin(1.0, deltaSeconds * 14.0);
}

// ----------------------------------------------------------------------
// Drawing
// ----------------------------------------------------------------------

function DrawToggleRow(GC gc, float X, float Y, string L, bool bOn, int Id, float a)
{
	local float tw;
	local bool bHot;

	bHot = (HoverId == Id);
	Class'RISkin'.static.Box2(gc, X, Y + 6 * S, 18 * S, 18 * S, AEdge(a));
	if (bOn)
		Fill(gc, X + 4 * S, Y + 10 * S, 10 * S, 10 * S, AAcc(a));
	tw = Class'RIText'.static.Width(Class'RIFontBody', L, 0.72);
	Class'RIText'.static.DrawIn(gc, Class'RIFontBody', X + 28 * S, Y, tw, 30 * S, L,
		Class'RIUtil'.static.Mix(C3(220, 200, 155, a), C3(255, 255, 255, a), int(bHot)), 0, 0.72);
	AddHot(Id, X, Y, tw + 30 * S, 30 * S);
}

function float DrawGoalsOfType(GC gc, float X, float Y, float W, bool bPrimary, float a)
{
	local DeusExGoal G;
	local float h, tw;
	local bool bAny, bDone;
	local string T;

	if (bPrimary)
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', X, Y, Caps(PrimaryLabel), AAcc(a), 0.72);
	else
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', X, Y, Caps(SecondaryLabel), AAcc(a), 0.72);
	Y += 30 * S;

	for (G = Player.FirstGoal; G != None; G = G.next)
	{
		if (G.bPrimaryGoal != bPrimary)
			continue;
		bDone = G.bCompleted;
		if (bDone && !ShowCompleted())
			continue;
		bAny = True;
		T = G.text;
		h = Class'RIText'.static.DrawWrapped(None, Class'RIFontBody', 0, 0, W - 60 * S, T, C3(0, 0, 0, 0), 0.82, 1.35) + 20 * S;
		h = FMax(46 * S, h);
		Fill(gc, X, Y, W, h, C3(30, 25, 11, 0.55 * a));
		Class'RIText'.static.Box(gc, X, Y, W, h, C3(90, 75, 36, a));
		Class'RIText'.static.Box(gc, X + 16 * S, Y + 14 * S, 16 * S, 16 * S, AHi(a));
		if (bDone)
		{
			Fill(gc, X + 19 * S, Y + 17 * S, 10 * S, 10 * S, AAcc(a));
			Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', X + 46 * S, Y + 10 * S, W - 60 * S, T, C3(150, 132, 92, a), 0.82, 1.35);
			tw = FMin(W - 60 * S, Class'RIText'.static.Width(Class'RIFontBody', T, 0.82));
			Class'RIText'.static.HLine(gc, X + 46 * S, Y + 22 * S, tw, C3(150, 132, 92, a));
		}
		else
			Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', X + 46 * S, Y + 10 * S, W - 60 * S, T, ATxt(a), 0.82, 1.35);
		Y += h + 8 * S;
	}
	if (!bAny)
	{
		Class'RIText'.static.Draw(gc, Class'RIFontBody', X + 16 * S, Y + 4 * S, NoGoalsLabel, ALbl(a), 0.8);
		Y += 40 * S;
	}
	return Y + 12 * S;
}

function DrawPage(GC gc, float a)
{
	local float gx, gy, gw, nx, ny, nw, y, h, top, bottom, st, bx, tw, blink, gb, fs, bw;
	local int i;
	local DeusExNote N;
	local string T, Src;
	local bool bSel, bHot;

	// ---- Goals (left) ----
	// ---- Goals (left) ----
	gx = OX + 140 * S;
	gy = 170 * S;
	gw = 820 * S;
	gb = 860 * S;
	if (VPlus())
	{
		// in the left frame
		gx = OX + 404 * S;
		gw = 568 * S;
		y = 184 * S;
		gb = 888 * S;
	}
	else
	{
		Heading(gc, gx, gy, gw, GoalsTitle, a);
		y = gy + 64 * S;
	}
	st = gc.PushGC();
	gc.Intersect(gx - 4 * S, y, gw + 8 * S, gb - y);
	y = DrawGoalsOfType(gc, gx, y, gw, True, a);
	y = DrawGoalsOfType(gc, gx, y, gw, False, a);
	gc.PopGC(st);
	DrawToggleRow(gc, gx, 900 * S, ShowCompletedLabel, ShowCompleted(), HOT_COMPLETED, a);
	if (VPlus())
	{
		if (Class'RIBase'.static.Has("GoalsOnScreen"))
			DrawToggleRow(gc, gx + 290 * S, 900 * S, OnScreenLabel, PB("bShowGoalsOnScreen"), HOT_ONSCREEN, a);
	}
	else
	{
		if (Class'RIBase'.static.Has("GoalsOnScreen"))
			DrawToggleRow(gc, gx + 400 * S, 900 * S, OnScreenLabel, PB("bShowGoalsOnScreen"), HOT_ONSCREEN, a);
		Class'RIText'.static.VLine(gc, OX + 990 * S, 170 * S, 800 * S, ADim(a));
	}

	// ---- Notes (right) ----
	nx = OX + 1020 * S;
	ny = 170 * S;
	nw = 760 * S;
	fs = 170 * S;
	if (VPlus())
	{
		// title bar, filters and list in the body, add buttons in the lower box
		nx = OX + 1072 * S;
		nw = 446 * S;
		fs = 125 * S;
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', nx, 177 * S, nw, 28 * S, Caps(NotesTitle), ATxt(a), 0, 0.5);
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', OX + 1066 * S, 756 * S, 98 * S, 30 * S, Caps(NotesTitle), ALbl(a), 1, 0.5);
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', OX + 1066 * S, 786 * S, 98 * S, 40 * S, string(NumNotes), ATxt(a), 1, 0.6);
		DrawBtn(gc, OX + 1180 * S, 758 * S, 170 * S, 38 * S, AddLabel, True, HoverId == HOT_ADD, True, a);
		AddHot(HOT_ADD, OX + 1180 * S, 758 * S, 170 * S, 38 * S);
		if (Extras())
		{
			DrawBtn(gc, OX + 1358 * S, 758 * S, 170 * S, 38 * S, MarkerLabel, True, HoverId == HOT_MARKER, False, a);
			AddHot(HOT_MARKER, OX + 1358 * S, 758 * S, 170 * S, 38 * S);
		}
		y = 224 * S;
	}
	else
	{
		Heading(gc, nx, ny, nw, NotesTitle, a);
		bx = nx + nw;
		bx -= 190 * S;
		if (Extras())
		{
			DrawBtn(gc, bx, ny, 190 * S, 40 * S, MarkerLabel, True, HoverId == HOT_MARKER, False, a);
			AddHot(HOT_MARKER, bx, ny, 190 * S, 40 * S);
		}
		bx -= 200 * S;
		DrawBtn(gc, bx, ny, 190 * S, 40 * S, AddLabel, True, HoverId == HOT_ADD, True, a);
		AddHot(HOT_ADD, bx, ny, 190 * S, 40 * S);
		y = ny + 60 * S;
	}

	// Filters (base feature)
	if (Extras())
	{
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', nx, y + 6 * S, Caps(FilterLabel), ALbl(a), 0.66);
		tw = Class'RIText'.static.Width(Class'RIFontSmall', Caps(FilterLabel), 0.66) + 18 * S;
		DrawToggleRow(gc, nx + tw, y, FRegular, PB("bShowRegularNotes"), HOT_FREGULAR, a);
		DrawToggleRow(gc, nx + tw + fs, y, FMine, PB("bShowUserNotes"), HOT_FMINE, a);
		DrawToggleRow(gc, nx + tw + fs * 1.76, y, FMarkers, PB("bShowMarkerNotes"), HOT_FMARKERS, a);
	}

	// List
	top = y + 44 * S;
	bottom = 830 * S;
	if (VPlus())
		bottom = 652 * S;
	st = gc.PushGC();
	gc.Intersect(nx - 4 * S, top, nw + 8 * S, bottom - top);
	y = top - NoteScroll;
	for (i = 0; i < NumNotes; i++)
	{
		N = Notes[i];
		bSel = (i == NoteSel);
		bHot = (HoverId == HOT_NOTE + i);
		T = Class'RIConView'.static.Lines(N.text);
		if (bSel && bEditing && bFreshEdit)
			T = N.text;
		if (NB(N, "bPinned"))
			Src = SrcPinned;
		else if (NB(N, "bMarkerNote"))
			Src = SrcMarker;
		else if (N.bUserNote)
			Src = SrcMine;
		else
			Src = SrcGame;
		h = 44 * S + Class'RIText'.static.DrawWrapped(None, Class'RIFontBody', 0, 0, nw - 32 * S, T, C3(0, 0, 0, 0), 0.78, 1.35);
		if ((y + h > top) && (y < bottom))
		{
			Fill(gc, nx, y, nw, h, C3(30, 25, 11, 0.55 * a));
			if (bSel)
				SelRow(gc, nx, y, nw, h, a);
			else if (bHot)
				Class'RIText'.static.Box(gc, nx, y, nw, h, AEdge(a));
			else
				Class'RIText'.static.Box(gc, nx, y, nw, h, C3(90, 75, 36, a));
			Class'RIText'.static.Draw(gc, Class'RIFontSmall', nx + 16 * S, y + 10 * S, Caps(Src), Class'RIUtil'.static.Mix(ALbl(a), AAcc(a), int(NB(N, "bPinned"))), 0.62);
			Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', nx + 16 * S, y + 32 * S, nw - 32 * S, T, ATxt(a), 0.78, 1.35);
			if (bSel && bEditing)
			{
				blink = 0.5 + 0.5 * Sin(Age * 6.0);
				Fill(gc, nx + nw - 18 * S, y + 8 * S, 1.5, h - 16 * S, C3(255 * blink, 232 * blink, 150 * blink, a));
				Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', nx + nw * 0.5, y + 6 * S, nw * 0.5 - 28 * S, 22 * S, "EDITING", AHi(a), 2, 0.6);
			}
			AddHot(HOT_NOTE + i, nx, FMax(y, top), nw, FMin(y + h, bottom) - FMax(y, top));
		}
		y += h + 8 * S;
	}
	if (NumNotes == 0)
		Class'RIText'.static.Draw(gc, Class'RIFontBody', nx + 16 * S, top + 10 * S, NoNotesLabel, ALbl(a), 0.8);
	gc.PopGC(st);
	NotesH = (y + NoteScroll) - top - (bottom - top);

	// Actions for the selected note
	y = 850 * S;
	bw = 150 * S;
	if (VPlus())
	{
		y = 806 * S;
		bw = 112 * S;
	}
	N = CurNote();
	if (N != None)
	{
		bx = nx;
		if (VPlus())
			bx = OX + 1180 * S;
		if (Extras())
		{
			if (NB(N, "bPinned"))
				DrawBtn(gc, bx, y, bw, 38 * S, UnpinLabel, True, HoverId == HOT_PIN, False, a);
			else
				DrawBtn(gc, bx, y, bw, 38 * S, PinLabel, True, HoverId == HOT_PIN, False, a);
			AddHot(HOT_PIN, bx, y, bw, 38 * S);
			bx += bw + 8 * S;
		}
		if (bEditing)
			DrawBtn(gc, bx, y, bw, 38 * S, DoneLabel, True, HoverId == HOT_EDIT, True, a);
		else
			DrawBtn(gc, bx, y, bw, 38 * S, EditLabel, CanEdit(N), HoverId == HOT_EDIT, False, a);
		AddHot(HOT_EDIT, bx, y, bw, 38 * S);
		bx += bw + 8 * S;
		if (bDeleteArmed)
			DrawBtn(gc, bx, y, bw, 38 * S, ConfirmDeleteLabel, True, True, True, a);
		else
			DrawBtn(gc, bx, y, bw, 38 * S, DeleteLabel, True, HoverId == HOT_DELETE, False, a);
		AddHot(HOT_DELETE, bx, y, bw, 38 * S);
	}
	if (VPlus())
	{
		if (Extras())
		{
			DrawToggleRow(gc, nx, 672 * S, ShowMarkersLabel, PB("bShowMarkers"), HOT_SHOWMARK, a);
			DrawToggleRow(gc, nx + 220 * S, 672 * S, AllowEditLabel, PB("bAllowNoteEditing"), HOT_ALLOWEDIT, a);
		}
		return;
	}
	if (Extras())
	{
		DrawToggleRow(gc, nx, 910 * S, ShowMarkersLabel, PB("bShowMarkers"), HOT_SHOWMARK, a);
		DrawToggleRow(gc, nx + 260 * S, 910 * S, AllowEditLabel, PB("bAllowNoteEditing"), HOT_ALLOWEDIT, a);
	}

	Class'RIText'.static.Draw(gc, Class'RIFontSmall', OX + 140 * S, FY + FH + 22 * S, HintText, ALbl(a * 0.8), 0.7);
}

defaultproperties
{
     GoalsTitle="Goals"
     NotesTitle="Notes"
     PrimaryLabel="Primary"
     SecondaryLabel="Secondary"
     NoGoalsLabel="None at the moment."
     ShowCompletedLabel="Show completed goals"
     OnScreenLabel="Show goals on HUD"
     AddLabel="Add note"
     MarkerLabel="Add marker"
     PinLabel="Pin"
     UnpinLabel="Unpin"
     DeleteLabel="Delete"
     ConfirmDeleteLabel="Delete? Again"
     EditLabel="Edit"
     DoneLabel="Done"
     FilterLabel="Show"
     FRegular="Game"
     FMine="Mine"
     FMarkers="Markers"
     ShowMarkersLabel="Markers on map"
     AllowEditLabel="Edit any note"
     SrcPinned="Pinned"
     SrcMarker="Map marker"
     SrcMine="Your note"
     SrcGame="Recorded"
     NewNoteText="New note"
     NoNotesLabel="No notes."
     HintText="UP / DOWN select a note     ENTER or double-click edit     DEL delete     ESC close"
     bHideScreen=True
}

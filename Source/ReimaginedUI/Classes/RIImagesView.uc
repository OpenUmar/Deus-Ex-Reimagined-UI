//=============================================================================
// RIImagesView
// Journal > Images, in the original gold. Left: every image picked up, with
// a thumbnail and its note count ("New" until viewed). Right: the image,
// upscaled, with the player's notes pinned where they were placed. Notes
// are added, edited and deleted here: Add note, then click the image where
// it should go and type; click a note to select it, double-click (or Enter)
// to edit it, Delete to remove it. Notes are AE's own (DataVaultImageNote),
// so they show on AE's page too and are saved with the game.
//=============================================================================
class RIImagesView extends RIPersonaView;

const HOT_ROW     = 100;    // + row
const HOT_NOTES   = 50;
const HOT_ADD     = 52;
const HOT_DEL     = 53;
const HOT_IMAGE   = 54;
const HOT_NOTE    = 200;    // + note index

var DataVaultImage Img[64];
var int   NumImg, Sel;
var float DescAge;
var bool  bShowNotes;
var bool  bPlacing;          // Add note: the next click on the image places it
var bool  bEditing;          // typing into NoteSel
var DataVaultImageNote NoteSel;
var float ImgX, ImgY, ImgK;  // image on screen: left, top, scale
var float Blink;
var float ListScroll, ListScrollTarget, ListMax, ListTop, ListBottom, ListRight;

var localized string ImagesTitle, NewLabel, NotesLabel, NoNotesLabel, NoneLabel, ShowNotesLabel, EditLabel, HintText;
var localized string AddNoteLabel, DeleteNoteLabel, PlaceHint, EditHint, NewNoteText;

function ScreenAttached()
{
	local DataVaultImage I;

	ActiveTab = TAB_IMAGES;
	Class'RIPersonaView'.default.JournalLast = TAB_IMAGES;
	bShowNotes = True;
	NumImg = 0;
	for (I = Player.FirstImage; (I != None) && (NumImg < 64); I = I.nextImage)
		Img[NumImg++] = I;
	Sel = -1;
	if (NumImg > 0)
		SelectRow(0);
}

function SelectRow(int i)
{
	if ((i < 0) || (i >= NumImg) || (i == Sel))
		return;
	FinishEdit();
	bPlacing = False;
	NoteSel = None;
	Sel = i;
	DescAge = 0;
	Img[i].bPlayerViewedImage = True;
}

function int CountNotes(DataVaultImage I)
{
	local DataVaultImageNote N;
	local int c;

	for (N = I.firstNote; N != None; N = N.nextNote)
		c++;
	return c;
}

function PageClick(int Id, EInputKey button, int numClicks)
{
	if (button != IK_LeftMouse)
		return;
	if ((Id >= HOT_ROW) && (Id < HOT_ROW + 64))
	{
		SelectRow(Id - HOT_ROW);
		PlaySound(Sound'Menu_Press', 0.2);
	}
	else if (Id == HOT_NOTES)
	{
		bShowNotes = !bShowNotes;
		PlaySound(Sound'Menu_Press', 0.2);
	}
	else if (Id == HOT_ADD)
	{
		FinishEdit();
		bPlacing = !bPlacing;
		bShowNotes = True;
		PlaySound(Sound'Menu_Press', 0.2);
	}
	else if (Id == HOT_DEL)
		DeleteSel();
	else if ((Id >= HOT_NOTE) && (Id < HOT_NOTE + 64))
	{
		if (bPlacing)
			return;
		if ((numClicks >= 2) && (NoteAt(Id - HOT_NOTE) == NoteSel))
			StartEdit();
		else
		{
			FinishEdit();
			NoteSel = NoteAt(Id - HOT_NOTE);
			PlaySound(Sound'Menu_Press', 0.2);
		}
	}
	else if (Id == HOT_IMAGE)
	{
		if (bPlacing)
			PlaceNote(LastMouseX, LastMouseY);
		else
		{
			FinishEdit();
			NoteSel = None;
		}
	}
}

// ----------------------------------------------------------------------
// Notes
// ----------------------------------------------------------------------

function DataVaultImage CurImage()
{
	if ((Sel < 0) || (Sel >= NumImg))
		return None;
	return Img[Sel];
}

function DataVaultImageNote NoteAt(int Want)
{
	local DataVaultImageNote N;
	local int i;

	if (CurImage() == None)
		return None;
	for (N = CurImage().firstNote; N != None; N = N.nextNote)
	{
		if (i == Want)
			return N;
		i++;
	}
	return None;
}

// A new note where the image was clicked (AE's own note object), then type
function PlaceNote(float MX, float MY)
{
	local DataVaultImageNote N;

	bPlacing = False;
	if ((CurImage() == None) || (ImgK <= 0))
		return;
	N = Player.CreateDataVaultImageNoteObject();
	if (N == None)
		return;
	N.posX = int(FClamp((MX - ImgX) / ImgK, 0, 400));
	N.posY = int(FClamp((MY - ImgY) / ImgK, 0, 400));
	N.noteText = "";
	CurImage().AddNote(N);
	NoteSel = N;
	bEditing = True;
	PlaySound(Sound'Menu_Press', 0.25);
}

function StartEdit()
{
	if (NoteSel == None)
		return;
	bEditing = True;
	PlaySound(Sound'Menu_Press', 0.2);
}

// An empty note is removed when editing ends
function FinishEdit()
{
	if (!bEditing)
		return;
	bEditing = False;
	if ((NoteSel != None) && (NoteSel.noteText == "") && (CurImage() != None))
	{
		CurImage().DeleteNote(NoteSel);
		NoteSel = None;
	}
}

function DeleteSel()
{
	if ((NoteSel == None) || (CurImage() == None))
		return;
	bEditing = False;
	CurImage().DeleteNote(NoteSel);
	NoteSel = None;
	PlaySound(Sound'Menu_Press', 0.25);
}

function bool IsTyping()
{
	return bEditing || bPlacing;
}

event bool VirtualKeyPressed(EInputKey key, bool bRepeat)
{
	// While typing, Escape ends the edit instead of closing the screen
	if ((bEditing || bPlacing) && (key == IK_Escape))
	{
		bPlacing = False;
		FinishEdit();
		return True;
	}
	return Super.VirtualKeyPressed(key, bRepeat);
}

event bool KeyPressed(string key)
{
	if (!bEditing || (NoteSel == None) || IsKeyDown(IK_Ctrl) || IsKeyDown(IK_Alt))
		return False;
	if ((Len(key) == 1) && (Asc(key) >= 32) && (Len(NoteSel.noteText) < 120))
		NoteSel.noteText = NoteSel.noteText $ key;
	Blink = 0;
	return True;
}

function bool PageKey(EInputKey key, bool bRepeat)
{
	if (bEditing)
	{
		if (key == IK_Enter)
		{
			FinishEdit();
			PlaySound(Sound'Menu_Press', 0.2);
			return True;
		}
		if ((key == IK_Backspace) && (NoteSel != None))
		{
			NoteSel.noteText = Left(NoteSel.noteText, Max(0, Len(NoteSel.noteText) - 1));
			Blink = 0;
			return True;
		}
		// Letters arrive through KeyPressed; let the key event pass
		return (key == IK_Up) || (key == IK_Down) || (key == IK_Delete);
	}
	if ((key == IK_Enter) && !bRepeat && (NoteSel != None))
	{
		StartEdit();
		return True;
	}
	if ((key == IK_Delete) && (NoteSel != None))
	{
		DeleteSel();
		return True;
	}
	if (key == IK_MouseWheelUp)
	{
		ListScrollTarget -= 90 * S;
		return True;
	}
	if (key == IK_MouseWheelDown)
	{
		ListScrollTarget += 90 * S;
		return True;
	}
	if (key == IK_Up)
	{
		SelectRow(Max(0, Sel - 1));
		return True;
	}
	if (key == IK_Down)
	{
		SelectRow(Min(NumImg - 1, Sel + 1));
		return True;
	}
	return False;
}

function PageTick(float deltaSeconds)
{
	DescAge += deltaSeconds;
	Blink += deltaSeconds;
	ListScrollTarget = FClamp(ListScrollTarget, 0, FMax(0, ListMax));
	ListScroll += (ListScrollTarget - ListScroll) * FMin(1.0, deltaSeconds * 14.0);
}

function DrawPage(GC gc, float a)
{
	DrawList(gc, a);
	DrawViewer(gc, a * Class'RIUtil'.static.Phase(DescAge, 0.0, 0.2));
	if (VPlus())
		return;
	Class'RIText'.static.VLine(gc, OX + 640 * S, 170 * S, 790 * S, ADim(a));
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', OX + 140 * S, FY + FH + 22 * S, HintText, ALbl(a * 0.8), 0.7);
}

// The image is 400 x 400, in four textures (AE's PersonaImageWindow layout)
function DrawImage(GC gc, DataVaultImage I, float X, float Y, float k)
{
	gc.SetStyle(DSTY_Normal);
	// each quarter overlaps the next by a pixel so no seam shows when scaled
	if (I.imageTextures[0] != None)
		Class'RIHD'.static.DrawStretched(gc, X, Y, 256 * k + 1, 256 * k + 1, 0, 0, 256, 256, I.imageTextures[0]);
	if (I.imageTextures[1] != None)
		Class'RIHD'.static.DrawStretched(gc, X + 256 * k, Y, 144 * k, 256 * k + 1, 0, 0, 144, 256, I.imageTextures[1]);
	if (I.imageTextures[2] != None)
		Class'RIHD'.static.DrawStretched(gc, X, Y + 256 * k, 256 * k + 1, 144 * k, 0, 0, 256, 144, I.imageTextures[2]);
	if (I.imageTextures[3] != None)
		Class'RIHD'.static.DrawStretched(gc, X + 256 * k, Y + 256 * k, 144 * k, 144 * k, 0, 0, 144, 144, I.imageTextures[3]);
}

function DrawList(GC gc, float a)
{
	local float x, y, w, rh, sh, kh;
	local int i, st, nn;
	local bool bSel, bHot;
	local string Sub;

	x = OX + 140 * S;
	w = 470 * S;
	ListTop = 236 * S;
	ListBottom = 960 * S;
	rh = 84 * S;
	if (VPlus())
	{
		// the list in the right frame's body (the picture gets the big left frame)
		x = OX + 1068 * S;
		w = 456 * S;
		ListTop = 220 * S;
		ListBottom = 654 * S;
		rh = 70 * S;
	}
	else
		Heading(gc, x, 170 * S, w, ImagesTitle, a);
	ListRight = x + w + 20 * S;
	st = gc.PushGC();
	gc.Intersect(x - 4 * S, ListTop, w + 8 * S, ListBottom - ListTop);
	y = ListTop - ListScroll;
	for (i = 0; i < NumImg; i++)
	{
		bSel = (i == Sel);
		bHot = (HoverId == HOT_ROW + i);
		if (bSel)
			SelRow(gc, x, y, w, rh, a);
		else if (bHot)
			Class'RIText'.static.Box(gc, x, y, w, rh, AEdge(a));
		else
			Class'RIText'.static.HLine(gc, x + 8 * S, y + rh, w - 16 * S, C3(60, 50, 24, a));
		// Thumbnail
		gc.SetTileColor(C3(255, 255, 255, a));
		DrawImage(gc, Img[i], x + 10 * S, y + 8 * S, (rh - 16 * S) / 400.0);
		Class'RIText'.static.Box(gc, x + 10 * S, y + 8 * S, rh - 16 * S, rh - 16 * S, C3(90, 75, 36, a));
		Class'RIText'.static.DrawIn(gc, Class'RIFontBody', x + rh + 8 * S, y + 10 * S, w - rh - 20 * S, 30 * S,
			Class'RIText'.static.Fit(Class'RIFontBody', Img[i].imageDescription, w - rh - 20 * S, 0.78),
			Class'RIUtil'.static.Mix(ATxt(a), C3(255, 255, 255, a), int(bSel)), 0, 0.78);
		nn = CountNotes(Img[i]);
		if (nn == 0)
			Sub = NoNotesLabel;
		else
			Sub = string(nn) @ NotesLabel;
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x + rh + 8 * S, y + 44 * S, w - rh - 20 * S, 24 * S, Caps(Sub), ALbl(a), 0, 0.6);
		if (!Img[i].bPlayerViewedImage)
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x, y + 44 * S, w - 12 * S, 24 * S, Caps(NewLabel), AHi(a), 2, 0.6);
		if ((y + rh > ListTop) && (y < ListBottom))
			AddHot(HOT_ROW + i, x, FMax(y, ListTop), w, FMin(y + rh, ListBottom) - FMax(y, ListTop));
		y += rh + 6 * S;
	}
	gc.PopGC(st);
	ListMax = FMax(0, (y + ListScroll - ListTop) - (ListBottom - ListTop));
	if (ListMax > 1)
	{
		sh = ListBottom - ListTop;
		kh = FMax(30 * S, sh * sh / (sh + ListMax));
		Fill(gc, x + w + 8 * S, ListTop, 2 * S, sh, C3(50, 42, 20, a));
		Fill(gc, x + w + 8 * S, ListTop + (sh - kh) * (ListScroll / ListMax), 2 * S, kh, AAcc(a));
	}
	if (NumImg == 0)
		Class'RIText'.static.Draw(gc, Class'RIFontBody', x, ListTop, NoneLabel, ALbl(a), 0.8);
}

function DrawViewer(GC gc, float a)
{
	local float x, y, w, k, ix, iy, isz, nx, ny, tw, bw, cx;
	local int NoteIx;
	local DataVaultImage I;
	local DataVaultImageNote N;
	local string T;

	x = OX + 670 * S;
	w = 1110 * S;
	y = 170 * S;
	if ((Sel < 0) || (Sel >= NumImg))
		return;
	I = Img[Sel];
	if (VPlus())
	{
		// name in the title bar, floor in the footer; the picture fills the left frame
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', OX + 1072 * S, 177 * S, 446 * S, 28 * S, Caps(Class'RIText'.static.Fit(Class'RIFontHead', I.imageDescription, 446 * S, 0.5)), ATxt(a), 0, 0.5);
		if (I.floorDescription != "")
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', OX + 1072 * S, 670 * S, 446 * S, 30 * S, Caps(I.floorDescription), ALbl(a), 0, 0.54);
		isz = 568 * S;
		ix = OX + 404 * S;
		iy = 186 * S;
	}
	else
	{
		Class'RIText'.static.Draw(gc, Class'RIFontTitle', x + (1 - a) * 8 * S, y, Caps(Class'RIText'.static.Fit(Class'RIFontTitle', I.imageDescription, w, 0.44)), ATxt(a), 0.44);
		if (I.floorDescription != "")
			Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y + 48 * S, Caps(I.floorDescription), ALbl(a), 0.66);
		// Image, square, as large as fits
		isz = FMin(w, 960 * S - 250 * S);
		ix = x + (w - isz) * 0.5;
		iy = 250 * S;
	}
	k = isz / 400.0;
	CGlow(gc, ix - 40 * S, iy - 30 * S, isz + 80 * S, isz + 60 * S, C3(30, 25, 11, a));
	gc.SetTileColor(C3(255, 255, 255, a));
	DrawImage(gc, I, ix, iy, k);
	Class'RISkin'.static.Box2(gc, ix, iy, isz, isz, AEdge(a));

	ImgX = ix;
	ImgY = iy;
	ImgK = k;
	AddHot(HOT_IMAGE, ix, iy, isz, isz);

	// Notes, pinned where the player put them; the selected one lit, the one
	// being typed into with a caret
	if (bShowNotes)
	{
		NoteIx = 0;
		for (N = I.firstNote; N != None; N = N.nextNote)
		{
			nx = ix + N.posX * k;
			ny = iy + N.posY * k;
			T = N.noteText;
			if ((T == "") && !(bEditing && (N == NoteSel)))
				T = NewNoteText;
			T = Class'RIText'.static.Fit(Class'RIFontBody', T, 320 * S, 0.7);
			tw = FMax(40 * S, Class'RIText'.static.Width(Class'RIFontBody', T, 0.7));
			Fill(gc, nx - 5 * S, ny - 5 * S, 10 * S, 10 * S, AHi(a));
			Fill(gc, nx + 12 * S, ny - 14 * S, tw + 26 * S, 30 * S, C3(20, 15, 6, 0.92 * a));
			if (N == NoteSel)
				Class'RISkin'.static.Box2(gc, nx + 12 * S, ny - 14 * S, tw + 26 * S, 30 * S, AHi(a));
			else
				Class'RIText'.static.Box(gc, nx + 12 * S, ny - 14 * S, tw + 26 * S, 30 * S, AEdge(a));
			Class'RIText'.static.DrawIn(gc, Class'RIFontBody', nx + 22 * S, ny - 14 * S, tw, 30 * S, T, C3(255, 241, 194, a), 0, 0.7);
			if (bEditing && (N == NoteSel) && (int(Blink * 2.0) % 2 == 0))
				Fill(gc, nx + 22 * S + Class'RIText'.static.Width(Class'RIFontBody', T, 0.7) + 2 * S, ny - 8 * S, 2 * S, 18 * S, AHi(a));
			AddHot(HOT_NOTE + NoteIx, nx - 8 * S, ny - 14 * S, tw + 46 * S, 30 * S);
			NoteIx++;
		}
	}

	// Controls: Show notes, then Add note / Delete note (Vanilla+: the lower box)
	y = iy + isz + 18 * S;
	cx = ix;
	if (VPlus())
	{
		y = 760 * S;
		cx = OX + 1180 * S;
	}
	Class'RISkin'.static.Box2(gc, cx, y + 6 * S, 18 * S, 18 * S, AEdge(a));
	if (bShowNotes)
		Fill(gc, cx + 4 * S, y + 10 * S, 10 * S, 10 * S, AAcc(a));
	tw = Class'RIText'.static.Width(Class'RIFontBody', ShowNotesLabel, 0.72);
	Class'RIText'.static.DrawIn(gc, Class'RIFontBody', cx + 28 * S, y, tw, 30 * S, ShowNotesLabel,
		Class'RIUtil'.static.Mix(C3(220, 200, 155, a), C3(255, 255, 255, a), int(HoverId == HOT_NOTES)), 0, 0.72);
	AddHot(HOT_NOTES, cx, y, tw + 30 * S, 30 * S);

	if (VPlus())
	{
		bw = 170 * S;
		DrawBtn(gc, OX + 1180 * S, 806 * S, bw, 38 * S, AddNoteLabel, True, HoverId == HOT_ADD, bPlacing, a);
		AddHot(HOT_ADD, OX + 1180 * S, 806 * S, bw, 38 * S);
		DrawBtn(gc, OX + 1358 * S, 806 * S, bw, 38 * S, DeleteNoteLabel, NoteSel != None, HoverId == HOT_DEL, False, a);
		if (NoteSel != None)
			AddHot(HOT_DEL, OX + 1358 * S, 806 * S, bw, 38 * S);
		if (bPlacing)
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', ix, iy + isz + 14 * S, isz, 24 * S, Caps(PlaceHint), AHi(a), 1, 0.56);
		else if (bEditing)
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', ix, iy + isz + 14 * S, isz, 24 * S, Caps(EditHint), AHi(a), 1, 0.56);
		return;
	}
	bw = 180 * S;
	DrawBtn(gc, ix + isz - bw, y - 4 * S, bw, 38 * S, AddNoteLabel, True, HoverId == HOT_ADD, bPlacing, a);
	AddHot(HOT_ADD, ix + isz - bw, y - 4 * S, bw, 38 * S);
	DrawBtn(gc, ix + isz - bw * 2 - 12 * S, y - 4 * S, bw, 38 * S, DeleteNoteLabel, NoteSel != None, HoverId == HOT_DEL, False, a);
	if (NoteSel != None)
		AddHot(HOT_DEL, ix + isz - bw * 2 - 12 * S, y - 4 * S, bw, 38 * S);

	if (bPlacing)
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', ix, iy - 30 * S, isz, 24 * S, Caps(PlaceHint), AHi(a), 1, 0.6);
	else if (bEditing)
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', ix, iy - 30 * S, isz, 24 * S, Caps(EditHint), AHi(a), 1, 0.6);
}

defaultproperties
{
     ImagesTitle="Images"
     NewLabel="New"
     NotesLabel="notes"
     NoNotesLabel="No notes"
     NoneLabel="No images yet."
     ShowNotesLabel="Show notes"
     EditLabel=""
     AddNoteLabel="Add note"
     DeleteNoteLabel="Delete note"
     PlaceHint="Click the image where the note should go  -  Esc to cancel"
     EditHint="Type the note  -  Enter to finish"
     NewNoteText="(empty note)"
     HintText="CLICK select     DOUBLE-CLICK a note to edit     DEL delete note     WHEEL scroll     ESC close"
     bHideScreen=True
}

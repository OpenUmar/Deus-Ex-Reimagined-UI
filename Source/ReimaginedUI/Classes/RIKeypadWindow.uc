//=============================================================================
// RIKeypadWindow
// AE's keypad (all of SARGE's logic: number-pad / phone layout, < and C keys,
// digit display, No Keypad Cheese, instant hack success, autofill) drawn
// natively for the rebuilt UI, sized in 1080p pixels:
//   title row, a code readout with one slot per digit, a status line
//   (ENTER CODE / ACCESS GRANTED / ACCESS DENIED), a 3 x 4 grid of keys and
//   a key-hint row, in the persona gold. Sleek style only for now.
// AE's own text window is kept (it still holds the state) but hidden.
//=============================================================================
class RIKeypadWindow extends HUDKeypadWindow;

var float UIS;           // UI units per 1080p pixel
var float PW, PH;        // panel size, 1080p pixels
var float Age;           // seconds open (drives the cursor blink and the rise-in)
var float ResultAge;     // seconds since the code was judged
var bool  bWasWait;

var localized string TitleLabel, LblEnter, LblGranted, LblDenied, LblBypass;
var localized string HintErase, HintClear, HintConfirm, HintClose;

// Vanilla+: the original keypad's housing (HUDKeypadBorder: the rounded case
// with its handle on top and feet below) is drawn round the panel, so the
// content moves down by this much and the window grows by VPGrow
function float CaseOY()
{
	if (Class'RIVP'.static.On())
		return 26;
	return 0;
}

function float VPGrow()
{
	if (Class'RIVP'.static.On())
		return 44;
	return 0;
}

// The case's frame is off-centre in its art (26 texels in on the left, 4 on
// the right), so the window is this much wider and the content moves right
// by the same amount: it then sits centred inside the frame
function float CaseOX()
{
	if (Class'RIVP'.static.On())
		return 22;
	return 0;
}

function Measure()
{
	UIS = GetRootWindow().height / 1080.0;
	if (UIS <= 0)
		UIS = 0.5;
}

event InitWindow()
{
	Super.InitWindow();
	Measure();
	SetSize((PW + CaseOX()) * UIS, (PH + VPGrow()) * UIS);
	PlaceButtons();
}

function CreateKeypadButtons()
{
	local int i;

	Measure();
	for (i = 0; i < 12; i++)
	{
		btnKeys[i] = HUDKeypadButton(NewChild(Class'RIKeypadButton'));
		btnKeys[i].num = i;     // 0-8 are 1-9, then *, 0, # (IndexToString)
		btnKeys[i].StyleChanged();
	}
	PlaceButtons();
}

function PlaceButtons()
{
	local int i, col, row;
	local float kw, kh, gap, gx, gy;

	kw = 100;
	kh = 78;
	gap = 12;
	gx = CaseOX() + (PW - (kw * 3 + gap * 2)) * 0.5;
	gy = 204 + CaseOY();
	for (i = 0; i < 12; i++)
	{
		if (btnKeys[i] != None)
		{
			row = i / 3;
			col = i - row * 3;
			btnKeys[i].SetSize(kw * UIS, kh * UIS);
			btnKeys[i].SetPos((gx + col * (kw + gap)) * UIS, (gy + row * (kh + gap)) * UIS);
		}
	}
}

// AE's text readout holds the state but isn't drawn (this window draws it)
function CreateInputTextWindow()
{
	Super.CreateInputTextWindow();
	winText.Hide();
}

function Tick(float deltaTime)
{
	Super.Tick(deltaTime);
	Age += deltaTime;
	if (bWait && !bWasWait)
		ResultAge = 0;
	bWasWait = bWait;
	ResultAge += deltaTime;
}

// The verdict after a code is entered: AE keeps it in jumpOut; the original
// keypad only says it in its text line
function bool Granted()
{
	if (Class'RIUtil'.static.PHas(Self, "jumpOut"))
		return Class'RIUtil'.static.PBool(Self, "jumpOut");
	return (winText != None) && (winText.GetText() == msgAccessGranted);
}

function Color StatusCol(float a)
{
	// Vanilla+: the original keypad's pure green / red verdicts
	if (bWait && Class'RIVP'.static.On())
	{
		if (Granted())
			return Class'RIUtil'.static.Raw(60 * a, 255 * a, 90 * a);
		return Class'RIUtil'.static.Raw(255 * a, 50 * a, 40 * a);
	}
	if (bWait && Granted())
		return Class'RIUtil'.static.Raw(110 * a, 225 * a, 140 * a);
	if (bWait)
		return Class'RIUtil'.static.Raw(235 * a, 92 * a, 70 * a);
	return Class'RIVP'.static.Lbl(a);
}

// Everything but the keys (they draw themselves on top)
function DrawBackground(GC gc)
{
	local float s, ts, w, h, rise, dx, dy, dw, dh, slot, sx, a, oy, ox, fw;
	local Texture TB;
	local int i, count;
	local string ch, kStatus, kHints;
	local Color cDig, cLine;
	local bool bBlink;

	Class'RITheme'.static.SetMode(2);
	s  = UIS;
	ts = s * 2.0;
	w  = PW * s;
	h  = (PH + VPGrow()) * s;
	oy = CaseOY() * s;
	ox = CaseOX() * s;
	fw = w + ox;        // the whole window (w is the content's width)
	rise = Class'RIUtil'.static.EaseOut(FClamp(Age / 0.22, 0, 1));
	a = 0.4 + 0.6 * rise;

	// --- panel
	gc.SetStyle(DSTY_Modulated);
	gc.DrawStretchedTexture(-60 * s, -60 * s, fw + 120 * s, h + 120 * s, 0, 0, 256, 64, Texture'ReimaginedUI.UI.RI_ShadeC');
	if (!Class'RIVP'.static.On())
	{
		Class'RIVP'.static.Dim(gc, 0, 0, w, h);
		Class'RIVP'.static.Dim(gc, 0, 0, w, h);
	}
	if (Class'RIVP'.static.On())
	{
		// Vanilla+: the original keypad case over a dark fill (its frame
		// runs 26..412 x 34..624 of the 416 x 648 art, in HD texels)
		// the dark body only inside the case's frame (26..412 x 34..624 of 416 x 648)
		Class'RIVP'.static.Dim(gc, fw * 28 / 416, h * 36 / 648, fw * 382 / 416, h * 586 / 648);
		Class'RIVP'.static.Dim(gc, fw * 28 / 416, h * 36 / 648, fw * 382 / 416, h * 586 / 648);
		Class'RISkin'.static.FillC(gc, fw * 28 / 416, h * 36 / 648, fw * 382 / 416, h * 586 / 648, Class'RIUtil'.static.Col(14 * a, 13 * a, 11 * a));
		TB = Texture'DeusExUI.UserInterface.HUDKeypadBorder';
		gc.SetStyle(DSTY_Translucent);
		gc.SetTileColor(Class'RIVP'.static.Acc(a));
		Class'RIHD'.static.DrawStretched(gc, 0, 0, fw, h, 0, 0, TB.USize * 416.0 / 512.0, TB.VSize * 648.0 / 1024.0, TB);
	}
	else
	{
		Class'RISkin'.static.FillC(gc, 0, 0, w, h, Class'RIUtil'.static.Col(12 * a, 10 * a, 4 * a));
		Class'RIText'.static.Box(gc, 0, 0, w, h, Class'RIUtil'.static.Col(126 * a, 105 * a, 50 * a));
		Class'RISkin'.static.FillC(gc, 0, 0, 120 * s, 3 * s, Class'RIVP'.static.Acc(a));
	}

	// --- title row
	Class'RIText'.static.Draw(gc, Class'RIFontHead', ox + 30 * s, oy + 26 * s, Caps(TitleLabel), Class'RIUtil'.static.Col(255 * a, 241 * a, 194 * a), 0.62 * ts);
	if ((keypadOwner != None) && (player != None) && (Class'RIUtil'.static.PInt(player, "iNoKeypadCheese") < 3))
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', ox, oy + 24 * s, w - 30 * s, 20 * s,
			Len(keypadOwner.validCode) $ "-DIGIT", Class'RIVP'.static.Lbl(a), 2, 0.8 * ts);

	// --- code readout
	dx = ox + 30 * s;
	dy = oy + 62 * s;
	dw = w - 60 * s;
	dh = 92 * s;
	Class'RIVP'.static.Dim(gc, dx, dy, dw, dh);
	Class'RIVP'.static.Dim(gc, dx, dy, dw, dh);
	Class'RIText'.static.Box(gc, dx, dy, dw, dh, Class'RIUtil'.static.Col(90 * a, 75 * a, 36 * a));
	if (bWait)
	{
		// the box lights in the verdict's colour, fading over half a second
		Class'RIText'.static.Box(gc, dx, dy, dw, dh, StatusCol(FMax(0.35, 1.0 - ResultAge * 1.4)));
		Class'RISkin'.static.GlowC(gc, dx, dy, dw, dh, 18 * s, StatusCol(0.18 * FMax(0, 1.0 - ResultAge * 2.0)));
	}

	count = Len(inputCode);
	if ((keypadOwner != None) && (player != None) && (Class'RIUtil'.static.PInt(player, "iNoKeypadCheese") < 3))
		count = Max(count, Len(keypadOwner.validCode));
	bBlink = (int(Age * 2.4) & 1) == 0;

	if (count == 0)
	{
		// nothing to show yet (code length hidden): a lone blinking cursor
		if (bBlink && !bWait)
			Class'RISkin'.static.FillC(gc, dx + dw * 0.5 - 14 * s, dy + 64 * s, 28 * s, 3 * s, Class'RIVP'.static.Acc(a));
	}
	else
	{
		slot = FMin(40 * s, (dw - 24 * s) / count);
		sx = dx + (dw - slot * count) * 0.5;
		if (bWait)
			cDig = StatusCol(1);
		else
			cDig = Class'RIUtil'.static.Col(255 * a, 241 * a, 194 * a);
		for (i = 0; i < count; i++)
		{
			ch = Mid(inputCode, i, 1);
			if (ch != "")
			{
				if (!Class'RIUtil'.static.PBool(Self, "bDigitDisplay"))
					ch = "*";
				Class'RIText'.static.DrawIn(gc, Class'RIFontTitle', sx + i * slot, dy + 8 * s, slot, 60 * s, ch, cDig, 1, 0.85 * ts * FMin(1, slot / (40 * s)));
				cLine = Class'RIUtil'.static.Col(150 * a, 126 * a, 62 * a);
			}
			else if ((i == Len(inputCode)) && !bWait && bBlink)
				cLine = Class'RIVP'.static.Acc(a);
			else
				cLine = Class'RIUtil'.static.Col(70 * a, 58 * a, 28 * a);
			Class'RISkin'.static.FillC(gc, sx + i * slot + 6 * s, dy + 66 * s, slot - 12 * s, 2 * s, cLine);
		}
	}

	// --- kStatus line
	if (bWait && Granted())
		kStatus = LblGranted;
	else if (bWait)
		kStatus = LblDenied;
	else if (bInstantSuccess)
		kStatus = LblBypass;
	else
		kStatus = LblEnter;
	Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', ox, oy + 162 * s, w, 26 * s, Caps(kStatus), StatusCol(a), 1, 0.95 * ts);

	// --- key hints (the grid ends at 204 + 4 * 78 + 3 * 12 = 552)
	kHints = HintErase;
	if (Class'RIUtil'.static.PBool(Self, "bReplaceSymbols"))
		kHints = kHints $ "     " $ HintClear;
	if ((player != None) && (Class'RIUtil'.static.PInt(player, "iNoKeypadCheese") >= 3))
		kHints = kHints $ "     " $ HintConfirm;
	kHints = kHints $ "     " $ HintClose;
	Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', ox, oy + 566 * s, w, 22 * s, kHints, Class'RIVP'.static.Lbl(0.85 * a), 1, 0.72 * ts);
}

function DrawBorder(GC gc)
{
}

defaultproperties
{
     PW=392
     PH=604
     TitleLabel="Security Keypad"
     LblEnter="Enter access code"
     LblGranted="Access granted"
     LblDenied="Access denied"
     LblBypass="Bypassing lock"
     HintErase="BACKSPACE  ERASE"
     HintClear="DEL  CLEAR"
     HintConfirm="ENTER  CONFIRM"
     HintClose="ESC  CLOSE"
}

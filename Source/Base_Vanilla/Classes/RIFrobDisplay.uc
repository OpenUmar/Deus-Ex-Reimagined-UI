//=============================================================================
// RIFrobDisplay (vanilla)
// The original's highlight frame for the rebuilt HUD.
// Vanilla+: the original box itself (its pulsing corner brackets, the dark
// patterned box with the double outline, the strength bars and tools count,
// placed where the original puts it) in the HUD theme's colours, only the
// text in the HUD font.
// Sleek / Default: thin gold brackets and a name tag beside them, doors and
// devices listing lock / door / bypass strength as rows with thin bars.
// The original draws everything in one DrawWindow, so this replaces it
// whole; with the HUD on Classic the original draws unchanged.
//=============================================================================
class RIFrobDisplay extends FrobDisplayWindow;

var bool bGold;      // colours currently set for the rebuilt HUD

// The targeting box this frame (screen pixels) and its corner length
var float FbL, FbT, FbR, FbB, FbCorner;

// Stat rows of the tag (lock / door / bypass strength)
var string RowLabel[3];
var string RowValue[3];
var string RowNote[3];
var float  RowFrac[3];      // bar fill 0..1, or -1 for no bar
var int    NumRows;


function bool RIOn()
{
	return (RIDeusExHUD(GetParent()) != None) && RIDeusExHUD(GetParent()).bRI;
}

// Gold only for Sleek / Default; Vanilla+ keeps the HUD theme's colours
function bool GoldOn()
{
	return RIOn() && !Class'RIVP'.static.On();
}

event StyleChanged()
{
	Super.StyleChanged();
	bGold = GoldOn();
	if (bGold)
	{
		colText = Class'RIUtil'.static.Col(242, 211, 107);
		colBorder = Class'RIUtil'.static.Col(126, 105, 50);
	}
}

function Color RC(int R, int G, int B)
{
	return Class'RIUtil'.static.Col(R, G, B);
}

// ----------------------------------------------------------------------
// Drawing
// ----------------------------------------------------------------------

function DrawWindow(GC gc)
{
	local Actor Target;
	local string Title;

	if (GoldOn() != bGold)
		StyleChanged();
	if (!RIOn())
	{
		Super.DrawWindow(gc);
		return;
	}
	if (player == None)
		return;
	Target = player.FrobTarget;
	if ((Target == None) || !player.IsHighlighted(Target))
		return;
	if (Class'RIVP'.static.On())
	{
		DrawVanilla(gc, Target);
		return;
	}

	FindBox(Target);
	Brackets(gc, FbL + 1, FbT + 1, FbR + 1, FbB + 1, FbCorner, RC(0, 0, 0));
	Brackets(gc, FbL, FbT, FbR, FbB, FbCorner, RC(242, 211, 107));

	NumRows = 0;
	Title = InfoFor(Target);
	if (Title != "")
		DrawTag(gc, Target, Title);
}

// The same box the original computes (the actor's projected bounds)
function FindBox(Actor Target)
{
	local Mover M;
	local int i, j, k;
	local float cx, cy, boxCX, boxCY, boxW, boxH;
	local Vector centerLoc, v1, v2;

	M = Mover(Target);
	if (M != None)
	{
		M.GetBoundingBox(v1, v2, False, M.KeyPos[M.KeyNum] + M.BasePos, M.KeyRot[M.KeyNum] + M.BaseRot);
		centerLoc = v1 + (v2 - v1) * 0.5;
		v1.X = 16;
		v1.Y = 16;
		v1.Z = 16;
	}
	else
	{
		centerLoc = Target.Location;
		v1.X = Target.CollisionRadius;
		v1.Y = Target.CollisionRadius;
		v1.Z = Target.CollisionHeight;
	}
	ConvertVectorToCoordinates(centerLoc, boxCX, boxCY);
	FbL = boxCX;
	FbT = boxCY;
	FbR = boxCX;
	FbB = boxCY;
	for (i = -1; i <= 1; i += 2)
		for (j = -1; j <= 1; j += 2)
			for (k = -1; k <= 1; k += 2)
			{
				v2 = v1;
				v2.X *= i;
				v2.Y *= j;
				v2.Z *= k;
				v2 += centerLoc;
				if (ConvertVectorToCoordinates(v2, cx, cy))
				{
					FbL = FMin(FbL, cx);
					FbT = FMin(FbT, cy);
					FbR = FMax(FbR, cx);
					FbB = FMax(FbB, cy);
				}
			}
	if (M == None)
	{
		FbL += Target.CollisionRadius / 4.0;
		FbT += Target.CollisionHeight / 4.0;
		FbR -= Target.CollisionRadius / 4.0;
		FbB -= Target.CollisionHeight / 4.0;
	}
	FbL = FClamp(FbL, margin, width - margin);
	FbT = FClamp(FbT, margin, height - margin);
	FbR = FClamp(FbR, margin, width - margin);
	FbB = FClamp(FbB, margin, height - margin);
	boxW = FbR - FbL;
	boxH = FbB - FbT;
	FbCorner = FClamp((boxW + boxH) * 0.08, 8.0, 30.0);
	if (boxW < FbCorner * 2)
	{
		FbL -= FbCorner;
		FbR += FbCorner;
	}
	if (boxH < FbCorner * 2)
	{
		FbT -= FbCorner;
		FbB += FbCorner;
	}
}

function Brackets(GC gc, float L, float T, float R, float B, float C, Color Col)
{
	Class'RISkin'.static.FillC(gc, L, T, C, 1, Col);
	Class'RISkin'.static.FillC(gc, L, T, 1, C, Col);
	Class'RISkin'.static.FillC(gc, R - C + 1, T, C, 1, Col);
	Class'RISkin'.static.FillC(gc, R, T, 1, C, Col);
	Class'RISkin'.static.FillC(gc, L, B, C, 1, Col);
	Class'RISkin'.static.FillC(gc, L, B - C + 1, 1, C, Col);
	Class'RISkin'.static.FillC(gc, R - C + 1, B, C, 1, Col);
	Class'RISkin'.static.FillC(gc, R, B - C + 1, 1, C, Col);
}

// ----------------------------------------------------------------------
// What the tag says (the original's rules: doors and devices always,
// everything else only when object names are on and it isn't static)
// ----------------------------------------------------------------------

function AddRow(string L, string V, string N, float F)
{
	if (NumRows >= 3)
		return;
	if (Right(L, 2) == ": ")
		L = Left(L, Len(L) - 2);
	RowLabel[NumRows] = L;
	RowValue[NumRows] = V;
	RowNote[NumRows] = N;
	RowFrac[NumRows] = F;
	NumRows++;
}

// Picks / multitools needed at the player's current skill
function int Tools(float Str, Class<Skill> SC)
{
	local float v;

	if (player.SkillSystem == None)
		return 0;
	v = player.SkillSystem.GetSkillLevelValue(SC);
	if (v <= 0)
		return 0;
	return int(Str / v + 0.99);
}

function string InfoFor(Actor Target)
{
	local DeusExMover D;
	local HackableDevices H;
	local int n;

	if (Target.IsA('Mover'))
	{
		D = DeusExMover(Target);
		if ((D == None) || !D.bLocked)
			return msgUnlocked;
		if (D.bPickable)
		{
			n = Tools(D.lockStrength, Class'SkillLockpicking');
			if (n == 1)
				AddRow(msgLockStr, FormatString(D.lockStrength * 100.0) $ "%", string(n) @ msgPick, D.lockStrength);
			else
				AddRow(msgLockStr, FormatString(D.lockStrength * 100.0) $ "%", string(n) @ msgPicks, D.lockStrength);
		}
		else
			AddRow(msgLockStr, msgInf, "", -1);
		if (D.bBreakable)
			AddRow(msgDoorStr, FormatString(D.doorStrength * 100.0) $ "%", "", D.doorStrength);
		else
			AddRow(msgDoorStr, msgInf, "", -1);
		return msgLocked;
	}
	if (Target.IsA('HackableDevices'))
	{
		H = HackableDevices(Target);
		if (!H.bHackable)
			AddRow(msgHackStr, msgInf, "", -1);
		else if (H.hackStrength == 0.0)
			AddRow(msgHacked, "", "", -1);
		else
		{
			n = Tools(H.hackStrength, Class'SkillTech');
			if (n == 1)
				AddRow(msgHackStr, FormatString(H.hackStrength * 100.0) $ "%", string(n) @ msgTool, H.hackStrength);
			else
				AddRow(msgHackStr, FormatString(H.hackStrength * 100.0) $ "%", string(n) @ msgTools, H.hackStrength);
		}
		return H.itemName;
	}
	if (Target.bStatic || !player.bObjectNames)
		return "";
	if (Target.IsA('Pawn'))
		return player.GetDisplayName(Target);
	if (Target.IsA('DeusExCarcass'))
		return DeusExCarcass(Target).itemName;
	if (Target.IsA('Inventory'))
		return Inventory(Target).itemName;
	if (Target.IsA('DeusExDecoration'))
		return player.GetDisplayName(Target);
	if (Target.IsA('DeusExProjectile'))
		return DeusExProjectile(Target).itemName;
	return Target.GetItemName(String(Target.Class));
}

// ----------------------------------------------------------------------
// The tag beside the brackets: title and stat rows
// ----------------------------------------------------------------------

function DrawTag(GC gc, Actor Target, string Title)
{
	local float tx, ty, tw, th, lh, rh, w, lw, nw, bw;
	local int i;

	Title = Caps(Title);

	// measure
	lh = Class'RIText'.static.LineHeight(Class'RIFontSmall', 0.62) + 4;
	rh = lh + 7;
	tw = Class'RIText'.static.Width(Class'RIFontHead', Title, 0.5);
	for (i = 0; i < NumRows; i++)
	{
		w = Class'RIText'.static.Width(Class'RIFontSmall', RowLabel[i], 0.62) + 10
			+ Class'RIText'.static.Width(Class'RIFontSmall', RowValue[i], 0.62);
		if (RowNote[i] != "")
			w += 20 + Class'RIText'.static.Width(Class'RIFontSmall', RowNote[i], 0.62);
		tw = FMax(tw, w);
	}
	if (NumRows > 0)
		tw = FMax(tw, 190);
	tw += 28;
	th = 6 + 26 + NumRows * rh + 4;

	// beside the brackets, or on the left when there's no room
	tx = FbR + 16;
	if (tx + tw > width - 10)
		tx = FbL - 16 - tw;
	tx = FMax(10, tx);
	ty = FClamp(FbT, 10, height - th - 10);

	if (Class'RIVP'.static.On())
		Class'RIVP'.static.Panel(gc, tx - 8, ty - 4, tw + 16, th + 8, 8, 1);
	else
	{
		Class'RISkin'.static.DrawDim(gc, tx, ty, tw + 30, th, 0.35);
		Class'RISkin'.static.DrawDim(gc, tx, ty, tw, th, 0.4);
		Class'RISkin'.static.FillC(gc, tx, ty, 1, th, RC(242, 211, 107));
	}

	// title
	ty += 6;
	Class'RIText'.static.Draw(gc, Class'RIFontHead', tx + 14, ty, Title, RC(255, 241, 194), 0.5);
	ty += 26;

	// rows: label and value on the left, tools needed on the right, a thin
	// strength bar underneath (the original's red-to-green scale)
	bw = tw - 28;
	for (i = 0; i < NumRows; i++)
	{
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', tx + 14, ty, RowLabel[i], RC(200, 172, 104), 0.62);
		lw = Class'RIText'.static.Width(Class'RIFontSmall', RowLabel[i], 0.62);
		if (RowValue[i] != "")
			Class'RIText'.static.Draw(gc, Class'RIFontSmall', tx + 24 + lw, ty, RowValue[i], RC(255, 241, 194), 0.62);
		if (RowNote[i] != "")
		{
			nw = Class'RIText'.static.Width(Class'RIFontSmall', RowNote[i], 0.62);
			Class'RIText'.static.Draw(gc, Class'RIFontSmall', tx + tw - 14 - nw, ty, RowNote[i], RC(168, 143, 78), 0.62);
		}
		if (RowFrac[i] >= 0)
		{
			Class'RISkin'.static.FillC(gc, tx + 14, ty + lh, bw, 3, RC(52, 44, 21));
			Class'RISkin'.static.FillC(gc, tx + 14, ty + lh, bw * FClamp(RowFrac[i], 0, 1), 3, GetColorScaled(RowFrac[i]));
		}
		ty += rh;
	}
}

// ----------------------------------------------------------------------
// Vanilla+: the original box, line for line, in the HUD theme's colours
// with the text in the HUD font
// ----------------------------------------------------------------------

function DrawVanilla(GC gc, Actor Target)
{
	local string strInfo, Line, Rest, Tl;
	local DeusExMover D;
	local HackableDevices H;
	local float infoX, infoY, infoW, infoH, lh, lw, sc, boxW, boxH, corner, f1, f2;
	local int i, n, offset, numTools, p;
	local bool bBars;

	sc = 0.62;
	f1 = -1;
	f2 = -1;
	Tl = "";

	// the original's box and corner rules
	FindBox(Target);
	boxW = FbR - FbL;
	boxH = FbB - FbT;
	corner = FClamp((boxW + boxH) * 0.1, 4.0, 40.0);
	offset = 24.0 * (Target.Level.TimeSeconds % 0.3);

	// drop shadow first, then the brackets
	gc.SetStyle(DSTY_Normal);
	gc.SetTileColorRGB(0, 0, 0);
	for (i = 1; i >= 0; i--)
	{
		gc.DrawBox(FbL + i + offset, FbT + i + offset, corner, 1, 0, 0, 1, Texture'Solid');
		gc.DrawBox(FbL + i + offset, FbT + i + offset, 1, corner, 0, 0, 1, Texture'Solid');
		gc.DrawBox(FbR + i - corner - offset, FbT + i + offset, corner, 1, 0, 0, 1, Texture'Solid');
		gc.DrawBox(FbR + i - offset, FbT + i + offset, 1, corner, 0, 0, 1, Texture'Solid');
		gc.DrawBox(FbL + i + offset, FbB + i - offset, corner, 1, 0, 0, 1, Texture'Solid');
		gc.DrawBox(FbL + i + offset, FbB + i - corner - offset, 1, corner, 0, 0, 1, Texture'Solid');
		gc.DrawBox(FbR + i - corner + 1 - offset, FbB + i - offset, corner, 1, 0, 0, 1, Texture'Solid');
		gc.DrawBox(FbR + i - offset, FbB + i - corner - offset, 1, corner, 0, 0, 1, Texture'Solid');
		gc.SetTileColor(colText);
	}

	// what it says (the original's text)
	if (Target.IsA('Mover'))
	{
		D = DeusExMover(Target);
		if ((D != None) && D.bLocked)
		{
			strInfo = msgLocked $ CR() $ msgLockStr;
			if (D.bPickable)
				strInfo = strInfo $ FormatString(D.lockStrength * 100.0) $ "%";
			else
				strInfo = strInfo $ msgInf;
			strInfo = strInfo $ CR() $ msgDoorStr;
			if (D.bBreakable)
				strInfo = strInfo $ FormatString(D.doorStrength * 100.0) $ "%";
			else
				strInfo = strInfo $ msgInf;
			f1 = D.lockStrength;
			f2 = D.doorStrength;
			if (D.bPickable)
			{
				numTools = Tools(D.lockStrength, Class'SkillLockpicking');
				if (numTools == 1)
					Tl = string(numTools) @ msgPick;
				else
					Tl = string(numTools) @ msgPicks;
			}
		}
		else
			strInfo = msgUnlocked;
	}
	else if (Target.IsA('HackableDevices'))
	{
		H = HackableDevices(Target);
		strInfo = H.itemName $ CR() $ msgHackStr;
		if (H.bHackable)
		{
			if (H.hackStrength != 0.0)
				strInfo = strInfo $ FormatString(H.hackStrength * 100.0) $ "%";
			else
				strInfo = H.itemName $ ": " $ msgHacked;
		}
		else
			strInfo = strInfo $ msgInf;
		if (H.hackStrength != 0.0)
		{
			f1 = H.hackStrength;
			if (H.bHackable)
			{
				numTools = Tools(H.hackStrength, Class'SkillTech');
				if (numTools == 1)
					Tl = string(numTools) @ msgTool;
				else
					Tl = string(numTools) @ msgTools;
			}
		}
	}
	else if (!Target.bStatic && player.bObjectNames)
		strInfo = InfoFor(Target);
	if (strInfo == "")
		return;
	bBars = (f1 >= 0) || (f2 >= 0);

	// measure (lines split on the original's carriage returns)
	lh = Class'RIText'.static.LineHeight(Class'RIFontSmall', sc) + 2;
	infoW = 0;
	n = 0;
	Rest = strInfo;
	while ((Rest != "") && (n < 6))
	{
		p = InStr(Rest, CR());
		if (p < 0)
		{
			Line = Rest;
			Rest = "";
		}
		else
		{
			Line = Left(Rest, p);
			Rest = Mid(Rest, p + Len(CR()));
		}
		infoW = FMax(infoW, Class'RIText'.static.Width(Class'RIFontSmall', Line, sc));
		n++;
	}
	infoW += 8;
	if (bBars)
		infoW += barLength + 2;
	infoH = n * lh + 6;      // 4 above the first line, 4 below the last (lh has a 2 gap)
	infoX = FClamp(FbL + 10, infoW / 2 + 10, width - 10 - infoW / 2);
	infoY = FClamp(FbT + 10, infoH / 2 + 10, height - 10 - infoH / 2);

	// dark background
	gc.SetStyle(DSTY_Modulated);
	gc.SetTileColorRGB(0, 0, 0);
	gc.DrawPattern(infoX, infoY, infoW, infoH, 0, 0, Texture'ConWindowBackground');

	// coloured bars: the lock / bypass row, then the door row
	gc.SetStyle(DSTY_Translucent);
	if (f1 >= 0)
	{
		gc.SetTileColor(GetColorScaled(f1));
		gc.DrawPattern(infoX + (infoW - barLength - 4), infoY + 4 + lh, barLength * FClamp(f1, 0, 1), lh - 2, 0, 0, Texture'ConWindowBackground');
	}
	if (f2 >= 0)
	{
		gc.SetTileColor(GetColorScaled(f2));
		gc.DrawPattern(infoX + (infoW - barLength - 4), infoY + 4 + 2 * lh, barLength * FClamp(f2, 0, 1), lh - 2, 0, 0, Texture'ConWindowBackground');
	}

	// text
	n = 0;
	Rest = strInfo;
	while ((Rest != "") && (n < 6))
	{
		p = InStr(Rest, CR());
		if (p < 0)
		{
			Line = Rest;
			Rest = "";
		}
		else
		{
			Line = Left(Rest, p);
			Rest = Mid(Rest, p + Len(CR()));
		}
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', infoX + 4, infoY + 4 + n * lh, Line, colText, sc);
		n++;
	}

	// the two highlight boxes
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(colBorder);
	gc.DrawBox(infoX, infoY, infoW, infoH, 0, 0, 1, Texture'Solid');
	gc.SetTileColor(colBackground);
	gc.DrawBox(infoX + 1, infoY + 1, infoW - 2, infoH - 2, 0, 0, 1, Texture'Solid');

	// picks / multitools needed, on top of the bar
	if (Tl != "")
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', infoX + (infoW - barLength - 2), infoY + 4 + lh, Tl, colText, sc);
}

defaultproperties
{
}

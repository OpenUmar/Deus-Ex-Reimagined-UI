//=============================================================================
// RIFrobDisplay
// AE's highlight frame (targeting brackets, names, lock / door / bypass
// strength, picks and tools needed) restyled for the rebuilt HUD: gold
// brackets, a soft dark backing without the pattern, a single gold rule in
// place of the double box. Everything AE shows is still shown. With the HUD
// on Classic it draws exactly as AE's.
//=============================================================================
class RIFrobDisplay extends FrobDisplayWindow;

var bool bGold;      // colours currently set for the rebuilt HUD
var string UseKey;   // key bound to use / pick up (ParseRightClick)
var float UseKeyTime;
var localized string PickUpLabel, ReadLabel, TalkLabel, SearchLabel, UseLabel;

function bool RIOn()
{
	return (RIDeusExHUD(GetParent()) != None) && RIDeusExHUD(GetParent()).bRI;
}

event StyleChanged()
{
	Super.StyleChanged();
	bGold = RIOn();
	if (bGold)
	{
		colText = Class'RIUtil'.static.Col(242, 211, 107);
		colBorder = Class'RIUtil'.static.Col(126, 105, 50);
	}
}

function DrawDarkBackground(GC gc, float infoX, float infoY, float infoW, float infoH)
{
	if (!RIOn())
	{
		Super.DrawDarkBackground(gc, infoX, infoY, infoW, infoH);
		return;
	}
	if (Class'RIVP'.static.On())
	{
		Class'RIVP'.static.Panel(gc, infoX - 6, infoY - 4, infoW + 12, infoH + 8, 8, 1);
		return;
	}
	Class'RISkin'.static.DrawDim(gc, infoX - 6, infoY - 4, infoW + 12, infoH + 8, 0.25);
	Class'RISkin'.static.DrawDim(gc, infoX, infoY, infoW, infoH, 0.45);
}

function DrawHightlightBox(GC gc, float infoX, float infoY, float infoW, float infoH)
{
	if (!RIOn())
	{
		Super.DrawHightlightBox(gc, infoX, infoY, infoW, infoH);
		return;
	}
	// one gold rule down the left; AE's outline colour (key / tools state) along the bottom
	Class'RISkin'.static.FillC(gc, infoX, infoY, 2, infoH, Class'RIUtil'.static.Col(242, 211, 107));
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(outlineColour);
	gc.DrawBox(infoX + 2, infoY + infoH - 1, infoW - 2, 1, 0, 0, 1, Texture'Solid');
}

// ----------------------------------------------------------------------
// Rebuilt HUD: thin brackets and a name tag beside them
// ----------------------------------------------------------------------

function Color RC(int R, int G, int B)
{
	return Class'RIUtil'.static.Col(R, G, B);
}

// Same box AE computes (the actor's projected bounds), drawn as thin gold
// corner brackets with a faint shadow
function DrawTargetingBox(GC gc, actor frobTarget)
{
	local Mover M;
	local int i, j, k;
	local float corner, cx, cy, boxCX, boxCY, boxW, boxH;
	local Vector centerLoc, v1, v2;

	if (!RIOn())
	{
		Super.DrawTargetingBox(gc, frobTarget);
		return;
	}
	M = Mover(frobTarget);
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
		centerLoc = frobTarget.Location;
		v1.X = frobTarget.CollisionRadius;
		v1.Y = frobTarget.CollisionRadius;
		v1.Z = frobTarget.CollisionHeight;
	}
	ConvertVectorToCoordinates(centerLoc, boxCX, boxCY);
	boxTLX = boxCX;
	boxTLY = boxCY;
	boxBRX = boxCX;
	boxBRY = boxCY;
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
					boxTLX = FMin(boxTLX, cx);
					boxTLY = FMin(boxTLY, cy);
					boxBRX = FMax(boxBRX, cx);
					boxBRY = FMax(boxBRY, cy);
				}
			}
	if (M == None)
	{
		boxTLX += frobTarget.CollisionRadius / 3.5;
		boxTLY += frobTarget.CollisionHeight / 3.5;
		boxBRX -= frobTarget.CollisionRadius / 3.5;
		boxBRY -= frobTarget.CollisionHeight / 3.5;
	}
	boxTLX = FClamp(boxTLX, margin, width - margin);
	boxTLY = FClamp(boxTLY, margin, height - margin);
	boxBRX = FClamp(boxBRX, margin, width - margin);
	boxBRY = FClamp(boxBRY, margin, height - margin);
	boxW = boxBRX - boxTLX;
	boxH = boxBRY - boxTLY;
	corner = FClamp((boxW + boxH) * 0.08, 8.0, 30.0);
	if (boxW < corner * 2)
	{
		boxTLX -= corner;
		boxBRX += corner;
	}
	if (boxH < corner * 2)
	{
		boxTLY -= corner;
		boxBRY += corner;
	}
	Brackets(gc, boxTLX + 1, boxTLY + 1, boxBRX + 1, boxBRY + 1, corner, RC(0, 0, 0));
	Brackets(gc, boxTLX, boxTLY, boxBRX, boxBRY, corner, RC(242, 211, 107));
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

// The key bound to use / pick up, re-read every few seconds so a rebind shows
function string FrobKey()
{
	local int i;
	local string KeyName, Mouse;

	if ((player == None) || ((UseKey != "") && (player.Level.TimeSeconds - UseKeyTime < 5.0) && (UseKeyTime > 0)))
		return UseKey;
	UseKeyTime = player.Level.TimeSeconds;
	UseKey = "";
	Mouse = "";
	for (i = 0; i < 255; i++)
	{
		KeyName = player.ConsoleCommand("KEYNAME " $ i);
		if (KeyName == "")
			continue;
		if (InStr(Caps(player.ConsoleCommand("KEYBINDING " $ KeyName)), "PARSERIGHTCLICK") < 0)
			continue;
		if (InStr(Caps(KeyName), "MOUSE") >= 0)
		{
			if (Mouse == "")
				Mouse = KeyName;
		}
		else
		{
			UseKey = Caps(KeyName);
			break;
		}
	}
	if ((UseKey == "") && (Mouse != ""))
		UseKey = Caps(Mouse);
	return UseKey;
}

function string Verb(actor frobTarget)
{
	if (frobTarget.IsA('InformationDevices'))
		return ReadLabel;
	if (frobTarget.IsA('Pawn'))
		return TalkLabel;
	if (frobTarget.IsA('DeusExCarcass'))
		return SearchLabel;
	if (frobTarget.IsA('Inventory'))
		return PickUpLabel;
	return UseLabel;
}

// Name tag beside the brackets: the name (and any extra lines AE adds) in
// the HUD's fonts, then "[key] verb", over a soft backing with a gold rule
function DrawOtherHudInformation(GC gc, actor frobTarget)
{
	local string strInfo, Line, Rest, Hint;
	local float tx, ty, tw, th, lh, w0;
	local int p, n;

	if (!RIOn())
	{
		Super.DrawOtherHudInformation(gc, frobTarget);
		return;
	}
	if (frobTarget.IsA('Pawn'))
		strInfo = player.GetDisplayName(frobTarget);
	else if (frobTarget.IsA('InformationDevices'))
		strInfo = InformationDevices(frobTarget).GetFrobString(player);
	else if (frobTarget.IsA('DeusExCarcass'))
		strInfo = DeusExCarcass(frobTarget).GetFrobString(player);
	else if (frobTarget.IsA('AugmentationCannister'))
		strInfo = GetAugCanInformation(AugmentationCannister(frobTarget));
	else if (frobTarget.IsA('DeusExPickup'))
		strInfo = DeusExPickup(frobTarget).GetFrobString(player);
	else if (frobTarget.IsA('DeusExAmmo'))
		strInfo = DeusExAmmo(frobTarget).itemName @ "(" $ DeusExAmmo(frobTarget).AmmoAmount $ ")";
	else if (frobTarget.IsA('DeusExWeapon'))
		strInfo = DeusExWeapon(frobTarget).GetFrobString(player);
	else if (frobTarget.IsA('Inventory'))
		strInfo = Inventory(frobTarget).itemName;
	else if (frobTarget.IsA('DeusExDecoration'))
		strInfo = player.GetDisplayName(frobTarget);
	else if (frobTarget.IsA('DeusExProjectile'))
		strInfo = DeusExProjectile(frobTarget).itemName;
	else
		strInfo = frobTarget.GetItemName(String(frobTarget.Class));
	if (player.bExtraObjectDetails)
	{
		if (frobTarget.IsA('DeusExDecoration') && !DeusExDecoration(frobTarget).bInvincible)
			strInfo = strInfo $ CR() $ msgHP $ string(DeusExDecoration(frobTarget).HitPoints);
		else if (frobTarget.IsA('DeusExPickup') && DeusExPickup(frobTarget).bBreakable)
			strInfo = strInfo $ CR() $ msgHP2;
		if (frobTarget.IsA('DeusExDecoration') && DeusExDecoration(frobTarget).bPushable)
			strInfo = strInfo $ CR() $ msgMass $ string(int(frobTarget.Mass)) $ " lbs";
	}
	if (strInfo == "")
		return;

	Hint = FrobKey();
	if (Hint != "")
		Hint = "[" $ Hint $ "]  " $ Verb(frobTarget);
	else
		Hint = Verb(frobTarget);

	// measure
	lh = Class'RIText'.static.LineHeight(Class'RIFontSmall', 0.62) + 4;
	tw = Class'RIText'.static.Width(Class'RIFontSmall', Hint, 0.62);
	Rest = strInfo;
	n = 0;
	while ((Rest != "") && (n < 8))
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
		if (n == 0)
			w0 = Class'RIText'.static.Width(Class'RIFontHead', Caps(Line), 0.5);
		else
			w0 = Class'RIText'.static.Width(Class'RIFontSmall', Line, 0.62);
		tw = FMax(tw, w0);
		n++;
	}
	th = 26 + (n - 1) * lh + lh + 12;
	tw += 28;

	// beside the brackets, or on the left when there's no room
	tx = boxBRX + 16;
	if (tx + tw > width - 10)
		tx = boxTLX - 16 - tw;
	ty = FClamp(boxTLY, 10, height - th - 10);

	if (Class'RIVP'.static.On())
		Class'RIVP'.static.Panel(gc, tx - 8, ty - 4, tw + 16, th + 8, 8, 1);
	else
	{
		Class'RISkin'.static.DrawDim(gc, tx, ty, tw + 30, th, 0.35);
		Class'RISkin'.static.DrawDim(gc, tx, ty, tw, th, 0.4);
		Class'RISkin'.static.FillC(gc, tx, ty, 1, th, RC(242, 211, 107));
	}

	// lines
	Rest = strInfo;
	n = 0;
	ty += 6;
	while ((Rest != "") && (n < 8))
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
		if (n == 0)
		{
			Class'RIText'.static.Draw(gc, Class'RIFontHead', tx + 14, ty, Caps(Line), RC(255, 241, 194), 0.5);
			ty += 26;
		}
		else
		{
			Class'RIText'.static.Draw(gc, Class'RIFontSmall', tx + 14, ty, Line, RC(200, 172, 104), 0.62);
			ty += lh;
		}
		n++;
	}
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', tx + 14, ty + 2, Hint, RC(168, 143, 78), 0.62);
}

function DrawWindow(GC gc)
{
	if (RIOn() != bGold)
		StyleChanged();
	Super.DrawWindow(gc);
}

defaultproperties
{
     PickUpLabel="Pick up"
     ReadLabel="Read"
     TalkLabel="Talk"
     SearchLabel="Search"
     UseLabel="Use"
}

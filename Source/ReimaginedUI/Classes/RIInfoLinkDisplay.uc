//=============================================================================
// RIInfoLinkDisplay
// AE's InfoLink window (all its logic: speaker, portrait, static, typed text,
// "message waiting") restyled for the rebuilt HUD: wider, a soft dark backing
// in place of the riveted box, a hairline-framed portrait and the original
// gold. With the HUD on Classic it draws exactly as AE's.
//=============================================================================
class RIInfoLinkDisplay extends HUDInfoLinkDisplay;

function bool RIOn()
{
	return (RIDeusExHUD(GetParent()) != None) && RIDeusExHUD(GetParent()).bRI;
}

function Color Col(int R, int G, int B)
{
	return Class'RIUtil'.static.Col(R, G, B);
}

event InitWindow()
{
	Super.InitWindow();
	if (RIOn())
		Relayout();
}

function Relayout()
{
	SetSize(540, 88);
	winPortrait.SetPos(16, 12);
	winStatic.SetPos(16, 12);
	winName.SetSize(410, 15);
	winName.SetPos(96, 7);
	winQueued.SetSize(200, 15);
	winQueued.SetPos(306, 7);
	winLine.SetSize(420, 1);
	winLine.SetPos(96, 23);
	winText.SetPos(96, 28);
	winText.SetTextSize(58, 5);
	Recolour();
}

function Recolour()
{
	if (winName == None)
		return;
	winName.SetTextColor(Col(255, 241, 194));
	winQueued.SetTextColor(Col(143, 208, 224));
	winLine.SetTileColor(Col(126, 105, 50));
	winText.SetFontColor(Col(230, 195, 117));
	winText.SetCursorColor(Col(242, 211, 107));
}

event StyleChanged()
{
	Super.StyleChanged();
	if (RIOn())
		Recolour();
}

// Soft dark backing: darkest in the middle, no hard edges
function DrawBackground(GC gc)
{
	local int i;
	local float inX, inY;

	if (!RIOn())
	{
		Super.DrawBackground(gc);
		return;
	}
	if (Class'RIVP'.static.On())
	{
		// the HUD corners board's InfoLink box, stretched so its frame runs
		// round this window (the box sits at 20,23 - 868,238 in the art)
		Class'RITheme'.static.SetMode(2);
		// a soft shade with no edges (a rectangle showed as a box inside the frame)
		gc.SetStyle(DSTY_Modulated);
		gc.DrawStretchedTexture(-width * 0.08, -height * 0.25, width * 1.16, height * 1.5, 0, 0, 256, 64, Texture'ReimaginedUI.UI.RI_ShadeC');
		gc.SetStyle(DSTY_Translucent);
		gc.SetTileColor(Class'RIVP'.static.Acc(1));
		gc.DrawStretchedTexture(-20 * width / 848.0, -23 * height / 215.0, 896 * width / 848.0, 256 * height / 215.0,
			0, 0, 896, 256, Texture'ReimaginedUI.VPlus.VPH_Info');
		return;
	}
	for (i = 0; i < 7; i++)
	{
		inX = i * width * 0.05;
		inY = i * 7;
		if (height - inY * 2 <= 2)
			break;
		Class'RISkin'.static.DrawDim(gc, inX, inY, width - inX * 2, height - inY * 2, 0.12);
	}
}

// Hairline frame round the portrait, a short gold rule along the top
function DrawBorder(GC gc)
{
	if (!RIOn())
	{
		Super.DrawBorder(gc);
		return;
	}
	if (Class'RIVP'.static.On())
	{
		Class'RIVP'.static.Inset(gc, 15, 11, 66, 66, 1);
		return;
	}
	Class'RIText'.static.Box(gc, 15, 11, 66, 66, Col(126, 105, 50));
	Class'RIText'.static.HLine(gc, 22, 4, 140, Col(126, 105, 50));
}

defaultproperties
{
}

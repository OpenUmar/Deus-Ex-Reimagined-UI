//=============================================================================
// RIAugDisplay
// AE's augmentation display (vision, targeting, threat, drone view: all its
// logic) with its framed boxes (the drone feed, target readouts) drawn in
// the Sleek style: a soft dark keyline round the box, a hairline gold edge
// and short corner brackets. With the HUD on Classic it draws as AE's.
//=============================================================================
class RIAugDisplay extends AugmentationDisplayWindow;

function bool RIOn()
{
	return (RIDeusExHUD(GetParent()) != None) && RIDeusExHUD(GetParent()).bRI;
}

// The game's accuracy reticle (brackets round the centre, placed half a unit
// off) is replaced by RICrosshair, which spreads with the weapon's accuracy
// on the exact centre. Everything else this does still runs (target tracking,
// the crosshair's friend / foe colour); with the Targeting aug on it draws as
// the game's, since that aug's readouts are drawn here too.
function DrawTargetAugmentation(GC gc)
{
	local bool bWas;

	if (!RIOn() || bTargetActive)
	{
		Super.DrawTargetAugmentation(gc);
		return;
	}
	bWas = gc.IsDrawingEnabled();
	gc.EnableDrawing(False);
	Super.DrawTargetAugmentation(gc);
	gc.EnableDrawing(bWas);
}

function DrawDropShadowBox(GC gc, float x, float y, float w, float h)
{
	local Color oldColor, cEdge, cAcc;
	local float k;

	if (!RIOn())
	{
		Super.DrawDropShadowBox(gc, x, y, w, h);
		return;
	}
	gc.GetTileColor(oldColor);
	Class'RITheme'.static.SetMode(2);
	cEdge = Class'RIUtil'.static.Col(150, 126, 62);
	cAcc  = Class'RIUtil'.static.Col(230, 195, 117);
	// a dark keyline just outside, then the gold hairline
	gc.SetStyle(DSTY_Modulated);
	Class'RIText'.static.Tex(gc, x - 2, y - 2, w + 4, 2, 0, 0, 16, 16, Texture'ReimaginedUI.UI.RI_Dark');
	Class'RIText'.static.Tex(gc, x - 2, y + h, w + 4, 2, 0, 0, 16, 16, Texture'ReimaginedUI.UI.RI_Dark');
	Class'RIText'.static.Tex(gc, x - 2, y, 2, h, 0, 0, 16, 16, Texture'ReimaginedUI.UI.RI_Dark');
	Class'RIText'.static.Tex(gc, x + w, y, 2, h, 0, 0, 16, 16, Texture'ReimaginedUI.UI.RI_Dark');
	Class'RIText'.static.Box(gc, x - 0.5, y - 0.5, w + 1, h + 1, cEdge);
	// corner brackets
	k = FMin(10, FMin(w, h) * 0.2);
	Class'RISkin'.static.FillC(gc, x - 1, y - 1, k, 1, cAcc);
	Class'RISkin'.static.FillC(gc, x - 1, y - 1, 1, k, cAcc);
	Class'RISkin'.static.FillC(gc, x + w + 1 - k, y - 1, k, 1, cAcc);
	Class'RISkin'.static.FillC(gc, x + w, y - 1, 1, k, cAcc);
	Class'RISkin'.static.FillC(gc, x - 1, y + h, k, 1, cAcc);
	Class'RISkin'.static.FillC(gc, x - 1, y + h + 1 - k, 1, k, cAcc);
	Class'RISkin'.static.FillC(gc, x + w + 1 - k, y + h, k, 1, cAcc);
	Class'RISkin'.static.FillC(gc, x + w, y + h + 1 - k, 1, k, cAcc);
	Class'RITheme'.static.SetMode(0);
	gc.SetTileColor(oldColor);
}

// ----------------------------------------------------------------------
// Vision aug, Vanilla+ (original game only; AE keeps its own). The same
// logic as the original (light amp in a centre window, at level 1+ the
// rest of the screen in red with heat sources drawn through it), with a
// larger window framed as the other Vanilla+ panels: the rounded frame,
// the original DX trim, corner brackets, centre ticks, and readouts in
// the mod's type in place of the pixel-font line.
// ----------------------------------------------------------------------

function DrawVisionAugmentation(GC gc)
{
	local Vector loc;
	local float bx, by, bw, bh, dist, K, tw;
	local Actor A;
	local Texture oldSkins[9];
	local Color cAcc, cTxt, cRed;
	local string T;

	if (!RIOn() || !Class'RIVP'.static.On() || !Class'RIBase'.static.OwnVision() || (Player.Level.NetMode != NM_Standalone))
	{
		Super.DrawVisionAugmentation(gc);
		return;
	}
	K = height / 1080.0;
	bw = width * 0.58;
	bh = height * 0.6;
	bx = (width - bw) * 0.5;
	by = (height - bh) * 0.5;

	// level 1+: thermal outside the window
	if (visionLevel >= 1)
	{
		gc.SetStyle(DSTY_Modulated);
		Class'RIText'.static.Pat(gc, 0, 0, width, by, 0, 0, Texture'ConWindowBackground');
		Class'RIText'.static.Pat(gc, 0, by + bh, width, height - by - bh, 0, 0, Texture'ConWindowBackground');
		Class'RIText'.static.Pat(gc, 0, by, bx, bh, 0, 0, Texture'ConWindowBackground');
		Class'RIText'.static.Pat(gc, bx + bw, by, width - bx - bw, bh, 0, 0, Texture'ConWindowBackground');
		Class'RIText'.static.Pat(gc, 0, 0, width, by, 0, 0, Texture'SolidRed');
		Class'RIText'.static.Pat(gc, 0, by + bh, width, height - by - bh, 0, 0, Texture'SolidRed');
		Class'RIText'.static.Pat(gc, 0, by, bx, bh, 0, 0, Texture'SolidRed');
		Class'RIText'.static.Pat(gc, bx + bw, by, width - bx - bw, bh, 0, 0, Texture'SolidRed');
		gc.SetStyle(DSTY_Translucent);

		loc = Player.Location;
		loc.Z += Player.BaseEyeHeight;
		foreach Player.AllActors(class'Actor', A)
		{
			if (!A.bVisionImportant || !IsHeatSource(A))
				continue;
			dist = VSize(A.Location - loc);
			if ((dist <= visionLevelValue) || Player.LineOfSightTo(A, True))
			{
				VisionTargetStatus = GetVisionTargetStatus(A);
				SetSkins(A, oldSkins);
				gc.DrawActor(A, False, False, True, 1.0, 2.0, None);
				ResetSkins(A, oldSkins);
			}
		}
	}

	// light amp in the window
	gc.SetStyle(DSTY_Modulated);
	Class'RIText'.static.Pat(gc, bx, by, bw, bh, 0, 0, Texture'SolidGreen');
	Class'RIText'.static.Pat(gc, bx, by, bw, bh, 0, 0, Texture'SolidGreen');
	gc.SetStyle(DSTY_Normal);

	// frame: rounded edge, the DX trim, brackets and centre ticks
	Class'RITheme'.static.SetMode(2);
	cAcc = Class'RIVP'.static.Acc(1);
	cTxt = Class'RIVP'.static.Txt(1);
	cRed = Class'RIUtil'.static.Raw(255, 96, 70);
	Class'RIVP'.static.Edges(gc, bx, by, bw, bh, 16 * K, 1);
	Class'RIVP'.static.DXAround(gc, bx, by, bw, bh, K, 1);
	Bracket(gc, bx + 10 * K, by + 10 * K, 1, 1, K, cAcc);
	Bracket(gc, bx + bw - 10 * K, by + 10 * K, -1, 1, K, cAcc);
	Bracket(gc, bx + 10 * K, by + bh - 10 * K, 1, -1, K, cAcc);
	Bracket(gc, bx + bw - 10 * K, by + bh - 10 * K, -1, -1, K, cAcc);
	Class'RISkin'.static.FillC(gc, bx + bw * 0.5 - 1 * K, by + 6 * K, 2 * K, 14 * K, cAcc);
	Class'RISkin'.static.FillC(gc, bx + bw * 0.5 - 1 * K, by + bh - 20 * K, 2 * K, 14 * K, cAcc);
	Class'RISkin'.static.FillC(gc, bx + 6 * K, by + bh * 0.5 - 1 * K, 14 * K, 2 * K, cAcc);
	Class'RISkin'.static.FillC(gc, bx + bw - 20 * K, by + bh * 0.5 - 1 * K, 14 * K, 2 * K, cAcc);

	// readouts: mode tag in the top-left, level top-right; thermal range
	// over the window when it's on
	T = Caps(StripDots(msgLightAmpActive));
	Class'RIVP'.static.Panel(gc, bx + 30 * K, by + 22 * K, Class'RIText'.static.Width(Class'RIFontHead', T, 0.46) + 28 * K, 30 * K, 8 * K, 1);
	Class'RIText'.static.DrawIn(gc, Class'RIFontHead', bx + 44 * K, by + 22 * K, 400 * K, 30 * K, T, cTxt, 0, 0.46);
	T = "LV " $ string(visionLevel + 1);
	tw = Class'RIText'.static.Width(Class'RIFontHead', T, 0.46);
	Class'RIText'.static.DrawIn(gc, Class'RIFontHead', bx + bw - 44 * K - tw, by + 22 * K, tw, 30 * K, T, cAcc, 0, 0.46);
	if (visionLevel >= 1)
	{
		T = Caps(StripDots(msgIRAmpActive)) $ "   " $ msgRange @ string(int(visionLevelValue / 16)) @ msgRangeUnits;
		T = Caps(T);
		tw = Class'RIText'.static.Width(Class'RIFontSmall', T, 0.62);
		Class'RIVP'.static.Panel(gc, bx + (bw - tw) * 0.5 - 16 * K, by - 54 * K, tw + 32 * K, 30 * K, 8 * K, 1);
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', bx, by - 54 * K, bw, 30 * K, T, cRed, 1, 0.62);
	}
	Class'RITheme'.static.SetMode(0);
}

// "Light Amplification Active..." -> without the trailing dots / colon
function string StripDots(string S)
{
	while ((S != "") && ((Right(S, 1) == ".") || (Right(S, 1) == ":") || (Right(S, 1) == " ")))
		S = Left(S, Len(S) - 1);
	return S;
}

// A corner bracket at X,Y opening toward DX,DY (+1 / -1): two arms, 2 thick,
// joined by a quarter circle (radius 10) so it follows the frame's rounded
// corners rather than meeting square
function Bracket(GC gc, float X, float Y, float DX, float DY, float K, Color C)
{
	local float L, R, r2, cx, cy, hy, vx, th, px, py;
	local int i;

	// drawn solid: overlapping translucent squares would bead along the curve
	gc.SetStyle(DSTY_Normal);
	gc.SetTileColor(C);
	L = 26 * K;
	R = 10 * K;
	hy = Y + DY * K;          // the arms' centre lines
	vx = X + DX * K;
	// horizontal arm, from the end of the curve out to L
	if (DX > 0)
		Solid(gc, X + R, hy - K, L - R, 2 * K);
	else
		Solid(gc, X - L, hy - K, L - R, 2 * K);
	// vertical arm
	if (DY > 0)
		Solid(gc, vx - K, Y + R, 2 * K, L - R);
	else
		Solid(gc, vx - K, Y - L, 2 * K, L - R);
	// the curve: small squares along a quarter circle through both centre lines
	cx = X + DX * R;
	cy = Y + DY * R;
	r2 = R - K;
	for (i = 0; i <= 12; i++)
	{
		th = (i / 12.0) * 1.5707963;
		px = cx - DX * r2 * Cos(th);
		py = cy - DY * r2 * Sin(th);
		Solid(gc, px - K, py - K, 2 * K, 2 * K);
	}
}

function Solid(GC gc, float X, float Y, float W, float H)
{
	Class'RIText'.static.Fill(gc, X, Y, W, H);
}

defaultproperties
{
}

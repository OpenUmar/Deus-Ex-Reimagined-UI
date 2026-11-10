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
	gc.DrawStretchedTexture(x - 2, y - 2, w + 4, 2, 0, 0, 16, 16, Texture'ReimaginedUI.UI.RI_Dark');
	gc.DrawStretchedTexture(x - 2, y + h, w + 4, 2, 0, 0, 16, 16, Texture'ReimaginedUI.UI.RI_Dark');
	gc.DrawStretchedTexture(x - 2, y, 2, h, 0, 0, 16, 16, Texture'ReimaginedUI.UI.RI_Dark');
	gc.DrawStretchedTexture(x + w, y, 2, h, 0, 0, 16, 16, Texture'ReimaginedUI.UI.RI_Dark');
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

defaultproperties
{
}

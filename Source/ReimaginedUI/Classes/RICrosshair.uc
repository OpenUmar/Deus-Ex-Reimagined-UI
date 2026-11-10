//=============================================================================
// RICrosshair
// AE's crosshair (same show / hide and colour from AE's settings), drawn as a
// thin modern cross: four short strokes round a gap and a one-pixel dot, each
// with a dark keyline so it reads on bright and dark scenes alike. With the
// HUD on Classic it draws AE's CrossSquare as before.
//=============================================================================
class RICrosshair extends Crosshair;

var Color CrossCol;

event InitWindow()
{
	Super.InitWindow();
	SetBackground(None);
}

function SetCrosshairColor(color newColor)
{
	CrossCol = newColor;
	Super.SetCrosshairColor(newColor);
}

event ParentRequestedPreferredSize(bool bWidthSpecified, out float preferredWidth,
                                   bool bHeightSpecified, out float preferredHeight)
{
	preferredWidth = 16;
	preferredHeight = 16;
}

function bool RIOn()
{
	return (RIDeusExHUD(GetParent()) != None) && RIDeusExHUD(GetParent()).bRI;
}

// A stroke with its keyline (UI units; half a unit is one pixel at 1080p)
function Stroke(GC gc, float X, float Y, float W, float H)
{
	gc.SetStyle(DSTY_Normal);
	gc.SetTileColor(Class'RIUtil'.static.Raw(8, 8, 8));
	Class'RIText'.static.Fill(gc, X - 0.5, Y - 0.5, W + 1.0, H + 1.0);
	gc.SetTileColor(CrossCol);
	Class'RIText'.static.Fill(gc, X, Y, W, H);
}

event DrawWindow(GC gc)
{
	local float cx, cy, gap, len, t;

	if (!RIOn())
	{
		gc.SetStyle(DSTY_Masked);
		gc.SetTileColor(CrossCol);
		gc.DrawTexture((width - 16) * 0.5, (height - 16) * 0.5, 16, 16, 0, 0, Texture'CrossSquare');
		return;
	}
	cx = Class'RIText'.static.Snap(width * 0.5);
	cy = Class'RIText'.static.Snap(height * 0.5);
	gap = 2.5;
	len = 4.0;
	t = 0.5;
	Stroke(gc, cx - gap - len, cy - t * 0.5, len, t);
	Stroke(gc, cx + gap, cy - t * 0.5, len, t);
	Stroke(gc, cx - t * 0.5, cy - gap - len, t, len);
	Stroke(gc, cx - t * 0.5, cy + gap, t, len);
	Stroke(gc, cx - t * 0.5, cy - t * 0.5, t, t);
}

defaultproperties
{
     CrossCol=(R=255,G=255,B=255)
}

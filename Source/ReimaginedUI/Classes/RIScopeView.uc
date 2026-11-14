//=============================================================================
// RIScopeView
// AE's scope / binocular view (same activation, zoom and rangefinder) drawn
// in the Sleek style: a soft-edged round lens (two for binoculars) with the
// world blacked out round it, a thin duplex reticle with stadia ticks, and a
// Michroma readout of range and zoom. AE's "classic scope" setting, the HUD
// on Classic and the GEP zoom keep AE's own drawing.
//=============================================================================
class RIScopeView extends DeusExScopeView;

var localized string ZoomLabel, RangeLabel, RangeUnits;

function bool RIOn()
{
	local RIRootWindow R;

	R = RIRootWindow(GetRootWindow());
	return (R != None) && !R.bClassicHUD && (player != None) && !Class'RIUtil'.static.PBool(player, "bClassicScope");
}

function Line(GC gc, float X, float Y, float W, float H, Color C)
{
	gc.SetStyle(DSTY_Normal);
	gc.SetTileColor(C);
	Class'RIText'.static.Fill(gc, X, Y, W, H);
}

event DrawWindow(GC gc)
{
	local float d, lx, ly, lw, lh, cx, cy, r, i, tick, zoom;
	local Color cDark, cGold;
	local string S;
	local int zi;

	if ((player == None) || !RIOn() || Class'RIUtil'.static.PBool(player, "bGEPzoomActive"))
	{
		Super.DrawWindow(gc);
		return;
	}
	if (player.IsInState('Dying'))
		return;

	cx = Class'RIText'.static.Snap(width * 0.5);
	cy = Class'RIText'.static.Snap(height * 0.5);
	cDark = Class'RIUtil'.static.Raw(10, 10, 10);
	Class'RITheme'.static.SetMode(2);
	cGold = Class'RIUtil'.static.Col(230, 195, 117);

	// --- lens(es) and the black round them
	d = height * 0.96;
	if (bBinocs)
	{
		lh = d * 0.86;
		lw = lh * 2.0;
	}
	else
	{
		lh = d;
		lw = d;
	}
	lx = cx - lw * 0.5;
	ly = cy - lh * 0.5;
	if (player.Level.NetMode == NM_Standalone)
	{
		Class'RIVP'.static.Black(gc, 0, 0, width, ly + 1);
		Class'RIVP'.static.Black(gc, 0, ly + lh - 1, width, height - ly - lh + 1);
		Class'RIVP'.static.Black(gc, 0, ly, lx + 1, lh);
		Class'RIVP'.static.Black(gc, lx + lw - 1, ly, width - lx - lw + 1, lh);
	}
	gc.SetStyle(DSTY_Modulated);
	if (bBinocs)
		gc.DrawStretchedTexture(lx, ly, lw, lh, 0, 0, 512, 256, Texture'ReimaginedUI.UI.RI_BinocMask');
	else
		gc.DrawStretchedTexture(lx, ly, lw, lh, 0, 0, 256, 256, Texture'ReimaginedUI.UI.RI_ScopeMask');

	// --- reticle
	r = lh * 0.5;
	if (bBinocs)
	{
		// binoculars: a light gold cross with a gap, and corner brackets
		Line(gc, cx - r * 0.42, cy - 0.5, r * 0.34, 1, cGold);
		Line(gc, cx + r * 0.08, cy - 0.5, r * 0.34, 1, cGold);
		Line(gc, cx - 0.5, cy - r * 0.42, 1, r * 0.34, cGold);
		Line(gc, cx - 0.5, cy + r * 0.08, 1, r * 0.34, cGold);
		for (i = -1; i <= 1; i += 2)
		{
			Line(gc, cx + i * r * 0.62 - 0.5, cy - r * 0.3, 1, r * 0.6, Class'RIUtil'.static.Col(150, 126, 62));
			Line(gc, cx + i * r * 0.62 - (i + 1) * r * 0.04, cy - r * 0.3, r * 0.08, 1, Class'RIUtil'.static.Col(150, 126, 62));
			Line(gc, cx + i * r * 0.62 - (i + 1) * r * 0.04, cy + r * 0.3 - 1, r * 0.08, 1, Class'RIUtil'.static.Col(150, 126, 62));
		}
	}
	else
	{
		// rifle scope: heavy outer posts thinning to a fine centre cross
		Line(gc, cx - r, cy - 1.5, r * 0.62, 3, cDark);
		Line(gc, cx + r * 0.38, cy - 1.5, r * 0.62, 3, cDark);
		Line(gc, cx - 1.5, cy + r * 0.38, 3, r * 0.62, cDark);
		Line(gc, cx - 1.5, cy - r, 3, r * 0.62, cDark);
		Line(gc, cx - r * 0.38, cy - 0.5, r * 0.76, 1, cDark);
		Line(gc, cx - 0.5, cy - r * 0.38, 1, r * 0.76, cDark);
		// stadia ticks along the fine lines
		tick = r * 0.076;
		for (i = 1; i <= 4; i += 1)
		{
			Line(gc, cx - i * tick - 0.5, cy - 2, 1, 4, cDark);
			Line(gc, cx + i * tick - 0.5, cy - 2, 1, 4, cDark);
			Line(gc, cx - 2, cy + i * tick - 0.5, 4, 1, cDark);
		}
		// a small gold centre point
		Line(gc, cx - 0.5, cy - 0.5, 1, 1, cGold);
	}

	// --- readout: range, and zoom from the view's field of view
	S = RangeText();
	zoom = 90.0;
	if (player.DesiredFOV > 1)
		zoom = 90.0 / player.DesiredFOV;
	zi = int(zoom * 10 + 0.5);
	S = Caps(S) $ "     " $ ZoomLabel $ " " $ string(zi / 10) $ "." $ string(zi - (zi / 10) * 10) $ "X";
	Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', 0, cy + r * 0.62, width, 12, S, cGold, 1, 0.8);
	Class'RITheme'.static.SetMode(0);
}

// Distance to what the view points at, in feet (AE's binocular readout,
// the same trace its AugmentationDisplayWindow uses)
function string RangeText()
{
	local vector HitLocation, HitNormal, StartTrace, EndTrace;

	StartTrace = player.Location;
	EndTrace = player.Location + (Vector(player.ViewRotation) * 160000);
	StartTrace.Z += player.BaseEyeHeight;
	EndTrace.Z += player.BaseEyeHeight;
	player.Trace(HitLocation, HitNormal, EndTrace, StartTrace, True);
	return RangeLabel @ string(int(VSize(HitLocation - player.Location) / 16)) @ RangeUnits;
}

defaultproperties
{
     ZoomLabel="ZOOM"
     RangeLabel="Range"
     RangeUnits="ft"
}

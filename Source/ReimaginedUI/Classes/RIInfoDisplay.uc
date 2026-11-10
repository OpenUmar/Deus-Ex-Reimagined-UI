//=============================================================================
// RIInfoDisplay
// AE's reader for books, datacubes, newspapers and manuals, restyled for the
// rebuilt HUD: a dark panel with a gold hairline and warm text in place of the
// shared border art. AE fills it and sizes it as before. With the HUD on
// Classic it draws exactly as AE's.
//=============================================================================
class RIInfoDisplay extends HUDInformationDisplay;

function bool RIOn()
{
	return (RIDeusExHUD(GetParent()) != None) && RIDeusExHUD(GetParent()).bRI;
}

function DrawBackground(GC gc)
{
	local int i;

	if (!RIOn())
	{
		Super.DrawBackground(gc);
		return;
	}
	if (Class'RIVP'.static.On())
	{
		Class'RIVP'.static.Black(gc, 3, 3, width - 6, height - 6);
		Class'RIVP'.static.Frame(gc, 0, 0, width, height, 12, 1);
		return;
	}
	// soft shadow round the panel, then the panel itself
	for (i = 1; i <= 4; i++)
		Class'RISkin'.static.DrawDim(gc, -i * 6, -i * 6, width + i * 12, height + i * 12, 0.08);
	Class'RISkin'.static.FillC(gc, 0, 0, width, height, Class'RIUtil'.static.Col(20, 15, 6));
}

function DrawBorder(GC gc)
{
	if (!RIOn())
	{
		Super.DrawBorder(gc);
		return;
	}
	if (Class'RIVP'.static.On())
		return;
	Class'RIText'.static.Box(gc, 0, 0, width, height, Class'RIUtil'.static.Col(126, 105, 50));
	Class'RISkin'.static.FillC(gc, 0, 0, 3, height, Class'RIUtil'.static.Col(242, 211, 107));
}

defaultproperties
{
     colInfoText=(R=236,G=214,160)
}

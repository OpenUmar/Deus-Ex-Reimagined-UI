//=============================================================================
// RIInfoDisplay
// AE's reader for books, datacubes, newspapers and manuals, restyled for the
// rebuilt HUD. AE (or the original) still fills it through AddTextWindow;
// while the new look is on, those text windows stay hidden and their text
// is drawn here in the mod's own type, word-wrapped, inside a framed panel
// (Vanilla+: the mechanical frame with the original DX trim and a gold
// accent bar; Sleek: dark panel, gold hairline). The panel sizes itself to
// the text. With the HUD on Classic it draws exactly as the base's.
//=============================================================================
class RIInfoDisplay extends HUDInformationDisplay;

const PadX = 34;      // text inset from the window's sides (1080p pixels)
const PadY = 30;      // and from its top and bottom
const Edge = 10;      // the panel sits this far in, so the DX trim isn't clipped

var string SizedText;  // the text the panel was last sized for

function bool RIOn()
{
	return (RIDeusExHUD(GetParent()) != None) && RIDeusExHUD(GetParent()).bRI;
}

function float K()
{
	if ((GetParent() != None) && (GetParent().height > 0))
		return GetParent().height / 1080.0;
	return 1.0;
}

function float ReadSc()
{
	return 0.74;
}

// A paragraph without the spaces and line breaks round it
function string RITrim(string P)
{
	local bool bCut;

	bCut = True;
	while (bCut)
	{
		bCut = False;
		if (Left(P, 2) == "|n")       { P = Mid(P, 2); bCut = True; }
		else if (Left(P, 1) == " ")   { P = Mid(P, 1); bCut = True; }
		if (Right(P, 2) == "|n")      { P = Left(P, Len(P) - 2); bCut = True; }
		else if (Right(P, 1) == " ")  { P = Left(P, Len(P) - 1); bCut = True; }
	}
	return P;
}

// All the reader's text in reading order (the tile's first child is at the
// bottom of the window stack, so walk upward from it), one blank line
// between paragraphs whatever breaks the text itself carried
function string AllText()
{
	local Window W;
	local string T, P;

	if (winTile == None)
		return "";
	for (W = winTile.GetBottomChild(); W != None; W = W.GetHigherSibling())
	{
		if (TextWindow(W) == None)
			continue;
		P = RITrim(Class'RIConView'.static.Lines(TextWindow(W).GetText()));
		if (P == "")
			continue;
		if (T != "")
			T = T $ "|n|n";
		T = T $ P;
	}
	return T;
}

function bool HasImages()
{
	local Window W;

	if (winTile == None)
		return False;
	for (W = winTile.GetTopChild(); W != None; W = W.GetLowerSibling())
		if ((TextWindow(W) == None) && (W.IsVisible(False)))
			return True;
	return False;
}

// The new look only for plain text (pages with pictures keep the base's)
function bool Own()
{
	return RIOn() && !HasImages();
}

// The longest line, unwrapped
function float LongestLine(string T)
{
	local int p;
	local float w;

	while (T != "")
	{
		p = InStr(T, "|n");
		if (p < 0)
		{
			w = FMax(w, Class'RIText'.static.Width(Class'RIFontBody', T, ReadSc()));
			break;
		}
		w = FMax(w, Class'RIText'.static.Width(Class'RIFontBody', Left(T, p), ReadSc()));
		T = Mid(T, p + 2);
	}
	return w;
}

event ParentRequestedPreferredSize(bool bWidthSpecified, out float preferredWidth,
                                   bool bHeightSpecified, out float preferredHeight)
{
	local float s, inner;
	local string T;

	if (!Own())
	{
		if (!winTile.IsVisible(False))
			winTile.Show();
		Super.ParentRequestedPreferredSize(bWidthSpecified, preferredWidth, bHeightSpecified, preferredHeight);
		return;
	}
	s = K();
	T = AllText();
	SizedText = T;
	if (!bWidthSpecified)
		preferredWidth = FClamp(LongestLine(T) + 2 * PadX * s + 2 * Edge * s, 420 * s, 900 * s);
	inner = preferredWidth - 2 * PadX * s - 2 * Edge * s;
	preferredHeight = Class'RIText'.static.DrawWrapped(None, Class'RIFontBody', 0, 0, inner, T, Class'RIVP'.static.Txt(1), ReadSc(), 1.45)
		+ 2 * PadY * s + 2 * Edge * s;
	// never taller than the screen leaves room for (very long pages step
	// their type down in DrawReader instead of running off the screen)
	if ((GetParent() != None) && (GetParent().height > 0))
		preferredHeight = FMin(preferredHeight, GetParent().height * 0.8);
}

function ConfigurationChanged()
{
	Super.ConfigurationChanged();
	if (Own())
	{
		if (winTile.IsVisible(False))
			winTile.Hide();
	}
	else if (!winTile.IsVisible(False))
		winTile.Show();
}

function DrawBackground(GC gc)
{
	local int i;
	local float s, e;

	if (!RIOn())
	{
		Super.DrawBackground(gc);
		return;
	}
	s = K();
	e = Edge * s;
	if (Class'RIVP'.static.On())
	{
		Class'RIVP'.static.Dim(gc, e, e, width - 2 * e, height - 2 * e);
		Class'RIVP'.static.Dim(gc, e, e, width - 2 * e, height - 2 * e);
		Class'RIVP'.static.Frame(gc, e, e, width - 2 * e, height - 2 * e, 14 * s, 1);
		return;
	}
	// soft shadow round the panel, then the panel itself
	for (i = 1; i <= 4; i++)
		Class'RISkin'.static.DrawDim(gc, e - i * 6, e - i * 6, width - 2 * e + i * 12, height - 2 * e + i * 12, 0.08);
	Class'RISkin'.static.FillC(gc, e, e, width - 2 * e, height - 2 * e, Class'RIUtil'.static.Col(20, 15, 6));
}

function DrawBorder(GC gc)
{
	local float s, e;

	if (!RIOn())
	{
		Super.DrawBorder(gc);
		return;
	}
	s = K();
	e = Edge * s;
	if (Class'RIVP'.static.On())
		// accent bar inside the frame's left edge
		Class'RISkin'.static.FillC(gc, e + 10 * s, e + 14 * s, 2 * s, height - 2 * e - 28 * s, Class'RIVP'.static.Acc(1));
	else
	{
		Class'RIText'.static.Box(gc, e, e, width - 2 * e, height - 2 * e, Class'RIUtil'.static.Col(126, 105, 50));
		Class'RISkin'.static.FillC(gc, e, e, 3, height - 2 * e, Class'RIUtil'.static.Col(242, 211, 107));
	}
	if (Own())
		DrawReader(gc, s, e);
}

// The text, at the reader's size; if the HUD gave the window less height
// than it asked for (very long pages), the type steps down until it fits
function DrawReader(GC gc, float s, float e)
{
	local string T;
	local float sc, iw, ih;

	T = AllText();
	// The base fills its text windows AFTER asking for a new size (AddTextWindow
	// asks, then the text is set), so the panel was sized for an unfinished
	// page: its type shrank and the end was cut off. Size again for the text
	// as it is now; the next frame draws it at the normal size.
	if (T != SizedText)
	{
		SizedText = T;
		AskParentForReconfigure();
	}
	iw = width - 2 * PadX * s - 2 * e;
	ih = height - 2 * PadY * s - 2 * e;
	sc = ReadSc();
	while ((sc > 0.5) && (Class'RIText'.static.DrawWrapped(None, Class'RIFontBody', 0, 0, iw, T, Class'RIVP'.static.Txt(1), sc, 1.45) > ih))
		sc -= 0.04;
	Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', e + PadX * s, e + PadY * s, iw, T, Class'RIVP'.static.Txt(1), sc, 1.45);
}

defaultproperties
{
     colInfoText=(R=236,G=214,160)
}

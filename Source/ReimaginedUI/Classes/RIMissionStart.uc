//=============================================================================
// RIMissionStart
// AE's mission start text (the location lines typed out after a new mission
// loads), restyled for the rebuilt HUD: bottom left, the mission number
// small, the first line large in caps, further lines in the body font, over
// a soft backing with a gold rule. AE still decides the text and the timing
// (one character a frame, then a hold); this draws what has been typed so
// far and fades out at the end. With the HUD on Classic it draws as AE's.
//=============================================================================
class RIMissionStart extends HUDMissionStartTextDisplay;

var float HoldStart;
var localized string MissionWord;

function bool RIOn()
{
	return (RIDeusExHUD(GetParent()) != None) && RIDeusExHUD(GetParent()).bRI;
}

function StartMessage()
{
	Super.StartMessage();
	HoldStart = default.displayTime;
	if (RIOn())
	{
		winText.Hide();
		winTextShadow.Hide();
	}
}

function Color Col(float R, float G, float B, float a)
{
	return Class'RIUtil'.static.Col(R * a, G * a, B * a);
}

event DrawWindow(GC gc)
{
	local float S, x, y, a, lh, w, h;
	local string Typed, Line, Rest;
	local int p, n, mn;
	local DeusExLevelInfo Info;
	local DeusExPlayer DP;

	if (!RIOn())
		return;
	if (winText.IsVisible(False))
	{
		winText.Hide();
		winTextShadow.Hide();
	}
	Class'RITheme'.static.SetMode(2);
	S = height / 1080.0;
	a = 1.0;
	if (!bSpewingText)
		a = FClamp(displayTime / 0.8, 0, 1);
	if (a <= 0.01)
		return;

	Typed = Left(message, charIndex);
	x = 120 * S;
	lh = 30 * S;

	// count lines for the backing height
	n = 0;
	Rest = message;
	while (Rest != "")
	{
		p = InStr(Rest, "|n");
		if (p < 0)
			Rest = "";
		else
			Rest = Mid(Rest, p + 2);
		n++;
	}
	h = 40 * S + 44 * S + Max(0, n - 1) * lh + 24 * S;
	w = 760 * S;
	y = height - 300 * S - h;
	if (Class'RIVP'.static.On())
		Class'RIVP'.static.Panel(gc, x - 8 * S, y - 8 * S, w + 16 * S, h + 16 * S, 12 * S, a);
	else
	{
		Class'RISkin'.static.DrawDim(gc, x, y, w, h, 0.45 * a);
		Class'RISkin'.static.DrawDim(gc, x, y, w * 0.6, h, 0.25 * a);
		Class'RISkin'.static.FillC(gc, x, y, 2 * S, h, Col(242, 211, 107, a));
	}

	// (the original's mission text window keeps no player; AE's does)
	DP = DeusExPlayer(GetPlayerPawn());
	if (DP != None)
		Info = DP.GetLevelInfo();
	if (Info != None)
		mn = Info.MissionNumber;
	y += 20 * S;
	if (mn > 0)
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', x + 26 * S, y, Caps(MissionWord) @ Right("0" $ string(mn), 2), Col(168, 143, 78, a), 0.62);
	y += 26 * S;

	n = 0;
	Rest = Typed;
	while ((Rest != "") && (n < 6))
	{
		p = InStr(Rest, "|n");
		if (p < 0)
		{
			Line = Rest;
			Rest = "";
		}
		else
		{
			Line = Left(Rest, p);
			Rest = Mid(Rest, p + 2);
		}
		if (n == 0)
		{
			Class'RIText'.static.Draw(gc, Class'RIFontTitle', x + 26 * S, y, Caps(Line), Col(255, 241, 194, a), 0.5);
			y += 44 * S;
		}
		else
		{
			Class'RIText'.static.Draw(gc, Class'RIFontBody', x + 26 * S, y, Line, Col(230, 195, 117, a), 0.82);
			y += lh;
		}
		n++;
	}
	// typing cursor
	if (bSpewingText)
		Class'RISkin'.static.FillC(gc, x + 26 * S, y + 2 * S, 10 * S, 2 * S, Col(242, 211, 107, a));
}


defaultproperties
{
     MissionWord="Mission"
}

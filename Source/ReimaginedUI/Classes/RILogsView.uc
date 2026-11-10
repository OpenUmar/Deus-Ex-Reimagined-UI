//=============================================================================
// RILogsView
// Journal > Logs, in the original gold: every log message (goals, items
// received, InfoLink lines...), newest first, wrapped in full. Clear Log
// runs AE's own ClearLog.
//=============================================================================
class RILogsView extends RIPersonaView;

const HOT_CLEAR = 50;

var string Lines[512];
var int   NumLines;
var float Scroll, ScrollTarget, ScrollMax, Top, Bottom;

var localized string LogsTitle, ClearLabel, NoneLabel, HintText, CountLabel;

function ScreenAttached()
{
	ActiveTab = TAB_LOGS;
	Class'RIPersonaView'.default.JournalLast = TAB_LOGS;
	Gather();
}

// AE adds new messages at the front of the list: that order is newest first
function Gather()
{
	local DeusExLog L;

	NumLines = 0;
	for (L = Player.FirstLog; (L != None) && (NumLines < 512); L = L.next)
		Lines[NumLines++] = L.text;
}

function PageClick(int Id, EInputKey button, int numClicks)
{
	if ((button == IK_LeftMouse) && (Id == HOT_CLEAR) && (NumLines > 0))
	{
		PlaySound(Sound'Menu_Press', 0.25);
		Player.ClearLog();
		Gather();
		Scroll = 0;
		ScrollTarget = 0;
	}
}

function bool PageKey(EInputKey key, bool bRepeat)
{
	if ((key == IK_MouseWheelUp) || (key == IK_Up))
	{
		ScrollTarget -= 90 * S;
		return True;
	}
	if ((key == IK_MouseWheelDown) || (key == IK_Down))
	{
		ScrollTarget += 90 * S;
		return True;
	}
	return False;
}

function PageTick(float deltaSeconds)
{
	ScrollTarget = FClamp(ScrollTarget, 0, FMax(0, ScrollMax));
	Scroll += (ScrollTarget - Scroll) * FMin(1.0, deltaSeconds * 14.0);
}

function DrawPage(GC gc, float a)
{
	local float x, y, w, th, sh, kh, ra;
	local int i, st;

	if (VPlus())
	{
		// the log in the left frame; count and Clear on the right
		x = OX + 404 * S;
		w = 568 * S;
		Top = 182 * S;
		Bottom = 936 * S;
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', OX + 1072 * S, 177 * S, 446 * S, 28 * S, Caps(LogsTitle), ATxt(a), 0, 0.5);
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', OX + 1072 * S, 226 * S, 446 * S, 30 * S, Caps(CountLabel) @ string(NumLines), ALbl(a), 0, 0.6);
		DrawBtn(gc, OX + 1182 * S, 784 * S, 168 * S, 40 * S, ClearLabel, NumLines > 0, HoverId == HOT_CLEAR, False, a);
		AddHot(HOT_CLEAR, OX + 1182 * S, 784 * S, 168 * S, 40 * S);
	}
	else
	{
		x = OX + 140 * S;
		w = 1640 * S;
		Heading(gc, x, 170 * S, w, LogsTitle, a);
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x, 170 * S, w - 250 * S, 40 * S,
			Caps(CountLabel) @ string(NumLines), ALbl(a), 2, 0.7);
		DrawBtn(gc, x + w - 220 * S, 166 * S, 220 * S, 44 * S, ClearLabel, NumLines > 0, HoverId == HOT_CLEAR, False, a);
		AddHot(HOT_CLEAR, x + w - 220 * S, 166 * S, 220 * S, 44 * S);
		Top = 240 * S;
		Bottom = 960 * S;
	}
	st = gc.PushGC();
	gc.Intersect(x - 4 * S, Top, w + 8 * S, Bottom - Top);
	y = Top - Scroll;
	for (i = 0; i < NumLines; i++)
	{
		ra = a * Class'RIUtil'.static.Phase(Age, 0.05 + FMin(i, 20) * 0.015, 0.2);
		Fill(gc, x, y + 10 * S, 6 * S, 6 * S, C3(150, 126, 62, ra));
		th = Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', x + 24 * S, y, w - 60 * S, Lines[i],
			Class'RIUtil'.static.Mix(C3(236, 216, 168, ra), C3(255, 246, 215, ra), int(i < 3)), 0.78, 1.36);
		y += FMax(th, 26 * S) + 10 * S;
		Class'RIText'.static.HLine(gc, x + 24 * S, y - 5 * S, w - 60 * S, C3(46, 38, 18, ra));
	}
	gc.PopGC(st);
	ScrollMax = FMax(0, (y + Scroll - Top) - (Bottom - Top));
	if (ScrollMax > 1)
	{
		sh = Bottom - Top;
		kh = FMax(30 * S, sh * sh / (sh + ScrollMax));
		Fill(gc, x + w - 6 * S, Top, 2 * S, sh, C3(50, 42, 20, a));
		Fill(gc, x + w - 6 * S, Top + (sh - kh) * (Scroll / ScrollMax), 2 * S, kh, AAcc(a));
	}
	if (NumLines == 0)
		Class'RIText'.static.Draw(gc, Class'RIFontBody', x, Top, NoneLabel, ALbl(a), 0.8);
	if (!VPlus())
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', OX + 140 * S, FY + FH + 22 * S, HintText, ALbl(a * 0.8), 0.7);
}

defaultproperties
{
     LogsTitle="Logs"
     ClearLabel="Clear log"
     NoneLabel="The log is empty."
     CountLabel="Messages"
     HintText="WHEEL or UP / DOWN scroll     ESC close"
     bHideScreen=True
}

//=============================================================================
// RIConsView
// Journal > Conversations, in the original gold. Left: every conversation
// and InfoLink so far, newest first (contact, location, kind). Right: the
// selected one's transcript, speaker by speaker. Reads AE's own history.
//=============================================================================
class RIConsView extends RIPersonaView;

const HOT_ROW = 100;        // + row

var ConHistory Hist[256];
var int   NumHist, Sel;
var float DescAge;
var float ListScroll, ListScrollTarget, ListMax, ListTop, ListBottom, ListRight;
var float TxScroll, TxScrollTarget, TxMax, TxTop, TxBottom;

var localized string ConsTitle, InfoLinkLabel, SpokenLabel, NoneLabel, PickLabel, HintText;

function ScreenAttached()
{
	ActiveTab = TAB_CONS;
	Class'RIPersonaView'.default.JournalLast = TAB_CONS;
	Gather();
	Sel = -1;
	if (NumHist > 0)
		SelectRow(0);
}

// Newest first (AE's history list runs oldest to newest)
function Gather()
{
	local ConHistory H;
	local ConHistory Tmp[256];
	local int n, i;

	n = 0;
	for (H = Player.ConHistory; (H != None) && (n < 256); H = H.next)
		Tmp[n++] = H;
	NumHist = n;
	for (i = 0; i < n; i++)
		Hist[i] = Tmp[n - 1 - i];
}

function SelectRow(int i)
{
	if ((i < 0) || (i >= NumHist) || (i == Sel))
		return;
	Sel = i;
	DescAge = 0;
	TxScroll = 0;
	TxScrollTarget = 0;
}

function PageClick(int Id, EInputKey button, int numClicks)
{
	if ((button == IK_LeftMouse) && (Id >= HOT_ROW) && (Id < HOT_ROW + 256))
	{
		SelectRow(Id - HOT_ROW);
		PlaySound(Sound'Menu_Press', 0.2);
	}
}

function bool PageKey(EInputKey key, bool bRepeat)
{
	local bool bOverList;

	bOverList = (LastMouseX < ListRight);
	if (key == IK_MouseWheelUp)
	{
		if (bOverList)
			ListScrollTarget -= 90 * S;
		else
			TxScrollTarget -= 90 * S;
		return True;
	}
	if (key == IK_MouseWheelDown)
	{
		if (bOverList)
			ListScrollTarget += 90 * S;
		else
			TxScrollTarget += 90 * S;
		return True;
	}
	if (key == IK_Up)
	{
		SelectRow(Max(0, Sel - 1));
		return True;
	}
	if (key == IK_Down)
	{
		SelectRow(Min(NumHist - 1, Sel + 1));
		return True;
	}
	return False;
}

function PageTick(float deltaSeconds)
{
	DescAge += deltaSeconds;
	ListScrollTarget = FClamp(ListScrollTarget, 0, FMax(0, ListMax));
	ListScroll += (ListScrollTarget - ListScroll) * FMin(1.0, deltaSeconds * 14.0);
	TxScrollTarget = FClamp(TxScrollTarget, 0, FMax(0, TxMax));
	TxScroll += (TxScrollTarget - TxScroll) * FMin(1.0, deltaSeconds * 14.0);
}

function DrawPage(GC gc, float a)
{
	DrawList(gc, a);
	DrawTranscript(gc, a * Class'RIUtil'.static.Phase(DescAge, 0.0, 0.2));
	if (VPlus())
		return;
	Class'RIText'.static.VLine(gc, OX + 790 * S, 170 * S, 790 * S, ADim(a));
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', OX + 140 * S, FY + FH + 22 * S, HintText, ALbl(a * 0.8), 0.7);
}

function DrawList(GC gc, float a)
{
	local float x, y, w, rh, sh, kh, cw;
	local int i, st;
	local bool bSel, bHot;
	local string K;

	x = OX + 140 * S;
	w = 620 * S;
	ListTop = 236 * S;
	ListBottom = 960 * S;
	if (VPlus())
	{
		x = OX + 404 * S;
		w = 552 * S;
		ListTop = 182 * S;
		ListBottom = 936 * S;
	}
	else
		Heading(gc, x, 170 * S, w, ConsTitle, a);
	ListRight = x + w + 20 * S;
	rh = 68 * S;
	st = gc.PushGC();
	gc.Intersect(x - 4 * S, ListTop, w + 8 * S, ListBottom - ListTop);
	y = ListTop - ListScroll;
	for (i = 0; i < NumHist; i++)
	{
		bSel = (i == Sel);
		bHot = (HoverId == HOT_ROW + i);
		if (bSel)
			SelRow(gc, x, y, w, rh, a);
		else if (bHot)
			Class'RIText'.static.Box(gc, x, y, w, rh, AEdge(a));
		else
			Class'RIText'.static.HLine(gc, x + 8 * S, y + rh, w - 16 * S, C3(60, 50, 24, a));
		if (Hist[i].bInfoLink)
			K = InfoLinkLabel;
		else
			K = SpokenLabel;
		cw = Class'RIText'.static.Width(Class'RIFontSmall', Caps(K), 0.56) + 16 * S;
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x + 16 * S, y + 8 * S, w - cw - 40 * S, 30 * S,
			Caps(Class'RIText'.static.Fit(Class'RIFontHead', Hist[i].conOwnerName, w - cw - 40 * S, 0.52)),
			Class'RIUtil'.static.Mix(ATxt(a), C3(255, 255, 255, a), int(bSel)), 0, 0.52);
		if (Hist[i].bInfoLink)
			Class'RIText'.static.Box(gc, x + w - cw - 14 * S, y + 12 * S, cw, 22 * S, C3(111, 183, 201, a));
		else
			Class'RIText'.static.Box(gc, x + w - cw - 14 * S, y + 12 * S, cw, 22 * S, AEdge(a));
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x + w - cw - 14 * S, y + 12 * S, cw, 22 * S, Caps(K), ALbl(a), 1, 0.56);
		Class'RIText'.static.DrawIn(gc, Class'RIFontBody', x + 16 * S, y + 36 * S, w - 32 * S, 26 * S,
			Class'RIText'.static.Fit(Class'RIFontBody', Hist[i].strLocation, w - 32 * S, 0.7), ALbl(a), 0, 0.7);
		if ((y + rh > ListTop) && (y < ListBottom))
			AddHot(HOT_ROW + i, x, FMax(y, ListTop), w, FMin(y + rh, ListBottom) - FMax(y, ListTop));
		y += rh + 6 * S;
	}
	gc.PopGC(st);
	ListMax = FMax(0, (y + ListScroll - ListTop) - (ListBottom - ListTop));
	if (ListMax > 1)
	{
		sh = ListBottom - ListTop;
		kh = FMax(30 * S, sh * sh / (sh + ListMax));
		Fill(gc, x + w + 8 * S, ListTop, 2 * S, sh, C3(50, 42, 20, a));
		Fill(gc, x + w + 8 * S, ListTop + (sh - kh) * (ListScroll / ListMax), 2 * S, kh, AAcc(a));
	}
	if (NumHist == 0)
		Class'RIText'.static.Draw(gc, Class'RIFontBody', x, ListTop, NoneLabel, ALbl(a), 0.8);
}

function DrawTranscript(GC gc, float a)
{
	local float x, y, w, sw, th, sh, kh;
	local int st;
	local ConHistory H;
	local ConHistoryEvent E;
	local bool bJC;

	x = OX + 820 * S;
	w = 960 * S;
	y = 170 * S;
	if (VPlus())
	{
		x = OX + 1072 * S;
		w = 446 * S;
	}
	if ((Sel < 0) || (Sel >= NumHist))
	{
		if (VPlus())
			Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x, 177 * S, w, 28 * S, Caps(PickLabel), ALbl(a), 0, 0.46);
		else
			Class'RIText'.static.Draw(gc, Class'RIFontBody', x, y + 10 * S, PickLabel, ALbl(a), 0.8);
		return;
	}
	H = Hist[Sel];
	if (VPlus())
	{
		// name in the title bar, kind and place in the footer, transcript in the body
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x, 177 * S, w, 28 * S, Caps(Class'RIText'.static.Fit(Class'RIFontHead', H.conOwnerName, w, 0.5)), ATxt(a), 0, 0.5);
		if (H.bInfoLink)
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x, 670 * S, w, 30 * S, Caps(InfoLinkLabel $ "  //  " $ H.strLocation), ALbl(a), 0, 0.54);
		else
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x, 670 * S, w, 30 * S, Caps(SpokenLabel $ "  //  " $ H.strLocation), ALbl(a), 0, 0.54);
		TxTop = 224 * S;
		TxBottom = 652 * S;
		sw = 110 * S;
	}
	else
	{
		Class'RIText'.static.Draw(gc, Class'RIFontTitle', x + (1 - a) * 8 * S, y, Caps(Class'RIText'.static.Fit(Class'RIFontTitle', H.conOwnerName, w, 0.44)), ATxt(a), 0.44);
		if (H.bInfoLink)
			Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y + 48 * S, Caps(InfoLinkLabel $ "  //  " $ H.strLocation), ALbl(a), 0.66);
		else
			Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y + 48 * S, Caps(SpokenLabel $ "  //  " $ H.strLocation), ALbl(a), 0.66);
		Class'RIText'.static.HLine(gc, x, y + 80 * S, w, ADim(a));
		TxTop = y + 96 * S;
		TxBottom = 960 * S;
		sw = 200 * S;
	}
	st = gc.PushGC();
	gc.Intersect(x - 4 * S, TxTop, w + 8 * S, TxBottom - TxTop);
	y = TxTop - TxScroll;
	for (E = H.firstEvent; E != None; E = E.next)
	{
		bJC = (E.conSpeaker == Player.TruePlayerName) || (E.conSpeaker == "JC Denton") || (E.conSpeaker == "JC");
		if (bJC)
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x, y + 2 * S, sw - 16 * S, 24 * S,
				Caps(Class'RIText'.static.Fit(Class'RIFontSmall', E.conSpeaker, sw - 16 * S, 0.62)), AHi(a), 0, 0.62);
		else
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x, y + 2 * S, sw - 16 * S, 24 * S,
				Caps(Class'RIText'.static.Fit(Class'RIFontSmall', E.conSpeaker, sw - 16 * S, 0.62)), ALbl(a), 0, 0.62);
		if (bJC)
			th = Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', x + sw, y, w - sw - 16 * S, E.speech, C3(200, 172, 112, a), 0.78, 1.38);
		else
			th = Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', x + sw, y, w - sw - 16 * S, E.speech, C3(236, 216, 168, a), 0.78, 1.38);
		y += FMax(th, 28 * S) + 14 * S;
	}
	gc.PopGC(st);
	TxMax = FMax(0, (y + TxScroll - TxTop) - (TxBottom - TxTop));
	if (TxMax > 1)
	{
		sh = TxBottom - TxTop;
		kh = FMax(30 * S, sh * sh / (sh + TxMax));
		Fill(gc, x + w + 8 * S, TxTop, 2 * S, sh, C3(50, 42, 20, a));
		Fill(gc, x + w + 8 * S, TxTop + (sh - kh) * (TxScroll / TxMax), 2 * S, kh, AAcc(a));
	}
}

defaultproperties
{
     ConsTitle="Conversations"
     InfoLinkLabel="InfoLink"
     SpokenLabel="Spoken"
     NoneLabel="No conversations yet."
     PickLabel="Select a conversation."
     HintText="CLICK select     UP / DOWN move     WHEEL scroll     ESC close"
     bHideScreen=True
}

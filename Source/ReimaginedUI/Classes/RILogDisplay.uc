//=============================================================================
// RILogDisplay
// AE's message log ("Light deactivated", "Goal Received", "You found some
// 10mm Ammo"...) for the rebuilt HUD. AE's logic is untouched (when it
// shows, hides, pauses for the InfoLink, plays its sound); only the look is
// new: no riveted box or icon, the lines in the HUD's fonts over a soft
// backing with a gold rule, each line fading when its time is up, and a
// line repeated back to back shown once with a count ("x3").
// AE's own text window keeps running hidden. With the HUD on Classic it
// draws exactly as AE's.
//=============================================================================
class RILogDisplay extends HUDLogDisplay;

const MAXL = 8;

var string LText[8];
var float  LAge[8];
var int    LCount[8];
var int    NumL;

// Pickup lines wait one tick here: AE posts some pickups to its Received
// list as well (corpses, ammo) and some only as a log line (items picked
// up from the floor). Those with no Received entry are added to it.
// The panel as last drawn (window coordinates), for RIHud to stack the
// Received box under it; MatchW is the Received box's width, so the two
// boxes share one width while both are up (Vanilla+)
var float PanelX, PanelY, PanelH, NatW, MatchW;

var string PText[8];
var int    PTicks[8];
var int    PNum;

function bool RIOn()
{
	return (RIDeusExHUD(GetParent()) != None) && RIDeusExHUD(GetParent()).bRI;
}

function bool IsPickupLine(string L)
{
	local string P;

	P = Class'DeusExPickup'.default.PickupMessage;
	return (P != "") && (Left(L, Len(P) + 1) == (P $ " "));
}

function float K()
{
	if ((GetParent() != None) && (GetParent().height > 0))
		return GetParent().height / 1080.0;
	return 1.0;
}

function AddLog(coerce String newLog, Color linecol)
{
	Super.AddLog(newLog, linecol);
	if (newLog == "")
		return;
	// "You found:" (searching a body) only heads the Received box, which
	// says it already: not repeated as a log line
	if (RIOn() && (newLog == Class'DeusExCarcass'.default.msgSearching))
		return;
	// Pickups appear as item toasts on the right (AE's received list)
	if (RIOn() && IsPickupLine(newLog))
	{
		if (PNum < 8)
		{
			PText[PNum] = newLog;
			PTicks[PNum] = 0;
			PNum++;
		}
		return;
	}
	RecordLine(newLog);
}

function RecordLine(string newLog)
{
	local int i;

	if ((NumL > 0) && (LText[NumL - 1] == newLog))
	{
		LCount[NumL - 1]++;
		LAge[NumL - 1] = 0;
	}
	else
	{
		if (NumL >= MAXL)
		{
			for (i = 1; i < MAXL; i++)
			{
				LText[i - 1] = LText[i];
				LAge[i - 1] = LAge[i];
				LCount[i - 1] = LCount[i];
			}
			NumL = MAXL - 1;
		}
		LText[NumL] = newLog;
		LAge[NumL] = 0;
		LCount[NumL] = 1;
		NumL++;
	}
	AskParentForReconfigure();
}

// Called by RIHud every tick
function FlushPickups()
{
	local int i, j;

	for (i = 0; i < PNum; i++)
		PTicks[i]++;
	while ((PNum > 0) && (PTicks[0] >= 1))
	{
		ShowPickup(PText[0]);
		for (j = 1; j < PNum; j++)
		{
			PText[j - 1] = PText[j];
			PTicks[j - 1] = PTicks[j];
		}
		PNum--;
	}
}

// "You found a Flare", "You found 10mm Ammo (12)": the item is the one in
// the inventory whose name the line holds (the longest match). Lines that
// say anything else after the name (declined, too many...) stay in the log.
function ShowPickup(string L)
{
	local Inventory Inv, Best;
	local string Tail, IName;
	local int Cnt, BestLen;
	local Texture Ic;
	local HUDReceivedDisplay R;

	if ((player == None) || (DeusExRootWindow(player.rootWindow) == None) || (DeusExRootWindow(player.rootWindow).hud == None))
	{
		RecordLine(L);
		return;
	}
	R = DeusExRootWindow(player.rootWindow).hud.receivedItems;
	for (Inv = player.Inventory; Inv != None; Inv = Inv.Inventory)
	{
		IName = Inv.itemName;
		if ((IName != "") && (Len(IName) > BestLen) && (InStr(L, IName) >= 0))
		{
			Best = Inv;
			BestLen = Len(IName);
		}
	}
	if ((Best == None) || (R == None))
	{
		RecordLine(L);
		return;
	}
	Tail = Mid(L, InStr(L, Best.itemName) + BestLen);
	Cnt = 1;
	if (Tail != "")
	{
		if ((Left(Tail, 2) == " (") && (Right(Tail, 1) == ")"))
			Cnt = int(Mid(Tail, 2, Len(Tail) - 3));
		else
			Cnt = 0;
		if (Cnt <= 0)
		{
			RecordLine(L);
			return;
		}
	}
	Ic = Class'RIBase'.static.ItemIcon(Best);
	if (Showing(R, Ic))
		return;
	Class'RIBase'.static.Receive(player, R, Best, Cnt);
}

function bool Showing(HUDReceivedDisplay R, Texture Ic)
{
	local int i, n, Qty;
	local Texture T;
	local string Lbl;
	local byte bDecl;

	if (!R.bTickEnabled)
		return False;
	n = Class'RIBase'.static.ReceivedCount(R);
	for (i = 0; i < n; i++)
		if (Class'RIBase'.static.ReceivedItem(R, i, T, Lbl, Qty, bDecl) && (T == Ic))
			return True;
	return False;
}

event Tick(float deltaSeconds)
{
	local int i, j;
	local bool bDrop;

	Super.Tick(deltaSeconds);
	if (RIOn())
		HideOriginal();
	if (!IsVisible())
		return;
	for (i = 0; i < NumL; i++)
		LAge[i] += deltaSeconds;
	// lines past their time leave from the top
	while ((NumL > 0) && (LAge[0] > FMax(1.0, displayTime) + 0.5))
	{
		for (j = 1; j < NumL; j++)
		{
			LText[j - 1] = LText[j];
			LAge[j - 1] = LAge[j];
			LCount[j - 1] = LCount[j];
		}
		NumL--;
		bDrop = True;
	}
	if (bDrop)
		AskParentForReconfigure();
}

event ParentRequestedPreferredSize(bool bWidthSpecified, out float preferredWidth,
                                   bool bHeightSpecified, out float preferredHeight)
{
	if (!RIOn())
	{
		Super.ParentRequestedPreferredSize(bWidthSpecified, preferredWidth, bHeightSpecified, preferredHeight);
		return;
	}
	// + room round the panel for the Vanilla+ frame's DX border
	preferredHeight = (16 + Max(1, NumL) * 22 + 26) * K();
}

function ConfigurationChanged()
{
	Super.ConfigurationChanged();
	if (RIOn())
		HideOriginal();
	else
	{
		if (!winIcon.IsVisible(False))
			winIcon.Show();
		if (!winLog.IsVisible(False))
			winLog.Show();
	}
}

// The original icon and text window stay hidden while the new look is on
// (each checked on its own: the icon alone was turning up)
function HideOriginal()
{
	if (winIcon.IsVisible(False))
		winIcon.Hide();
	if (winLog.IsVisible(False))
		winLog.Hide();
}

function DrawBackground(GC gc)
{
	if (!RIOn())
		Super.DrawBackground(gc);
}

// Everything is drawn here, after the (empty) background: a compact list on
// the left, small type, a thin gold rule beside it and a soft shade that
// stops just past the longest line (no box), newest line at the bottom
function DrawBorder(GC gc)
{
	if (!RIOn())
	{
		Super.DrawBorder(gc);
		return;
	}
	if (Class'RIRootWindow'.static.HudTiltDeg() > 0)
		Class'RIText'.static.Begin3D(Self, gc, -1, Class'RIRootWindow'.static.HudTiltDeg());
	DrawLog(gc);
	Class'RIText'.static.End3D();
}

function DrawLog(GC gc)
{
	local int i;
	local float S, y, lh, a, bh, tw, w, maxw, sc, ox, oy;
	local string T;

	if (!RIOn())
	{
		Super.DrawBorder(gc);
		return;
	}
	HideOriginal();
	if (NumL <= 0)
	{
		NatW = 0;
		PanelH = 0;
		return;
	}
	Class'RITheme'.static.SetMode(2);
	S = K();
	sc = 0.6;
	lh = 22 * S;
	bh = 16 * S + NumL * lh;
	maxw = width - 60 * S;
	// the panel sits in from the window's edge so the DX border drawn round
	// it (Vanilla+) isn't clipped
	ox = 8 * S;
	oy = 10 * S;

	// the shade spans the widest line (with its count)
	w = 0;
	for (i = 0; i < NumL; i++)
	{
		tw = Class'RIText'.static.Width(Class'RIFontBody', Class'RIText'.static.Fit(Class'RIFontBody', LText[i], maxw, sc), sc);
		if (LCount[i] > 1)
			tw += 40 * S;
		w = FMax(w, tw);
	}
	w = FMin(width - 2 * ox, w + 34 * S);
	NatW = w;
	if (Class'RIVP'.static.On())
		w = FMin(width - 2 * ox, FMax(w, MatchW));
	if (Class'RIVP'.static.On())
	{
		// Vanilla+: darkened game, the mechanical frame and the original DX
		// border round it (as the screens' panels), accent bar inside the left
		Class'RIVP'.static.Dim(gc, ox + 3 * S, oy + 3 * S, w - 6 * S, bh - 6 * S);
		Class'RIVP'.static.Frame(gc, ox, oy, w, bh, 12 * S, 1);
		Class'RISkin'.static.FillC(gc, ox + 6 * S, oy + 7 * S, 2 * S, bh - 14 * S, Class'RIVP'.static.Acc(1));
	}
	else
	{
		ox = 0;
		oy = 0;
		Class'RISkin'.static.DrawDim(gc, 0, 0, w, bh, 0.35);
		Class'RISkin'.static.DrawDim(gc, w, 0, FMin(28 * S, width - w), bh, 0.15);
		Class'RISkin'.static.FillC(gc, 0, 0, 2 * S, bh, Class'RIUtil'.static.Col(242, 211, 107));
	}
	PanelX = ox;
	PanelY = oy;
	PanelH = bh;

	y = oy + 8 * S;
	for (i = 0; i < NumL; i++)
	{
		a = FClamp((FMax(1.0, displayTime) + 0.5 - LAge[i]) / 0.5, 0, 1) * FClamp(LAge[i] / 0.12, 0.3, 1);
		T = Class'RIText'.static.Fit(Class'RIFontBody', LText[i], maxw, sc);
		Class'RIText'.static.DrawIn(gc, Class'RIFontBody', ox + 16 * S, y, maxw, lh, T,
			Class'RIUtil'.static.Col(236 * a, 214 * a, 160 * a), 0, sc);
		if (LCount[i] > 1)
		{
			tw = Class'RIText'.static.Width(Class'RIFontBody', T, sc);
			Class'RIText'.static.DrawIn(gc, Class'RIFontHead', ox + 16 * S + tw + 10 * S, y, 40 * S, lh, "x" $ LCount[i],
				Class'RIUtil'.static.Col(242 * a, 211 * a, 107 * a), 0, 0.42);
		}
		y += lh;
	}
}

defaultproperties
{
}

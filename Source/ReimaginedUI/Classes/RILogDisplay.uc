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
	if (Best.IsA('DeusExAmmo'))
		Ic = DeusExAmmo(Best).GetHDTPIcon();
	else
		Ic = Best.icon;
	if (Showing(R, Ic))
		return;
	player.AddReceivedItem("", Best, Cnt);
}

function bool Showing(HUDReceivedDisplay R, Texture Ic)
{
	local int i;

	if (!R.bTickEnabled)
		return False;
	for (i = 0; (i < R.displayItemNum) && (i < 60); i++)
		if ((R.displayItems[i] != None) && (R.displayItems[i].itemIcon == Ic))
			return True;
	return False;
}

event Tick(float deltaSeconds)
{
	local int i, j;
	local bool bDrop;

	Super.Tick(deltaSeconds);
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
	preferredHeight = (24 + Max(1, NumL) * 30) * K();
}

function ConfigurationChanged()
{
	Super.ConfigurationChanged();
	if (RIOn())
	{
		if (winIcon.IsVisible(False))
			winIcon.Hide();
		if (winLog.IsVisible(False))
			winLog.Hide();
	}
	else
	{
		if (!winIcon.IsVisible(False))
			winIcon.Show();
		if (!winLog.IsVisible(False))
			winLog.Show();
	}
}

function DrawBackground(GC gc)
{
	if (!RIOn())
		Super.DrawBackground(gc);
}

// Everything is drawn here, after the (empty) background
function DrawBorder(GC gc)
{
	local int i, n;
	local float S, y, lh, a, bh, tw;
	local string T;

	if (!RIOn())
	{
		Super.DrawBorder(gc);
		return;
	}
	if (winLog.IsVisible(False))
	{
		winIcon.Hide();
		winLog.Hide();
	}
	if (NumL <= 0)
		return;
	Class'RITheme'.static.SetMode(2);
	S = K();
	lh = 30 * S;
	bh = 24 * S + NumL * lh;

	// soft backing, darker in the middle, a gold rule on the left
	if (Class'RIVP'.static.On())
		Class'RIVP'.static.Panel(gc, 0, 0, width, bh, 10 * S, 1);
	else
	{
		Class'RISkin'.static.DrawDim(gc, 0, 0, width, bh, 0.3);
		Class'RISkin'.static.DrawDim(gc, width * 0.08, 0, width * 0.84, bh, 0.25);
		Class'RISkin'.static.FillC(gc, 0, 0, 2 * S, bh, Class'RIUtil'.static.Col(242, 211, 107));
	}

	y = 12 * S;
	for (i = 0; i < NumL; i++)
	{
		a = FClamp((FMax(1.0, displayTime) + 0.5 - LAge[i]) / 0.5, 0, 1) * FClamp(LAge[i] / 0.12, 0.3, 1);
		T = LText[i];
		Class'RIText'.static.Draw(gc, Class'RIFontBody', 22 * S, y, T,
			Class'RIUtil'.static.Col(236 * a, 214 * a, 160 * a), 0.8);
		if (LCount[i] > 1)
		{
			tw = Class'RIText'.static.Width(Class'RIFontBody', T, 0.8);
			Class'RIText'.static.Draw(gc, Class'RIFontHead', 22 * S + tw + 14 * S, y + 3 * S, "x" $ LCount[i],
				Class'RIUtil'.static.Col(242 * a, 211 * a, 107 * a), 0.5);
		}
		y += lh;
		n++;
	}
}

defaultproperties
{
}

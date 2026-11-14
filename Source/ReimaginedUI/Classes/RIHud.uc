//=============================================================================
// RIHud
// The in-game HUD, rebuilt in the original gold (design: HUD v2 boards).
// Sits over AE's DeusExHUD and draws: the body monitor (remade figure, each
// part tinted by its health, white flash on damage), health / bioenergy /
// breath bars and stance, the compass (top centre), active augs and charged
// items (bottom left), the belt (bottom centre) and the weapon card (bottom
// right). AE's own versions of those pieces are hidden; everything else on
// AE's HUD (crosshair, InfoLink, log, damage arrows...) is untouched. AE's
// HUD settings (which pieces are shown) are respected.
//=============================================================================
class RIHud extends Window;

var DeusExPlayer Player;
var float S, Age;
var int   NorthYaw;
var bool  bNorthKnown;

// Body monitor: shown health per part (eases toward the real value) and a
// damage flash. Order: head, torso, right arm, left arm, right leg, left leg
var float PartShown[6], PartFlash[6], PartLast[6];

var localized string HealthLabel, EnergyLabel, BreathLabel, StaminaLabel;
var localized string BioShort, StaminaShort, BreathShort;   // the Sleek vertical bars' labels
var localized string WalkLabel, RunLabel, CrouchLabel, LeanLabel, SwimLabel;
var localized string ReloadLabel, ClipsLabel, RoundsLabel, ScopeLabel, LaserLabel, SilencerLabel, SlotLabel;
var localized string MagLabel, ReserveLabel, TotalLabel, MagsLabel, CountLabel, ReceivedLabel;

// AE's received-items list keeps running hidden; its timer is advanced here
// if the engine doesn't tick it while hidden
var float RecvLastT;
var bool  bAugBarScoped;      // the game's aug bar was hidden for a scope
var Window InfoScoped;        // the InfoLink window hidden for a scope (shown again if it still exists)
var float BarGoal[2], BarShown[2], BarGhost[2], BarHold[2];   // Vanilla+ BIO / STAMINA bars (eased, with a drain trail)
var localized string CompassNames[8];
var localized string VitalsTitle;
// HUD motion: the HUD layer's offset (lag behind the view, walking bob)
var float SwayX, SwayY, BobT, BobAmt, RateX, RateY, SwayVX, SwayVY, DispX, DispY;
var int   LastYaw, LastPitch;
var bool  bSwayInit;
var bool  bSleekFig;    // Sleek: the figure in its gold palette   // Modern: the body monitor frame's tab

event InitWindow()
{
	Super.InitWindow();
	SetSensitivity(False);
	bTickEnabled = True;
}

function DeusExHUD Hud()
{
	return DeusExHUD(GetParent());
}

// ----------------------------------------------------------------------
// Colours (original gold)
// ----------------------------------------------------------------------

function Color C3(float R, float G, float B)
{
	return Class'RIUtil'.static.Col(R, G, B);
}

function Color CA(float R, float G, float B, float a)
{
	return Class'RIUtil'.static.Col(R * a, G * a, B * a);
}

function Fill(GC gc, float X, float Y, float W, float H, Color C)
{
	Class'RISkin'.static.FillC(gc, X, Y, W, H, C);
}

function CGlow(GC gc, float X, float Y, float W, float H, Color C)
{
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(C);
	gc.DrawStretchedTexture(X, Y, W, H, 0, 0, 256, 64, Texture'ReimaginedUI.UI.RI_GlowC');
}

// Soft dark backing: darkest in the middle, fading out on every side
function Shade(GC gc, float X, float Y, float W, float H)
{
	gc.SetStyle(DSTY_Modulated);
	gc.DrawStretchedTexture(X, Y, W, H, 0, 0, 256, 64, Texture'ReimaginedUI.UI.RI_ShadeC');
}

// Green at full health, through yellow, to red
function Color HealthCol(float f)
{
	f = FClamp(f, 0, 1);
	if (f > 0.5)
		return Class'RIUtil'.static.Mix(Class'RIUtil'.static.Raw(228, 192, 58), Class'RIUtil'.static.Raw(96, 214, 114), (f - 0.5) * 2);
	return Class'RIUtil'.static.Mix(Class'RIUtil'.static.Raw(220, 58, 42), Class'RIUtil'.static.Raw(228, 192, 58), f * 2);
}

// Sleek's figure: gold when whole, through amber, to red
function Color SleekHealthCol(float f)
{
	f = FClamp(f, 0, 1);
	if (f > 0.5)
		return Class'RIUtil'.static.Mix(Class'RIUtil'.static.Raw(232, 128, 40), Class'RIUtil'.static.Raw(242, 211, 107), (f - 0.5) * 2);
	return Class'RIUtil'.static.Mix(Class'RIUtil'.static.Raw(214, 50, 36), Class'RIUtil'.static.Raw(232, 128, 40), f * 2);
}

// HUD motion: when looking around the HUD lags the view a little (offset
// against the turn, a few pixels at most) and glides back. The whole layer moves (this window), so everything on it
// keeps its spacing; the crosshair is drawn elsewhere and stays put.
function TickSway(DeusExHUD H, float dt)
{
	local int dy, dp;
	local float k, tx, ty, ox, oy, w;

	k = H.height / 1080.0;
	if (!Class'RIRootWindow'.default.bHudSway || (dt <= 0) || (dt > 0.25))
	{
		SwayX = 0;
		SwayY = 0;
		SwayVX = 0;
		SwayVY = 0;
		RateX = 0;
		RateY = 0;
		bSwayInit = False;
	}
	else
	{
		if (!bSwayInit)
		{
			LastYaw = Player.ViewRotation.Yaw;
			LastPitch = Player.ViewRotation.Pitch;
			bSwayInit = True;
		}
		dy = ((Player.ViewRotation.Yaw - LastYaw + 32768) & 65535) - 32768;
		dp = ((Player.ViewRotation.Pitch - LastPitch + 32768) & 65535) - 32768;
		LastYaw = Player.ViewRotation.Yaw;
		LastPitch = Player.ViewRotation.Pitch;
		// the turn rate (degrees per second), filtered against frame noise
		RateX += ((dy * 360.0 / 65536.0) / dt - RateX) * FMin(1.0, dt * 6.0);
		RateY += ((dp * 360.0 / 65536.0) / dt - RateY) * FMin(1.0, dt * 6.0);
		tx = FClamp(-RateX * 0.04, -10, 10);
		ty = FClamp(RateY * 0.04, -6, 6);
		// critically damped spring toward the target: glides, never overshoots
		w = 6.0;
		SwayVX += (w * w * (tx - SwayX) - 2.0 * w * SwayVX) * dt;
		SwayVY += (w * w * (ty - SwayY) - 2.0 * w * SwayVY) * dt;
		SwayX += SwayVX * dt;
		SwayY += SwayVY * dt;
	}
	// no walking bob: under a pixel it only flickered between two positions
	ox = SwayX * k * 2.0;       // in screen pixels
	oy = SwayY * k * 2.0;
	// whole screen pixels, with a dead zone so the HUD never flips back and
	// forth between two neighbouring pixels
	if (Abs(ox - DispX) >= 0.8)
		DispX = float(int(ox + 0.5 * SwaySign(ox)));
	if (Abs(oy - DispY) >= 0.8)
		DispY = float(int(oy + 0.5 * SwaySign(oy)));
	// settle exactly home once the motion has died away
	if (!bSwayInit || (Abs(ox) < 0.3))
		DispX = 0;
	if (!bSwayInit || (Abs(oy) < 0.3))
		DispY = 0;
	if ((x != DispX * 0.5) || (y != DispY * 0.5) || (width != H.width) || (height != H.height))
		SetConfiguration(DispX * 0.5, DispY * 0.5, H.width, H.height);
}

function float SwaySign(float V)
{
	if (V < 0)
		return -1;
	return 1;
}

// ----------------------------------------------------------------------
// Tick: keep the size, hide AE's versions, animate the body monitor
// ----------------------------------------------------------------------

event Tick(float deltaSeconds)
{
	local DeusExHUD H;
	local int i;
	local float v;

	Age += deltaSeconds;
	H = Hud();
	if (H == None)
		return;
	Player = DeusExPlayer(GetRootWindow().parentPawn);
	if (Player == None)
		return;
	TickSway(H, deltaSeconds);
	if (RIDeusExHUD(H) == None)
		HideAE(H);
	if (RILogDisplay(H.msgLog) != None)
		RILogDisplay(H.msgLog).FlushPickups();
	TickReceived(H.receivedItems, deltaSeconds);
	ScopeAugBar(H);
	ScopeInfoLink(H);
	SkinAugBar(H);
	Class'RIAugKeys'.static.Step(Player, deltaSeconds);

	for (i = 0; i < 6; i++)
	{
		v = PartValue(i);
		if (v < PartLast[i] - 0.5)
			PartFlash[i] = 1.0;
		PartLast[i] = v;
		PartShown[i] += (v - PartShown[i]) * FMin(1.0, deltaSeconds * 6.0);
		PartFlash[i] = FMax(0, PartFlash[i] - deltaSeconds * 2.0);
	}
	// BIO / STAMINA: the fill eases to its value; the trail holds a moment
	// on a drop, then slides down after it
	for (i = 0; i < 2; i++)
	{
		BarShown[i] += (BarGoal[i] - BarShown[i]) * FMin(1.0, deltaSeconds * 10.0);
		if (BarGoal[i] >= BarGhost[i])
		{
			BarGhost[i] = BarShown[i];
			BarHold[i] = 0;
		}
		else
		{
			BarHold[i] += deltaSeconds;
			if (BarHold[i] > 0.45)
				BarGhost[i] = FMax(BarShown[i], BarGhost[i] - deltaSeconds * 0.5);
		}
	}
}

// The game's own aug bar (activeItems) is the HUD's aug bar; while a scope
// or binoculars are up it's hidden with the rest of the HUD, then put back
function ScopeAugBar(DeusExHUD H)
{
	if (H.activeItems == None)
		return;
	if (Class'RIUtil'.static.Scoped(Self))
	{
		if (H.activeItems.IsVisible(False))
		{
			H.activeItems.Hide();
			bAugBarScoped = True;
		}
	}
	else if (bAugBarScoped)
	{
		bAugBarScoped = False;
		H.activeItems.Show();
	}
}

// ----------------------------------------------------------------------
// The game's aug / item bar (activeItems: augs with their F-keys, active
// charged items), kept faithful: its own frame and cell backgrounds at the
// game's exact geometry and colours (translucent, like the rest of the
// HUD's art; the cells darken the world behind them, like the belt's
// slots), redrawn here from the
// upscaled HD textures on exact pixels (this window is drawn just before
// the bar, so the game's icons and charge bars land on top). Only the
// F-keys move from the pixel font to the HUD font, as in the rest of the UI.
// The game's own drawing of those pieces is switched off every tick.
// ----------------------------------------------------------------------

function SkinAugBar(DeusExHUD H)
{
	local HUDActiveItemsDisplay D;

	D = H.activeItems;
	if (D == None)
		return;
	SkinBarBox(D.winAugsContainer);
	SkinBarBox(D.winItemsContainer);
}

function SkinBarBox(HUDActiveItemsBorderBase B)
{
	local Window C;

	if (B == None)
		return;
	B.bDrawBorder = False;
	if (B.winIcons == None)
		return;
	for (C = B.winIcons.GetTopChild(); C != None; C = C.GetLowerSibling())
	{
		if (HUDActiveItemBase(C) != None)
			HUDActiveItemBase(C).texBackground = Texture'ReimaginedUI.UI.RI_Clear';
		if (HUDActiveAug(C) != None)
			HUDActiveAug(C).hotKeyString = "";
	}
}

function DrawAugBar(GC gc)
{
	local HUDActiveItemsDisplay D;

	if (Hud() == None)
		return;
	D = Hud().activeItems;
	if ((D == None) || !D.IsVisible())
		return;
	DrawBarBox(gc, D.winAugsContainer);
	DrawBarBox(gc, D.winItemsContainer);
}

// As HUDActiveItemsBorderBase.DrawBorder (top, the middle tiled down,
// bottom) and HUDActiveItemBase.DrawBackground, from the HD textures
function DrawBarBox(GC gc, HUDActiveItemsBorderBase B)
{
	local Window C;
	local HUDActiveItemBase I;
	local Texture T;
	local float bx, by, cx, cy, ty, seg, endY;
	local string Key;
	local bool bLit;
	local float rTop, rBot, rX;

	if ((B == None) || !B.IsVisible() || (B.winIcons == None) || (B.iconCount <= 0))
		return;
	ConvertCoordinates(B, 0, 0, Self, bx, by);
	// Sleek: as the Sleek belt, no boxes. The column floats on one soft
	// shadow; each aug has a thin underline (bright, full width and glowing
	// while it's on; short and dim while off) and its key in small type to
	// the left, lit with it
	if (!Class'RIModern'.static.On() && !Class'RIVP'.static.On())
	{
		rTop = -1;
		rBot = -1;
		rX = -1;
		for (C = B.winIcons.GetTopChild(); C != None; C = C.GetLowerSibling())
		{
			if ((HUDActiveItemBase(C) == None) || !C.IsVisible())
				continue;
			ConvertCoordinates(C, 0, 0, Self, cx, cy);
			if ((rTop < 0) || (cy < rTop))
				rTop = cy;
			if (cy + C.height > rBot)
				rBot = cy + C.height;
			if ((rX < 0) || (cx < rX))
				rX = cx;
		}
		if (rTop < 0)
			return;
		Shade(gc, rX - 120 * S, rTop - 60 * S, B.width + 200 * S, rBot - rTop + 120 * S);
		for (C = B.winIcons.GetTopChild(); C != None; C = C.GetLowerSibling())
		{
			I = HUDActiveItemBase(C);
			if ((I == None) || !C.IsVisible())
				continue;
			ConvertCoordinates(C, 0, 0, Self, cx, cy);
			bLit = True;
			Key = "";
			if (HUDActiveAug(C) != None)
			{
				Key = HotKey(HUDActiveAug(C).hotKeyNum);
				bLit = (Augmentation(I.GetClientObject()) != None) && Augmentation(I.GetClientObject()).bIsActive;
			}
			if (bLit)
			{
				CGlow(gc, cx - 8 * S, cy + C.height - 20 * S, C.width + 16 * S, 26 * S, C3(64, 52, 20));
				Fill(gc, cx, cy + C.height - 1 * S, C.width, 2 * S, C3(242, 211, 107));
				if (Key != "")
					Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', cx - 38 * S, cy, 32 * S, C.height, Key, C3(255, 241, 194), 2, 0.46);
			}
			else
			{
				Fill(gc, cx + C.width * 0.25, cy + C.height - 0.5 * S, C.width * 0.5, 1 * S, C3(150, 126, 62));
				if (Key != "")
					Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', cx - 38 * S, cy, 32 * S, C.height, Key, C3(184, 154, 87), 2, 0.46);
			}
		}
		return;
	}
	if (Class'RIModern'.static.On())
	{
		// no boxes: a hairline rail down the left of the column, a tick to
		// each aug; each aug framed by corner brackets (gold, with a soft glow
		// behind the icon, while on); its key set left of the rail
		rTop = -1;
		rBot = -1;
		rX = -1;
		for (C = B.winIcons.GetTopChild(); C != None; C = C.GetLowerSibling())
		{
			if ((HUDActiveItemBase(C) == None) || !C.IsVisible())
				continue;
			ConvertCoordinates(C, 0, 0, Self, cx, cy);
			if ((rTop < 0) || (cy < rTop))
				rTop = cy;
			if (cy + C.height > rBot)
				rBot = cy + C.height;
			if ((rX < 0) || (cx < rX))
				rX = cx;
		}
		if (rTop < 0)
			return;
		rX -= 9 * S;
		Class'RIText'.static.VLine(gc, rX, rTop + 4 * S, rBot - rTop - 8 * S, C3(110, 92, 52));
		for (C = B.winIcons.GetTopChild(); C != None; C = C.GetLowerSibling())
		{
			I = HUDActiveItemBase(C);
			if ((I == None) || !C.IsVisible())
				continue;
			ConvertCoordinates(C, 0, 0, Self, cx, cy);
			bLit = True;
			Key = "";
			if (HUDActiveAug(C) != None)
			{
				Key = HotKey(HUDActiveAug(C).hotKeyNum);
				bLit = (Augmentation(I.GetClientObject()) != None) && Augmentation(I.GetClientObject()).bIsActive;
			}
			if (bLit)
			{
				CGlow(gc, cx - 10 * S, cy - 6 * S, C.width + 20 * S, C.height + 12 * S, C3(70, 52, 14));
				Class'RIModern'.static.Brackets(gc, cx, cy, C.width, C.height, 7 * S, C3(242, 196, 90));
				Class'RIText'.static.HLine(gc, rX, cy + C.height * 0.5, 6 * S, C3(242, 196, 90));
				if (Key != "")
					Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', rX - 40 * S, cy, 34 * S, C.height, Key, C3(255, 236, 190), 2, 0.44);
			}
			else
			{
				Class'RIModern'.static.Brackets(gc, cx, cy, C.width, C.height, 5 * S, C3(110, 92, 52));
				Class'RIText'.static.HLine(gc, rX, cy + C.height * 0.5, 4 * S, C3(110, 92, 52));
				if (Key != "")
					Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', rX - 40 * S, cy, 34 * S, C.height, Key, C3(150, 138, 112), 2, 0.44);
			}
		}
		return;
	}
	// translucent, as the rest of the HUD's art (the game's own styles,
	// solid or masked, made the HD textures look frosted next to it)
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(B.colBorder);
	Tex1(gc, bx, by, B.width, B.topHeight, B.texBorderTop);
	T = B.texBorderCenter;
	endY = by + B.height - B.bottomOffset;
	if ((T != None) && (T.VSize > 0))
		for (ty = by + B.topOffset; ty < endY; ty += T.VSize)
		{
			seg = FMin(T.VSize, endY - ty);
			Tex1(gc, bx, ty, B.width, seg, T);
		}
	Tex1(gc, bx, by + B.height - B.bottomHeight, B.width, B.bottomHeight, B.texBorderBottom);

	for (C = B.winIcons.GetTopChild(); C != None; C = C.GetLowerSibling())
	{
		I = HUDActiveItemBase(C);
		if ((I == None) || !C.IsVisible())
			continue;
		ConvertCoordinates(C, 0, 0, Self, cx, cy);
		// the cell: a light see-through grey glass, as the belt slots, body
		// monitor and weapon box (the world dimmed a little, a faint tint of
		// the HUD colour), no edge of its own inside the bar's frame
		gc.SetStyle(DSTY_Modulated);
		gc.DrawStretchedTexture(cx + 1, cy + 1, C.width - 2, C.height - 2, 0, 0, 16, 16, Texture'ReimaginedUI.UI.RI_Dim2');
		Fill(gc, cx + 1, cy + 1, C.width - 2, C.height - 2, Class'RIVP'.static.Edge(0.16));
		if (HUDActiveAug(C) != None)
		{
			// where the game put it: top-right of the cell
			Key = HotKey(HUDActiveAug(C).hotKeyNum);
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', cx + 14, cy + 0.5, 18, 9, Key, I.colText, 2, 0.4);
		}
	}
}

// A texture at its own size from its top-left corner, clipped to W x H (as
// the game's DrawTexture), from the HD set on exact pixels
function Tex1(GC gc, float X, float Y, float W, float H, Texture T)
{
	if ((T == None) || (W <= 0) || (H <= 0))
		return;
	Class'RIHD'.static.DrawExact(gc, X, Y, W, H, 0, 0, W, H, T);
}

// A transmission's window while a scope is up: hidden (the transmission
// plays on), shown again afterwards if it's still the same window (the game
// destroys it when a transmission ends)
function ScopeInfoLink(DeusExHUD H)
{
	if (Class'RIUtil'.static.Scoped(Self))
	{
		if ((H.infolink != None) && H.infolink.IsVisible(False))
		{
			H.infolink.Hide();
			InfoScoped = H.infolink;
		}
	}
	else if (InfoScoped != None)
	{
		if ((H.infolink != None) && (H.infolink == InfoScoped))
			H.infolink.Show();
		InfoScoped = None;
	}
}

function HideAE(DeusExHUD H)
{
	if ((H.hit != None) && H.hit.IsVisible(False))
		H.hit.Hide();
	if ((H.compass != None) && H.compass.IsVisible(False))
		H.compass.Hide();
	if ((H.ammo != None) && H.ammo.IsVisible(False))
		H.ammo.Hide();
	Class'RIBase'.static.HideHudExtras(H);
	if ((H.belt != None) && H.belt.IsVisible(False))
		H.belt.Hide();
}

function TickReceived(HUDReceivedDisplay R, float DT)
{
	if ((R == None) || !R.bTickEnabled || R.IsVisible(False))
		return;
	if (R.displayTimer == RecvLastT)
		R.displayTimer += DT;
	RecvLastT = R.displayTimer;
	if (R.displayTimer > R.displayLength)
		R.RemoveItems();
}

// Health fraction of a body part (0..1)
function float PartValue(int i)
{
	switch (i)
	{
		case 0: return float(Player.HealthHead) / FMax(1, Player.default.HealthHead + Class'RIBase'.static.HeadBonus(Player));
		case 1: return float(Player.HealthTorso) / FMax(1, Player.default.HealthTorso + Class'RIBase'.static.TorsoBonus(Player));
		case 2: return float(Player.HealthArmRight) / FMax(1, Player.default.HealthArmRight);
		case 3: return float(Player.HealthArmLeft) / FMax(1, Player.default.HealthArmLeft);
		case 4: return float(Player.HealthLegRight) / FMax(1, Player.default.HealthLegRight);
		case 5: return float(Player.HealthLegLeft) / FMax(1, Player.default.HealthLegLeft);
	}
	return 1;
}

// ----------------------------------------------------------------------
// Drawing
// ----------------------------------------------------------------------

// Text and layout both follow Settings > Interface > HUD size
event DrawWindow(GC gc)
{
	Class'RIText'.default.TextMul = Class'RIRootWindow'.static.HudK();
	DrawHud(gc);
	Class'RIText'.default.TextMul = 1.0;
}

function DrawHud(GC gc)
{
	Class'RITheme'.static.SetMode(2);   // the HUD follows the HUD theme
	if (Player == None)
		return;
	S = height / 1080.0 * Class'RIRootWindow'.static.HudK();
	gc.EnableSmoothing(True);
	// a scope or binoculars: nothing but the view (messages still come
	// through the log)
	if (Class'RIUtil'.static.Scoped(Self))
	{
		if ((Hud() != None) && (RILogDisplay(Hud().msgLog) != None))
			RILogDisplay(Hud().msgLog).MatchW = 0;
		return;
	}
	DrawAugBar(gc);
	if (Class'RIVP'.static.On())
	{
		DrawVP(gc);
		DrawReceived(gc);
		return;
	}
	if (Player.bHitDisplayVisible)
	{
		if (Class'RIModern'.static.On())
			DrawModernVitals(gc);
		else
			DrawVitals(gc);
	}
	if (Player.bCompassVisible)
		DrawCompass(gc);
	if (Player.bObjectBeltVisible)
		DrawBelt(gc);
	if (Player.bAmmoDisplayVisible)
		DrawWeapon(gc);
	DrawReceived(gc);
}

// Body monitor, top left: the figure, and beside it vertical bars as tall
// as the figure (bioelectric; stamina or breath when shown), label above,
// value below. Stance under the figure.
function DrawVitals(GC gc)
{
	local float x0, y0, k, fh, bx, bw, f, r;
	local bool bWater;
	local string T;

	x0 = 36 * S;
	y0 = 44 * S;
	fh = 160 * S;                 // figure height (was 196)
	k = fh / 360.0;
	bw = 8 * S;
	if (Class'RIModern'.static.On())
	{
		// content dropped below the tab so the bar labels clear the edge
		x0 = 46 * S;
		y0 = 82 * S;
		if (Class'RIBase'.static.StaminaShown(Player) || ((Player.HeadRegion.Zone != None) && Player.HeadRegion.Zone.bWaterZone))
			Class'RIModern'.static.Frame(gc, 24 * S, 24 * S, 200 * S, 262 * S, S, 1, VitalsTitle);
		else
			Class'RIModern'.static.Frame(gc, 24 * S, 24 * S, 166 * S, 262 * S, S, 1, VitalsTitle);
	}
	else
		Shade(gc, -160 * S, -90 * S, 620 * S, 400 * S);

	// Figure: 173 x 360 design pixels, standing on a thin lit base line
	CGlow(gc, x0 - 30 * S, y0 + 16 * S, 173 * k + 60 * S, 122 * S, C3(10, 14, 8));
	CGlow(gc, x0 - 10 * S, y0 + fh - 14 * S, 173 * k + 20 * S, 28 * S, C3(40, 34, 14));
	Fill(gc, x0, y0 + fh + 2 * S, 173 * k, 1 * S, C3(150, 126, 62));
	bSleekFig = True;
	DrawPart(gc, 0, x0, y0, k, Texture'ReimaginedUI.UI.RI_HudHead',  70,   0,  35,  44);
	DrawPart(gc, 1, x0, y0, k, Texture'ReimaginedUI.UI.RI_HudTorso', 58,  43,  59, 125);
	DrawPart(gc, 2, x0, y0, k, Texture'ReimaginedUI.UI.RI_HudArmR',   0,  52,  60, 135);
	DrawPart(gc, 3, x0, y0, k, Texture'ReimaginedUI.UI.RI_HudArmL', 115,  53,  58, 134);
	DrawPart(gc, 4, x0, y0, k, Texture'ReimaginedUI.UI.RI_HudLegR',  36, 138,  51, 221);
	DrawPart(gc, 5, x0, y0, k, Texture'ReimaginedUI.UI.RI_HudLegL',  87, 139,  53, 220);
	bSleekFig = False;

	// Bioelectric, just right of the figure (no health bar: the figure
	// shows health part by part)
	bx = x0 + 173 * k + 18 * S;
	if (Class'RIUtil'.static.PBool(Player, "bEnergyBarShowsReserve") && (Player.AugmentationSystem != None))
	{
		f = Player.Energy / FMax(1, Class'RIBase'.static.MaxEnergy(Player, True));
		r = Class'RIBase'.static.EnergyReserve(Player) / 100.0;
	}
	else
	{
		f = Player.Energy / FMax(1, Class'RIBase'.static.MaxEnergy(Player, False));
		r = 0;
	}
	VertBar(gc, bx, y0, bw, fh, BioShort, string(int(Player.Energy)), f, r, C3(104, 170, 224), C3(52, 74, 104));

	// Stamina (GMDX's stamina system shares the breath timer); breath underwater
	bWater = (Player.HeadRegion.Zone != None) && Player.HeadRegion.Zone.bWaterZone;
	if (bWater || Class'RIBase'.static.StaminaShown(Player))
	{
		f = FClamp(Player.swimTimer / FMax(0.01, Player.swimDuration), 0, 1);
		if (bWater)
			VertBar(gc, bx + 34 * S, y0, bw, fh, BreathShort, string(int(f * 100)), f, 0, C3(150, 220, 235), C3(0, 0, 0));
		else
			VertBar(gc, bx + 34 * S, y0, bw, fh, StaminaShort, string(int(f * 100)), f, 0, C3(242, 211, 107), C3(0, 0, 0));
	}

	// Stance (AE's setting: 0 off, 1 walk / run only, 2 all), under the figure
	if (Class'RIUtil'.static.PInt(Player, "iStanceHud") > 0)
	{
		T = StanceText();
		if (T != "")
			Class'RIText'.static.Draw(gc, Class'RIFontSmall', x0, y0 + fh + 12 * S, Caps(T), C3(242, 211, 107), 0.62);
	}
}

// A vertical bar H tall, in the Sleek belt's manner: no box. A hairline
// track; the fill a slim bright column rising from the bottom (reserve
// stacked on it), with a soft glow at its head and a short bright cap; a
// thin base line under it like the belt's underlines. Short label centred
// above, the value below.
function VertBar(GC gc, float X, float Y, float W, float H, string L, string V, float f, float r, Color C, Color RC)
{
	local float fh, rh, cx, bw;

	Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', X - 20 * S, Y - 20 * S, W + 40 * S, 16 * S, Caps(L), C3(184, 154, 87), 1, 0.5);
	cx = X + W * 0.5;
	bw = FMax(1.0, W * 0.5);
	// track and base
	Fill(gc, cx - 0.25, Y, 0.5, H, C3(70, 58, 28));
	Fill(gc, X - 3 * S, Y + H, W + 6 * S, 1 * S, C3(150, 126, 62));
	// fill
	fh = H * FClamp(f, 0, 1);
	Fill(gc, cx - bw * 0.5, Y + H - fh, bw, fh, C);
	if (r > 0)
	{
		rh = H * FClamp(r, 0, 1 - FClamp(f, 0, 1));
		Fill(gc, cx - bw * 0.5, Y + H - fh - rh, bw, rh, RC);
	}
	if (fh > 0)
	{
		CGlow(gc, cx - 14 * S, Y + H - fh - 12 * S, 28 * S, 24 * S, C3(C.R * 0.3, C.G * 0.3, C.B * 0.3));
		// the cap a lighter shade of the bar's own colour, as the belt's
		// underlines are of the gold
		Fill(gc, cx - bw, Y + H - fh, bw * 2, 1 * S, Class'RIUtil'.static.Mix(C, C3(255, 255, 255), 0.55));
	}
	// the value small, in the belt's label size, tinted toward the bar
	Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', X - 24 * S, Y + H + 6 * S, W + 48 * S, 14 * S, V,
		Class'RIUtil'.static.Mix(C, C3(255, 241, 194), 0.6), 1, 0.46);
}

function DrawPart(GC gc, int i, float X, float Y, float k, Texture T, float px, float py, float pw, float ph)
{
	local Color C;

	if (bSleekFig)
		C = Class'RIUtil'.static.Mix(SleekHealthCol(PartShown[i]), C3(255, 241, 194), PartFlash[i]);
	else
		C = Class'RIUtil'.static.Mix(HealthCol(PartShown[i]), C3(255, 255, 255), PartFlash[i]);
	if (PartShown[i] <= 0.001)
		C = Class'RIUtil'.static.Raw(58, 24, 20);
	gc.SetStyle(DSTY_Masked);
	gc.SetTileColor(C);
	// on exact screen pixels: the engine's own call rounds each part to whole
	// UI units, so the parts drifted apart (gaps at the shoulders and hips)
	Class'RIHD'.static.DrawExact(gc, X + px * k, Y + py * k, pw * k, ph * k, 0, 0, pw, ph, T);
}

// The game's own total (DeusExPlayer.GenerateTotalHealth): 0 as soon as the
// head or torso is gone, otherwise half limbs, half head and torso
function float TotalHealth()
{
	return FClamp(float(Player.Health) / FMax(1, Class'RIBase'.static.TotalMaxHealth(Player)), 0, 1);
}

// Head or torso at zero kills, so the bar's colour follows the weaker of
// the total and those two parts
function float VitalHealth()
{
	return FMin(TotalHealth(), FMin(FClamp(PartValue(0), 0, 1), FClamp(PartValue(1), 0, 1)));
}

function DrawBar(GC gc, float X, float Y, float W, string L, string V, float f, float r, Color C, Color RC)
{
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', X, Y, Caps(L), C3(184, 154, 87), 0.58);
	Class'RIText'.static.DrawIn(gc, Class'RIFontHead', X, Y - 4 * S, W, 24 * S, V, C3(255, 241, 194), 2, 0.5);
	Y += 22 * S;
	Fill(gc, X, Y, W, 7 * S, C3(14, 11, 5));
	Class'RIText'.static.Box(gc, X, Y, W, 7 * S, C3(74, 62, 28));
	Fill(gc, X + 1, Y + 1, (W - 2) * FClamp(f, 0, 1), 7 * S - 2, C);
	if (r > 0)
		Fill(gc, X + 1 + (W - 2) * FClamp(f, 0, 1), Y + 1, (W - 2) * FClamp(r, 0, 1 - FClamp(f, 0, 1)), 7 * S - 2, RC);
}

function string StanceText()
{
	if (Class'RIUtil'.static.PInt(Player, "iStanceHud") == 1)
	{
		if (Class'RIBase'.static.IsCrouching(Player) || Player.IsLeaning())
			return "";
		if (Player.bIsWalking)
			return WalkLabel;
		return RunLabel;
	}
	if (Player.IsInState('PlayerSwimming'))
		return SwimLabel;
	if (Player.IsLeaning())
		return LeanLabel;
	if (Class'RIBase'.static.IsCrouching(Player))
		return CrouchLabel;
	if (Player.bIsWalking)
		return WalkLabel;
	return RunLabel;
}

// Compass strip, top centre: N / NE / E ... sliding past a centre mark
function DrawCompass(GC gc)
{
	local float cx, y, w, h, heading, d, x, a, span;
	local int i;
	local DeusExLevelInfo Info;
	local string L;

	if (!bNorthKnown)
	{
		Info = Player.GetLevelInfo();
		if (Info != None)
			NorthYaw = Info.TrueNorth;
		bNorthKnown = True;
	}
	heading = float((Player.Rotation.Yaw - NorthYaw) & 65535) * 360.0 / 65536.0;
	w = 560 * S;
	h = 40 * S;
	cx = width * 0.5;
	y = 24 * S;
	span = 70;        // degrees either side of the centre

	if (Class'RIVP'.static.On())
	{
		// HUD corners mockup: a dark band with hairlines, no box
		Shade(gc, cx - w * 0.62, y - 12 * S, w * 1.24, h + 26 * S);
		gc.SetStyle(DSTY_Translucent);
		gc.SetTileColor(C3(110, 92, 44));
		gc.DrawStretchedTexture(cx - w * 0.5, y - 4 * S, w, 1.5 * S, 0, 28, 256, 8, Texture'ReimaginedUI.UI.RI_GlowC');
		gc.DrawStretchedTexture(cx - w * 0.5, y + h + 6 * S, w, 1.5 * S, 0, 28, 256, 8, Texture'ReimaginedUI.UI.RI_GlowC');
	}
	else
		Shade(gc, cx - w * 0.75, y - 40 * S, w * 1.5, h + 80 * S);

	// Ticks every 15 degrees, labels every 45
	for (i = 0; i < 24; i++)
	{
		d = i * 15 - heading;
		while (d > 180)
			d -= 360;
		while (d < -180)
			d += 360;
		if (Abs(d) > span)
			continue;
		x = cx + d / span * w * 0.5;
		a = 1 - Abs(d) / span;
		if ((i % 3) == 0)
		{
			L = CompassNames[i / 3];
			if (Abs(d) < 8)
				Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x - 30 * S, y + 4 * S, 60 * S, 26 * S, L, CA(255, 241, 194, a), 1, 0.56);
			else
				Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x - 30 * S, y + 4 * S, 60 * S, 26 * S, L, CA(184, 154, 87, a), 1, 0.5);
		}
		else
			Fill(gc, x, y + h - 12 * S, 1, 8 * S, CA(126, 105, 50, a));
	}
	// Centre mark
	Fill(gc, cx - 1 * S, y - 2 * S, 2 * S, 7 * S, C3(242, 211, 107));
	Class'RIText'.static.HLine(gc, cx - w * 0.35, y + h, w * 0.7, C3(74, 62, 28));
}

// Active augs and charged items (bottom left), F-key above each
function DrawAugs(GC gc)
{
	local Augmentation Aug;
	local Inventory I;
	local ChargedPickup CP;
	local float x, y, c, f;
	local int n;
	local bool bAny;

	c = 58 * S;
	x = 36 * S;
	y = height - 30 * S - c;
	if (Player.AugmentationSystem != None)
		for (Aug = Player.AugmentationSystem.FirstAug; Aug != None; Aug = Aug.next)
		{
			if (!Class'RIBase'.static.AugCanActivate(Aug) || (!Player.bHUDShowAllAugs && !Aug.bIsActive))
				continue;
			if (!bAny && !Class'RIVP'.static.On() && !Class'RIModern'.static.On())
				Shade(gc, -200 * S, y - 90 * S, 1000 * S, c + 170 * S);
			bAny = True;
			DrawAugCell(gc, x, y, c, AugIcon(Aug), Aug.bIsActive, HotKey(Aug.HotKeyNum), -1, Class'RIBase'.static.AugColor(Aug, True));
			x += c + 10 * S;
			if (++n >= 12)
				break;
		}
	for (I = Player.Inventory; I != None; I = I.Inventory)
	{
		CP = ChargedPickup(I);
		if ((CP == None) || !CP.bIsActive)
			continue;
		if (!bAny && !Class'RIVP'.static.On() && !Class'RIModern'.static.On())
			Shade(gc, -200 * S, y - 90 * S, 1000 * S, c + 170 * S);
		bAny = True;
		f = FClamp(CP.GetCurrentCharge() / 100.0, 0, 1);
		DrawAugCell(gc, x, y, c, CP.ChargedIcon, True, "", f, C3(255, 255, 255));
		x += c + 10 * S;
	}
}

function Texture AugIcon(Augmentation Aug)
{
	if (Aug.smallIcon != None)
		return Aug.smallIcon;
	return Aug.icon;
}

function string HotKey(int N)
{
	return Class'RIAugKeys'.static.KeyFor(Player, N);
}

// Tint: AE's own colour for the aug (active blue, toggle green, automatic
// cyan, passive yellow, off white or grey, recharging red)
function DrawAugCell(GC gc, float X, float Y, float C, Texture Icon, bool bOn, string Key, float Charge, Color Tint)
{
	if (Class'RIModern'.static.On())
	{
		Class'RIModern'.static.Slot(gc, X, Y, C, C, S, 1 + int(bOn), Key, "");
		if (Icon != None)
		{
			gc.SetStyle(DSTY_Translucent);
			gc.SetTileColor(Tint);
			Class'RIHD'.static.DrawAugIcon(gc, X + 9 * S, Y + 11 * S, C - 18 * S, C - 18 * S, Icon);
		}
		if (Charge >= 0)
		{
			Fill(gc, X + 5 * S, Y + C - 7 * S, C - 10 * S, 3 * S, C3(30, 25, 11));
			Fill(gc, X + 5 * S, Y + C - 7 * S, (C - 10 * S) * Charge, 3 * S, C3(242, 190, 72));
		}
		return;
	}
	if ((Key != "") && !Class'RIVP'.static.On())
	{
		if (bOn)
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', X, Y - 22 * S, C, 18 * S, Key, C3(242, 211, 107), 1, 0.56);
		else
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', X, Y - 22 * S, C, 18 * S, Key, C3(184, 154, 87), 1, 0.56);
	}
	if (Class'RIVP'.static.On())
	{
		Class'RIVP'.static.Panel(gc, X - 4 * S, Y - 28 * S, C + 8 * S, C + 32 * S, 8 * S, 1);
		if (bOn)
			Class'RIVP'.static.Btn(gc, X, Y, C, C, True, 0.9);
		else
			Class'RIVP'.static.Inset(gc, X, Y, C, C, 0.8);
	}
	else if (bOn)
	{
		CGlow(gc, X - 14 * S, Y - 10 * S, C + 28 * S, C + 20 * S, C3(52, 44, 18));
		Fill(gc, X, Y, C, C, C3(48, 39, 17));
		Class'RISkin'.static.Box2(gc, X, Y, C, C, C3(242, 211, 107));
	}
	else
	{
		Fill(gc, X, Y, C, C, C3(12, 10, 5));
		Class'RIText'.static.Box(gc, X, Y, C, C, C3(74, 62, 28));
	}
	if (Class'RIVP'.static.On() && (Key != ""))
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', X, Y - 24 * S, C, 20 * S, Key, Class'RIVP'.static.Txt(1), 1, 0.56);
	if (Icon != None)
	{
		// translucent, as the game draws HUD aug icons: their black drops
		// out (masked showed it as blotches, worst on IFF, which has no small
		// HUD icon and falls back to its large one with a black background)
		gc.SetStyle(DSTY_Translucent);
		gc.SetTileColor(Tint);
		Class'RIHD'.static.DrawAugIcon(gc, X + 7 * S, Y + 7 * S, C - 14 * S, C - 14 * S, Icon);
	}
	if (Charge >= 0)
	{
		Fill(gc, X + 4 * S, Y + C - 7 * S, C - 8 * S, 3 * S, C3(30, 25, 11));
		Fill(gc, X + 4 * S, Y + C - 7 * S, (C - 8 * S) * Charge, 3 * S, C3(242, 211, 107));
	}
}

// Belt, bottom centre: the numbered slots, the selected one lit
function DrawBelt(GC gc)
{
	local DeusExHUD H;
	local Inventory I, Cur;
	local int n, cnt;
	local float sw, sh, gap, x0, y, x, k;
	local Texture T;
	local bool bSel;
	local string BName;
	local DeusExPickup P;

	H = Hud();
	if ((H == None) || (H.belt == None))
		return;
	if (Class'RIModern'.static.On())
	{
		DrawModernBelt(gc);
		return;
	}
	if (!Class'RIVP'.static.On())
	{
		DrawSleekBelt(gc);
		return;
	}
	if (Class'RIUtil'.static.PBool(Player, "bBiggerBelt"))
		cnt = 12;
	else
		cnt = 10;
	sw = 74 * S;
	sh = 68 * S;
	gap = 6 * S;
	x0 = width * 0.5 - (cnt * sw + (cnt - 1) * gap) * 0.5;
	y = height - 30 * S - sh;
	if (Class'RIVP'.static.On())
		Class'RIVP'.static.Panel(gc, x0 - 14 * S, y - 12 * S, cnt * (sw + gap) - gap + 28 * S, sh + 24 * S, 12 * S, 1);
	else
		Shade(gc, x0 - 160 * S, y - 70 * S, cnt * (sw + gap) + 320 * S, sh + 150 * S);

	Cur = Player.inHandPending;
	if (Cur == None)
		Cur = Player.inHand;
	for (n = 0; n < cnt; n++)
	{
		x = x0 + Class'RIUtil'.static.BeltPos(n) * (sw + gap);
		I = H.belt.GetObjectFromBelt(n);
		bSel = (I != None) && (I == Cur);
		if (Class'RIVP'.static.On())
		{
			if (bSel)
				Class'RIVP'.static.Btn(gc, x, y, sw, sh, True, 1);
			else
				Class'RIVP'.static.Inset(gc, x, y, sw, sh, 0.8);
			Class'RIText'.static.HLine(gc, x, y + sh - 20 * S, sw, Class'RIVP'.static.Edge(0.6));
		}
		else if (bSel)
		{
			CGlow(gc, x - 12 * S, y - 10 * S, sw + 24 * S, sh + 20 * S, C3(50, 42, 18));
			Fill(gc, x, y, sw, sh, C3(46, 38, 17));
			Class'RISkin'.static.Box2(gc, x, y, sw, sh, C3(242, 211, 107));
		}
		else if (I != None)
		{
			Fill(gc, x, y, sw, sh, C3(14, 11, 5));
			Class'RIText'.static.Box(gc, x, y, sw, sh, C3(126, 105, 50));
		}
		else
		{
			Fill(gc, x, y, sw, sh, C3(10, 8, 4));
			Class'RIText'.static.Box(gc, x, y, sw, sh, C3(58, 48, 22));
		}
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', x + 6 * S, y + 3 * S, Mid("0123456789-=", n, 1), C3(242, 211, 107), 0.54);

		T = None;
		if (I != None)
			T = I.icon;
		else
			T = Class'RIBase'.static.BeltPlaceholder(Player, n);
		if (T != None)
		{
			k = FMin((sw - 12 * S) / 42.0, (sh - 26 * S) / 37.0);
			gc.SetStyle(DSTY_Masked);
			if (I != None)
				gc.SetTileColor(C3(255, 255, 255));
			else
				gc.SetTileColor(C3(80, 80, 80));
			Class'RIHD'.static.DrawExact(gc, x + (sw - 42 * k) * 0.5, y + 6 * S + (sh - 26 * S - 37 * k) * 0.5, 42 * k, 37 * k, 0, 0, 42, 37, T);
		}
		if (I != None)
		{
			BName = I.beltDescription;
			if (BName == "")
				BName = I.ItemName;
			if (bSel)
				Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x + 3 * S, y + sh - 18 * S, sw - 6 * S, 16 * S,
					Caps(Class'RIText'.static.Fit(Class'RIFontSmall', BName, sw - 6 * S, 0.44)), C3(255, 241, 194), 1, 0.44);
			else
				Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x + 3 * S, y + sh - 18 * S, sw - 6 * S, 16 * S,
					Caps(Class'RIText'.static.Fit(Class'RIFontSmall', BName, sw - 6 * S, 0.44)), C3(230, 195, 117), 1, 0.44);
			P = DeusExPickup(I);
			if ((P != None) && (P.NumCopies > 1))
				Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x, y + 3 * S, sw - 6 * S, 16 * S, string(P.NumCopies), C3(255, 241, 194), 2, 0.5);
		}
	}
}

// Modern belt, Human Revolution style: cut-corner slots with the number in
// the corner, a count pill (rounds for weapons, copies for pickups), the
// selected slot in bright gold with a warm glow, a weapon out of ammo in red,
// and the item's short name in small type under each slot
// Sleek belt: no boxes. The slots float on one soft shadow; each has a thin
// underline (bright, full width and glowing on the selected slot), its
// number small on the left, and its icon (empty slots show only the line
// and a dim number). Stacks show their count on the right. One label, the
// selected item's name, sits centred above the belt.
function DrawSleekBelt(GC gc)
{
	local DeusExHUD H;
	local Inventory I, Cur, SelI;
	local int n, cnt;
	local float sw, sh, gap, x0, y, x, k, iw, ih;
	local Texture T;
	local bool bSel;
	local string BName, CountT;
	local DeusExPickup P;
	local DeusExWeapon Wp;

	H = Hud();
	if (Class'RIUtil'.static.PBool(Player, "bBiggerBelt"))
		cnt = 12;
	else
		cnt = 10;
	sw = 72 * S;
	sh = 58 * S;
	gap = 8 * S;
	x0 = width * 0.5 - (cnt * sw + (cnt - 1) * gap) * 0.5;
	y = height - 34 * S - sh;
	Shade(gc, x0 - 180 * S, y - 80 * S, cnt * (sw + gap) + 360 * S, sh + 150 * S);
	Cur = Player.inHandPending;
	if (Cur == None)
		Cur = Player.inHand;
	for (n = 0; n < cnt; n++)
	{
		x = x0 + Class'RIUtil'.static.BeltPos(n) * (sw + gap);
		I = H.belt.GetObjectFromBelt(n);
		bSel = (I != None) && (I == Cur);
		if (bSel)
			SelI = I;

		// underline
		if (bSel)
		{
			CGlow(gc, x - 10 * S, y + sh - 26 * S, sw + 20 * S, 34 * S, C3(64, 52, 20));
			Fill(gc, x, y + sh - 2 * S, sw, 2 * S, C3(242, 211, 107));
		}
		else if (I != None)
			Fill(gc, x + sw * 0.2, y + sh - 1 * S, sw * 0.6, 1 * S, C3(150, 126, 62));
		else
			Fill(gc, x + sw * 0.3, y + sh - 1 * S, sw * 0.4, 1 * S, C3(70, 58, 28));

		// number
		if (bSel)
			Class'RIText'.static.Draw(gc, Class'RIFontSmall', x + 2 * S, y, Mid("0123456789-=", n, 1), C3(255, 241, 194), 0.5);
		else if (I != None)
			Class'RIText'.static.Draw(gc, Class'RIFontSmall', x + 2 * S, y, Mid("0123456789-=", n, 1), C3(184, 154, 87), 0.5);
		else
			Class'RIText'.static.Draw(gc, Class'RIFontSmall', x + 2 * S, y, Mid("0123456789-=", n, 1), C3(90, 76, 38), 0.5);

		// icon
		T = None;
		if (I != None)
			T = I.icon;
		else
			T = Class'RIBase'.static.BeltPlaceholder(Player, n);
		if (T != None)
		{
			k = FMin((sw - 12 * S) / 42.0, (sh - 14 * S) / 37.0);
			iw = 42 * k;
			ih = 37 * k;
			gc.SetStyle(DSTY_Masked);
			if (bSel)
				gc.SetTileColor(C3(255, 255, 255));
			else if (I != None)
				gc.SetTileColor(C3(200, 200, 200));
			else
				gc.SetTileColor(C3(60, 60, 60));
			Class'RIHD'.static.DrawExact(gc, x + (sw - iw) * 0.5, y + 4 * S + (sh - 10 * S - ih) * 0.5, iw, ih, 0, 0, 42, 37, T);
		}

		// count, bottom right
		CountT = "";
		Wp = DeusExWeapon(I);
		P = DeusExPickup(I);
		if ((Wp != None) && (Wp.AmmoType != None) && !Wp.AmmoType.IsA('AmmoNone') && (Wp.ReloadCount > 0))
			CountT = string(Wp.AmmoType.AmmoAmount);
		else if ((P != None) && (P.NumCopies > 1))
			CountT = string(P.NumCopies);
		if (CountT != "")
		{
			if ((Wp != None) && (Wp.AmmoType.AmmoAmount <= 0))
				Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x, y + sh - 18 * S, sw - 2 * S, 14 * S, CountT, C3(255, 120, 90), 2, 0.46);
			else
				Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x, y + sh - 18 * S, sw - 2 * S, 14 * S, CountT, C3(255, 241, 194), 2, 0.46);
		}
	}

	// the selected item's name, centred above the belt
	if (SelI != None)
	{
		BName = SelI.beltDescription;
		if (BName == "")
			BName = SelI.ItemName;
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x0, y - 26 * S, cnt * (sw + gap) - gap, 20 * S, Caps(BName), C3(242, 211, 107), 1, 0.46);
	}
}

// Modern belt, in the manner of Mankind Divided: folder-tab slots (number in
// the tab), a gold glow behind the selected item, a count pill (rounds for
// weapons, copies for pickups), a weapon out of ammo in red, large icons,
// and the item's short name in small type under each slot
function DrawModernBelt(GC gc)
{
	local DeusExHUD H;
	local Inventory I, Cur;
	local int n, cnt, st;
	local float sw, sh, gap, x0, y, x, k, top, iw, ih;
	local Texture T;
	local bool bSel, bWarn;
	local string BName, CountT;
	local DeusExPickup P;
	local DeusExWeapon Wp;

	H = Hud();
	if (Class'RIUtil'.static.PBool(Player, "bBiggerBelt"))
		cnt = 12;
	else
		cnt = 10;
	sw = 80 * S;
	sh = 92 * S;
	gap = 7 * S;
	x0 = width * 0.5 - (cnt * sw + (cnt - 1) * gap) * 0.5;
	y = height - 40 * S - sh;
	Cur = Player.inHandPending;
	if (Cur == None)
		Cur = Player.inHand;
	for (n = 0; n < cnt; n++)
	{
		x = x0 + Class'RIUtil'.static.BeltPos(n) * (sw + gap);
		I = H.belt.GetObjectFromBelt(n);
		bSel = (I != None) && (I == Cur);
		bWarn = False;
		CountT = "";
		Wp = DeusExWeapon(I);
		P = DeusExPickup(I);
		if ((Wp != None) && (Wp.AmmoType != None) && !Wp.AmmoType.IsA('AmmoNone') && (Wp.ReloadCount > 0))
		{
			CountT = string(Wp.AmmoType.AmmoAmount);
			bWarn = (Wp.AmmoType.AmmoAmount <= 0);
		}
		else if ((P != None) && (P.NumCopies > 1))
			CountT = string(P.NumCopies);
		if (bSel)
			st = 2;
		else if (I != None)
			st = 1;
		else
			st = 0;
		top = Class'RIModern'.static.Slot(gc, x, y, sw, sh, S, st, Mid("0123456789-=", n, 1), CountT, bWarn && !bSel);

		T = None;
		if (I != None)
			T = I.icon;
		else
			T = Class'RIBase'.static.BeltPlaceholder(Player, n);
		if (T != None)
		{
			// as large as the body allows, clear of the pill
			// clear of the tab line, the edges and the count pill: a margin
			// all round, centred low in the body
			k = FMin((sw - 26 * S) / 42.0, (y + sh - top - 34 * S) / 37.0);
			iw = 42 * k;
			ih = 37 * k;
			gc.SetStyle(DSTY_Masked);
			if (I != None)
				gc.SetTileColor(C3(255, 255, 255));
			else
				gc.SetTileColor(C3(60, 60, 60));
			Class'RIHD'.static.DrawExact(gc, x + (sw - iw) * 0.5, top + 12 * S + (y + sh - top - 30 * S - ih) * 0.5, iw, ih, 0, 0, 42, 37, T);
		}
		if (I != None)
		{
			BName = I.beltDescription;
			if (BName == "")
				BName = I.ItemName;
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x, y + sh + 3 * S, sw, 11 * S,
				Caps(Class'RIText'.static.Fit(Class'RIFontSmall', BName, sw, 0.34)), C3(170, 140, 80), 0, 0.34);
		}
	}
}

// Modern vitals (the HUD mockup's VITALS panel): the body figure, small, on
// the left; to its right labelled segmented bars, bioelectric and, when
// shown, stamina (or breath under water); stance under them
function DrawModernVitals(GC gc)
{
	local float fx, fy, fw, fh, k, x0, y0, bx, by, bw, f;
	local bool bWater, bTwo;
	local string T;

	bWater = (Player.HeadRegion.Zone != None) && Player.HeadRegion.Zone.bWaterZone;
	bTwo = bWater || Class'RIBase'.static.StaminaShown(Player);

	// the body monitor alone in a small frame
	fx = 24 * S;
	fy = 24 * S;
	fw = 84 * S;
	fh = 140 * S;
	Class'RIModern'.static.Frame(gc, fx, fy, fw, fh, S, 1);
	k = 116 * S / 360.0;
	x0 = fx + (fw - 173 * k) * 0.5;
	y0 = fy + (fh - 116 * S) * 0.5;
	DrawPart(gc, 0, x0, y0, k, Texture'ReimaginedUI.UI.RI_HudHead',  70,   0,  35,  44);
	DrawPart(gc, 1, x0, y0, k, Texture'ReimaginedUI.UI.RI_HudTorso', 58,  43,  59, 125);
	DrawPart(gc, 2, x0, y0, k, Texture'ReimaginedUI.UI.RI_HudArmR',   0,  52,  60, 135);
	DrawPart(gc, 3, x0, y0, k, Texture'ReimaginedUI.UI.RI_HudArmL', 115,  53,  58, 134);
	DrawPart(gc, 4, x0, y0, k, Texture'ReimaginedUI.UI.RI_HudLegR',  36, 138,  51, 221);
	DrawPart(gc, 5, x0, y0, k, Texture'ReimaginedUI.UI.RI_HudLegL',  87, 139,  53, 220);

	// bars to the right, on the world (a soft shade behind for reading)
	bx = fx + fw + 16 * S;
	bw = 170 * S;
	Shade(gc, bx - 40 * S, fy - 30 * S, bw + 110 * S, fh + 50 * S);
	by = fy + 10 * S;
	if (Player.AugmentationSystem != None)
		f = Player.Energy / FMax(1, Class'RIBase'.static.MaxEnergy(Player, False));
	else
		f = 0;
	ModernRow(gc, bx, by, bw, EnergyLabel, string(int(Player.Energy)), f, C3(110, 180, 240));
	if (bTwo)
	{
		f = FClamp(Player.swimTimer / FMax(0.01, Player.swimDuration), 0, 1);
		if (bWater)
			ModernRow(gc, bx, by + 38 * S, bw, BreathLabel, string(int(f * 100)), f, C3(150, 220, 235));
		else
			ModernRow(gc, bx, by + 38 * S, bw, StaminaLabel, string(int(f * 100)), f, C3(242, 211, 107));
	}
	if (Class'RIUtil'.static.PInt(Player, "iStanceHud") > 0)
	{
		T = StanceText();
		if (T != "")
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', bx, fy + fh - 18 * S, bw, 14 * S, Caps(T), C3(184, 154, 87), 0, 0.44);
	}
}

// One vitals row: label left, value right, 20 segments under
function ModernRow(GC gc, float X, float Y, float W, string L, string V, float f, Color OnC)
{
	Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', X, Y, W, 14 * S, Caps(L), C3(184, 154, 87), 0, 0.46);
	Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', X, Y, W, 14 * S, V, C3(255, 241, 194), 2, 0.5);
	Class'RIModern'.static.Segs(gc, X, Y + 17 * S, W, 6 * S, 20, f, OnC, C3(46, 38, 18));
}

// Modern weapon card (the HUD mockup's weapon panel): the name on the tab;
// the icon in a well on the left; the rounds in the magazine large with the
// reserve beside them, each labelled; pips for the magazine; ammo type and
// mods as tags down the right; the belt slot in the corner
function DrawModernWeapon(GC gc, Inventory Inv, DeusExWeapon W, string Big, bool bMag, int clip, int Reserve, bool bReload, bool bLow, bool bMulti, bool bNoAmmo, string AmmoT)
{
	local float FX, FY, FW, FH, NX, k, BigW, tx, ty, pw, px;
	local int i, pips;
	local string N, L;
	local Color BigC;

	FW = 420 * S;
	FH = 150 * S;
	FX = width - 24 * S - FW;
	FY = height - 24 * S - FH;
	N = Inv.beltDescription;
	if (N == "")
		N = Inv.ItemName;
	Class'RIModern'.static.Frame(gc, FX, FY, FW, FH, S, 1, N);

	// icon well
	Class'RIModern'.static.Cell(gc, FX + 18 * S, FY + 38 * S, 112 * S, 92 * S, S, False, 1);
	if (Inv.icon != None)
	{
		k = FMin(104 * S / 42.0, 84 * S / 37.0);
		gc.SetStyle(DSTY_Masked);
		gc.SetTileColor(C3(255, 255, 255));
		Class'RIHD'.static.DrawExact(gc, FX + 18 * S + (112 * S - 42 * k) * 0.5, FY + 38 * S + (92 * S - 37 * k) * 0.5, 42 * k, 37 * k, 0, 0, 42, 37, Inv.icon);
	}

	// numbers
	NX = FX + 148 * S;
	if (bReload)
	{
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', NX, FY + 50 * S, 180 * S, 40 * S, Caps(ReloadLabel), C3(242, 211, 107), 0, 0.62);
	}
	else if (bNoAmmo || (Big == ""))
	{
		Class'RIText'.static.Draw(gc, Class'RIFontTitle', NX, FY + 44 * S, "--", C3(150, 128, 70), 1.0);
	}
	else
	{
		if (bLow)
			BigC = C3(255, 120, 90);
		else
			BigC = C3(255, 241, 194);
		Class'RIText'.static.Draw(gc, Class'RIFontTitle', NX, FY + 44 * S, Big, BigC, 1.0);
		BigW = FMax(40 * S, Class'RIText'.static.Width(Class'RIFontTitle', Big, 1.0));
		if (bMag)
			L = MagLabel;
		else if (W != None)
			L = RoundsLabel;
		else
			L = CountLabel;
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', NX, FY + 104 * S, Caps(L), C3(156, 134, 72), 0.42);
		if (bMag)
		{
			if (Reserve == 0)
				BigC = C3(255, 120, 90);
			else
				BigC = C3(230, 195, 117);
			Class'RIText'.static.Draw(gc, Class'RIFontHead', NX + BigW + 16 * S, FY + 66 * S, "/ " $ string(Reserve), BigC, 0.8);
			Class'RIText'.static.Draw(gc, Class'RIFontSmall', NX + BigW + 16 * S, FY + 104 * S, Caps(ReserveLabel), C3(156, 134, 72), 0.42);
		}
	}
	// magazine pips along the bottom
	if (bMulti && !bReload && (W != None))
	{
		pips = W.ReloadCount;
		pw = FMin(8 * S, (150 * S - (pips - 1) * 2 * S) / pips);
		px = NX;
		for (i = 0; i < pips; i++)
		{
			if (i < clip)
				Fill(gc, px, FY + 124 * S, pw, 6 * S, C3(242, 211, 107));
			else
				Fill(gc, px, FY + 124 * S, pw, 6 * S, C3(46, 38, 18));
			px += pw + 2 * S;
		}
	}

	// tags down the right: ammo type, then mods (lit when in use)
	tx = FX + FW - 22 * S;
	ty = FY + 40 * S;
	if (AmmoT != "")
	{
		Tag(gc, tx - TagW(AmmoT) + 6 * S, ty, AmmoT, False);
		ty += 24 * S;
	}
	if ((W != None) && W.bHasScope)
	{
		Tag(gc, tx - TagW(ScopeLabel) + 6 * S, ty, ScopeLabel, W.bZoomed);
		ty += 24 * S;
	}
	if ((W != None) && W.bHasLaser)
	{
		Tag(gc, tx - TagW(LaserLabel) + 6 * S, ty, LaserLabel, W.bLasing);
		ty += 24 * S;
	}
	if ((W != None) && W.bHasSilencer)
		Tag(gc, tx - TagW(SilencerLabel) + 6 * S, ty, SilencerLabel, False);
	// belt slot, bottom right
	if (Inv.bInObjectBelt && (Inv.beltPos >= 0) && (Inv.beltPos < 12))
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', FX, FY + FH - 30 * S, FW - 22 * S, 14 * S,
			Caps(SlotLabel) @ Mid("0123456789-=", Inv.beltPos, 1), C3(156, 134, 72), 2, 0.44);
}

// Weapon readout, bottom right, in the manner of a classic shooter: no box,
// right-aligned. Name (and belt slot), then the rounds in the magazine large
// with the reserve beside it, magazine pips, and the ammo type and mods.
function DrawWeapon(GC gc)
{
	local DeusExHUD H;
	local Inventory Inv;
	local DeusExWeapon W;
	local DeusExPickup P;
	local float RX, y, k, px, pw, BigW, ResW, NumY, TagsW, IconX, fy;
	local int clip, i, pips, Reserve, Carried;
	local bool bReload, bLow, bMulti, bMag, bNoAmmo;
	local string Big, ResT, N, AmmoT;
	local Color BigC, ResC;

	H = Hud();
	if ((H == None) || (H.ammo == None))
		return;
	Inv = Class'RIBase'.static.HudWeapon(H.ammo);
	if (Inv == None)
		return;
	W = DeusExWeapon(Inv);
	P = DeusExPickup(Inv);

	// Counts, as AE keeps them
	if (W != None)
	{
		bReload = W.IsInState('Reload') && !Class'RIUtil'.static.PBool(W, "bPerShellReload");
		if ((W.AmmoType != None) && !W.AmmoType.IsA('AmmoNone'))
			Carried = W.AmmoType.AmmoAmount;
		if ((W.ReloadCount > 1) || W.IsA('WeaponGEPGun') || (W.AmmoName == Class'Ammo20mm'))
		{
			bMag = True;
			clip = W.AmmoLeftInClip();
			Reserve = Max(0, Class'RIBase'.static.ReserveRounds(W));
			Big = string(clip);
			bLow = ((W.ReloadCount > 1) && (clip <= W.ReloadCount / 2.0)) || (clip == 0);
			bMulti = (W.ReloadCount > 1) && (W.ReloadCount <= 40);
		}
		else if (W.ReloadCount == 0)
			bNoAmmo = True;
		else
		{
			Big = string(Carried);
			bLow = (Carried <= 1);
		}
		if ((W.AmmoType != None) && (DeusExAmmo(W.AmmoType) != None) && !W.AmmoType.IsA('AmmoNone'))
			AmmoT = DeusExAmmo(W.AmmoType).beltDescription;
	}
	else if ((P != None) && (P.NumCopies > 0))
		Big = string(P.NumCopies);

	if (Class'RIModern'.static.On())
	{
		DrawModernWeapon(gc, Inv, W, Big, bMag, clip, Reserve, bReload, bLow, bMulti, bNoAmmo, AmmoT);
		return;
	}
	RX = width - 40 * S;
	y = height - 30 * S;
	if (Class'RIVP'.static.On())
		Class'RIVP'.static.Panel(gc, width - 340 * S, height - 190 * S, 318 * S, 172 * S, 10 * S, 1);
	else if (Class'RIModern'.static.On())
	{
		// sized to the readout: name row on top, tags and pips when shown
		fy = height - 50 * S - 58 * S - 30 * S - 22 * S;
		if ((W != None) && ((AmmoT != "") || W.bHasScope || W.bHasLaser || W.bHasSilencer))
			fy -= 14 * S;
		if (bMulti && !bReload)
			fy -= 20 * S;
		Class'RIModern'.static.Frame(gc, width - 408 * S, fy, 384 * S, height - 24 * S - fy, S, 1);
	}
	else
		Shade(gc, width - 620 * S, height - 260 * S, 760 * S, 330 * S);

	// Bottom row: ammo type and mods, right-aligned
	TagsW = 0;
	if (AmmoT != "")
		TagsW += TagW(AmmoT);
	if ((W != None) && W.bHasScope)
		TagsW += TagW(ScopeLabel);
	if ((W != None) && W.bHasLaser)
		TagsW += TagW(LaserLabel);
	if ((W != None) && W.bHasSilencer)
		TagsW += TagW(SilencerLabel);
	y -= 20 * S;
	if (TagsW > 0)
	{
		px = RX - TagsW + 6 * S;
		if (AmmoT != "")
			px = Tag(gc, px, y, AmmoT, False);
		if (W.bHasScope)
			px = Tag(gc, px, y, ScopeLabel, W.bZoomed);
		if (W.bHasLaser)
			px = Tag(gc, px, y, LaserLabel, W.bLasing);
		if (W.bHasSilencer)
			px = Tag(gc, px, y, SilencerLabel, False);
		y -= 14 * S;
	}

	// Magazine pips, right-aligned
	if (bMulti && !bReload)
	{
		pips = W.ReloadCount;
		pw = FMin(9 * S, (440 * S - (pips - 1) * 2 * S) / pips);
		y -= 10 * S;
		px = RX - (pips * (pw + 2 * S) - 2 * S);
		for (i = 0; i < pips; i++)
		{
			if (i < clip)
				Fill(gc, px, y, pw, 9 * S, C3(242, 211, 107));
			else
				Class'RIText'.static.Box(gc, px, y, pw, 9 * S, C3(74, 62, 28));
			px += pw + 2 * S;
		}
		y -= 10 * S;
	}

	// Numbers: magazine large, reserve beside it
	NumY = y - 58 * S;
	ResW = 0;
	if (bMag)
	{
		ResT = "/ " $ string(Reserve);
		ResW = Class'RIText'.static.Width(Class'RIFontHead', ResT, 0.8);
		if (Reserve == 0)
			ResC = C3(255, 120, 90);
		else
			ResC = C3(230, 195, 117);
		Class'RIText'.static.Draw(gc, Class'RIFontHead', RX - ResW, NumY + 22 * S, ResT, ResC, 0.8);
		ResW += 12 * S;
	}
	BigW = 0;
	if (bReload)
	{
		BigW = Class'RIText'.static.Width(Class'RIFontHead', Caps(ReloadLabel), 0.6);
		Class'RIText'.static.Draw(gc, Class'RIFontHead', RX - ResW - BigW, NumY + 26 * S, Caps(ReloadLabel), C3(242, 211, 107), 0.6);
	}
	else if (bNoAmmo)
	{
		BigW = Class'RIText'.static.Width(Class'RIFontTitle', "--", 1.0);
		Class'RIText'.static.Draw(gc, Class'RIFontTitle', RX - BigW, NumY, "--", C3(168, 143, 78), 1.0);
	}
	else if (Big != "")
	{
		if (bLow)
			BigC = C3(255, 120, 90);
		else
			BigC = C3(255, 241, 194);
		BigW = Class'RIText'.static.Width(Class'RIFontTitle', Big, 1.0);
		Class'RIText'.static.Draw(gc, Class'RIFontTitle', RX - ResW - BigW, NumY, Big, BigC, 1.0);
	}

	// Icon, left of the numbers
	if (Inv.icon != None)
	{
		k = FMin(2.0, 64 * S / 37.0);
		IconX = RX - ResW - BigW - 24 * S - 42 * k;
		gc.SetStyle(DSTY_Masked);
		gc.SetTileColor(C3(255, 255, 255));
		Class'RIHD'.static.DrawExact(gc, IconX, NumY + 4 * S, 42 * k, 37 * k, 0, 0, 42, 37, Inv.icon);
	}

	// Name, and belt slot
	N = Inv.beltDescription;
	if (N == "")
		N = Inv.ItemName;
	N = Caps(N);
	if (Inv.bInObjectBelt && (Inv.beltPos >= 0) && (Inv.beltPos < 12))
		N = N $ "   " $ Mid("0123456789-=", Inv.beltPos, 1);
	Class'RIText'.static.DrawIn(gc, Class'RIFontHead', RX - 460 * S, NumY - 30 * S, 460 * S, 24 * S, N, C3(230, 195, 117), 2, 0.5);
}

function float TagW(string L)
{
	return Class'RIText'.static.Width(Class'RIFontSmall', Caps(L), 0.46) + 20 * S;
}

// Items received: on the left, stacked straight under the message log (one
// column for both), newest at the bottom; each row the item's icon, name
// and quantity. Vanilla+: one framed box the same width as the log's.
function DrawReceived(GC gc)
{
	local DeusExHUD H;
	local HUDReceivedDisplay R;
	local RILogDisplay L;
	local int i, n, Rows, Qty;
	local float a, rh, y, LeftX;
	local string T, Lbl;
	local Texture Ic;
	local byte bDecl;
	local float bw, bx, boxW;

	H = Hud();
	if (H == None)
		return;
	L = RILogDisplay(H.msgLog);
	if (L != None)
		L.MatchW = 0;
	R = H.receivedItems;
	if ((R == None) || !R.bTickEnabled)
		return;
	n = Class'RIBase'.static.ReceivedCount(R);
	if (n <= 0)
		return;
	a = FClamp(R.displayTimer / 0.15, 0, 1) * FClamp((R.displayLength - R.displayTimer) / 0.5, 0, 1);
	if (a <= 0.01)
		return;
	Rows = Min(n, 8);
	if (Rows == 0)
		return;
	rh = 47 * S;
	// under the log's panel when it shows lines, else where it would start.
	// Only a visible log's position counts: a hidden window is never moved,
	// so at the start of a game (and while a transmission hides the log) it
	// still sits at 0,0 and the box landed in the top-left corner.
	LeftX = 36 * S;
	y = 390 * S;
	if ((L != None) && L.IsVisible())
	{
		LeftX = L.x + 8 * S;
		y = L.y + 10 * S;
		if ((L.NumL > 0) && (L.PanelH > 0))
		{
			LeftX = L.x + L.PanelX;
			y = L.y + L.PanelY + L.PanelH + 12 * S;
		}
	}

	T = "";
	if (R.txtReceived != None)
		T = R.txtReceived.GetText();
	if (Right(T, 1) == ":")
		T = Left(T, Len(T) - 1);
	if (T == "")
		T = ReceivedLabel;

	// Vanilla+: one framed box, a row added for each item picked up
	if (Class'RIVP'.static.On())
	{
		Rows = 0;
		bw = 0;
		for (i = 0; (i < n) && (Rows < 8); i++)
			if (Class'RIBase'.static.ReceivedItem(R, i, Ic, Lbl, Qty, bDecl))
			{
				Rows++;
				bw = FMax(bw, Class'RISubs'.static.ToastRowW(S, Lbl, Qty));
			}
		// one width for the log and this box while both are up
		boxW = Class'RISubs'.static.ToastBoxW(S, T, bw);
		if ((L != None) && L.IsVisible() && (L.NumL > 0))
			boxW = FMax(boxW, L.NatW);
		if (L != None)
			L.MatchW = boxW;
		bx = Class'RISubs'.static.ToastBox(gc, LeftX + boxW, y, S, T, boxW - 12 * S, Rows, a);
		y += 46 * S;
		Rows = 0;
		for (i = 0; (i < n) && (Rows < 8); i++)
		{
			if (!Class'RIBase'.static.ReceivedItem(R, i, Ic, Lbl, Qty, bDecl))
				continue;
			Rows++;
			y += Class'RISubs'.static.ToastRow(gc, bx + Class'RISubs'.static.ToastRowW(S, Lbl, Qty), y, S, Ic, Lbl, Qty, bDecl != 0, a, True);
		}
		return;
	}
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', LeftX + 14 * S, y, Caps(T),
		Class'RIUtil'.static.Col(242 * a, 211 * a, 107 * a), 0.66);
	y += 30 * S;

	Rows = 0;
	for (i = 0; (i < n) && (Rows < 8); i++)
	{
		if (!Class'RIBase'.static.ReceivedItem(R, i, Ic, Lbl, Qty, bDecl))
			continue;
		Rows++;
		y += Class'RISubs'.static.ToastRow(gc, LeftX + Class'RISubs'.static.ToastRowW(S, Lbl, Qty), y, S, Ic, Lbl, Qty, bDecl != 0, a);
	}
}

function float Tag(GC gc, float X, float Y, string L, bool bLit)
{
	local float w;

	L = Caps(L);
	w = Class'RIText'.static.Width(Class'RIFontSmall', L, 0.46) + 14 * S;
	if (bLit)
		Class'RIText'.static.Box(gc, X, Y, w, 20 * S, C3(242, 211, 107));
	else
		Class'RIText'.static.Box(gc, X, Y, w, 20 * S, C3(126, 105, 50));
	if (bLit)
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', X, Y, w, 20 * S, L, C3(242, 211, 107), 1, 0.46);
	else
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', X, Y, w, 20 * S, L, C3(230, 195, 117), 1, 0.46);
	return X + w + 6 * S;
}

// ----------------------------------------------------------------------
// Vanilla+ HUD: the "HUD corners" board (body monitor top left, aug rail
// on the right, weapon box bottom right, belt bottom centre), the original
// art tinted to the HUD theme, with the live readouts placed in its boxes.
// Design pixels are 1920 x 1080: left pieces hang off the left edge, right
// pieces off the right edge, centre pieces stay centred.
// ----------------------------------------------------------------------

function float LX(float X) { return X * S; }
function float BY(float Y) { return height - (1080 - Y) * S; }      // kept at the bottom
function float MY(float Y) { return height * 0.5 + (Y - 540) * S; }  // kept at mid-height
function float CX(float X) { return (width - 1920 * S) * 0.5 + X * S; }
function float RX(float X) { return width - (1920 - X) * S; }

// The world darkened behind a HUD panel: a soft shade, darkest in the middle
// and fading out on every side, kept inside the panel's width (it must never
// show past the frame art)
function VDim(GC gc, float X, float Y, float W, float H)
{
	gc.SetStyle(DSTY_Modulated);
	gc.DrawStretchedTexture(X, Y - H * 0.15, W, H * 1.3, 0, 0, 256, 64, Texture'ReimaginedUI.UI.RI_ShadeC');
}

function Art(GC gc, float X, float Y, float W, float H, float U, float V, float UW, float VH, Texture T)
{
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(C3(230, 195, 117));
	gc.DrawStretchedTexture(X, Y, W, H, U, V, UW, VH, T);
}

function DrawVP(GC gc)
{
	if (Player.bHitDisplayVisible)
		DrawVPVitals(gc);
	if (Player.bCompassVisible)
		DrawCompass(gc);
	if (Player.bObjectBeltVisible)
		DrawVPBelt(gc);
	if (Player.bAmmoDisplayVisible)
		DrawVPWeapon(gc);
}

// A vertical bar, filling from the bottom
function VBar(GC gc, float X, float Y, float W, float H, float f, Color C)
{
	f = FClamp(f, 0, 1);
	Fill(gc, X, Y, W, H, C3(26, 22, 10));
	Fill(gc, X, Y + H * (1 - f), W, H * f, C);
	Class'RIText'.static.Box(gc, X - 1, Y - 1, W + 2, H + 2, C3(110, 92, 44));
}

// Vanilla+ BIO / STAMINA tube: ten cells with a lit core, a glowing cap on
// the level, a trail showing what was just spent, quarter notches on the
// outer side (Side -1 = left, 1 = right), and a slow pulse when low
function FancyBar(GC gc, int i, float X, float Y, float W, float H, float f, Color C, int Side)
{
	local int n;
	local float seg, gap, top, cy, lo, hi, p, k, nx;
	local Color Dim, Core;

	BarGoal[i] = FClamp(f, 0, 1);
	f = FClamp(BarShown[i], 0, 1);
	p = 1.0;
	if (BarGoal[i] < 0.25)
		p = 0.82 + 0.18 * Sin(Age * 5.0);
	Dim = Class'RIUtil'.static.Mix(C3(0, 0, 0), C, 0.16);
	Core = Class'RIUtil'.static.Mix(C, C3(255, 255, 255), 0.2);

	// soft light spilling round the filled part
	if (f > 0.01)
		CGlow(gc, X - 9 * S, Y + H * (1 - f) - 4 * S, W + 18 * S, H * f + 8 * S, Class'RIUtil'.static.Mix(C3(0, 0, 0), C, 0.12 * p));

	// cells: dark wells, the trail, the fill with a brighter core
	gap = FMax(1, 1.5 * S);
	seg = (H - 9 * gap) / 10.0;
	for (n = 0; n < 10; n++)
	{
		hi = Y + H - n * (seg + gap);
		lo = hi - seg;
		Fill(gc, X, lo, W, seg, C3(22, 19, 9));
		k = FClamp((BarGhost[i] * H - n * (seg + gap)) / seg, 0, 1);
		if (k > FClamp((f * H - n * (seg + gap)) / seg, 0, 1))
			Fill(gc, X, hi - seg * k, W, seg * k, Class'RIUtil'.static.Mix(C3(0, 0, 0), C3(255, 236, 190), 0.3));
		k = FClamp((f * H - n * (seg + gap)) / seg, 0, 1);
		if (k > 0)
		{
			Fill(gc, X, hi - seg * k, W, seg * k, Class'RIUtil'.static.Mix(Dim, C, 0.72 * p));
			Fill(gc, X + W * 0.3, hi - seg * k, W * 0.4, seg * k, Class'RIUtil'.static.Mix(Dim, Core, 0.4 * p));
		}
	}

	// the level: a bright cap with a small flare
	if (f > 0.005)
	{
		top = Y + H * (1 - f);
		CGlow(gc, X - 12 * S, top - 7 * S, W + 24 * S, 14 * S, Class'RIUtil'.static.Mix(C3(0, 0, 0), Core, 0.24 * p));
		Fill(gc, X - 1.5 * S, top - 0.75 * S, W + 3 * S, 1.5 * S, Class'RIUtil'.static.Mix(C, C3(255, 255, 255), 0.3));
	}

	// casing: hairline, end caps, quarter notches on the outer side
	Class'RIText'.static.Box(gc, X - 2 * S, Y - 2 * S, W + 4 * S, H + 4 * S, C3(110, 92, 44));
	Fill(gc, X - 3 * S, Y - 3 * S, W + 6 * S, 1.5 * S, C3(160, 135, 70));
	Fill(gc, X - 3 * S, Y + H + 1.5 * S, W + 6 * S, 1.5 * S, C3(160, 135, 70));
	if (Side < 0)
		nx = X - 7 * S;
	else
		nx = X + W + 3 * S;
	for (n = 1; n < 4; n++)
	{
		cy = Y + H * (1 - n * 0.25);
		if (n == 2)
			Fill(gc, nx - 1 * S, cy - 0.5 * S, 6 * S, 1 * S, C3(160, 135, 70));
		else
			Fill(gc, nx, cy - 0.5 * S, 4 * S, 1 * S, C3(126, 105, 50));
	}
}

function DrawVPVitals(GC gc)
{
	local float k, f, gx, gy, gs, bx, barX;
	local int n, cols;
	local bool bWater, bStam;
	local string T;

	VDim(gc, LX(38), 34 * S, 118 * S, 154 * S);
	Art(gc, LX(0), 0, 256 * S, 256 * S, 0, 0, 256, 256, Texture'ReimaginedUI.VPlus.VPH_Body');

	// the monitor's grid (14.4 px squares, 44..174). With two bars it is
	// five squares centred between them (62..134); on a base with no
	// stamina (the original) there is no right bar, so the grid takes six
	// squares and the body moves right to fill the screen (57..156)
	cols = 5;
	gx = LX(61.5);
	bx = 68;           // body offset: its visible figure centred on the grid
	barX = 144;          // right bar (stamina / breath)
	if (!Class'RIBase'.static.StaminaShown(Player))
	{
		cols = 6;
		gx = LX(63.3);
		bx = 77;
		barX = 150;      // breath only, inside the screen's right edge
	}
	gy = 44 * S;
	gs = 14.4 * S;
	for (n = 0; n <= cols; n++)
		Class'RIText'.static.VLine(gc, gx + n * gs, gy, 9 * gs, C3(74, 64, 36));
	for (n = 0; n <= 9; n++)
		Class'RIText'.static.HLine(gc, gx, gy + n * gs, cols * gs, C3(74, 64, 36));

	// the body, part by part, its visible figure centred on the grid (measured)
	k = 128 * S / 360.0;
	DrawPart(gc, 0, LX(bx), 46 * S, k, Texture'ReimaginedUI.UI.RI_HudHead',  70,   0,  35,  44);
	DrawPart(gc, 1, LX(bx), 46 * S, k, Texture'ReimaginedUI.UI.RI_HudTorso', 58,  43,  59, 125);
	DrawPart(gc, 2, LX(bx), 46 * S, k, Texture'ReimaginedUI.UI.RI_HudArmR',   0,  52,  60, 135);
	DrawPart(gc, 3, LX(bx), 46 * S, k, Texture'ReimaginedUI.UI.RI_HudArmL', 115,  53,  58, 134);
	DrawPart(gc, 4, LX(bx), 46 * S, k, Texture'ReimaginedUI.UI.RI_HudLegR',  36, 138,  51, 221);
	DrawPart(gc, 5, LX(bx), 46 * S, k, Texture'ReimaginedUI.UI.RI_HudLegL',  87, 139,  53, 220);

	// bioelectric on the left, stamina (breath underwater) on the right
	if (Class'RIUtil'.static.PBool(Player, "bEnergyBarShowsReserve") && (Player.AugmentationSystem != None))
		f = Player.Energy / FMax(1, Class'RIBase'.static.MaxEnergy(Player, True));
	else
		f = Player.Energy / FMax(1, Class'RIBase'.static.MaxEnergy(Player, False));
	FancyBar(gc, 0, LX(45), 46 * S, 6 * S, 128 * S, f, C3(90, 159, 214), -1);
	T = "BIO" @ string(int(Player.Energy));

	bWater = (Player.HeadRegion.Zone != None) && Player.HeadRegion.Zone.bWaterZone;
	bStam = bWater || Class'RIBase'.static.StaminaShown(Player);
	f = FClamp(Player.swimTimer / FMax(0.01, Player.swimDuration), 0, 1);
	if (bWater)
	{
		FancyBar(gc, 1, LX(barX), 46 * S, 6 * S, 128 * S, f, C3(150, 220, 235), 1);
		T = T $ "  -  " $ Caps(BreathLabel) @ string(int(f * 100));
	}
	else if (bStam)
	{
		FancyBar(gc, 1, LX(barX), 46 * S, 6 * S, 128 * S, f, C3(201, 205, 209), 1);
		T = T $ "  -  " $ Caps(StaminaLabel) @ string(int(f * 100));
	}
	// (no stamina on this base, e.g. the original: the right bar only appears
	// underwater, as breath; a full bar that never drains would mislead)
	Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', LX(0), 226 * S, 196 * S, 18 * S,
		Caps(Class'RIText'.static.Fit(Class'RIFontSmall', T, 190 * S, 0.5)), C3(200, 204, 208), 1, 0.5);

	if (Class'RIUtil'.static.PInt(Player, "iStanceHud") > 0)
	{
		T = StanceText();
		if (T != "")
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', LX(10), 250 * S, 180 * S, 16 * S, Caps(T), C3(184, 154, 87), 1, 0.42);
	}
}

// Augs (and running charged items) down the right-hand rail, F-key beside each
function DrawVPAugs(GC gc)
{
	local Augmentation Aug;
	local Inventory I;
	local ChargedPickup CP;
	local int n, k;
	local float step, x, y, c, top;

	n = 0;
	if (Player.AugmentationSystem != None)
		for (Aug = Player.AugmentationSystem.FirstAug; Aug != None; Aug = Aug.next)
			if (Class'RIBase'.static.AugCanActivate(Aug) && (Player.bHUDShowAllAugs || Aug.bIsActive))
				n++;
	for (I = Player.Inventory; I != None; I = I.Inventory)
		if ((ChargedPickup(I) != None) && ChargedPickup(I).bIsActive)
			n++;
	if (n == 0)
		return;

	// the original game's aug bar: a column down the right edge, on a thin
	// spine, keys on the left; it stops above the timer and weapon box
	c = 44 * S;
	top = 150 * S;
	y = height - 330 * S - c;      // lowest cell: clear of the weapon box art (top at 796) and the timer above it
	step = 58 * S;
	if (n > 1)
		step = FMin(58 * S, (y - top) / (n - 1));
	x = width - 52 * S - c;
	y = top + (n - 1) * step;
	Class'RIText'.static.VLine(gc, x + c + 14 * S, top + c * 0.5, y - top, C3(110, 92, 44));
	Fill(gc, x + c + 10 * S, top + c * 0.5 - 0.5 * S, 7 * S, 1.5 * S, C3(160, 135, 70));
	Fill(gc, x + c + 10 * S, y + c * 0.5 - 0.5 * S, 7 * S, 1.5 * S, C3(160, 135, 70));

	k = 0;
	if (Player.AugmentationSystem != None)
		for (Aug = Player.AugmentationSystem.FirstAug; Aug != None; Aug = Aug.next)
		{
			if (!Class'RIBase'.static.AugCanActivate(Aug) || (!Player.bHUDShowAllAugs && !Aug.bIsActive))
				continue;
			VPAugCell(gc, x, top + k * step, c, AugIcon(Aug), Aug.bIsActive, HotKey(Aug.HotKeyNum), -1, Class'RIBase'.static.AugColor(Aug, True));
			k++;
		}
	for (I = Player.Inventory; I != None; I = I.Inventory)
	{
		CP = ChargedPickup(I);
		if ((CP == None) || !CP.bIsActive)
			continue;
		VPAugCell(gc, x, top + k * step, c, CP.ChargedIcon, True, "", FClamp(CP.GetCurrentCharge() / 100.0, 0, 1), C3(255, 255, 255));
		k++;
	}
}

// One aug: no box. Active: a soft glow behind the icon, a notch lit on the
// spine (to the right of the icon) and a short bar under it; idle: the icon
// dimmed. Key to the left, toward the screen.
function VPAugCell(GC gc, float X, float Y, float C, Texture Icon, bool bOn, string Key, float Charge, Color Tint)
{
	if (bOn)
	{
		CGlow(gc, X - C * 0.45, Y - C * 0.3, C * 1.9, C * 1.6, C3(70, 58, 26));
		Fill(gc, X + C + 13 * S, Y + C * 0.5 - 4 * S, 3 * S, 8 * S, C3(242, 211, 107));
		Fill(gc, X + C * 0.2, Y + C + 2 * S, C * 0.6, 1.5 * S, C3(242, 211, 107));
	}
	else
		Fill(gc, X + C + 12 * S, Y + C * 0.5 - 0.5 * S, 5 * S, 1 * S, C3(110, 92, 44));
	if (Icon != None)
	{
		gc.SetStyle(DSTY_Translucent);      // as the game draws them (see DrawAugCell)
		if (bOn)
			gc.SetTileColor(Tint);
		else
			gc.SetTileColor(Class'RIUtil'.static.Mix(C3(0, 0, 0), Tint, 0.45));
		Class'RIHD'.static.DrawAugIcon(gc, X + 4 * S, Y + 4 * S, C - 8 * S, C - 8 * S, Icon);
	}
	if (Charge >= 0)
	{
		Fill(gc, X + 4 * S, Y + C + 2 * S, C - 8 * S, 2 * S, C3(40, 33, 15));
		Fill(gc, X + 4 * S, Y + C + 2 * S, (C - 8 * S) * Charge, 2 * S, C3(242, 211, 107));
	}
	if (Key != "")
	{
		if (bOn)
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', X - 50 * S, Y + (C - 16 * S) * 0.5, 40 * S, 16 * S, Key, C3(255, 241, 194), 2, 0.5);
		else
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', X - 50 * S, Y + (C - 16 * S) * 0.5, 40 * S, 16 * S, Key, C3(140, 118, 66), 2, 0.5);
	}
}

// The belt's backing: the world darkened evenly across the whole inside of
// the frame, end to end (the soft shade left both ends lighter)
function BeltBacking(GC gc, float X, float Y, float W, float H)
{
	gc.SetStyle(DSTY_Modulated);
	gc.DrawStretchedTexture(X, Y, W, H, 0, 0, 16, 16, Texture'ReimaginedUI.UI.RI_Dark');
}

// Belt in the board's ten slots, at Settings > Interface > Hotbar size
// (S scaled for the belt alone: CX keeps it centred, BY at the bottom)
function DrawVPBelt(GC gc)
{
	local float S0, M0;

	S0 = S;
	M0 = Class'RIText'.default.TextMul;
	S = S * Class'RIRootWindow'.static.BeltK();
	Class'RIText'.default.TextMul = M0 * Class'RIRootWindow'.static.BeltK();
	DrawVPBeltIn(gc);
	S = S0;
	Class'RIText'.default.TextMul = M0;
}

function DrawVPBeltIn(GC gc)
{
	local DeusExHUD H;
	local Inventory I, Cur;
	local int n, cnt;
	local float x, y, sw, sh, pitch, k, x0;
	local Texture T;
	local bool bSel;
	local string BName;
	local DeusExPickup P;

	H = Hud();
	if ((H == None) || (H.belt == None))
		return;
	// the art's slots: 85.5 wide, 102 apart, 888..986 (names under 964).
	// The 12-slot belt has its own art, two slots wider, still centred.
	if (Class'RIUtil'.static.PBool(Player, "bBiggerBelt"))
	{
		cnt = 12;
		x0 = 340.5;
		// The left end of this piece of art is drawn the other way round from
		// the right end (its gold bar sits outside the frame): skip it and use
		// the right end's cap, mirrored into its own texture (VPH_Belt12_L;
		// the slots are centred on 944.25)
		Art(gc, CX(338), BY(856), 400 * S, 176 * S, 44, 0, 400, 176, Texture'ReimaginedUI.VPlus.VPH_Belt12_0');
		Art(gc, CX(306.5), BY(856), 31 * S, 176 * S, 0, 0, 31, 176, Texture'ReimaginedUI.VPlus.VPH_Belt12_L');
		Art(gc, CX(738), BY(856), 444 * S, 176 * S, 0, 0, 444, 176, Texture'ReimaginedUI.VPlus.VPH_Belt12_1');
		Art(gc, CX(1182), BY(856), 444 * S, 176 * S, 0, 0, 444, 176, Texture'ReimaginedUI.VPlus.VPH_Belt12_2');
	}
	else
	{
		cnt = 10;
		x0 = 438.5;
		// The board in two pieces that meet in the gap between slots 5 and 6
		// (design x 940). The old three pieces met at 768, inside slot 4,
		// and the join showed as a line through it. The left end is the right
		// end's cap mirrored (the art's own left end didn't match).
		Art(gc, CX(372), BY(856), 568 * S, 176 * S, 0, 0, 568, 176, Texture'ReimaginedUI.VPlus.VPH_BeltA');
		Art(gc, CX(940), BY(856), 580 * S, 176 * S, 0, 0, 580, 176, Texture'ReimaginedUI.VPlus.VPH_BeltB');
	}
	pitch = 102;
	sw = 85.5 * S;
	sh = 98 * S;
	y = BY(888);
	Cur = Player.inHandPending;
	if (Cur == None)
		Cur = Player.inHand;
	for (n = 0; n < cnt; n++)
	{
		x = CX(x0 + Class'RIUtil'.static.BeltPos(n) * pitch);
		I = H.belt.GetObjectFromBelt(n);
		bSel = (I != None) && (I == Cur);
		if (bSel)
		{
			Fill(gc, x, y, sw, sh, C3(46, 38, 17));
			Class'RISkin'.static.Box2(gc, x - 2 * S, y - 2 * S, sw + 4 * S, sh + 4 * S, C3(255, 241, 194));
		}
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x, y + 3 * S, sw - 5 * S, 16 * S, Mid("0123456789-=", n, 1), C3(242, 211, 107), 2, 0.54);
		T = None;
		if (I != None)
			T = I.icon;
		else
			T = Class'RIBase'.static.BeltPlaceholder(Player, n);
		if (T != None)
		{
			k = FMin((sw - 16 * S) / 42.0, 56 * S / 37.0);
			gc.SetStyle(DSTY_Masked);
			if (I != None)
				gc.SetTileColor(C3(255, 255, 255));
			else
				gc.SetTileColor(C3(80, 80, 80));
			Class'RIHD'.static.DrawExact(gc, x + (sw - 42 * k) * 0.5, y + 14 * S + (62 * S - 37 * k) * 0.5, 42 * k, 37 * k, 0, 0, 42, 37, T);
		}
		if (I != None)
		{
			BName = I.beltDescription;
			if (BName == "")
				BName = I.ItemName;
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x + 2 * S, BY(965), sw - 4 * S, 21 * S,
				Caps(Class'RIText'.static.Fit(Class'RIFontSmall', BName, sw - 4 * S, 0.42)), C3(255, 241, 194), 1, 0.42);
			P = DeusExPickup(I);
			if ((P != None) && (P.NumCopies > 1))
				Class'RIText'.static.Draw(gc, Class'RIFontSmall', x + 5 * S, y + 3 * S, string(P.NumCopies), C3(255, 241, 194), 0.5);
		}
	}
}

// Weapon box: name above it, rounds large in the main box with the reserve
// under them, ammo type and active mod in the two small boxes
function DrawVPWeapon(GC gc)
{
	local DeusExHUD H;
	local Inventory Inv;
	local DeusExWeapon W;
	local DeusExPickup P;
	local int clip, Reserve, Carried;
	local bool bReload, bLow, bMag, bNoAmmo;
	local string Big, Sub, N, AmmoT, ModT;
	local bool bModLit;
	local Color BigC;

	H = Hud();
	if ((H == None) || (H.ammo == None))
		return;
	Inv = Class'RIBase'.static.HudWeapon(H.ammo);
	if (Inv == None)
		return;
	W = DeusExWeapon(Inv);
	P = DeusExPickup(Inv);
	if (W != None)
	{
		bReload = W.IsInState('Reload') && !Class'RIUtil'.static.PBool(W, "bPerShellReload");
		if ((W.AmmoType != None) && !W.AmmoType.IsA('AmmoNone'))
			Carried = W.AmmoType.AmmoAmount;
		if ((W.ReloadCount > 1) || W.IsA('WeaponGEPGun') || (W.AmmoName == Class'Ammo20mm'))
		{
			bMag = True;
			clip = W.AmmoLeftInClip();
			Reserve = Max(0, Class'RIBase'.static.ReserveRounds(W));
			Big = string(clip);
			Sub = "/ " $ string(Reserve);
			bLow = ((W.ReloadCount > 1) && (clip <= W.ReloadCount / 2.0)) || (clip == 0);
		}
		else if (W.ReloadCount == 0)
			bNoAmmo = True;
		else
		{
			Big = string(Carried);
			bLow = (Carried <= 1);
		}
		if ((W.AmmoType != None) && (DeusExAmmo(W.AmmoType) != None) && !W.AmmoType.IsA('AmmoNone'))
			AmmoT = DeusExAmmo(W.AmmoType).beltDescription;
		if (W.bHasLaser)
		{
			ModT = LaserLabel;
			bModLit = W.bLasing;
		}
		else if (W.bHasScope)
		{
			ModT = ScopeLabel;
			bModLit = W.bZoomed;
		}
		else if (W.bHasSilencer)
			ModT = SilencerLabel;
	}
	else if ((P != None) && (P.NumCopies > 0))
		Big = string(P.NumCopies);

	VDim(gc, RX(1673), BY(837), 162 * S, 108 * S);
	Art(gc, RX(1632), BY(796), 256 * S, 192 * S, 0, 0, 256, 192, Texture'ReimaginedUI.VPlus.VPH_Weapon');

	N = Inv.beltDescription;
	if (N == "")
		N = Inv.ItemName;
	N = Caps(N);
	if (Inv.bInObjectBelt && (Inv.beltPos >= 0) && (Inv.beltPos < 12))
		N = N $ "  " $ Mid("0123456789-=", Inv.beltPos, 1);
	Class'RIText'.static.DrawIn(gc, Class'RIFontHead', RX(1600), BY(808), 234 * S, 22 * S,
		Class'RIText'.static.Fit(Class'RIFontHead', N, 234 * S, 0.42), C3(255, 241, 194), 2, 0.42);

	// main box (1689, 848, 86 x 76)
	if (bReload)
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', RX(1689), BY(848), 86 * S, 76 * S, Caps(ReloadLabel), C3(242, 211, 107), 1, 0.46);
	else if (bNoAmmo)
		Class'RIText'.static.DrawIn(gc, Class'RIFontTitle', RX(1689), BY(848), 86 * S, 76 * S, "--", C3(168, 143, 78), 1, 0.7);
	else if (Big != "")
	{
		if (bLow)
			BigC = C3(255, 120, 90);
		else
			BigC = C3(255, 241, 194);
		if (Sub != "")
		{
			Class'RIText'.static.DrawIn(gc, Class'RIFontTitle', RX(1689), BY(850), 86 * S, 48 * S, Big, BigC, 1, 0.72);
			if (Reserve == 0)
				Class'RIText'.static.DrawIn(gc, Class'RIFontHead', RX(1689), BY(898), 86 * S, 22 * S, Sub, C3(255, 120, 90), 1, 0.46);
			else
				Class'RIText'.static.DrawIn(gc, Class'RIFontHead', RX(1689), BY(898), 86 * S, 22 * S, Sub, C3(230, 195, 117), 1, 0.46);
		}
		else
			Class'RIText'.static.DrawIn(gc, Class'RIFontTitle', RX(1689), BY(848), 86 * S, 76 * S, Big, BigC, 1, 0.72);
	}

	// small boxes (1779, 865 / 888, 40 x 19)
	if (AmmoT != "")
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', RX(1779), BY(865), 40 * S, 19 * S,
			Caps(Class'RIText'.static.Fit(Class'RIFontSmall', AmmoT, 38 * S, 0.34)), C3(230, 195, 117), 1, 0.34);
	if (ModT != "")
	{
		if (bModLit)
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', RX(1779), BY(888), 40 * S, 19 * S,
				Caps(Class'RIText'.static.Fit(Class'RIFontSmall', ModT, 38 * S, 0.34)), C3(255, 241, 194), 1, 0.34);
		else
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', RX(1779), BY(888), 40 * S, 19 * S,
				Caps(Class'RIText'.static.Fit(Class'RIFontSmall', ModT, 38 * S, 0.34)), C3(168, 143, 78), 1, 0.34);
	}
}

defaultproperties
{
     VitalsTitle="Vitals"
     BioShort="BIO"
     StaminaShort="STA"
     BreathShort="O2"
     HealthLabel="Health"
     EnergyLabel="Bioelectric"
     StaminaLabel="Stamina"
     BreathLabel="Breath"
     WalkLabel="Walking"
     RunLabel="Running"
     CrouchLabel="Crouching"
     LeanLabel="Leaning"
     SwimLabel="Swimming"
     ReloadLabel="Reloading"
     ClipsLabel="Clips"
     RoundsLabel="Rounds"
     ScopeLabel="Scope"
     LaserLabel="Laser"
     SilencerLabel="Silencer"
     SlotLabel="Slot"
     MagLabel="Magazine"
     ReserveLabel="Reserve"
     TotalLabel="Total"
     MagsLabel="Mags"
     CountLabel="Carried"
     ReceivedLabel="Received"
     CompassNames(0)="N"
     CompassNames(1)="NE"
     CompassNames(2)="E"
     CompassNames(3)="SE"
     CompassNames(4)="S"
     CompassNames(5)="SW"
     CompassNames(6)="W"
     CompassNames(7)="NW"
}

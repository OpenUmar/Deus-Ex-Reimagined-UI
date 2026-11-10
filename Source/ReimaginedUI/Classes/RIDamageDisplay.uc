//=============================================================================
// RIDamageDisplay
// The damage indicator for the rebuilt HUD, in place of AE's red box of
// arrows. AE still reports every hit (its AddIcon: the damage type and the
// direction it came from); here each hit becomes a soft halo of light at
// the edge of the screen on the side it came from, in the damage type's
// colour (red for gunfire, orange for fire, blue for electricity, green for
// gas...), stronger for harder hits, fading in about a second. Damage with
// no direction (gas, radiation, drowning) glows round the whole edge. While
// the head or torso is badly hurt, a slow red pulse stays at the edges.
// The damage type icons sit small under the body monitor, and AE's
// "% absorbed" readout shows under the crosshair.
// With the HUD on Classic it draws exactly as AE's.
//=============================================================================
class RIDamageDisplay extends DamageHUDDisplay;

const MAXHITS = 12;

var float HitTime[12], HitDir[12], HitStr[12];
var byte  HitCenter[12];
var Color HitCol[12];
var int   NumHits;
var float PrevHealth;

function bool RIOn()
{
	return (RIDeusExHUD(GetParent()) != None) && RIDeusExHUD(GetParent()).bRI;
}

function AddIcon(name damageType, vector hitOffset)
{
	local int i, j, k;
	local float dmg;
	local Color C;
	local bool bFound;

	Super.AddIcon(damageType, hitOffset);
	if ((damageType == '') || (player == None))
		return;

	// the type's colour (AE's table); anything else reads as a hit
	C.R = 230;
	C.G = 40;
	C.B = 30;
	for (i = 0; (i < ArrayCount(iconInfo)) && !bFound; i++)
		for (j = 0; j < ArrayCount(iconInfo[i].damageType); j++)
			if (iconInfo[i].damageType[j] == damageType)
			{
				if (i != 6)
					C = iconInfo[i].color;
				bFound = True;
				break;
			}

	if (NumHits >= MAXHITS)
	{
		for (k = 1; k < MAXHITS; k++)
		{
			HitTime[k - 1] = HitTime[k];
			HitDir[k - 1] = HitDir[k];
			HitStr[k - 1] = HitStr[k];
			HitCenter[k - 1] = HitCenter[k];
			HitCol[k - 1] = HitCol[k];
		}
		NumHits = MAXHITS - 1;
	}
	dmg = FMax(0, PrevHealth - player.Health);
	HitTime[NumHits] = player.Level.TimeSeconds;
	HitDir[NumHits] = Rotator(hitOffset).Yaw;
	HitCenter[NumHits] = byte(hitOffset == vect(0, 0, 0));
	HitStr[NumHits] = FClamp(0.5 + dmg / 30.0, 0.5, 1.0);
	HitCol[NumHits] = C;
	NumHits++;
	if (!IsVisible())
		Show();
}

function Glow(GC gc, float X, float Y, float W, float H, Color C, float a)
{
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(Class'RIUtil'.static.Raw(C.R * a, C.G * a, C.B * a));
	gc.DrawStretchedTexture(X, Y, W, H, 0, 0, 256, 64, Texture'ReimaginedUI.UI.RI_GlowC');
}

// A ring of light round the whole edge
function EdgeRing(GC gc, Color C, float a)
{
	Glow(gc, -width * 0.1, -height * 0.18, width * 1.2, height * 0.36, C, a);
	Glow(gc, -width * 0.1, height * 0.82, width * 1.2, height * 0.36, C, a);
	Glow(gc, -width * 0.12, -height * 0.1, width * 0.24, height * 1.2, C, a);
	Glow(gc, width * 0.88, -height * 0.1, width * 0.24, height * 1.2, C, a);
}

function DrawWindow(GC gc)
{
	local int i, j, n;
	local float now, t, a, ang, sa, ca, ex, ey, gw, gh, S, vit, ix, iy, strW, strH;
	local bool bAny;
	local Color Red;
	local string strInfo;

	if (!RIOn())
	{
		Super.DrawWindow(gc);
		return;
	}
	if (player == None)
		return;
	now = player.Level.TimeSeconds;
	S = height / 1080.0;

	// Hits: a halo on the side each came from
	for (i = 0; i < NumHits; i++)
	{
		t = now - HitTime[i];
		a = 1.0 - t / 1.1;
		if (a <= 0)
			continue;
		bAny = True;
		a = a * a * HitStr[i];
		if (HitCenter[i] != 0)
		{
			EdgeRing(gc, HitCol[i], a * 0.8);
			continue;
		}
		ang = HitDir[i] / 65536.0 * 6.2831853;
		sa = Sin(ang);
		ca = Cos(ang);
		ex = width * 0.5 + sa * width * 0.52;
		ey = height * 0.5 - ca * height * 0.52;
		gw = width * (0.22 + 0.5 * Abs(ca));
		gh = height * (0.3 + 0.55 * Abs(sa));
		Glow(gc, ex - gw * 0.5, ey - gh * 0.5, gw, gh, HitCol[i], a);
		Glow(gc, ex - gw * 0.3, ey - gh * 0.3, gw * 0.6, gh * 0.6, HitCol[i], a * 0.8);
	}
	// drop the ones that have faded
	n = 0;
	for (i = 0; i < NumHits; i++)
		if (now - HitTime[i] < 1.1)
		{
			HitTime[n] = HitTime[i];
			HitDir[n] = HitDir[i];
			HitStr[n] = HitStr[i];
			HitCenter[n] = HitCenter[i];
			HitCol[n] = HitCol[i];
			n++;
		}
	NumHits = n;

	// Badly hurt head or torso: a slow red pulse at the edges
	vit = FMin(float(player.HealthHead) / FMax(1, player.default.HealthHead),
		float(player.HealthTorso) / FMax(1, player.default.HealthTorso));
	if ((vit < 0.3) && (player.Health > 0))
	{
		Red.R = 200;
		Red.G = 20;
		Red.B = 16;
		EdgeRing(gc, Red, (1.0 - vit / 0.3) * (0.35 + 0.25 * Sin(now * 4.0)));
		bAny = True;
	}

	// Damage type icons, small, under the body monitor (AE's fade)
	ix = 40 * S;
	iy = 256 * S;
	for (i = 0; i < ArrayCount(iconInfo); i++)
	{
		if (!iconInfo[i].bActive)
			continue;
		a = 1.0 - ((now - iconInfo[i].initTime) / fadeTime);
		if (a <= 0)
		{
			iconInfo[i].bActive = False;
			iconInfo[i].initTime = 0;
			iconInfo[i].hitDir = 0;
			iconInfo[i].bHitCenter = False;
			continue;
		}
		bAny = True;
		if (iconInfo[i].icon != None)
		{
			gc.SetStyle(DSTY_Translucent);
			gc.SetTileColor(Class'RIUtil'.static.Raw(iconInfo[i].color.R * a, iconInfo[i].color.G * a, iconInfo[i].color.B * a));
			Class'RIHD'.static.DrawStretched(gc, ix, iy, 30 * S, 30 * S, 0, 0, iconInfo[i].icon.USize, iconInfo[i].icon.VSize, iconInfo[i].icon);
			ix += 36 * S;
		}
	}

	// Armour absorbed part of it
	if (absorptionPercent != 0.0)
	{
		if (bAny)
		{
			strInfo = Caps(Sprintf(msgAbsorbed, Int(absorptionPercent * 100.0)));
			strW = Class'RIText'.static.Width(Class'RIFontSmall', strInfo, 0.6);
			Class'RIText'.static.Draw(gc, Class'RIFontSmall', (width - strW) * 0.5, height * 0.5 + 54 * S, strInfo,
				Class'RIUtil'.static.Raw(120, 230, 140), 0.6);
		}
		else
			absorptionPercent = 0.0;
	}
	PrevHealth = player.Health;
}

event InitWindow()
{
	Super.InitWindow();
	bTickEnabled = True;
}

event Tick(float deltaSeconds)
{
	// health before the next hit (AddIcon may come after health has dropped)
	if ((player != None) && (NumHits == 0))
		PrevHealth = player.Health;
}

defaultproperties
{
}

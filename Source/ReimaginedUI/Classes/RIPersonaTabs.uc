//=============================================================================
// RIPersonaTabs
// For in-game screens that still use AE's own page layout (Inventory,
// Health, Augmentations, Images, Logs, Conversations, Outfit): replaces AE's
// button-style nav bar with the text tab row used by the rebuilt screens, in
// the original gold. Sits exactly where AE's nav bar was; AE's page, its
// widgets and its keyboard focus are untouched.
//=============================================================================
class RIPersonaTabs extends RIPersonaView;

var localized string NewViewLabel;

function AttachTo(PersonaScreenBaseWindow NewScreen)
{
	Screen = NewScreen;
	Player = DeusExPlayer(Screen.GetPlayerPawn());
	SetSelectability(False);
	ActiveTab = TabFor(Screen);
	Place();
}

static function int TabFor(Window W)
{
	if (W.IsA('PersonaScreenInventory'))      return TAB_INV;
	if (W.IsA('PersonaScreenHealth'))         return TAB_HEALTH;
	if (W.IsA('PersonaScreenAugmentations'))  return TAB_AUGS;
	if (W.IsA('PersonaScreenSkills'))         return TAB_SKILLS;
	if (W.IsA('PersonaScreenGoals'))          return TAB_GOALS;
	if (W.IsA('PersonaScreenOutfits'))        return TAB_OUTFIT;
	if (W.IsA('PersonaScreenConversations'))  return TAB_CONS;
	if (W.IsA('PersonaScreenImages'))         return TAB_IMAGES;
	if (W.IsA('PersonaScreenLogs'))           return TAB_LOGS;
	return 0;
}

// Over AE's nav bar, which is hidden
function Place()
{
	local Window N;

	N = Screen.winNavBar;
	if (N == None)
		return;
	ConfigureChild(N.x, N.y, N.width, N.height);
	if (N.IsVisible(False))
		N.Hide();
}

event Tick(float deltaSeconds)
{
	Age += deltaSeconds;
	if (Screen == None)
		return;
	Place();
	if (RIRootWindow(GetRootWindow()) != None)
		RIRootWindow(GetRootWindow()).GuardInitCount("Tabs");
}

function bool HasNewView()
{
	return Screen.IsA('PersonaScreenSkills') || Screen.IsA('PersonaScreenGoals') || Screen.IsA('PersonaScreenHealth')
		|| Screen.IsA('PersonaScreenAugmentations') || Screen.IsA('PersonaScreenInventory')
		|| Screen.IsA('PersonaScreenConversations') || Screen.IsA('PersonaScreenImages') || Screen.IsA('PersonaScreenLogs') || Screen.IsA('PersonaScreenOutfits');
}

event bool MouseButtonPressed(float pointX, float pointY, EInputKey button, int numClicks)
{
	if ((button == IK_LeftMouse) && (HotAt(pointX, pointY) == 11))
	{
		SwitchView(False);
		return True;
	}
	return Super.MouseButtonPressed(pointX, pointY, button, numClicks);
}

// Keys stay with AE's page
event bool VirtualKeyPressed(EInputKey key, bool bRepeat)
{
	return False;
}

event DrawWindow(GC gc)
{
	local int i;
	local float x, w, tw, ly, a, sc;
	local bool bOn, bHot;
	local string L;

	if (Screen == None)
		return;
	NumHot = 0;
	S = GetRootWindow().height / 1080.0;
	a = Class'RIUtil'.static.Phase(Age, 0.0, 0.2);
	gc.EnableSmoothing(True);
	BuildTabs();

	ly = height - 2;
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(C3(126, 105, 50, a));
	gc.DrawStretchedTexture(0, ly, width, 1.5, 0, 0, 256, 64, Texture'ReimaginedUI.UI.RI_Glow');

	// This page's section row, after a gap (no room for a second tier here)
	for (i = 0; i < NumSubs; i++)
	{
		TabId[NumTabs] = HOT_SUB + SubId[i];
		TabLabel[NumTabs] = SubNames[SubId[i]];
		NumTabs++;
	}

	// "New view" on pages that have a rebuilt version
	if (HasNewView())
	{
		TabId[NumTabs] = 11;
		TabLabel[NumTabs] = NewViewLabel;
		NumTabs++;
	}
	w = width / NumTabs;
	sc = FMin(0.5, 0.5 * (height / (30 * S)));
	x = 0;
	for (i = 0; i < NumTabs; i++)
	{
		bOn = (TabId[i] == MainOf(ActiveTab)) || (TabId[i] == HOT_SUB + ActiveTab);
		bHot = (HoverId == TabId[i]);
		L = Caps(TabLabel[i]);
		L = Class'RIText'.static.Fit(Class'RIFontHead', L, w - 6, sc);
		tw = Class'RIText'.static.Width(Class'RIFontHead', L, sc);
		if (TabId[i] == 11)
			Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x, 0, w, height - 2, L,
				Class'RIUtil'.static.Mix(AHi(a), C3(255, 255, 255, a), int(bHot)), 1, sc);
		else if (bOn)
		{
			CGlow(gc, x + (w - tw) * 0.5 - 20, 0, tw + 40, height, C3(52, 44, 20, a));
			Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x, 0, w, height - 2, L, C3(255, 240, 190, a), 1, sc);
			Fill(gc, x + (w - tw) * 0.5, ly - 1, tw, 2.5, AHi(a));
		}
		else if (bHot)
			Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x, 0, w, height - 2, L, AAcc(a), 1, sc);
		else
			Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x, 0, w, height - 2, L, ALbl(a), 1, sc);
		AddHot(TabId[i], x, 0, w, height);
		x += w;
	}
}

defaultproperties
{
     NewViewLabel="New view"
}

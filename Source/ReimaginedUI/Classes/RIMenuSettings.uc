//=============================================================================
// RIMenuSettings
// Full-screen settings layout after the concept: outer glowing frame,
// SETTINGS header, categories down the left, and a content panel on the right.
// Picking a category opens AE's own screen inside the content panel; most are
// drawn natively by RIPanel (RIRootWindow decides), so every AE/GMDX option
// keeps working with the reimagined look.
// There is no OK / Cancel: changes are kept with Apply. Leaving a screen with
// unapplied changes asks Apply / Discard / Stay.
//=============================================================================
class RIMenuSettings extends MenuSettings;

const LEAVE_PREVIOUS = -2;      // close settings (Previous Menu)
const LEAVE_BACK     = -3;      // close only the top screen

var float AnimTime;
var int   ActiveIndex;          // category currently open, -1 = none
var int   FirstCategory;        // (unused)

var int    PendingTarget;
var Window PromptBox;

// Layout (root coordinates; this window fills the root)
var float S;
var float FrameX, FrameY, FrameW, FrameH;
var float NavX, NavY, NavW, NavButtonH, NavGap;
var float ContentX, ContentY, ContentW, ContentH;

var localized string HeaderText;
var localized string EmptyText;
var localized string UnsavedTitle;
var localized string UnsavedText;
var localized string ApplyChoice;
var localized string DiscardChoice;
var localized string StayChoice;

event InitWindow()
{
	Super.InitWindow();

	SetWindowAlignments(HALIGN_Full, VALIGN_Full);
	ActiveIndex = -1;
	bTickEnabled = True;
}

function CreateControls()
{
}

function CreateMenuButtons()
{
	local int i;
	local RIMenuButton btn;

	for (i = 0; i < arrayCount(buttonDefaults); i++)
	{
		if (NewButtonNames[i] == "")
			break;

		btn = RIMenuButton(NewChild(Class'RIMenuButton'));
		btn.SetButtonText(NewButtonNames[i]);
		btn.TextScale = 0.9;
		btn.Slot = i;
		winButtons[i] = btn;
	}
}

event ParentRequestedPreferredSize(bool bWidthSpecified, out float preferredWidth,
                                   bool bHeightSpecified, out float preferredHeight)
{
	preferredWidth  = root.width;
	preferredHeight = root.height;
}

function ConfigurationChanged()
{
	local int i;

	S = height / 1080.0;

	FrameX = 30 * S;
	FrameY = 30 * S;
	FrameW = width - 60 * S;
	FrameH = height - 60 * S;

	NavX = 70 * S;
	NavY = 150 * S;
	NavW = 330 * S;
	NavButtonH = 52 * S;
	NavGap = 8 * S;

	ContentX = NavX + NavW + 50 * S;
	ContentY = 72 * S;
	ContentW = (width - 70 * S) - ContentX;
	ContentH = (height - 64 * S) - ContentY;

	for (i = 0; i < arrayCount(winButtons); i++)
	{
		if (winButtons[i] == None)
			continue;

		// "Previous Menu" sits at the bottom of the column
		if (buttonDefaults[i].action == MA_Previous)
			winButtons[i].ConfigureChild(NavX, ContentY + ContentH - NavButtonH, NavW, NavButtonH);
		else
			winButtons[i].ConfigureChild(NavX, NavY + i * (NavButtonH + NavGap), NavW, NavButtonH);
	}
}

// ----------------------------------------------------------------------
// Category switching
// ----------------------------------------------------------------------

function bool ButtonActivated(Window buttonPressed)
{
	local int i;

	for (i = 0; i < arrayCount(winButtons); i++)
	{
		if ((winButtons[i] == None) || (buttonPressed != winButtons[i]))
			continue;

		if (buttonDefaults[i].action == MA_Previous)
		{
			RequestLeave(LEAVE_PREVIOUS);
			return True;
		}

		if (buttonDefaults[i].action == MA_MenuScreen)
		{
			// Already showing this category's own screen: nothing to do
			if ((ActiveIndex == i) && (root.GetTopWindow() != Self) && !RIRootWindow(root).IsSubScreen(root.GetTopWindow()))
				return True;
			RequestLeave(i);
			return True;
		}
	}

	return Super.ButtonActivated(buttonPressed);
}

// The native panel of the screen on top, if any
function RIPanel TopPanel()
{
	return Class'RIPanel'.static.FindIn(root.GetTopWindow());
}

// Leave the open screen: Target is a category index, LEAVE_PREVIOUS or LEAVE_BACK.
// Asks first when there are unapplied changes.
function RequestLeave(int Target)
{
	local RIPanel P;

	P = TopPanel();
	if ((P != None) && P.HasUnapplied())
	{
		PendingTarget = Target;
		PromptBox = root.MessageBox(UnsavedTitle, UnsavedText, 0, False, Self);
		if (RIMessageBox(PromptBox) != None)
			RIMessageBox(PromptBox).SetCustomButtons(ApplyChoice, DiscardChoice, StayChoice);
		return;
	}
	DoLeave(Target);
}

event bool BoxOptionSelected(Window box, int buttonNumber)
{
	local RIPanel P;

	if ((PromptBox == None) || (box != PromptBox))
		return Super.BoxOptionSelected(box, buttonNumber);

	root.PopWindow();       // the prompt
	PromptBox = None;

	if (buttonNumber == 2)
		return True;        // Stay

	P = TopPanel();
	if (P != None)
	{
		if (buttonNumber == 0)
			P.Apply();
		else
			P.Discard();
	}
	DoLeave(PendingTarget);
	return True;
}

function DoLeave(int Target)
{
	local int i;

	if (Target == LEAVE_BACK)
	{
		if (root.GetTopWindow() != Self)
			root.PopWindow();
		if (root.GetTopWindow() == Self)
			SetActive(-1);
		return;
	}

	CloseEmbedded(True);

	if (Target == LEAVE_PREVIOUS)
	{
		for (i = 0; i < arrayCount(winButtons); i++)
			if ((winButtons[i] != None) && (buttonDefaults[i].action == MA_Previous))
			{
				Super.ButtonActivated(winButtons[i]);
				return;
			}
		return;
	}

	if ((Target >= 0) && (Target < arrayCount(winButtons)) && (winButtons[Target] != None))
	{
		SetActive(Target);
		Super.ButtonActivated(winButtons[Target]);
	}
}

// Close whatever is open in the content panel. Natively drawn screens were
// already applied or discarded; AE-drawn ones save, as their OK used to.
function CloseEmbedded(bool bSave)
{
	local Window top;

	top = root.GetTopWindow();
	while ((top != None) && (top != Self))
	{
		if (bSave && (MenuUIWindow(top) != None) && (Class'RIPanel'.static.FindIn(top) == None))
			MenuUIWindow(top).SaveSettings();
		root.PopWindow();
		top = root.GetTopWindow();
	}
}

// ----------------------------------------------------------------------
// Category list input passed on by the open screen's panel
// ----------------------------------------------------------------------

function int NavIndexAt(float X, float Y)
{
	local int i;
	local Window B;

	for (i = 0; i < arrayCount(winButtons); i++)
	{
		B = winButtons[i];
		if ((B != None) && B.IsVisible(False) && B.IsSensitive()
			&& (X >= B.x) && (X < B.x + B.width) && (Y >= B.y) && (Y < B.y + B.height))
			return i;
	}
	return -1;
}

function NavHoverAt(float X, float Y)
{
	local int i, h;

	h = NavIndexAt(X, Y);
	for (i = 0; i < arrayCount(winButtons); i++)
		if (RIMenuButton(winButtons[i]) != None)
			RIMenuButton(winButtons[i]).bHoverExternal = (i == h);
}

function bool NavClickAt(float X, float Y)
{
	local int i;

	i = NavIndexAt(X, Y);
	if (i < 0)
		return False;
	PlaySound(Sound'DeusExSounds.UserInterface.Menu_Press', 0.25);
	ButtonActivated(winButtons[i]);
	return True;
}

function SetActive(int Index)
{
	local int i;

	ActiveIndex = Index;
	for (i = 0; i < arrayCount(winButtons); i++)
		if (RIMenuButton(winButtons[i]) != None)
			RIMenuButton(winButtons[i]).bActive = (i == Index);
}

event Tick(float deltaSeconds)
{
	AnimTime += deltaSeconds;

	// (No windows are opened or closed from Tick: the engine asserts if the
	//  window tree changes mid-update. Categories open only on click/key.)

	if ((ActiveIndex != -1) && (root.GetTopWindow() == Self))
		SetActive(-1);

	// Hover passed on by a panel ends when this layout is on top again
	if (root.GetTopWindow() == Self)
		NavHoverAt(-1, -1);
}

// Called by RIRootWindow to place a screen inside the content panel.
// bFill: the screen is drawn by RIPanel and takes the whole content area.
function PlaceEmbedded(Window W, optional bool bFill)
{
	local float pw, ph, px, py;

	if (bFill)
	{
		// Whole window: the engine only sends input to the top screen, so the
		// panel covers everything and passes category-list clicks back here
		W.SetWindowAlignments(HALIGN_Full, VALIGN_Full);
		return;
	}

	W.QueryPreferredSize(pw, ph);
	px = ContentX + FMax(0, (ContentW - pw) * 0.5);
	py = ContentY + 40 * S;
	W.SetWindowAlignments(HALIGN_Left, VALIGN_Top, px, py);
}

// ----------------------------------------------------------------------
// Drawing (behind the category buttons; the backdrop comes from the root)
// ----------------------------------------------------------------------

event DrawWindow(GC gc)
{
	local float a, pulse, hx, hy, hw, hh, sx;

	Class'RITheme'.static.SetMode(1);

	a = Class'RIUtil'.static.Phase(AnimTime, 0.0, 0.35);
	pulse = 0.85 + 0.15 * Sin(AnimTime * 2.0);

	gc.EnableSmoothing(True);

	if (Class'RIVP'.static.InMenus())
	{
		Class'RISkin'.static.DrawDim(gc, 0, 0, width, height, 0.55 * a);
		Class'RIVP'.static.Black(gc, FrameX + 4 * S, FrameY + 4 * S, FrameW - 8 * S, FrameH - 8 * S);
		Class'RIVP'.static.Frame(gc, FrameX, FrameY, FrameW, FrameH, 16 * S, a);
		Class'RIVP'.static.Frame(gc, NavX, 62 * S, NavW, 54 * S, 12 * S, a);
		Class'RIVP'.static.Hdr(gc, NavX + 10 * S, 72 * S, NavW - 20 * S, 34 * S, a);
		Class'RIText'.static.DrawIn(gc, Class'RIFontTitle', NavX, 62 * S, NavW, 54 * S, HeaderText,
			Class'RIVP'.static.Txt(a), 1, 0.62);
		Class'RIText'.static.VLine(gc, ContentX - 26 * S, ContentY, ContentH, Class'RIVP'.static.Edge(a));
		if (root.GetTopWindow() == Self)
			Class'RIText'.static.DrawIn(gc, Class'RIFontHead', ContentX, ContentY, ContentW, ContentH, EmptyText,
				Class'RIVP'.static.Lbl(a), 1, 0.9);
		return;
	}

	// Darken the whole backdrop further, then the outer panel deeper still
	// Darkening fades in (stepped: modulated drawing can't take a colour fade)
	Class'RISkin'.static.DrawDim(gc, 0, 0, width, height, 0.55 * a);
	Class'RISkin'.static.DrawDim(gc, FrameX, FrameY, FrameW, FrameH, 0.85 * a);
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(Class'RIUtil'.static.Col(4 * a, 5 * a, 22 * a));
	Class'RIText'.static.Fill(gc, FrameX, FrameY, FrameW, FrameH);

	// Hairline frame with a faint outer echo
	Class'RIText'.static.Box(gc, FrameX, FrameY, FrameW, FrameH, Class'RIUtil'.static.Col(80 * a * pulse, 84 * a * pulse, 190 * a * pulse));
	Class'RIText'.static.Box(gc, FrameX - 3 * S, FrameY - 3 * S, FrameW + 6 * S, FrameH + 6 * S, Class'RIUtil'.static.Col(24 * a, 26 * a, 80 * a));

	// Header box with the title
	hx = NavX;
	hy = 62 * S;
	hw = NavW;
	hh = 54 * S;
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(Class'RIUtil'.static.Col(20 * a, 22 * a, 70 * a));
	gc.DrawStretchedTexture(hx, hy, hw, hh, 0, 0, 256, 64, Texture'ReimaginedUI.UI.RI_Glow');
	Class'RIText'.static.Box(gc, hx, hy, hw, hh, Class'RIUtil'.static.Col(150 * a, 154 * a, 240 * a));
	Class'RIText'.static.DrawIn(gc, Class'RIFontTitle', hx, hy, hw, hh, HeaderText,
		Class'RIUtil'.static.Col(236 * a, 238 * a, 255 * a), 1, 0.62);

	// Divider between the categories and the content
	sx = ContentX - 26 * S;
	Class'RIText'.static.VLine(gc, sx, ContentY, ContentH, Class'RIUtil'.static.Col(34 * a, 36 * a, 96 * a));

	// Empty state
	if (root.GetTopWindow() == Self)
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', ContentX, ContentY, ContentW, ContentH, EmptyText,
			Class'RIUtil'.static.Col(120 * a, 126 * a, 196 * a), 1, 0.9);
}

defaultproperties
{
     FirstCategory=2
     NewButtonNames(7)="Interface"
     NewButtonNames(8)="Previous Menu"
     buttonDefaults(7)=(Y=265,Action=MA_MenuScreen,Invoke=Class'ReimaginedUI.RIMenuScreenInterface')
     buttonDefaults(8)=(Y=302,Action=MA_Previous)
     HeaderText="SETTINGS"
     EmptyText="SELECT A CATEGORY"
     UnsavedTitle="Unapplied changes"
     UnsavedText="You changed settings on this screen without applying them. Apply them before leaving?"
     ApplyChoice="Apply"
     DiscardChoice="Discard"
     StayChoice="Stay"
}

//=============================================================================
// RISkin
// Restyles any AE menu screen in place: walks its window tree and swaps
// textures and colours on the shared building blocks (buttons, value boxes,
// lists, labels, help text, scrollbars). Nothing is saved; AE's colour
// themes and config are left untouched, so save games stay compatible.
//=============================================================================
class RISkin extends ExtensionObject
	abstract;

var bool bGold;     // see TextIdle()

// ----------------------------------------------------------------------
// Palette
// ----------------------------------------------------------------------

// bGold: set round a skin pass for in-game devices (computers, ATMs, bots),
// which take the persona gold instead of the menus' blue
static final function Color TextIdle()     { if (default.bGold) return Class'RIUtil'.static.Col(230, 195, 117); return Class'RIUtil'.static.Col(190, 194, 238); }
static final function Color TextHot()      { if (default.bGold) return Class'RIUtil'.static.Col(255, 241, 194); return Class'RIUtil'.static.Col(255, 255, 255); }
static final function Color TextDim()      { if (default.bGold) return Class'RIUtil'.static.Col(110, 92, 46); return Class'RIUtil'.static.Col(84, 88, 136); }
static final function Color TextHeader()   { if (default.bGold) return Class'RIUtil'.static.Col(242, 211, 107); return Class'RIUtil'.static.Col(95, 200, 255); }
static final function Color ButtonTint()   { if (default.bGold) return Class'RIUtil'.static.Col(176, 146, 72); return Class'RIUtil'.static.Col(95, 104, 255); }
static final function Color Highlight()    { if (default.bGold) return Class'RIUtil'.static.Col(76, 62, 26); return Class'RIUtil'.static.Col(52, 56, 160); }
static final function Color FocusLine()   { if (default.bGold) return Class'RIUtil'.static.Col(230, 195, 117); return Class'RIUtil'.static.Col(166, 170, 255); }

// ----------------------------------------------------------------------
// Safe hiding. The engine readies new windows (WindowReady) by walking only
// visible ones; a window hidden before it, or anything inside it, has been
// readied is never counted and the engine stops with "initCount == 0"
// (ExtRoot.cpp, XRootWindow::InitializeWindows). So only hide a window once
// it and everything visible inside it reports bIsInitialized.
// ----------------------------------------------------------------------

static function bool TreeReady(Window W)
{
	local Window C;

	if ((W == None) || !W.bIsInitialized)
		return False;
	for (C = W.GetTopChild(); C != None; C = C.GetLowerSibling())
		if (C.IsVisible(False) && !TreeReady(C))
			return False;
	return True;
}

// Hides W if that is safe now; returns False if it has to wait
static function bool SafeHide(Window W)
{
	if ((W == None) || !W.IsVisible(False))
		return True;
	if (!TreeReady(W))
		return False;
	W.Hide();
	return True;
}

// ----------------------------------------------------------------------
// SkinScreen: called once when a screen is pushed
// ----------------------------------------------------------------------

static function SkinScreen(MenuUIWindow Screen)
{
	local int i;

	if (Screen == None)
		return;

	// AE's frame pieces are replaced by RIScreenFrame
	SafeHide(Screen.winTitle);
	SafeHide(Screen.winLeftEdge);
	SafeHide(Screen.winRightEdge);
	SafeHide(Screen.winShadow);

	if (Screen.winClient != None)
		for (i = 0; i < arrayCount(Screen.winClient.clientTextures); i++)
			if (Screen.winClient.clientTextures[i] != None)
				Screen.winClient.SetClientTexture(i, Texture'ReimaginedUI.UI.RI_Clear');

	SkinTree(Screen);

	if ((MenuUIMessageBoxWindow(Screen) != None) && (MenuUIMessageBoxWindow(Screen).winText != None))
		MenuUIMessageBoxWindow(Screen).winText.SetTextColor(TextHot());
}

// ----------------------------------------------------------------------
// SkinTree: re-run periodically so widgets created later are caught too
// ----------------------------------------------------------------------

static function SkinTree(Window W)
{
	local Window Child;

	if (W == None)
		return;

	SkinWidget(W);

	Child = W.GetTopChild();
	while (Child != None)
	{
		SkinTree(Child);
		Child = Child.GetLowerSibling();
	}
}

static function SkinWidget(Window W)
{
	local MenuUIBorderButtonWindow Btn;
	local MenuUIMenuButtonWindow MenuBtn;
	local MenuUIListWindow List;
	local MenuUIClientWindow Client;
	local int i;

	// Our own animated buttons draw themselves
	if (RIMenuButton(W) != None)
		return;

	Btn = MenuUIBorderButtonWindow(W);
	if (Btn != None)
	{
		MenuBtn = MenuUIMenuButtonWindow(W);
		if (MenuBtn != None)
		{
			MenuBtn.buttonLights[0] = Texture'ReimaginedUI.UI.RI_Clear';
			MenuBtn.buttonLights[1] = Texture'ReimaginedUI.UI.RI_Clear';
			MenuBtn.buttonLights[2] = Texture'ReimaginedUI.UI.RI_Clear';
			MenuBtn.buttonLights[3] = Texture'ReimaginedUI.UI.RI_Clear';
		}

		if (MenuUIListHeaderButtonWindow(W) != None)
		{
			// Column headers: faint strip, cyan caption
			SetButtonTextures(Btn, Texture'ReimaginedUI.UI.RI_Head', Texture'ReimaginedUI.UI.RI_Head', Texture'ReimaginedUI.UI.RI_Head',
			                       Texture'ReimaginedUI.UI.RI_Head', Texture'ReimaginedUI.UI.RI_Head', Texture'ReimaginedUI.UI.RI_Head', 2, 2);
			SetButtonColors(Btn, TextHeader(), TextHeader(), TextHeader());
		}
		else if (MenuUIActionButtonBarWindow(W.GetParent()) != None)
		{
			// OK / Cancel / Reset bar: outlined, like the concept's buttons
			SetButtonTextures(Btn, Texture'ReimaginedUI.UI.RI_OutL', Texture'ReimaginedUI.UI.RI_OutC', Texture'ReimaginedUI.UI.RI_OutR',
			                       Texture'ReimaginedUI.UI.RI_OutLP', Texture'ReimaginedUI.UI.RI_OutCP', Texture'ReimaginedUI.UI.RI_OutRP', 2, 2);
			SetButtonColors(Btn, TextIdle(), TextHot(), TextDim());
		}
		else if ((MenuUIChoiceButton(W) != None) || (MenuUIInfoButtonWindow(W) != None))
		{
			// Option rows: no box, just a separator line; values in cyan
			SetButtonTextures(Btn, Texture'ReimaginedUI.UI.RI_Row', Texture'ReimaginedUI.UI.RI_Row', Texture'ReimaginedUI.UI.RI_Row',
			                       Texture'ReimaginedUI.UI.RI_RowP', Texture'ReimaginedUI.UI.RI_RowP', Texture'ReimaginedUI.UI.RI_RowP', 2, 2);
			if (MenuUIInfoButtonWindow(W) != None)
				SetButtonColors(Btn, TextHeader(), TextHot(), TextDim());
			else
				SetButtonColors(Btn, TextIdle(), TextHot(), TextDim());
		}
		else
		{
			// Everything else (menus, tabs): filled with a bright accent edge
			SetButtonTextures(Btn, Texture'ReimaginedUI.UI.RI_BtnL', Texture'ReimaginedUI.UI.RI_BtnC', Texture'ReimaginedUI.UI.RI_BtnR',
			                       Texture'ReimaginedUI.UI.RI_BtnLP', Texture'ReimaginedUI.UI.RI_BtnCP', Texture'ReimaginedUI.UI.RI_BtnRP', 4, 12);
			SetButtonColors(Btn, TextIdle(), TextHot(), TextDim());
		}
		return;
	}

	if (default.bGold && (PersonaBorderButtonWindow(W) != None))
	{
		SetPersonaButton(PersonaBorderButtonWindow(W));
		return;
	}

	List = MenuUIListWindow(W);
	if (List != None)
	{
		List.SetTextColor(TextIdle());
		List.SetHighlightTextColor(TextHot());
		List.SetHighlightColor(Highlight());
		List.SetFocusColor(FocusLine());
		for (i = 0; i < List.GetNumColumns(); i++)
			List.SetColumnColor(i, TextIdle());
		return;
	}

	Client = MenuUIClientWindow(W);
	if (Client != None)
	{
		Client.backgroundDrawStyle = DSTY_Translucent;
		return;
	}

	if (MenuUIHelpWindow(W) != None)
	{
		if (default.bGold)
			MenuUIHelpWindow(W).colText = TextIdle();
		else
			MenuUIHelpWindow(W).colText = Class'RIUtil'.static.Col(176, 182, 236);
		MenuUIHelpWindow(W).SetTextColor(MenuUIHelpWindow(W).colText);
		return;
	}

	if (MenuUILabelWindow(W) != None)
	{
		if (IsMessageBoxText(W))
			MenuUILabelWindow(W).SetTextColor(TextHot());
		else if (MenuUIHeaderWindow(W) != None)
			MenuUILabelWindow(W).SetTextColor(TextHeader());
		else
			MenuUILabelWindow(W).SetTextColor(TextIdle());
		return;
	}

	if (MenuUINormalLargeTextWindow(W) != None)
	{
		MenuUINormalLargeTextWindow(W).SetTextColor(TextIdle());
		return;
	}

	if (MenuUIEditWindow(W) != None)
	{
		MenuUIEditWindow(W).SetTextColor(TextHot());
		return;
	}

	if (MenuUIScrollAreaWindow(W) != None)
	{
		MenuUIScrollAreaWindow(W).upButton.SetButtonColors(ButtonTint(), ButtonTint(), ButtonTint(), ButtonTint(), ButtonTint(), ButtonTint());
		MenuUIScrollAreaWindow(W).downButton.SetButtonColors(ButtonTint(), ButtonTint(), ButtonTint(), ButtonTint(), ButtonTint(), ButtonTint());
		if (default.bGold)
			MenuUIScrollAreaWindow(W).vScale.SetScaleColor(Highlight());
		else
			MenuUIScrollAreaWindow(W).vScale.SetScaleColor(Class'RIUtil'.static.Col(40, 44, 120));
		MenuUIScrollAreaWindow(W).vScale.SetThumbColor(FocusLine());
		return;
	}
}

// Persona buttons (Ice Breaker, bots): the outlined button, gold
static function SetPersonaButton(PersonaBorderButtonWindow Btn)
{
	Btn.Left_Textures[0].Tex     = Texture'ReimaginedUI.UI.RI_OutL';   Btn.Left_Textures[0].Width   = 2;
	Btn.Left_Textures[1].Tex     = Texture'ReimaginedUI.UI.RI_OutLP';  Btn.Left_Textures[1].Width   = 2;
	Btn.Center_Textures[0].Tex   = Texture'ReimaginedUI.UI.RI_OutC';   Btn.Center_Textures[0].Width = 2;
	Btn.Center_Textures[1].Tex   = Texture'ReimaginedUI.UI.RI_OutCP';  Btn.Center_Textures[1].Width = 2;
	Btn.Right_Textures[0].Tex    = Texture'ReimaginedUI.UI.RI_OutR';   Btn.Right_Textures[0].Width  = 2;
	Btn.Right_Textures[1].Tex    = Texture'ReimaginedUI.UI.RI_OutRP';  Btn.Right_Textures[1].Width  = 2;
	Btn.bTranslucent  = True;
	Btn.colButtonFace = ButtonTint();
	Btn.colText[0] = TextIdle();
	Btn.colText[1] = TextHot();
	Btn.colText[2] = TextHot();
	Btn.colText[3] = TextDim();
}

// ----------------------------------------------------------------------
// In-game devices (Sleek): AE's widgets restyled in the persona gold, AE's
// frame pieces hidden (RITerminalSkin draws the panel behind them)
// ----------------------------------------------------------------------

static function SkinComputer(ComputerUIWindow S)
{
	local int i;

	if (S == None)
		return;
	default.bGold = True;
	SafeHide(S.winTitle);
	SafeHide(S.winLeftEdge);
	SafeHide(S.winRightEdge);
	if (S.winClient != None)
		for (i = 0; i < arrayCount(S.winClient.clientTextures); i++)
			if (S.winClient.clientTextures[i] != None)
				S.winClient.SetClientTexture(i, Texture'ReimaginedUI.UI.RI_Clear');
	SkinTree(S);
	default.bGold = False;
}

// AE's HUD-style device windows (Ice Breaker, account list): their own
// background and border art is swapped for clear, the widgets go gold
static function SkinDeviceTree(Window W)
{
	default.bGold = True;
	SkinTree(W);
	default.bGold = False;
}

// The Sleek device panel (keypad, notes, computers, bots): soft shade round
// it, darkened and lightly filled, hairline gold edge, an accent bar on the
// top-left, and an optional Michroma title in a strip above. K = UI units per
// 1080p pixel (0.5 at 1080p in root units; pass the window's own scale).
static function GoldPanel(GC gc, float X, float Y, float W, float H, float K, float a, optional string Title)
{
	gc.SetStyle(DSTY_Modulated);
	gc.DrawStretchedTexture(X - 60 * K, Y - 60 * K, W + 120 * K, H + 120 * K, 0, 0, 256, 64, Texture'ReimaginedUI.UI.RI_ShadeC');
	Class'RIVP'.static.Dim(gc, X, Y, W, H);
	Class'RIVP'.static.Dim(gc, X, Y, W, H);
	FillC(gc, X, Y, W, H, Class'RIUtil'.static.Col(12 * a, 10 * a, 4 * a));
	Class'RIText'.static.Box(gc, X, Y, W, H, Class'RIUtil'.static.Col(126 * a, 105 * a, 50 * a));
	FillC(gc, X, Y, FMin(120 * K, W), 3 * K, Class'RIVP'.static.Acc(a));
	if (Title != "")
		Class'RIText'.static.Draw(gc, Class'RIFontHead', X + 2 * K, Y - 34 * K, Caps(Title),
			Class'RIUtil'.static.Col(255 * a, 241 * a, 194 * a), 1.24 * K);
}

// The message in a message box sits in winClient, inside the box itself
static function bool IsMessageBoxText(Window W)
{
	if ((W.GetParent() == None) || (W.GetParent().GetParent() == None))
		return False;
	return MenuUIMessageBoxWindow(W.GetParent().GetParent()) != None;
}

static function SetButtonTextures(MenuUIBorderButtonWindow Btn,
	Texture L, Texture C, Texture R, Texture LP, Texture CP, Texture RP, int EdgeW, int RightW)
{
	Btn.Left_Textures[0].Tex     = L;   Btn.Left_Textures[0].Width   = EdgeW;
	Btn.Left_Textures[1].Tex     = LP;  Btn.Left_Textures[1].Width   = EdgeW;
	Btn.Center_Textures[0].Tex   = C;   Btn.Center_Textures[0].Width = 2;
	Btn.Center_Textures[1].Tex   = CP;  Btn.Center_Textures[1].Width = 2;
	Btn.Right_Textures[0].Tex    = R;   Btn.Right_Textures[0].Width  = RightW;
	Btn.Right_Textures[1].Tex    = RP;  Btn.Right_Textures[1].Width  = RightW;
	Btn.bTranslucent  = True;
	Btn.colButtonFace = ButtonTint();
}

static function SetButtonColors(MenuUIBorderButtonWindow Btn, Color Idle, Color Hot, Color Dim)
{
	Btn.colText[0] = Idle;
	Btn.colText[1] = Hot;
	Btn.colText[2] = Hot;
	Btn.colText[3] = Dim;
}

// ----------------------------------------------------------------------
// DrawKeyArt: the 1920x1080 key art from its two halves, at X,Y,W,H.
// Uses the current style and tile colour. The source rectangles stop at the
// seam (texel 1015.5 of the left half = texel 8.5 of the right), so filtering
// there samples real neighbours instead of wrapping to the far edge.
// ----------------------------------------------------------------------

static final function float KeyArtAspect() { return 1920.0 / 1080.0; }

static function DrawKeyArt(GC gc, float X, float Y, float W, float H)
{
	gc.DrawStretchedTexture(X, Y, W * 0.5, H, 0, 0, 1015.54, 1024, Texture'ReimaginedUI.UI.RI_KeyArtL');
	gc.DrawStretchedTexture(X + W * 0.5, Y, W * 0.5, H, 8.46, 0, 1015.54, 1024, Texture'ReimaginedUI.UI.RI_KeyArtR');
}

// ----------------------------------------------------------------------
// DrawDim: darken a rectangle by Amount (0 = none, 1 = strongest).
// Modulated drawing can't be faded with a colour, so it steps through eight
// pre-darkened textures; at 60 fps over a quarter second that reads as smooth.
// ----------------------------------------------------------------------

static function DrawDim(GC gc, float X, float Y, float W, float H, float Amount)
{
	local Texture T;

	switch (Clamp(int(Amount * 8.0 + 0.5), 0, 8))
	{
		case 1: T = Texture'ReimaginedUI.UI.RI_Dim1'; break;
		case 2: T = Texture'ReimaginedUI.UI.RI_Dim2'; break;
		case 3: T = Texture'ReimaginedUI.UI.RI_Dim3'; break;
		case 4: T = Texture'ReimaginedUI.UI.RI_Dim4'; break;
		case 5: T = Texture'ReimaginedUI.UI.RI_Dim5'; break;
		case 6: T = Texture'ReimaginedUI.UI.RI_Dim6'; break;
		case 7: T = Texture'ReimaginedUI.UI.RI_Dim7'; break;
		case 8: T = Texture'ReimaginedUI.UI.RI_Dim8'; break;
		default: return;
	}
	gc.SetStyle(DSTY_Modulated);
	gc.DrawStretchedTexture(X, Y, W, H, 0, 0, 16, 16, T);
}

// ----------------------------------------------------------------------
// DrawGameDim: in-game menus sit on the paused game view (AE's Render 3D or
// Snapshot background), faded down to a navy tint with a faint key-art ghost.
// K: 0 = game fully visible, 1 = fully dimmed.
// ----------------------------------------------------------------------

static function DrawGameDim(GC gc, float W, float H, float Amt, float T)
{
	if (Amt <= 0.0)
		return;

	gc.EnableSmoothing(True);
	// Two passes: dark enough that the game is only a hint and the UI pops
	DrawDim(gc, 0, 0, W, H, Amt);
	DrawDim(gc, 0, 0, W, H, 0.6 * Amt);
	DrawAmbience(gc, W, H, Amt, T);
}

// Shared dark backdrop details: a faint cool glow up top, vignette, scanlines
static function DrawAmbience(GC gc, float W, float H, float Amt, float T)
{
	local float g;

	g = (0.75 + 0.25 * Sin(T * 0.6)) * Amt;
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(Class'RIUtil'.static.Col(10 * g, 11 * g, 34 * g));
	gc.DrawStretchedTexture(W * 0.15, -H * 0.25, W * 0.7, H * 0.7, 0, 0, 256, 64, Texture'ReimaginedUI.UI.RI_Glow');

	gc.SetStyle(DSTY_Modulated);
	gc.DrawStretchedTexture(0, H * 0.55, W, H * 0.45, 0, 0, 8, 256, Texture'ReimaginedUI.UI.RI_FadeV');
	if (Amt > 0.6)
		gc.DrawPattern(0, 0, W, H, 0, 0, Texture'ReimaginedUI.UI.RI_Scan');
}

// ----------------------------------------------------------------------
// DrawBackdrop: the key art scene behind every menu screen (dimmed)
// ----------------------------------------------------------------------

static function DrawBackdrop(GC gc, float W, float H, float T)
{
	// Behind menus with no game to show: near-black navy, no key art (that
	// stays on the main menu and title card), so panels and text stand out
	gc.EnableSmoothing(True);
	gc.SetStyle(DSTY_Normal);
	gc.SetTileColor(Class'RIUtil'.static.Col(70, 70, 80));
	gc.DrawStretchedTexture(0, 0, W, H, 0, 0, 16, 16, Texture'ReimaginedUI.UI.RI_Navy');
	DrawDim(gc, 0, 0, W, H, 0.5);
	DrawAmbience(gc, W, H, 1.0, T);
}

// ----------------------------------------------------------------------
// Mockup kit: the shared pieces of the design canvas (1920x1080 design
// pixels; S = height / 1080 converts them to UI units). Colours:
//   frame #4B4FD6, panel edge #3B3FC4, bar #2E3290, accent #A6AAFF,
//   cyan #5FC8FF, label #8B90D4, text #E6E8FF.
// ----------------------------------------------------------------------

static function Color K(float R, float G, float B, float a)
{
	return Class'RIUtil'.static.Col(R * a, G * a, B * a);
}

static function FillC(GC gc, float X, float Y, float W, float H, Color C)
{
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(C);
	Class'RIText'.static.Fill(gc, X, Y, W, H);
}

// Two-pixel outline (the mockups use 2px borders)
static function Box2(GC gc, float X, float Y, float W, float H, Color C)
{
	Class'RIText'.static.Box(gc, X, Y, W, H, C);
	Class'RIText'.static.Box(gc, X + 0.5, Y + 0.5, W - 1.0, H - 1.0, C);
}

// Soft glow behind a shape (used where the mockups have box-shadow)
static function GlowC(GC gc, float X, float Y, float W, float H, float Spread, Color C)
{
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(C);
	gc.DrawStretchedTexture(X - Spread, Y - Spread, W + Spread * 2, H + Spread * 2, 0, 0, 256, 64, Texture'ReimaginedUI.UI.RI_GlowC');
}

// The big glowing frame every full-screen page sits in
static function MockFrame(GC gc, float X, float Y, float W, float H, float S, float a)
{
	DrawDim(gc, X, Y, W, H, 0.82 * a);
	FillC(gc, X, Y, W, H, K(8, 10, 40, a));
	GlowC(gc, X + 20 * S, Y + 20 * S, W - 40 * S, 40 * S, 30 * S, K(14, 15, 50, a));
	Box2(gc, X, Y, W, H, K(75, 79, 214, a));
	Class'RIText'.static.Box(gc, X - 1.5, Y - 1.5, W + 3, H + 3, K(50, 52, 90, a));
	Class'RIText'.static.Box(gc, X - 4 * S, Y - 4 * S, W + 8 * S, H + 8 * S, K(22, 24, 80, a));
}

// Bordered sub-panel
static function MockPanel(GC gc, float X, float Y, float W, float H, float S, float a)
{
	FillC(gc, X, Y, W, H, K(10, 12, 48, 0.7 * a));
	Box2(gc, X, Y, W, H, K(59, 63, 196, a));
}

// Title in a glowing box, followed by the long empty bar
static function float MockTitle(GC gc, float X, float Y, string T, float BarW, float S, float a)
{
	local float tw, h, w;

	h = 58 * S;
	tw = Class'RIText'.static.Width(Class'RIFontTitle', T, 0.62);
	w = tw + 48 * S;
	GlowC(gc, X, Y, w, h, 10 * S, K(40, 42, 120, a));
	Box2(gc, X, Y, w, h, K(143, 147, 255, a));
	Class'RIText'.static.DrawIn(gc, Class'RIFontTitle', X, Y, w, h, T, K(230, 232, 255, a), 1, 0.62);
	if (BarW > 0)
	{
		FillC(gc, X + w + 24 * S, Y + 15 * S, BarW, 28 * S, K(20, 22, 70, 0.6 * a));
		Box2(gc, X + w + 24 * S, Y + 15 * S, BarW, 28 * S, K(46, 50, 144, a));
	}
	return w;
}

// Section heading inside a panel (cyan, small, tracked)
static function MockLabel(GC gc, float X, float Y, string T, float a)
{
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', X, Y, Caps(T), K(95, 200, 255, a), 0.8);
}

// Selected / hovered row
static function MockSelRow(GC gc, float X, float Y, float W, float H, float S, float a)
{
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(K(46, 48, 132, a));
	gc.DrawStretchedTexture(X, Y, W, H, 0, 0, 256, 64, Texture'ReimaginedUI.UI.RI_Glow');
	Class'RIText'.static.Box(gc, X, Y, W, H, K(150, 154, 230, a));
}

// Key hint button: [ KEY ] LABEL. Returns its width; Hot brightens it.
static function float MockKeyHint(GC gc, float X, float Y, string Key, string Label, float S, float a, bool bHot, optional Color Tint)
{
	local float d, tw;
	local Color Edge, Txt;

	if ((Tint.R == 0) && (Tint.G == 0) && (Tint.B == 0))
	{
		Edge = K(166, 170, 255, a);
		Txt  = K(230, 232, 255, a);
	}
	else
	{
		Edge = Class'RIUtil'.static.Scale(Tint, a);
		Txt  = Edge;
	}
	if (bHot)
	{
		Edge = K(255, 255, 255, a);
		Txt  = K(255, 255, 255, a);
	}
	d = 42 * S;
	GlowC(gc, X, Y, d, d, 6 * S, K(30 + 30 * int(bHot), 32 + 30 * int(bHot), 100 + 60 * int(bHot), a));
	Box2(gc, X, Y, d, d, Edge);
	Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', X, Y, d, d, Key, Txt, 1, 0.55);
	tw = Class'RIText'.static.Width(Class'RIFontHead', Caps(Label), 0.72);
	Class'RIText'.static.DrawIn(gc, Class'RIFontHead', X + d + 12 * S, Y, tw, d, Caps(Label), Txt, 0, 0.72);
	return d + 12 * S + tw;
}

static function float MockKeyHintWidth(string Label, float S)
{
	return 42 * S + 12 * S + Class'RIText'.static.Width(Class'RIFontHead', Caps(Label), 0.72);
}

// Outlined text button (RESTORE DEFAULT style)
static function MockButton(GC gc, float X, float Y, float W, float H, string Label, float S, float a, bool bHot, bool bLive, optional bool bPrimary)
{
	local Color Edge, Txt;

	if (!bLive)
	{
		Edge = K(40, 42, 100, a);
		Txt  = K(80, 84, 136, a);
	}
	else if (bPrimary || bHot)
	{
		FillC(gc, X, Y, W, H, K(40, 44, 140, 0.45 * a));
		GlowC(gc, X, Y, W, H, 8 * S, K(40, 42, 130, a));
		Edge = K(166, 170, 255, a);
		Txt  = K(255, 255, 255, a);
	}
	else
	{
		Edge = K(75, 79, 214, a);
		Txt  = K(201, 204, 245, a);
	}
	Box2(gc, X, Y, W, H, Edge);
	Class'RIText'.static.DrawIn(gc, Class'RIFontHead', X, Y, W, H, Caps(Label), Txt, 1, 0.6);
}

defaultproperties
{
}

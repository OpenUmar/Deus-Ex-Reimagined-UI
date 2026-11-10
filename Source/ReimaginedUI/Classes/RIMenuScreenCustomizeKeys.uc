//=============================================================================
// RIMenuScreenCustomizeKeys
// AE's Keyboard/Mouse screen, drawn by RIPanel, plus two presets:
//   Classic Keys  original Deus Ex layout (with AE's mantle/tiptoe extras kept)
//   Modern Keys   Fully Augmented Control Scheme v1.0
// A preset applies at once so the list updates. Apply keeps it; leaving and
// choosing Discard (or Revert) restores the layout you had before.
// Presets live in RIKeyPresets. The control scheme's optional AutoHotkey
// script is not part of this.
//=============================================================================
class RIMenuScreenCustomizeKeys extends MenuScreenCustomizeKeys;

var string SavedKeys[256];
var string SavedBinds[256];
var int    NumSaved;
var bool   bPresetApplied;

var Window FocusPanel;
var bool   bSwallowMouseUp;    // remap was started by a click: its release is not the new binding      // the RIPanel drawing this screen

var localized string ClassicAppliedText;
var localized string ModernAppliedText;

function ProcessAction(String actionKey)
{
	if (actionKey == "RI_CLASSIC")
	{
		ApplyPreset(False);
		return;
	}
	if (actionKey == "RI_MODERN")
	{
		ApplyPreset(True);
		return;
	}
	Super.ProcessAction(actionKey);
}

// ----------------------------------------------------------------------
// Used by RIPanel
// ----------------------------------------------------------------------

// Starts waiting for a key. When a mouse click started it, the release of
// that same click must not become the binding: click, then press, then it's set.
function BeginRemap(int rowId, optional bool bFromMouse)
{
	ListRowActivated(lstKeys, rowId);
	bSwallowMouseUp = bFromMouse;
}

event bool RawMouseButtonPressed(float pointX, float pointY, EInputKey button, EInputState iState)
{
	if (bWaitingForInput && bSwallowMouseUp)
	{
		if (iState == IST_Release)
			bSwallowMouseUp = False;
		return True;
	}
	return Super.RawMouseButtonPressed(pointX, pointY, button, iState);
}

// A held key repeating (e.g. the Enter that started the remap) is not a new key
event bool VirtualKeyPressed(EInputKey key, bool bRepeat)
{
	if (bWaitingForInput && bRepeat)
		return True;
	return Super.VirtualKeyPressed(key, bRepeat);
}

function int WaitingRowId()
{
	if (!bWaitingForInput || (selection < 0))
		return -1;
	return lstKeys.IndexToRowId(selection);
}

function ClearRow(int rowId)
{
	lstKeys.SelectAllRows(False);
	lstKeys.SelectRow(rowId, True);
	ClearFunction();
}

function bool HasChanges()
{
	return (Pending > 0) || bPresetApplied;
}

// Throw away unapplied edits and any preset, without closing the screen
function RevertNoPop()
{
	local int i;

	if (bPresetApplied)
	{
		for (i = 0; i < NumSaved; i++)
			player.ConsoleCommand("SET InputExt " $ SavedKeys[i] $ " " $ SavedBinds[i]);
		player.KeybindManager.Setup(player);
	}
	bPresetApplied = False;
	NumSaved = 0;
	ResetToDefaults();      // AE: drop pending edits and re-read the live bindings
}

function WaitingForInput(bool bWaiting)
{
	Super.WaitingForInput(bWaiting);

	// AE hands focus back to its (hidden) list; give it to the panel instead
	if (!bWaiting && (FocusPanel != None))
		SetFocusWindow(FocusPanel);
}

function SaveSettings()
{
	Super.SaveSettings();
	bPresetApplied = False;
	NumSaved = 0;
}

// ----------------------------------------------------------------------
// Presets
// ----------------------------------------------------------------------

function SnapshotBindings()
{
	local int i;
	local string KeyName;

	NumSaved = 0;
	for (i = 0; i < 255; i++)
	{
		KeyName = player.ConsoleCommand("KEYNAME " $ i);
		if ((KeyName != "") && (NumSaved < arrayCount(SavedKeys)))
		{
			SavedKeys[NumSaved]  = KeyName;
			SavedBinds[NumSaved] = player.ConsoleCommand("KEYBINDING " $ KeyName);
			NumSaved++;
		}
	}
}

function ApplyPreset(bool bModern)
{
	local int i;
	local string Bind;

	if (!bPresetApplied)
	{
		// Apply any single-key edits first so the snapshot is what you see
		ProcessPending();
		SnapshotBindings();
		bPresetApplied = True;
	}

	Pending = 0;

	for (i = 0; i < Class'RIKeyPresets'.default.NumKeys; i++)
	{
		if (bModern)
			Bind = Class'RIKeyPresets'.default.ModernBinds[i];
		else
			Bind = Class'RIKeyPresets'.default.ClassicBinds[i];

		player.ConsoleCommand("SET InputExt " $ Class'RIKeyPresets'.default.KeyNames[i] $ " " $ Bind);
	}

	player.KeybindManager.Setup(player);
	BuildKeyBindings();
	PopulateKeyList();
	if (bModern)
		ShowHelp(ModernAppliedText);
	else
		ShowHelp(ClassicAppliedText);
}

function CancelScreen()
{
	if (bPresetApplied)
		RevertNoPop();
	Super.CancelScreen();
}

defaultproperties
{
     ClassicAppliedText="Classic preset loaded: the original Deus Ex keys. Apply to keep it, or leave and Discard to go back to your own bindings."
     ModernAppliedText="Modern preset loaded: the Fully Augmented Control Scheme. Apply to keep it, or leave and Discard to go back to your own bindings."
     btnLabelResetToDefaults="Revert"
     actionButtons(0)=(Align=HALIGN_Right,Action=AB_Cancel)
     actionButtons(1)=(Align=HALIGN_Right,Action=AB_OK)
     actionButtons(2)=(Action=AB_Reset)
     actionButtons(3)=(Action=AB_Other,Text="Classic Keys",Key="RI_CLASSIC")
     actionButtons(4)=(Action=AB_Other,Text="Modern Keys",Key="RI_MODERN")
}

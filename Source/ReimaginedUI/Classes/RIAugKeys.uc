//=============================================================================
// RIAugKeys
// Which key activates each augmentation, read from the real bindings (one
// pass over the keys), so rebinding shows up. Indexed by the aug's
// HotKeyNum: 3..12 are "ActivateAugmentation 0..9" (F3..F12 by default),
// 13 is AE's flashlight ("Flashlight", V by default). Augs with no key
// (EUAS, InfoLink) have HotKeyNum -1.
//
// Static only (kept in the class defaults): this used to be made with
// "new" from inside a window, which gave the object that window as its
// outer. Windows are deleted outright, not by the garbage collector, so the
// object outlived its outer; when the collector later freed it at a map
// change, the engine looked it up under the dead outer and stopped with
// "Assertion failed: Removed!=0" (UnObj.cpp).
//=============================================================================
class RIAugKeys extends Object
	abstract;

var string Keys[14];
var float  Age;
var bool   bRead;

static function Refresh(PlayerPawn P)
{
	local int i, n;
	local string KeyName, B;

	for (i = 0; i < 14; i++)
		default.Keys[i] = "";
	default.Age = 0;
	default.bRead = True;
	if (P == None)
		return;
	for (i = 0; i < 255; i++)
	{
		KeyName = P.ConsoleCommand("KEYNAME " $ i);
		if (KeyName == "")
			continue;
		B = Caps(P.ConsoleCommand("KEYBINDING " $ KeyName));
		if (Left(B, 21) == "ACTIVATEAUGMENTATION ")
		{
			n = int(Mid(B, 21)) + 3;
			if ((n >= 3) && (n <= 12) && (default.Keys[n] == ""))
				default.Keys[n] = KeyName;
		}
		else if ((B == "FLASHLIGHT") && (default.Keys[13] == ""))
			default.Keys[13] = KeyName;
	}
}

// Re-read every few seconds (rebinds show up)
static function Step(PlayerPawn P, float DeltaSeconds)
{
	default.Age += DeltaSeconds;
	if (!default.bRead || (default.Age > 5.0))
		Refresh(P);
}

static function string KeyFor(PlayerPawn P, int HotKeyNum)
{
	if (!default.bRead)
		Refresh(P);
	if ((HotKeyNum < 3) || (HotKeyNum > 13))
		return "";
	if (default.Keys[HotKeyNum] != "")
		return Caps(default.Keys[HotKeyNum]);
	if (HotKeyNum <= 12)
		return "F" $ string(HotKeyNum);
	return "";
}

defaultproperties
{
}

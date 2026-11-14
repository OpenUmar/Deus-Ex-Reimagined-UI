//=============================================================================
// RIChoiceXColor: Settings > Interface > Crosshair, the colour. "Friend / foe"
// is the game's own: it turns red over enemies and green over allies.
//=============================================================================
class RIChoiceXColor extends MenuUIChoiceEnum;

function LoadSetting()
{
	SetValue(Class'RICrosshair'.default.XColor);
}

function SaveSetting()
{
	Class'RICrosshair'.default.XColor = int(GetValue());
	Class'RICrosshair'.static.StaticSaveConfig();
}

function CycleNextValue()
{
	Super.CycleNextValue();
	SaveSetting();
}

function CyclePreviousValue()
{
	Super.CyclePreviousValue();
	SaveSetting();
}

function ResetToDefault()
{
	SetValue(0);
	SaveSetting();
}

defaultproperties
{
     enumText(0)="Friend / foe"
     enumText(1)="White"
     enumText(2)="Green"
     enumText(3)="Yellow"
     enumText(4)="Cyan"
     enumText(5)="Red"
     enumText(6)="Magenta"
     HelpText="The crosshair's colour. Friend / foe is the game's own: white, turning red over enemies and green over allies. The others stay one colour."
     actionText="Colour"
}

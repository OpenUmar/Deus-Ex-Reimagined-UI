//=============================================================================
// RIBuildInfo: build number and time, shown on the main menu.
// Build_ReimaginedUI.cmd regenerates this in the staging copy on every build;
// this file is only a fallback.
//=============================================================================
class RIBuildInfo extends Object abstract;

var string BuildNumber;
var string BuildTime;

defaultproperties
{
     BuildNumber="dev"
     BuildTime=""
}

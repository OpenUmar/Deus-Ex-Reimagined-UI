//=============================================================================
// RITextures
// Imports every texture used by the Reimagined UI add-on.
// Images live in ReimaginedUI\Textures (8-bit palettized PCX, power-of-two).
//=============================================================================
class RITextures extends Object
	abstract;

// Key art, 1920x1080, in two halves (one texture is limited to 1024x1024):
// each half is 968x1080 of the source, with 8 px of overlap at the seam,
// resampled to 1024x1024. RISkin.DrawKeyArt puts them back together.
#exec TEXTURE IMPORT NAME=RI_KeyArtL FILE=Textures\RI_KeyArtL.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_KeyArtR FILE=Textures\RI_KeyArtR.pcx GROUP=UI MIPS=Off
// Game of the Year logo, drawn in two passes for soft edges on any background:
// LogoMask (modulated) knocks out the shape, LogoAdd (translucent) adds the colour
#exec TEXTURE IMPORT NAME=RI_LogoMask FILE=Textures\RI_LogoMask.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_LogoAdd FILE=Textures\RI_LogoAdd.pcx GROUP=UI MIPS=Off

// Solids, tinted in code with SetTileColor
#exec TEXTURE IMPORT NAME=RI_White FILE=Textures\RI_White.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_Navy FILE=Textures\RI_Navy.pcx GROUP=UI MIPS=Off

// Modulated (darkening) layers: 128 = unchanged, 0 = black
#exec TEXTURE IMPORT NAME=RI_Dark FILE=Textures\RI_Dark.pcx GROUP=UI MIPS=Off
// Eight steps of modulated darkening (128 = none ... 36), for fades
#exec TEXTURE IMPORT NAME=RI_Dim1 FILE=Textures\RI_Dim1.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_Dim2 FILE=Textures\RI_Dim2.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_Dim3 FILE=Textures\RI_Dim3.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_Dim4 FILE=Textures\RI_Dim4.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_Dim5 FILE=Textures\RI_Dim5.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_Dim6 FILE=Textures\RI_Dim6.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_Dim7 FILE=Textures\RI_Dim7.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_Dim8 FILE=Textures\RI_Dim8.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_FadeH FILE=Textures\RI_FadeH.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_FadeV FILE=Textures\RI_FadeV.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_Scan FILE=Textures\RI_Scan.pcx GROUP=UI MIPS=Off

// Additive (translucent) glows: black = no effect
#exec TEXTURE IMPORT NAME=RI_Glow FILE=Textures\RI_Glow.pcx GROUP=UI MIPS=Off
// Body figures (V3, Umar's updated art; Health: 465 x 888, Augmentations: 477 x 891), each in
// the top-left of a 512 x 1024 texture, masked. RI_AugBody.pcx (the original
// art with its leg completed) stays in Textures as a fallback.
#exec TEXTURE IMPORT NAME=RI_HealthBody FILE=Textures\RI_HealthBodyV3.pcx GROUP=UI MIPS=Off FLAGS=2
#exec TEXTURE IMPORT NAME=RI_AugBody FILE=Textures\RI_AugBodyV3.pcx GROUP=UI MIPS=Off FLAGS=2
// Aug locations lit on the figure (additive, greyscale, tinted in code): each
// location's part of RI_AugBody, lifted and feathered, in the same place
#exec TEXTURE IMPORT NAME=RI_AugHi FILE=Textures\RI_AugHi.pcx GROUP=UI MIPS=Off
// Augs: installed-location art over the figure (the original screen's idea):
// arm and leg muscle cut from the Health figure, fitted to the Augs pose
#exec TEXTURE IMPORT NAME=RI_AugLocArm FILE=Textures\RI_AugLocArm.pcx GROUP=UI MIPS=Off FLAGS=2
#exec TEXTURE IMPORT NAME=RI_AugLocLeg FILE=Textures\RI_AugLocLeg.pcx GROUP=UI MIPS=Off FLAGS=2
// cranial, eyes, torso, subdermal: the game's own pieces, upscaled 4x with
// the PBRify RPLKSRd V3 model (Kim2091)
#exec TEXTURE IMPORT NAME=RI_AugLocCerebral FILE=Textures\RI_AugLocCerebral.pcx GROUP=UI MIPS=Off FLAGS=2
#exec TEXTURE IMPORT NAME=RI_AugLocEyes FILE=Textures\RI_AugLocEyes.pcx GROUP=UI MIPS=Off FLAGS=2
#exec TEXTURE IMPORT NAME=RI_AugLocTorso FILE=Textures\RI_AugLocTorso.pcx GROUP=UI MIPS=Off FLAGS=2
#exec TEXTURE IMPORT NAME=RI_AugLocSubdermal FILE=Textures\RI_AugLocSubdermal.pcx GROUP=UI MIPS=Off FLAGS=2
// Health: each part's glow (rim round the silhouette plus a lift inside),
// additive, tinted in code by the part's state; parts in their own places
#exec TEXTURE IMPORT NAME=RI_HealthHi FILE=Textures\RI_HealthHi.pcx GROUP=UI MIPS=Off
// HUD body monitor: the remade figure in six greyscale parts, tinted by
// each part's health (masked). Figure 173 x 360; offsets are in RIHud
#exec TEXTURE IMPORT NAME=RI_HudHead FILE=Textures\RI_HudHead.pcx GROUP=UI MIPS=Off FLAGS=2
#exec TEXTURE IMPORT NAME=RI_HudTorso FILE=Textures\RI_HudTorso.pcx GROUP=UI MIPS=Off FLAGS=2
#exec TEXTURE IMPORT NAME=RI_HudArmR FILE=Textures\RI_HudArmR.pcx GROUP=UI MIPS=Off FLAGS=2
#exec TEXTURE IMPORT NAME=RI_HudArmL FILE=Textures\RI_HudArmL.pcx GROUP=UI MIPS=Off FLAGS=2
#exec TEXTURE IMPORT NAME=RI_HudLegR FILE=Textures\RI_HudLegR.pcx GROUP=UI MIPS=Off FLAGS=2
#exec TEXTURE IMPORT NAME=RI_HudLegL FILE=Textures\RI_HudLegL.pcx GROUP=UI MIPS=Off FLAGS=2
// Soft shadow (modulated): darkest in the middle, fading out on every side
#exec TEXTURE IMPORT NAME=RI_ShadeC FILE=Textures\RI_ShadeC.pcx GROUP=UI MIPS=Off
// Centred glow (bright in the middle, fading to every edge)
#exec TEXTURE IMPORT NAME=RI_GlowC FILE=Textures\RI_GlowC.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_EdgeGlow FILE=Textures\RI_EdgeGlow.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_Beam FILE=Textures\RI_Beam.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_Sweep FILE=Textures\RI_Sweep.pcx GROUP=UI MIPS=Off

// Restyled AE buttons (additive, tinted per widget). P = pressed state.
#exec TEXTURE IMPORT NAME=RI_BtnL FILE=Textures\RI_BtnL.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_BtnC FILE=Textures\RI_BtnC.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_BtnR FILE=Textures\RI_BtnR.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_BtnLP FILE=Textures\RI_BtnLP.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_BtnCP FILE=Textures\RI_BtnCP.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_BtnRP FILE=Textures\RI_BtnRP.pcx GROUP=UI MIPS=Off
// Fully black: invisible when drawn additively (hides AE background art)
#exec TEXTURE IMPORT NAME=RI_Clear FILE=Textures\RI_Clear.pcx GROUP=UI MIPS=Off

// Concept-style rows and outlined buttons (all 2x32, drawn 19 px tall)
#exec TEXTURE IMPORT NAME=RI_Row FILE=Textures\RI_Row.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_RowP FILE=Textures\RI_RowP.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_Head FILE=Textures\RI_Head.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_OutL FILE=Textures\RI_OutL.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_OutC FILE=Textures\RI_OutC.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_OutR FILE=Textures\RI_OutR.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_OutLP FILE=Textures\RI_OutLP.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_OutCP FILE=Textures\RI_OutCP.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_OutRP FILE=Textures\RI_OutRP.pcx GROUP=UI MIPS=Off

// Baked font atlases (Michroma, Exo 2; SIL Open Font License), see fontgen/
#exec TEXTURE IMPORT NAME=RI_AtlasTitle FILE=Textures\RIFontTitle.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_AtlasHead FILE=Textures\RIFontHead.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_AtlasBody FILE=Textures\RIFontBody.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_AtlasSmall FILE=Textures\RIFontSmall.pcx GROUP=UI MIPS=Off

// Vanilla+ frame kit (grey, tinted by the HUD theme in game): rounded frame,
// chamfered button (normal / lit), header tab
#exec TEXTURE IMPORT NAME=VPK_Frame FILE=Textures\VPK_Frame.pcx GROUP=VPlus MIPS=Off
#exec TEXTURE IMPORT NAME=VPK_Btn FILE=Textures\VPK_Btn.pcx GROUP=VPlus MIPS=Off
#exec TEXTURE IMPORT NAME=VPK_BtnLit FILE=Textures\VPK_BtnLit.pcx GROUP=VPlus MIPS=Off
#exec TEXTURE IMPORT NAME=VPK_Hdr FILE=Textures\VPK_Hdr.pcx GROUP=VPlus MIPS=Off
#exec TEXTURE IMPORT NAME=VPH_Body FILE=Textures\VPH_Body.pcx GROUP=VPlus MIPS=Off
#exec TEXTURE IMPORT NAME=VPH_Info FILE=Textures\VPH_Info.pcx GROUP=VPlus MIPS=Off
#exec TEXTURE IMPORT NAME=VPH_Rail FILE=Textures\VPH_Rail.pcx GROUP=VPlus MIPS=Off
#exec TEXTURE IMPORT NAME=VPH_Weapon FILE=Textures\VPH_Weapon.pcx GROUP=VPlus MIPS=Off
#exec TEXTURE IMPORT NAME=VPH_Belt0 FILE=Textures\VPH_Belt0.pcx GROUP=VPlus MIPS=Off
#exec TEXTURE IMPORT NAME=VPH_Belt1 FILE=Textures\VPH_Belt1.pcx GROUP=VPlus MIPS=Off
#exec TEXTURE IMPORT NAME=VPH_Belt2 FILE=Textures\VPH_Belt2.pcx GROUP=VPlus MIPS=Off
#exec TEXTURE IMPORT NAME=VPH_Belt12_0 FILE=Textures\VPH_Belt12_0.pcx GROUP=VPlus MIPS=Off
#exec TEXTURE IMPORT NAME=VPH_Belt12_1 FILE=Textures\VPH_Belt12_1.pcx GROUP=VPlus MIPS=Off
#exec TEXTURE IMPORT NAME=VPH_Belt12_2 FILE=Textures\VPH_Belt12_2.pcx GROUP=VPlus MIPS=Off
#exec TEXTURE IMPORT NAME=VPH_Belt12_L FILE=Textures\VPH_Belt12_L.pcx GROUP=VPlus MIPS=Off
#exec TEXTURE IMPORT NAME=VPH_Belt_L FILE=Textures\VPH_Belt_L.pcx GROUP=VPlus MIPS=Off
#exec TEXTURE IMPORT NAME=VPH_BeltA FILE=Textures\VPH_BeltA.pcx GROUP=VPlus MIPS=Off
#exec TEXTURE IMPORT NAME=VPH_BeltB FILE=Textures\VPH_BeltB.pcx GROUP=VPlus MIPS=Off
// In-game devices and views (Sleek)
#exec TEXTURE IMPORT NAME=RI_Cursor FILE=Textures\RI_Cursor.pcx GROUP=UI MIPS=Off FLAGS=2
#exec TEXTURE IMPORT NAME=RI_ScopeMask FILE=Textures\RI_ScopeMask.pcx GROUP=UI MIPS=Off
#exec TEXTURE IMPORT NAME=RI_BinocMask FILE=Textures\RI_BinocMask.pcx GROUP=UI MIPS=Off

defaultproperties
{
}

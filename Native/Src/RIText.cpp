/*=============================================================================
	RIText.cpp: native text for the Reimagined UI.

	The UI is drawn in "UI units"; the engine scales them to screen pixels by
	an integer factor kept in the graphics context (XGC::hMultiplier, 2 at
	1080p). Script-side atlas text had to be baked at one size and resampled,
	which made spacing and baselines uneven. Here each font is rasterised at
	the exact pixel size needed (stb_truetype), packed into an engine texture,
	and every glyph is placed on whole screen pixels with proper kerning.

	Sheets are cached per (font, pixel size). They and their palette are
	ROOTED (AddToRoot): they are referenced only from this DLL's statics,
	which the garbage collector can't see, and RF_Standalone does not keep
	objects alive in the game (only the editor keeps it). Unrooted, every map
	change freed them while these statics still pointed at them; the "still
	valid" index check could then be fooled by a new object reusing the same
	index and address, and the renderer wrote into that object as if it were
	a texture - heap corruption that surfaced at the next map change as
	"Assertion failed: Removed!=0" in UnObj.cpp. A sheet dropped from the
	cache is unrooted, so the engine frees it at a safe point (map change).

	Glyphs are NOT drawn through XGC::DrawStretchedTexture: Extension.dll's
	XGC::DrawTile rounds every position and size to a whole UI unit before
	scaling (2 screen pixels at 1080p), which shifts letters by a pixel and
	makes spacing uneven. Instead the same steps are done here in exact
	pixels (window origin + clip rectangle from XGC::clipRect, colour and
	poly flags from the GC) and the tile goes straight to UCanvas::DrawTile.
=============================================================================*/

#define RINATIVE_API DLL_EXPORT
#include "Engine.h"

// Only data members of XGC are read (the pixel multiplier); no private
// functions are called, so their decorated names are unaffected.
#define private public
#define protected public
#include "Extension.h"
#undef private
#undef protected

#include "RIFonts.h"

#define RI_FIRST 32
#define RI_LAST  126
#define RI_NUM   (RI_LAST - RI_FIRST + 1)
#define RI_MAXSHEETS 48

struct FRIGlyph
{
	INT X, Y, W, H;     // in the sheet
	INT XOff, YOff;     // from pen / baseline, pixels
};

struct FRISheet
{
	INT       Font, Px;
	UTexture* Tex;
	INT       TexIndex;     // to detect garbage collection
	FLOAT     Scale;        // font units -> pixels
	FRIGlyph  G[RI_NUM];
};

static FRISheet GSheets[RI_MAXSHEETS];
static INT      GNumSheets;
static INT      GNextRecycle;
static UPalette* GGrayPal;
static INT      GGrayPalIndex = -1;

static UBOOL StillValid( UObject* Obj, INT Index )
{
	return Obj && Index >= 0 && UObject::GetIndexedObject(Index) == Obj;
}

static UPalette* GrayPalette()
{
	if( StillValid(GGrayPal, GGrayPalIndex) )
		return GGrayPal;
	GGrayPal = (UPalette*)UObject::StaticConstructObject( UPalette::StaticClass(), UObject::GetTransientPackage(), NAME_None, RF_Transient );
	GGrayPal->AddToRoot();
	GGrayPal->Colors.Empty();
	for( INT i=0; i<256; i++ )
		GGrayPal->Colors.AddItem( FColor(i,i,i,0) );
	GGrayPalIndex = GGrayPal->GetIndex();
	return GGrayPal;
}

static INT PowerOfTwo( INT V, INT* Bits )
{
	INT P = 1, B = 0;
	while( P < V ) { P <<= 1; B++; }
	*Bits = B;
	return P;
}

static FRISheet* BuildSheet( FRISheet* S, INT Font, INT Px )
{
	unsigned char* Bmp[RI_NUM];
	INT W[RI_NUM], H[RI_NUM], XO[RI_NUM], YO[RI_NUM];
	INT i, x, y, rowh, SheetW, SheetH, UBits, VBits, Pad = 1;

	S->Font  = Font;
	S->Px    = Px;
	S->Scale = RIF_ScaleForEm( Font, (FLOAT)Px );

	for( i=0; i<RI_NUM; i++ )
		Bmp[i] = RIF_Glyph( Font, S->Scale, RI_FIRST + i, &W[i], &H[i], &XO[i], &YO[i] );

	// Shelf-pack into a fixed-width sheet (wider for large sizes)
	SheetW = Px > 48 ? 1024 : 512;
	x = y = rowh = 0;
	for( i=0; i<RI_NUM; i++ )
	{
		S->G[i].W = Bmp[i] ? W[i] : 0;
		S->G[i].H = Bmp[i] ? H[i] : 0;
		S->G[i].XOff = XO[i];
		S->G[i].YOff = YO[i];
		if( !Bmp[i] )
			continue;
		if( x + W[i] + Pad > SheetW ) { x = 0; y += rowh + Pad; rowh = 0; }
		S->G[i].X = x;
		S->G[i].Y = y;
		x += W[i] + Pad;
		if( H[i] > rowh ) rowh = H[i];
	}
	SheetW = PowerOfTwo( SheetW, &UBits );
	SheetH = PowerOfTwo( y + rowh + 1, &VBits );
	if( SheetH < 8 ) { SheetH = 8; VBits = 3; }

	// a sheet being replaced (cache full) is handed back to the engine
	if( StillValid(S->Tex, S->TexIndex) )
		S->Tex->RemoveFromRoot();
	S->Tex = NULL;
	S->Tex = (UTexture*)UObject::StaticConstructObject( UTexture::StaticClass(), UObject::GetTransientPackage(), NAME_None, RF_Transient );
	S->Tex->AddToRoot();
	S->Tex->Init( SheetW, SheetH );
	S->Tex->Format  = TEXF_P8;
	S->Tex->Palette = GrayPalette();
	S->Tex->USize   = SheetW;
	S->Tex->VSize   = SheetH;
	S->Tex->UBits   = (BYTE)UBits;
	S->Tex->VBits   = (BYTE)VBits;
	S->Tex->UClamp  = SheetW;
	S->Tex->VClamp  = SheetH;
	S->TexIndex     = S->Tex->GetIndex();

	// Deus Ex's UTexture::Init only records the size; the pixel storage (one
	// mip level, no mipmaps needed for 1:1 text) is created here
	if( S->Tex->Mips.Num() == 0 || S->Tex->Mips(0).DataArray.Num() < SheetW * SheetH )
	{
		S->Tex->Mips.Empty();
		new(S->Tex->Mips) FMipmap( (BYTE)UBits, (BYTE)VBits );
	}
	if( S->Tex->Mips.Num() == 0 || S->Tex->Mips(0).DataArray.Num() < SheetW * SheetH )
	{
		S->Tex->RemoveFromRoot();
		S->Tex = NULL;      // couldn't allocate: draw nothing rather than crash
		return S;
	}

	BYTE* Dest = &S->Tex->Mips(0).DataArray(0);
	appMemzero( Dest, SheetW * SheetH );
	for( i=0; i<RI_NUM; i++ )
	{
		if( !Bmp[i] )
			continue;
		for( INT r=0; r<H[i]; r++ )
			appMemcpy( Dest + (S->G[i].Y + r) * SheetW + S->G[i].X, Bmp[i] + r * W[i], W[i] );
		RIF_Free( Bmp[i] );
	}
	return S;
}

static FRISheet* GetSheet( INT Font, INT Px )
{
	INT i;
	if( Px < 4 )   Px = 4;
	if( Px > 160 ) Px = 160;
	for( i=0; i<GNumSheets; i++ )
		if( GSheets[i].Font == Font && GSheets[i].Px == Px )
		{
			if( !StillValid(GSheets[i].Tex, GSheets[i].TexIndex) )
				BuildSheet( &GSheets[i], Font, Px );
			return &GSheets[i];
		}
	if( GNumSheets >= RI_MAXSHEETS )
	{
		// cache full: overwrite the oldest entries in turn (BuildSheet
		// unroots the sheet it replaces)
		INT Slot = GNextRecycle;
		GNextRecycle = (GNextRecycle + 1) % RI_MAXSHEETS;
		return BuildSheet( &GSheets[Slot], Font, Px );
	}
	GSheets[GNumSheets].Tex = NULL;
	GSheets[GNumSheets].TexIndex = -1;
	return BuildSheet( &GSheets[GNumSheets++], Font, Px );
}

static INT GlyphIndex( TCHAR C )
{
	if( C < RI_FIRST || C > RI_LAST )
		C = '?';
	return C - RI_FIRST;
}

static INT ClampFont( INT Font )
{
	return (Font < 0 || Font >= RIF_Count) ? RIF_Exo2Medium : Font;
}

/*-----------------------------------------------------------------------------
	Pixel-exact tile drawing (bypasses XGC's whole-UI-unit rounding)
-----------------------------------------------------------------------------*/

// X0..Y1 are absolute screen pixels; U, V the texel at (X0, Y0); 1 texel = 1 pixel
// unless UScale / VScale say otherwise. Clipped to the GC's clip rectangle.
static void DrawTilePx( XGC* gc, UTexture* Tex, FLOAT X0, FLOAT Y0, FLOAT X1, FLOAT Y1,
                        FLOAT U, FLOAT V, FLOAT UScale, FLOAT VScale )
{
	FLOAT KH = gc->hMultiplier > 0 ? (FLOAT)gc->hMultiplier : 1.f;
	FLOAT KV = gc->vMultiplier > 0 ? (FLOAT)gc->vMultiplier : 1.f;
	XClipRect& R = gc->clipRect;
	FLOAT CX0 = (R.originX + R.clipX) * KH, CY0 = (R.originY + R.clipY) * KV;
	FLOAT CX1 = CX0 + R.clipWidth * KH,   CY1 = CY0 + R.clipHeight * KV;

	if( X1 <= CX0 || X0 >= CX1 || Y1 <= CY0 || Y0 >= CY1 || X1 <= X0 || Y1 <= Y0 )
		return;
	if( X0 < CX0 ) { U += (CX0 - X0) * UScale; X0 = CX0; }
	if( Y0 < CY0 ) { V += (CY0 - Y0) * VScale; Y0 = CY0; }
	if( X1 > CX1 ) X1 = CX1;
	if( Y1 > CY1 ) Y1 = CY1;

	gc->canvas->DrawTile( Tex, X0, Y0, X1 - X0, Y1 - Y0, U, V, (X1 - X0) * UScale, (Y1 - Y0) * VScale,
		NULL, gc->canvas->Z, gc->tilePlane, FPlane(0,0,0,0), gc->polyFlags );
}

// Any texture, X/Y/W/H in UI units relative to the GC's window, edges rounded
// to whole SCREEN pixels (never less than one pixel when W or H > 0).
// Uses the GC's current style and colour.
void RINativeDrawTileUI( XGC* gc, UTexture* Tex, FLOAT X, FLOAT Y, FLOAT W, FLOAT H,
                         FLOAT U, FLOAT V, FLOAT UL, FLOAT VL )
{
	FLOAT KH, KV, X0, Y0, X1, Y1;

	if( !gc || !Tex || !gc->canvas || !gc->bDrawEnabled || W <= 0.f || H <= 0.f )
		return;
	KH = gc->hMultiplier > 0 ? (FLOAT)gc->hMultiplier : 1.f;
	KV = gc->vMultiplier > 0 ? (FLOAT)gc->vMultiplier : 1.f;
	X0 = appFloor( (gc->clipRect.originX + X) * KH + 0.5f );
	Y0 = appFloor( (gc->clipRect.originY + Y) * KV + 0.5f );
	X1 = appFloor( (gc->clipRect.originX + X + W) * KH + 0.5f );
	Y1 = appFloor( (gc->clipRect.originY + Y + H) * KV + 0.5f );
	if( X1 <= X0 ) X1 = X0 + 1;
	if( Y1 <= Y0 ) Y1 = Y0 + 1;
	DrawTilePx( gc, Tex, X0, Y0, X1, Y1, U, V, UL / (X1 - X0), VL / (Y1 - Y0) );
}

/*-----------------------------------------------------------------------------
	Script interface (class RINative)
-----------------------------------------------------------------------------*/

// Width of a string in UI units, at a size given in UI units (em height)
FLOAT RINativeTextWidthUI( INT Font, FLOAT SizeUI, FLOAT SpacingUI, const TCHAR* Text )
{
	INT Adv, Lsb, i, n;
	FLOAT Scale, W = 0.f;

	Font = ClampFont(Font);
	if( !RIF_Init() || SizeUI <= 0.f )
		return 0.f;
	Scale = RIF_ScaleForEm( Font, SizeUI );
	n = appStrlen( Text );
	for( i=0; i<n; i++ )
	{
		INT C = GlyphIndex(Text[i]) + RI_FIRST;
		RIF_HMetrics( Font, C, &Adv, &Lsb );
		W += Adv * Scale + SpacingUI;
		if( i + 1 < n )
			W += RIF_Kern( Font, C, GlyphIndex(Text[i+1]) + RI_FIRST ) * Scale;
	}
	return W;
}

FLOAT RINativeAscentUI( INT Font, FLOAT SizeUI )
{
	INT A, D, G;
	Font = ClampFont(Font);
	RIF_VMetrics( Font, &A, &D, &G );
	return A * RIF_ScaleForEm( Font, SizeUI );
}

FLOAT RINativeDescentUI( INT Font, FLOAT SizeUI )
{
	INT A, D, G;
	Font = ClampFont(Font);
	RIF_VMetrics( Font, &A, &D, &G );
	return -D * RIF_ScaleForEm( Font, SizeUI );
}

// Draws Text with the top of the line at (X, Y), UI units. Returns the width.
FLOAT RINativeDrawTextUI( XGC* gc, INT Font, FLOAT X, FLOAT Y, const TCHAR* Text, FColor Col, FLOAT SizeUI, FLOAT SpacingUI )
{
	FRISheet* S;
	INT K, Px, i, n, Adv, Lsb, A, D, G;
	FLOAT Pen, Start, Base;

	if( !gc || !Text || !RIF_Init() || SizeUI <= 0.f )
		return 0.f;
	Font = ClampFont(Font);

	K = gc->hMultiplier;                // screen pixels per UI unit
	if( K < 1 ) K = 1;
	Px = (INT)(SizeUI * K + 0.5f);
	S  = GetSheet( Font, Px );
	if( !S || !S->Tex )
		return 0.f;

	RIF_VMetrics( Font, &A, &D, &G );
	// Absolute screen pixels: window origin from the GC's clip rectangle
	Start = (gc->clipRect.originX + X) * K;
	Pen   = Start;
	Base  = appFloor( (gc->clipRect.originY + Y) * (gc->vMultiplier > 0 ? gc->vMultiplier : K) + A * S->Scale + 0.5f );

	// Let the GC work out poly flags and colour plane for us
	gc->SetStyle( STY_Translucent );
	gc->SetTileColor( Col );
	gc->EnableSmoothing( TRUE );

	n = appStrlen( Text );
	for( i=0; i<n; i++ )
	{
		INT Gi = GlyphIndex( Text[i] );
		FRIGlyph& Gl = S->G[Gi];
		if( Gl.W > 0 && Gl.H > 0 && gc->canvas && gc->bDrawEnabled )
		{
			FLOAT Dx = appFloor( Pen + Gl.XOff + 0.5f );
			FLOAT Dy = Base + Gl.YOff;
			DrawTilePx( gc, S->Tex, Dx, Dy, Dx + Gl.W, Dy + Gl.H, (FLOAT)Gl.X, (FLOAT)Gl.Y, 1.f, 1.f );
		}
		RIF_HMetrics( Font, Gi + RI_FIRST, &Adv, &Lsb );
		Pen += Adv * S->Scale + SpacingUI * K;
		if( i + 1 < n )
			Pen += RIF_Kern( Font, Gi + RI_FIRST, GlyphIndex(Text[i+1]) + RI_FIRST ) * S->Scale;
	}
	return (Pen - Start) / K;
}

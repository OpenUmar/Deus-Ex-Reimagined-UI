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

/*-----------------------------------------------------------------------------
	3D panels (perspective tilt, as Human Revolution / Mankind Divided)

	A HUD panel is treated as a flat card turned about a vertical hinge line
	and seen in perspective from an eye in front of the screen. The renderer
	is never asked to draw anything but ordinary 2D tiles: a card turned about
	a VERTICAL axis keeps every vertical line vertical on screen, so the
	projected panel is drawn exactly as a run of thin vertical slices, each a
	plain tile with its own height and texture range. That works the same on
	every renderer (stock Direct3D, OpenGL, SecondRevision, software): no
	depth buffer, no 3D polygons, no near-plane clipping.

	Screen pixels, absolute. For a point at x on the card (y doesn't change
	the depth), with dx = x - Hinge:
		Z      = dx * sin(Yaw)                       depth behind the screen
		X      = Hinge + dx * cos(Yaw)
		s      = D / (D + Z)                         perspective scale
		x'     = Ex + (X - Ex) * s,  y' = Ey + (y - Ey) * s
	The inverse (screen column -> card x) is closed form:
		dx = D * (b - a) / (a * sin - D * cos),  a = x' - Ex, b = Hinge - Ex
	Positive Yaw pushes the card's right side away (a left-hand panel hinged
	on the screen's left edge); negative pushes the left side away.

	The state is set from script round a panel and cleared after it, and only
	applies to the GC it was set on.
-----------------------------------------------------------------------------*/

struct FRI3D
{
	UBOOL On;
	XGC*  Gc;
	FLOAT Hinge, Ex, Ey, D, Cs, Sn;
	INT   Grid;     // slice width in screen pixels, on one grid for the whole card
	FLOAT FX, FY;   // the window's sub-pixel offset, taken off so the card sits on whole pixels
};
static FRI3D G3D;

// sin / cos without the C runtime (|A| <= pi / 4 here, so a short series is exact to float precision)
static FLOAT RISin( FLOAT A )
{
	FLOAT A2 = A * A;
	return A * (1.f - A2 / 6.f * (1.f - A2 / 20.f * (1.f - A2 / 42.f * (1.f - A2 / 72.f))));
}
static FLOAT RICos( FLOAT A )
{
	FLOAT A2 = A * A;
	return 1.f - A2 / 2.f * (1.f - A2 / 12.f * (1.f - A2 / 30.f * (1.f - A2 / 56.f * (1.f - A2 / 90.f))));
}

static inline FLOAT RIRound( FLOAT V ) { return (FLOAT)appFloor( V + 0.5f ); }

// Card x -> perspective scale (never below a tenth: the card stays in front of the eye)
static inline FLOAT P3Scale( FLOAT X )
{
	FLOAT Den = G3D.D + (X - G3D.Hinge) * G3D.Sn;
	if( Den < G3D.D * 0.1f ) Den = G3D.D * 0.1f;
	return G3D.D / Den;
}
static inline FLOAT P3X( FLOAT X )
{
	FLOAT dx = X - G3D.Hinge;
	return G3D.Ex + (G3D.Hinge + dx * G3D.Cs - G3D.Ex) * P3Scale( X );
}
static inline FLOAT P3InvX( FLOAT SX )
{
	FLOAT a = SX - G3D.Ex, b = G3D.Hinge - G3D.Ex;
	FLOAT Den = a * G3D.Sn - G3D.D * G3D.Cs;
	if( Den > -1e-3f && Den < 1e-3f )
		Den = Den < 0.f ? -1e-3f : 1e-3f;
	return G3D.Hinge + G3D.D * (b - a) / Den;
}

// UI units in the GC's window -> absolute screen pixels; Yaw in degrees
UBOOL RINativeSet3DUI( XGC* gc, FLOAT HingeUI, FLOAT EyeXUI, FLOAT EyeYUI, FLOAT DistUI, FLOAT YawDeg )
{
	FLOAT KH, KV, A;

	G3D.On = 0;
	G3D.Gc = NULL;
	if( !gc || DistUI <= 1.f || (YawDeg > -0.05f && YawDeg < 0.05f) )
		return 0;
	if( YawDeg >  40.f ) YawDeg =  40.f;
	if( YawDeg < -40.f ) YawDeg = -40.f;
	KH = gc->hMultiplier > 0 ? (FLOAT)gc->hMultiplier : 1.f;
	KV = gc->vMultiplier > 0 ? (FLOAT)gc->vMultiplier : 1.f;
	A  = YawDeg * (3.14159265f / 180.f);
	// A window that moves by a fraction of a pixel (HUD motion at a scale
	// that isn't a whole number of pixels per UI unit) is drawn snapped to the
	// nearest whole pixel, so the card's pixels stay put relative to each other
	G3D.FX    = gc->clipRect.originX * KH - (FLOAT)appFloor( gc->clipRect.originX * KH + 0.5f );
	G3D.FY    = gc->clipRect.originY * KV - (FLOAT)appFloor( gc->clipRect.originY * KV + 0.5f );
	G3D.Hinge = (gc->clipRect.originX + HingeUI) * KH - G3D.FX;
	G3D.Ex    = (gc->clipRect.originX + EyeXUI) * KH - G3D.FX;
	G3D.Ey    = (gc->clipRect.originY + EyeYUI) * KV - G3D.FY;
	G3D.D     = DistUI * KH;
	G3D.Sn    = RISin( A );
	G3D.Cs    = RICos( A );
	// Slices sit on one global column grid, and each grid cell has ONE scale:
	// tiles stacked in the same columns (text over a panel, a box's edges)
	// then round their shared edges identically, with no seams or overlaps.
	// The cell is narrow enough that heights are right to half a pixel
	// anywhere on screen (the scale changes by about sin / D per pixel).
	{
		FLOAT Rate = (G3D.Sn < 0 ? -G3D.Sn : G3D.Sn) / G3D.D * (G3D.Ey > 1.f ? G3D.Ey : 1.f);
		G3D.Grid = Rate > 0.f ? (INT)(0.1f / Rate) : 16;
		if( G3D.Grid < 1 )  G3D.Grid = 1;
		if( G3D.Grid > 16 ) G3D.Grid = 16;
	}
	G3D.Gc    = gc;
	G3D.On    = 1;
	return 1;
}

void RINativeClear3DUI()
{
	G3D.On = 0;
	G3D.Gc = NULL;
}

// Where a point of the card lands, UI units in and out (for script: hit
// tests, placing things drawn by other windows over a tilted panel)
void RINativeProject3DUI( XGC* gc, FLOAT X, FLOAT Y, FLOAT* OX, FLOAT* OY )
{
	FLOAT KH, KV, PX, PY, Sc;

	*OX = X;
	*OY = Y;
	if( !gc || !G3D.On || G3D.Gc != gc )
		return;
	KH = gc->hMultiplier > 0 ? (FLOAT)gc->hMultiplier : 1.f;
	KV = gc->vMultiplier > 0 ? (FLOAT)gc->vMultiplier : 1.f;
	PX = (gc->clipRect.originX + X) * KH;
	PY = (gc->clipRect.originY + Y) * KV;
	Sc = P3Scale( PX );
	*OX = P3X( PX ) / KH - gc->clipRect.originX;
	*OY = (G3D.Ey + (PY - G3D.Ey) * Sc) / KV - gc->clipRect.originY;
}

// One horizontal band of a slice: screen rows PY0..PY1, card rows CY0..CY1,
// tinted by Cov (the share of the edge pixel the card really covers)
static void Slice3D( XGC* gc, UTexture* Tex, FLOAT CA, FLOAT CB, FLOAT PY0, FLOAT PY1,
                     FLOAT CY0, FLOAT CY1, FLOAT Y0, FLOAT UA, FLOAT UL, FLOAT V, FLOAT VScale, FLOAT Cov )
{
	FPlane C = gc->tilePlane;

	if( PY1 <= PY0 || CY1 <= CY0 || Cov <= 0.004f )
		return;
	if( Cov < 0.996f )
		C = FPlane( C.X * Cov, C.Y * Cov, C.Z * Cov, C.W * Cov );
	if( CB <= CA )
		return;
	gc->canvas->DrawTile( Tex, CA, PY0, CB - CA, PY1 - PY0,
		UA, V + (CY0 - Y0) * VScale, UL, (CY1 - CY0) * VScale,
		NULL, gc->canvas->Z, C, FPlane(0,0,0,0), gc->polyFlags );
}

// A run of screen columns that draw the same band the same way, merged into one tile
struct FRIRun
{
	UBOOL On;
	INT   CA, CB;          // screen columns
	FLOAT XA, XB;          // card x under them
	FLOAT PY0, PY1, Cov;   // screen rows, coverage
	INT   Kind;            // 0 top edge row, 1 full rows, 2 bottom edge row, 3 one thin row
	FLOAT ScSum; INT N;    // perspective scale, averaged over the run
	FLOAT F0;              // the exact top edge where the run began
};

static void FlushRun( XGC* gc, UTexture* Tex, FRIRun& R, FLOAT X0, FLOAT Y0, FLOAT Y1,
                      FLOAT U, FLOAT V, FLOAT UScale, FLOAT VScale )
{
	FLOAT Sc, CY0, CY1;

	if( !R.On )
		return;
	R.On = 0;
	Sc = R.ScSum / R.N;
	#define CARDY(Row) (G3D.Ey + ((Row) - G3D.Ey) / Sc)
	switch( R.Kind )
	{
		case 0:  CY0 = Y0;            CY1 = CARDY(R.PY1); break;
		case 1:  CY0 = CARDY(R.PY0);  CY1 = CARDY(R.PY1); break;
		case 2:  CY0 = CARDY(R.PY0);  CY1 = Y1;           break;
		default: CY0 = Y0;            CY1 = Y1;           break;
	}
	#undef CARDY
	if( CY0 < Y0 ) CY0 = Y0;
	if( CY1 > Y1 ) CY1 = Y1;
	Slice3D( gc, Tex, R.CA, R.CB, R.PY0, R.PY1, CY0, CY1, Y0,
		U + (R.XA - X0) * UScale, (R.XB - R.XA) * UScale, V, VScale, R.Cov );
}

// Adds one column to a band's run, flushing the run first if this column
// differs (another row, coverage more than 1/48 apart, or the edge has
// drifted a fifth of a pixel, so texture rows inside the run stay put)
static void AddCol( XGC* gc, UTexture* Tex, FRIRun& R, INT Kind, INT C, FLOAT XA, FLOAT XB,
                    FLOAT PY0, FLOAT PY1, FLOAT Cov, FLOAT Sc, FLOAT FY,
                    FLOAT X0, FLOAT Y0, FLOAT Y1, FLOAT U, FLOAT V, FLOAT UScale, FLOAT VScale )
{
	if( R.On && (R.Kind != Kind || R.CB != C || R.PY0 != PY0 || R.PY1 != PY1
		|| Cov - R.Cov > 1.f / 48.f || R.Cov - Cov > 1.f / 48.f
		|| FY - R.F0 > 0.2f || R.F0 - FY > 0.2f) )
		FlushRun( gc, Tex, R, X0, Y0, Y1, U, V, UScale, VScale );
	if( !R.On )
	{
		R.On = 1; R.Kind = Kind; R.CA = C; R.XA = XA;
		R.PY0 = PY0; R.PY1 = PY1; R.Cov = Cov; R.ScSum = 0.f; R.N = 0; R.F0 = FY;
	}
	R.CB = C + 1;
	R.XB = XB;
	R.ScSum += Sc;
	R.N++;
}

// One tile of the card (already clipped, absolute pixels), drawn in perspective.
// Nothing is snapped to whole pixels: every edge sits where the projection
// puts it, so letters keep their exact widths and nothing hops between
// neighbouring pixels as the HUD moves.
// Translucent (additive) tiles are anti-aliased in both directions: every
// screen column gets its own depth, and each pixel the card only partly
// covers (left, right, top or bottom edge) is drawn dimmer by the covered
// fraction, so edges slope and slide smoothly (tiles sharing an edge still
// add up to exactly one). Neighbouring columns that come out the same are
// merged into one tile. Other styles (masked, modulated, normal) can't be
// dimmed that way; they are drawn in narrow slices on a shared column grid
// with exact, unrounded edges.
static void DrawTile3D( XGC* gc, UTexture* Tex, FLOAT X0, FLOAT Y0, FLOAT X1, FLOAT Y1,
                        FLOAT U, FLOAT V, FLOAT UScale, FLOAT VScale )
{
	INT   P0, P1, C, G = G3D.Grid;
	FLOAT SX0, SX1;
	UBOOL bAA = (gc->polyFlags & PF_Translucent) && !(gc->polyFlags & PF_Modulated);

	X0 -= G3D.FX; X1 -= G3D.FX;
	Y0 -= G3D.FY; Y1 -= G3D.FY;
	SX0 = P3X( X0 );
	SX1 = P3X( X1 );
	if( SX1 <= SX0 )
		return;

	if( bAA )
	{
		FRIRun RT, RM, RB;
		RT.On = RM.On = RB.On = 0;
		P0 = appFloor( SX0 );
		P1 = appFloor( SX1 );
		if( (FLOAT)P1 < SX1 ) P1++;           // columns P0 .. P1-1 are touched
		for( C = P0; C < P1; C++ )
		{
			FLOAT SA, SB, HC, XA, XB, Sc, FYA, FYB, TA, TB;

			// the part of this pixel column the card covers
			SA = (FLOAT)C;     if( SA < SX0 ) SA = SX0;
			SB = (FLOAT)C + 1; if( SB > SX1 ) SB = SX1;
			HC = SB - SA;
			if( HC <= 0.f )
				continue;
			XA = (SA == SX0) ? X0 : P3InvX( SA );
			XB = (SB == SX1) ? X1 : P3InvX( SB );
			if( XA < X0 ) XA = X0;
			if( XB > X1 ) XB = X1;
			if( XB <= XA )
				continue;
			Sc  = P3Scale( (XA + XB) * 0.5f );
			FYA = G3D.Ey + (Y0 - G3D.Ey) * Sc;
			FYB = G3D.Ey + (Y1 - G3D.Ey) * Sc;
			TA  = (FLOAT)appFloor( FYA );
			TB  = (FLOAT)appFloor( FYB );
			if( TA == TB )
			{
				AddCol( gc, Tex, RT, 3, C, XA, XB, TA, TA + 1.f, (FYB - FYA) * HC, Sc, FYA, X0, Y0, Y1, U, V, UScale, VScale );
				continue;
			}
			AddCol( gc, Tex, RT, 0, C, XA, XB, TA, TA + 1.f, (TA + 1.f - FYA) * HC, Sc, FYA, X0, Y0, Y1, U, V, UScale, VScale );
			if( TB > TA + 1.f )
				AddCol( gc, Tex, RM, 1, C, XA, XB, TA + 1.f, TB, HC, Sc, FYA, X0, Y0, Y1, U, V, UScale, VScale );
			if( FYB > TB )
				AddCol( gc, Tex, RB, 2, C, XA, XB, TB, TB + 1.f, (FYB - TB) * HC, Sc, FYA, X0, Y0, Y1, U, V, UScale, VScale );
		}
		FlushRun( gc, Tex, RT, X0, Y0, Y1, U, V, UScale, VScale );
		FlushRun( gc, Tex, RM, X0, Y0, Y1, U, V, UScale, VScale );
		FlushRun( gc, Tex, RB, X0, Y0, Y1, U, V, UScale, VScale );
		return;
	}

	// Masked / modulated / normal: slices whose inner edges sit on the shared
	// grid (so stacked tiles agree) and whose outer edges are exact
	P0 = appFloor( SX0 );
	for( C = P0; (FLOAT)C < SX1; )
	{
		INT   Cell, CB;
		FLOAT SA, SB, XA, XB, Sc, FYA, FYB;

		Cell = C >= 0 ? C / G : -((G - 1 - C) / G);
		CB = (Cell + 1) * G;
		SA = (FLOAT)C;  if( SA < SX0 ) SA = SX0;
		SB = (FLOAT)CB; if( SB > SX1 ) SB = SX1;
		C = CB;
		if( SB <= SA )
			continue;
		XA = (SA == SX0) ? X0 : P3InvX( SA );
		XB = (SB == SX1) ? X1 : P3InvX( SB );
		if( XA < X0 ) XA = X0;
		if( XB > X1 ) XB = X1;
		if( XB <= XA )
			continue;
		Sc  = P3Scale( P3InvX( Cell * G + G * 0.5f ) );
		FYA = G3D.Ey + (Y0 - G3D.Ey) * Sc;
		FYB = G3D.Ey + (Y1 - G3D.Ey) * Sc;
		Slice3D( gc, Tex, SA, SB, FYA, FYB, Y0, Y1, Y0, U + (XA - X0) * UScale, (XB - XA) * UScale, V, VScale, 1.f );
	}
}

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

	if( G3D.On && G3D.Gc == gc )
	{
		DrawTile3D( gc, Tex, X0, Y0, X1, Y1, U, V, UScale, VScale );
		return;
	}
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

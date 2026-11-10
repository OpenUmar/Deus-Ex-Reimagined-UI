#define NULL ((void*)0)
/*=============================================================================
	RIFonts.c: font rasterising for the Reimagined UI (stb_truetype).
	Built as plain C with no engine headers; uses the C runtime the game
	already ships (MSVCRT.dll) for malloc and maths.
=============================================================================*/
/* The few C runtime functions stb needs, from the MSVCRT.dll the game ships.
   Declared here directly so no C library headers are involved. */
typedef unsigned int ri_size_t;
void*  __cdecl malloc(ri_size_t);
void   __cdecl free(void*);
void*  __cdecl memcpy(void*, const void*, ri_size_t);
void*  __cdecl memset(void*, int, ri_size_t);
ri_size_t __cdecl strlen(const char*);
double __cdecl sqrt(double);
double __cdecl pow(double, double);
double __cdecl fmod(double, double);
double __cdecl cos(double);
double __cdecl acos(double);
double __cdecl fabs(double);
double __cdecl floor(double);
double __cdecl ceil(double);

#define STBTT_ifloor(x)    ((int) floor(x))
#define STBTT_iceil(x)     ((int) ceil(x))
#define STBTT_sqrt(x)      sqrt(x)
#define STBTT_pow(x,y)     pow(x,y)
#define STBTT_fmod(x,y)    fmod(x,y)
#define STBTT_cos(x)       cos(x)
#define STBTT_acos(x)      acos(x)
#define STBTT_fabs(x)      fabs(x)
#define STBTT_malloc(x,u)  ((void)(u),malloc(x))
#define STBTT_free(x,u)    ((void)(u),free(x))
#define STBTT_strlen(x)    strlen(x)
#define STBTT_memcpy       memcpy
#define STBTT_memset       memset
#define STBTT_assert(x) ((void)0)
#define STB_TRUETYPE_IMPLEMENTATION
#define STBTT_STATIC
#include "stb_truetype.h"
#include "RIFonts.h"

extern const unsigned char RIFont_Michroma[];
extern const unsigned char RIFont_Exo2Medium[];
extern const unsigned char RIFont_Exo2SemiBold[];

static stbtt_fontinfo GFonts[RIF_Count];
static int GReady;

int RIF_Init(void)
{
	const unsigned char* Data[RIF_Count];
	int i;

	if (GReady)
		return GReady > 0;
	Data[0] = RIFont_Michroma;
	Data[1] = RIFont_Exo2Medium;
	Data[2] = RIFont_Exo2SemiBold;
	GReady = 1;
	for (i = 0; i < RIF_Count; i++)
		if (!stbtt_InitFont(&GFonts[i], Data[i], stbtt_GetFontOffsetForIndex(Data[i], 0)))
			GReady = -1;
	return GReady > 0;
}

static int Ok(int Font) { return RIF_Init() && Font >= 0 && Font < RIF_Count; }

float RIF_ScaleForEm(int Font, float EmPixels)
{
	if (!Ok(Font)) return 0.f;
	return stbtt_ScaleForMappingEmToPixels(&GFonts[Font], EmPixels);
}

void RIF_VMetrics(int Font, int* Ascent, int* Descent, int* LineGap)
{
	*Ascent = *Descent = *LineGap = 0;
	if (Ok(Font)) stbtt_GetFontVMetrics(&GFonts[Font], Ascent, Descent, LineGap);
}

void RIF_HMetrics(int Font, int Codepoint, int* Advance, int* Lsb)
{
	*Advance = *Lsb = 0;
	if (Ok(Font)) stbtt_GetCodepointHMetrics(&GFonts[Font], Codepoint, Advance, Lsb);
}

int RIF_Kern(int Font, int A, int B)
{
	if (!Ok(Font)) return 0;
	return stbtt_GetCodepointKernAdvance(&GFonts[Font], A, B);
}

unsigned char* RIF_Glyph(int Font, float Scale, int Codepoint, int* W, int* H, int* XOff, int* YOff)
{
	*W = *H = *XOff = *YOff = 0;
	if (!Ok(Font)) return 0;
	return stbtt_GetCodepointBitmap(&GFonts[Font], Scale, Scale, Codepoint, W, H, XOff, YOff);
}

void RIF_Free(void* P)
{
	if (P) stbtt_FreeBitmap((unsigned char*)P, 0);
}

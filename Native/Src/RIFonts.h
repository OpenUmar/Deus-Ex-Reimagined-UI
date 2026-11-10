/*=============================================================================
	RIFonts.h: small C interface over stb_truetype, so the engine-side C++
	never sees stb's types (and stb never sees the engine's).
=============================================================================*/
#ifndef RIFONTS_H
#define RIFONTS_H
#ifdef __cplusplus
extern "C" {
#endif

enum { RIF_Michroma = 0, RIF_Exo2Medium = 1, RIF_Exo2SemiBold = 2, RIF_Count = 3 };

int            RIF_Init(void);                                  /* 1 when all fonts parsed */
float          RIF_ScaleForEm(int Font, float EmPixels);
void           RIF_VMetrics(int Font, int* Ascent, int* Descent, int* LineGap);  /* font units */
void           RIF_HMetrics(int Font, int Codepoint, int* Advance, int* Lsb);    /* font units */
int            RIF_Kern(int Font, int A, int B);                                 /* font units */
unsigned char* RIF_Glyph(int Font, float Scale, int Codepoint, int* W, int* H, int* XOff, int* YOff);
void           RIF_Free(void* P);

#ifdef __cplusplus
}
#endif
#endif

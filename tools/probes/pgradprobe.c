/* Probe: paints Story View's scene-card shadow corner (GDI+ path gradient with a preset blend) and prints pixels; stock Wine gives ffffffff inside the quarter circle, patch 0013 a faint slate shadow. Build: x86_64-w64-mingw32-gcc -O1 -o pgradprobe.exe pgradprobe.c -lgdiplus */
#include <windows.h>
#include <stdio.h>

typedef int GpStatus;
typedef struct { UINT32 GdiplusVersion; void *cb; BOOL a, b; } StartupInput;
typedef struct { float X, Y; } PointF;
GpStatus WINAPI GdiplusStartup(ULONG_PTR *, const StartupInput *, void *);
GpStatus WINAPI GdipCreateBitmapFromScan0(INT, INT, INT, INT, BYTE *, void **);
GpStatus WINAPI GdipGetImageGraphicsContext(void *, void **);
GpStatus WINAPI GdipGraphicsClear(void *, DWORD);
GpStatus WINAPI GdipCreatePath(INT, void **);
GpStatus WINAPI GdipAddPathEllipseI(void *, INT, INT, INT, INT);
GpStatus WINAPI GdipCreatePathGradientFromPath(void *, void **);
GpStatus WINAPI GdipSetPathGradientPresetBlend(void *, const DWORD *, const float *, INT);
GpStatus WINAPI GdipSetPathGradientCenterPoint(void *, const PointF *);
GpStatus WINAPI GdipFillRectangleI(void *, void *, INT, INT, INT, INT);
GpStatus WINAPI GdipBitmapGetPixel(void *, INT, INT, DWORD *);

int main(void)
{
    ULONG_PTR tok; StartupInput si = {1}; void *bmp, *g, *path, *brush; DWORD px;
    DWORD colors[3] = { 0x00ffffff, 0x0a575f7d, 0x1a575f7d };
    float pos[3] = { 0.0f, 0.5f, 1.0f };
    PointF c = { 17.0f, 17.0f };
    int s = GdiplusStartup(&tok, &si, NULL);
    s |= GdipCreateBitmapFromScan0(40, 40, 0, 0x26200a /* PixelFormat32bppARGB */, NULL, &bmp);
    s |= GdipGetImageGraphicsContext(bmp, &g);
    s |= GdipGraphicsClear(g, 0xffb8bec8);
    /* Storyline's top-left scene corner: ellipse of radius 17 centered on the card corner (17,17), fill the 17x17 square outside it */
    s |= GdipCreatePath(0, &path);
    s |= GdipAddPathEllipseI(path, 0, 0, 34, 34);
    s |= GdipCreatePathGradientFromPath(path, &brush);
    s |= GdipSetPathGradientPresetBlend(brush, colors, pos, 3);
    s |= GdipSetPathGradientCenterPoint(brush, &c);
    s |= GdipFillRectangleI(g, brush, 0, 0, 17, 17);
    printf("status %d\n", s);
    for (int y = 0; y <= 16; y += 4)
    {
        for (int x = 0; x <= 16; x += 4) { GdipBitmapGetPixel(bmp, x, y, &px); printf(" %08lx", px); }
        printf("\n");
    }
    return 0;
}

/* Probe: builds the pill path of Storyline's MetroButton, calls GdipClosePathFigures and prints path types before and after flattening/widening; stock Wine leaves the last point without the 0x80 close flag, patch 0014 sets it. Build: x86_64-w64-mingw32-gcc -O1 -o closeprobe.exe closeprobe.c -lgdiplus */
#include <windows.h>
#include <stdio.h>

typedef int GpStatus;
typedef struct { UINT32 v; void *cb; BOOL a, b; } StartupInput;
typedef struct { float X, Y; } PointF;
GpStatus WINAPI GdiplusStartup(ULONG_PTR *, const StartupInput *, void *);
GpStatus WINAPI GdipCreatePath(INT, void **);
GpStatus WINAPI GdipClonePath(void *, void **);
GpStatus WINAPI GdipAddPathArcI(void *, INT, INT, INT, INT, float, float);
GpStatus WINAPI GdipAddPathLineI(void *, INT, INT, INT, INT);
GpStatus WINAPI GdipClosePathFigures(void *);
GpStatus WINAPI GdipFlattenPath(void *, void *, float);
GpStatus WINAPI GdipWidenPath(void *, void *, void *, float);
GpStatus WINAPI GdipGetPointCount(void *, INT *);
GpStatus WINAPI GdipGetPathTypes(void *, BYTE *, INT);
GpStatus WINAPI GdipGetPathPoints(void *, PointF *, INT);
GpStatus WINAPI GdipCreatePen1(DWORD, float, INT, void **);

static void types(const char *title, void *p, int all)
{
    INT n; BYTE t[512]; PointF pt[512];
    GdipGetPointCount(p, &n); GdipGetPathTypes(p, t, n); GdipGetPathPoints(p, pt, n);
    printf("%s: %d points\n", title, n);
    for (int i = 0; i < n; i++)
        if (all || i < 2 || i >= n - 2 || (t[i] & 0x80) || (t[i] & 7) == 0) printf("  %3d type %02x (%.2f, %.2f)\n", i, t[i], pt[i].X, pt[i].Y);
}

int main(void)
{
    ULONG_PTR tok; StartupInput si = {1}; void *p, *f, *pen;
    GdiplusStartup(&tok, &si, NULL);
    GdipCreatePath(0, &p);
    GdipAddPathArcI(p, 0, 0, 34, 35, 90.0f, 180.0f);
    GdipAddPathArcI(p, 61, 0, 34, 35, 270.0f, 180.0f);
    GdipClosePathFigures(p);
    types("pill as built", p, 1);
    GdipClonePath(p, &f); GdipFlattenPath(f, NULL, 0.25f);
    types("pill flattened", f, 0);
    GdipCreatePen1(0xff000000, 1.0f, 2, &pen);
    GdipClonePath(p, &f); GdipWidenPath(f, pen, NULL, 0.25f);
    types("pill widened (1 px pen)", f, 0);
    return 0;
}

/* Probe: shows IDC_WAIT (or IDC_APPSTARTING with argument "app") over a window with the mouse parked on it for 20 s; with WINEDEBUG=trace+cursor, stock winemac sets the Windows hourglass as bitmap frames (cursor_name null), patch 0016 sets cursor_name busyButClickableCursor. Build: x86_64-w64-mingw32-gcc -O1 -mwindows -o waitcursorprobe.exe waitcursorprobe.c */
#include <windows.h>
#include <string.h>

static HCURSOR cursor;

static LRESULT CALLBACK wndproc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp)
{
    if (msg == WM_SETCURSOR) { SetCursor(cursor); return TRUE; }
    if (msg == WM_TIMER || msg == WM_DESTROY) { PostQuitMessage(0); return 0; }
    return DefWindowProcA(hwnd, msg, wp, lp);
}

int WINAPI WinMain(HINSTANCE inst, HINSTANCE prev, LPSTR cmd, int show)
{
    WNDCLASSA wc = {0};
    HWND hwnd;
    MSG msg;

    cursor = LoadCursorA(NULL, strstr(cmd, "app") ? IDC_APPSTARTING : IDC_WAIT);
    wc.lpfnWndProc = wndproc;
    wc.hInstance = inst;
    wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    wc.lpszClassName = "waitcursorprobe";
    RegisterClassA(&wc);
    hwnd = CreateWindowA("waitcursorprobe", "waitcursorprobe", WS_OVERLAPPEDWINDOW | WS_VISIBLE, 200, 200, 400, 300, NULL, NULL, inst, NULL);
    SetForegroundWindow(hwnd);
    SetCursorPos(400, 350);
    SetTimer(hwnd, 1, 20000, NULL);
    while (GetMessageA(&msg, NULL, 0, 0)) { TranslateMessage(&msg); DispatchMessageA(&msg); }
    return 0;
}

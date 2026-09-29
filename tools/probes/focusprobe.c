/* Probe: which window holds keyboard focus in Storyline's UI thread, and the visible/enabled state of every window on the path to it. */
#include <windows.h>
#include <stdio.h>

static DWORD target_pid;
static HWND main_hwnd;

static BOOL CALLBACK find_main( HWND hwnd, LPARAM lp )
{
    DWORD pid; char title[256];
    GetWindowThreadProcessId( hwnd, &pid );
    if (pid != target_pid || !IsWindowVisible( hwnd )) return TRUE;
    GetWindowTextA( hwnd, title, sizeof(title) );
    if (strstr( title, "Storyline" )) { main_hwnd = hwnd; return FALSE; }
    return TRUE;
}

static void describe( const char *label, HWND hwnd )
{
    char cls[128] = "", title[128] = ""; RECT r = {0}; LONG style, ex;
    if (!hwnd) { printf( "%-10s (null)\n", label ); return; }
    GetClassNameA( hwnd, cls, sizeof(cls) );
    GetWindowTextA( hwnd, title, sizeof(title) );
    GetWindowRect( hwnd, &r );
    style = GetWindowLongA( hwnd, GWL_STYLE ); ex = GetWindowLongA( hwnd, GWL_EXSTYLE );
    printf( "%-10s %p style=%08lx ex=%08lx %s%s%s rect=(%ld,%ld)-(%ld,%ld) class=%s title=\"%s\"\n", label, hwnd, style, ex,
            (style & WS_VISIBLE) ? "WS_VISIBLE " : "hidden ", IsWindowVisible( hwnd ) ? "IsWindowVisible " : "notVisibleInChain ",
            IsWindowEnabled( hwnd ) ? "enabled" : "DISABLED", r.left, r.top, r.right, r.bottom, cls, title );
}

int main( int argc, char **argv )
{
    GUITHREADINFO gti = { sizeof(gti) }; DWORD tid; HWND h; int depth = 0;
    if (argc < 2) { printf( "usage: focusprobe <storyline pid> | list\n" ); return 1; }
    if (!strcmp( argv[1], "list" ))
    {
        for (h = GetTopWindow( NULL ); h; h = GetWindow( h, GW_HWNDNEXT ))
        {
            DWORD pid; char title[128] = "";
            GetWindowTextA( h, title, sizeof(title) );
            GetWindowThreadProcessId( h, &pid );
            if (IsWindowVisible( h ) && title[0]) printf( "pid %lu hwnd %p \"%s\"\n", pid, h, title );
        }
        return 0;
    }
    target_pid = strtoul( argv[1], NULL, 0 );
    EnumWindows( find_main, 0 );
    if (!main_hwnd)
    {
        printf( "no visible window titled Storyline for pid %lu; its top-level windows:\n", target_pid );
        for (h = GetTopWindow( NULL ); h; h = GetWindow( h, GW_HWNDNEXT ))
        {
            DWORD pid; GetWindowThreadProcessId( h, &pid );
            if (pid == target_pid) describe( "  top", h );
        }
        return 1;
    }
    tid = GetWindowThreadProcessId( main_hwnd, NULL );
    describe( "main", main_hwnd );
    if (!GetGUIThreadInfo( tid, &gti )) { printf( "GetGUIThreadInfo failed %lu\n", GetLastError() ); return 1; }
    describe( "active", gti.hwndActive );
    describe( "focus", gti.hwndFocus );
    describe( "caret", gti.hwndCaret );
    describe( "capture", gti.hwndCapture );
    printf( "foreground %p\n", GetForegroundWindow() );
    printf( "-- parent chain of focus window\n" );
    for (h = gti.hwndFocus; h && depth < 30; h = GetAncestor( h, GA_PARENT ), depth++) describe( "  parent", h );
    return 0;
}

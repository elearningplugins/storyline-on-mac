/* slauto: drive Storyline's UI from inside the Wine prefix.
 *   slauto list                      - list top-level windows (hwnd, class, title)
 *   slauto wait  <title-substr> [s]  - wait until a window with that title exists
 *   slauto focus <title-substr>      - bring the window to the foreground
 *   slauto keys  <text>              - type text; {ENTER} {ESC} {TAB} {CTRL+x} {ALT+x} {F1..} {WAIT:ms}
 *   slauto click <x> <y>             - click at screen coordinates
 *   slauto clickw <title-substr> <x> <y> - click at client coordinates of that window
 */
#include <windows.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

static char g_title[512]; static HWND g_found;
static BOOL CALLBACK enum_find(HWND h, LPARAM lp)
{
    char t[512];
    if (!IsWindowVisible(h)) return TRUE;
    GetWindowTextA(h, t, sizeof(t));
    if (t[0] && strstr(t, g_title)) { g_found = h; return FALSE; }
    return TRUE;
}
static BOOL CALLBACK enum_list(HWND h, LPARAM lp)
{
    char t[256], c[128]; RECT r;
    if (!IsWindowVisible(h)) return TRUE;
    GetWindowTextA(h, t, sizeof(t)); GetClassNameA(h, c, sizeof(c)); GetWindowRect(h, &r);
    if (t[0]) printf("%p  [%ld,%ld %ldx%ld]  %-40.40s  %s\n", h, r.left, r.top, r.right-r.left, r.bottom-r.top, c, t);
    return TRUE;
}
static HWND find(const char *s) { strncpy(g_title, s, sizeof(g_title)-1); g_found = NULL; EnumWindows(enum_find, 0); return g_found; }
static void key(WORD vk, BOOL down)
{
    INPUT in = {0}; in.type = INPUT_KEYBOARD; in.ki.wVk = vk; in.ki.dwFlags = down ? 0 : KEYEVENTF_KEYUP; SendInput(1, &in, sizeof(in));
}
static void tap(WORD vk) { key(vk, TRUE); Sleep(30); key(vk, FALSE); Sleep(30); }
static WORD vk_of(const char *name)
{
    if (!strcmp(name,"ENTER")) return VK_RETURN; if (!strcmp(name,"ESC")) return VK_ESCAPE; if (!strcmp(name,"TAB")) return VK_TAB;
    if (!strcmp(name,"DEL")) return VK_DELETE; if (!strcmp(name,"HOME")) return VK_HOME; if (!strcmp(name,"END")) return VK_END;
    if (name[0]=='F' && atoi(name+1)) return VK_F1 + atoi(name+1) - 1;
    if (strlen(name)==1) return (WORD)VkKeyScanA(name[0]) & 0xff;
    return 0;
}
static void type_text(const char *s)
{
    while (*s)
    {
        if (*s == '{')
        {
            char tok[64]; const char *e = strchr(s, '}'); if (!e) break;
            snprintf(tok, sizeof(tok), "%.*s", (int)(e - s - 1), s + 1); s = e + 1;
            if (!strncmp(tok, "WAIT:", 5)) { Sleep(atoi(tok + 5)); continue; }
            if (!strncmp(tok, "CTRL+", 5)) { key(VK_CONTROL, TRUE); tap(vk_of(tok + 5)); key(VK_CONTROL, FALSE); continue; }
            if (!strncmp(tok, "ALT+", 4))  { key(VK_MENU, TRUE); tap(vk_of(tok + 4)); key(VK_MENU, FALSE); continue; }
            tap(vk_of(tok)); continue;
        }
        INPUT in[2] = {0}; in[0].type = in[1].type = INPUT_KEYBOARD;
        in[0].ki.wScan = in[1].ki.wScan = (WORD)*s; in[0].ki.dwFlags = KEYEVENTF_UNICODE; in[1].ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;
        SendInput(2, in, sizeof(INPUT)); Sleep(25); s++;
    }
}
static void click_at(int x, int y)
{
    SetCursorPos(x, y); Sleep(60);
    INPUT in[2] = {0}; in[0].type = in[1].type = INPUT_MOUSE; in[0].mi.dwFlags = MOUSEEVENTF_LEFTDOWN; in[1].mi.dwFlags = MOUSEEVENTF_LEFTUP;
    SendInput(1, &in[0], sizeof(INPUT)); Sleep(40); SendInput(1, &in[1], sizeof(INPUT));
}
/* Foreground rules block SetForegroundWindow from another process; attach to the
 * target's input thread first, and simulate a key tap so the system counts us as
 * the last input source. */
static void force_foreground(HWND h)
{
    DWORD target = GetWindowThreadProcessId(h, NULL), self = GetCurrentThreadId();
    key(VK_MENU, TRUE); key(VK_MENU, FALSE);
    AttachThreadInput(self, target, TRUE);
    SetForegroundWindow(h); SetActiveWindow(h); SetFocus(h);
    AttachThreadInput(self, target, FALSE);
    Sleep(300);
}
int main(int argc, char **argv)
{
    if (argc < 2) { puts("usage: slauto list|wait|focus|keys|click|clickw ..."); return 2; }
    if (!strcmp(argv[1], "list")) { EnumWindows(enum_list, 0); return 0; }
    if (!strcmp(argv[1], "wait") && argc >= 3)
    {
        int secs = argc >= 4 ? atoi(argv[3]) : 120; HWND h;
        for (int i = 0; i < secs * 4; i++) { if ((h = find(argv[2]))) { printf("%p\n", h); return 0; } Sleep(250); }
        puts("timeout"); return 1;
    }
    if (!strcmp(argv[1], "focus") && argc >= 3)
    {
        HWND h = find(argv[2]); if (!h) { puts("not found"); return 1; }
        force_foreground(h); return 0;
    }
    if (!strcmp(argv[1], "keys") && argc >= 3) { type_text(argv[2]); return 0; }
    if (!strcmp(argv[1], "click") && argc >= 4) { click_at(atoi(argv[2]), atoi(argv[3])); return 0; }
    if (!strcmp(argv[1], "clickw") && argc >= 5)
    {
        HWND h = find(argv[2]); if (!h) { puts("not found"); return 1; }
        POINT p = { atoi(argv[3]), atoi(argv[4]) }; ClientToScreen(h, &p); force_foreground(h); click_at(p.x, p.y); return 0;
    }
    puts("bad args"); return 2;
}

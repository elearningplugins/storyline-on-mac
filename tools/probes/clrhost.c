/* Minimal native CLR host: mirrors what WiX mbahost / DTF SFXCA do before creating an AppDomain. */
#define COBJMACROS
#include <windows.h>
#include <stdio.h>
#include <metahost.h>

int main(void)
{
    HRESULT hr; ICLRMetaHost *mh = NULL; ICLRRuntimeInfo *ri = NULL; ICorRuntimeHost *host = NULL; IUnknown *dom = NULL;
    HMODULE m = LoadLibraryA("mscoree.dll");
    printf("mscoree.dll = %p\n", m);
    HRESULT (WINAPI *pCLRCreateInstance)(REFCLSID, REFIID, LPVOID*) = (void*)GetProcAddress(m, "CLRCreateInstance");
    hr = pCLRCreateInstance(&CLSID_CLRMetaHost, &IID_ICLRMetaHost, (void**)&mh);
    printf("CLRCreateInstance -> 0x%08lx\n", hr); if (FAILED(hr)) return 1;
    hr = ICLRMetaHost_GetRuntime(mh, L"v4.0.30319", &IID_ICLRRuntimeInfo, (void**)&ri);
    printf("GetRuntime(v4.0.30319) -> 0x%08lx\n", hr); if (FAILED(hr)) return 1;
    BOOL loadable = FALSE; hr = ICLRRuntimeInfo_IsLoadable(ri, &loadable);
    printf("IsLoadable -> 0x%08lx loadable=%d\n", hr, loadable);
    WCHAR ver[64]; DWORD n = 64; ICLRRuntimeInfo_GetVersionString(ri, ver, &n); wprintf(L"runtime version %s\n", ver);
    hr = ICLRRuntimeInfo_GetInterface(ri, &CLSID_CorRuntimeHost, &IID_ICorRuntimeHost, (void**)&host);
    printf("GetInterface(CorRuntimeHost) -> 0x%08lx\n", hr); if (FAILED(hr)) return 1;
    hr = ICorRuntimeHost_Start(host);
    printf("ICorRuntimeHost::Start -> 0x%08lx\n", hr); if (FAILED(hr)) return 1;
    hr = ICorRuntimeHost_GetDefaultDomain(host, &dom);
    printf("GetDefaultDomain -> 0x%08lx\n", hr);
    hr = ICorRuntimeHost_CreateDomain(host, L"probe", NULL, &dom);
    printf("CreateDomain -> 0x%08lx\n", hr);
    return 0;
}

/* Probe: can wined3d create D3D11 / D3D10.1 devices, and which feature level? */
#define COBJMACROS
#include <windows.h>
#include <stdio.h>
#include <d3d11.h>
#include <d3d10_1.h>
typedef HRESULT (WINAPI *PFN_D3D10CreateDevice1)(IDXGIAdapter*,D3D10_DRIVER_TYPE,HMODULE,UINT,D3D10_FEATURE_LEVEL1,UINT,ID3D10Device1**);
int main(void)
{
    static const D3D_FEATURE_LEVEL fls[] = { D3D_FEATURE_LEVEL_11_1, D3D_FEATURE_LEVEL_11_0, D3D_FEATURE_LEVEL_10_1, D3D_FEATURE_LEVEL_10_0, D3D_FEATURE_LEVEL_9_3 };
    ID3D11Device *dev = NULL; D3D_FEATURE_LEVEL got = 0; HRESULT hr;
    hr = D3D11CreateDevice(NULL, D3D_DRIVER_TYPE_HARDWARE, NULL, D3D11_CREATE_DEVICE_BGRA_SUPPORT, fls, 5, D3D11_SDK_VERSION, &dev, &got, NULL);
    printf("D3D11CreateDevice(HARDWARE, BGRA) -> 0x%08lx level 0x%x\n", hr, got);
    if (dev) ID3D11Device_Release(dev); dev = NULL;
    hr = D3D11CreateDevice(NULL, D3D_DRIVER_TYPE_HARDWARE, NULL, 0, NULL, 0, D3D11_SDK_VERSION, &dev, &got, NULL);
    printf("D3D11CreateDevice(HARDWARE, default) -> 0x%08lx level 0x%x\n", hr, got);
    if (dev) ID3D11Device_Release(dev);
    ID3D10Device1 *d10 = NULL;
    PFN_D3D10CreateDevice1 pD3D10CreateDevice1 = (PFN_D3D10CreateDevice1)GetProcAddress(LoadLibraryA("d3d10_1.dll"), "D3D10CreateDevice1");
    hr = pD3D10CreateDevice1(NULL, D3D10_DRIVER_TYPE_HARDWARE, NULL, D3D10_CREATE_DEVICE_BGRA_SUPPORT, D3D10_FEATURE_LEVEL_10_1, D3D10_1_SDK_VERSION, &d10);
    printf("D3D10CreateDevice1(10_1, BGRA) -> 0x%08lx\n", hr);
    if (d10) ID3D10Device1_Release(d10); d10 = NULL;
    hr = pD3D10CreateDevice1(NULL, D3D10_DRIVER_TYPE_HARDWARE, NULL, 0, D3D10_FEATURE_LEVEL_10_0, D3D10_1_SDK_VERSION, &d10);
    printf("D3D10CreateDevice1(10_0) -> 0x%08lx\n", hr);
    if (d10) ID3D10Device1_Release(d10);
    return 0;
}

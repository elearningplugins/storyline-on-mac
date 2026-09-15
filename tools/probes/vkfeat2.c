
#include <windows.h>
#include <stdio.h>
#include <stdint.h>
typedef struct { uint32_t sType; uint32_t pad; const void *pNext; uint32_t flags; uint32_t pad2; const void *pApplicationInfo; uint32_t enabledLayerCount; uint32_t pad3; const char *const *ppEnabledLayerNames; uint32_t enabledExtensionCount; uint32_t pad4; const char *const *ppEnabledExtensionNames; } VkInstanceCreateInfo;
typedef struct { uint32_t sType; uint32_t pad; void *pNext; uint32_t f[55]; } VkPhysicalDeviceFeatures2;
typedef struct { uint32_t sType; uint32_t pad; void *pNext; uint32_t shaderDrawParameters; } DrawParams;
typedef struct { uint32_t sType; uint32_t pad; void *pNext; uint32_t divisor, zeroDivisor; } Divisor;
typedef struct { uint32_t apiVersion, driverVersion, vendorID, deviceID, deviceType; char deviceName[256]; uint8_t rest[4096]; } Props;
typedef void *(__stdcall *GIPA)(void *, const char *);
int main(void)
{
    HMODULE h = LoadLibraryA("vulkan-1.dll"); if (!h) { puts("no vulkan-1.dll"); return 1; }
    GIPA gipa = (GIPA)GetProcAddress(h, "vkGetInstanceProcAddr");
    int (__stdcall *vkCreateInstance)(const VkInstanceCreateInfo *, void *, void **) = (void *)gipa(NULL, "vkCreateInstance");
    VkInstanceCreateInfo ici = { 1 }; void *inst = NULL;
    int r = vkCreateInstance(&ici, NULL, &inst); if (r) { printf("vkCreateInstance -> %d\n", r); return 1; }
    int (__stdcall *enumPD)(void *, uint32_t *, void **) = (void *)gipa(inst, "vkEnumeratePhysicalDevices");
    void (__stdcall *getF2)(void *, VkPhysicalDeviceFeatures2 *) = (void *)gipa(inst, "vkGetPhysicalDeviceFeatures2");
    void (__stdcall *getP)(void *, Props *) = (void *)gipa(inst, "vkGetPhysicalDeviceProperties");
    if (!getF2) getF2 = (void *)gipa(inst, "vkGetPhysicalDeviceFeatures2KHR");
    uint32_t n = 4; void *pd[4]; enumPD(inst, &n, pd); if (!n) { puts("no devices"); return 1; }
    static Props p; getP(pd[0], &p); printf("device: %s (vendor %04x, api %u.%u)\n", p.deviceName, p.vendorID, p.apiVersion>>22, (p.apiVersion>>12)&0x3ff);
    Divisor dv = { 1000190002 }; DrawParams dp = { 1000063000, 0, &dv }; VkPhysicalDeviceFeatures2 f2 = { 1000059000, 0, &dp };
    getF2(pd[0], &f2);
    printf("  %-34s %u\n", "multiViewport", f2.f[18]);
    printf("  %-34s %u\n", "geometryShader", f2.f[4]);
    printf("  %-34s %u\n", "depthClamp", f2.f[11]);
    printf("  %-34s %u\n", "depthBiasClamp", f2.f[12]);
    printf("  %-34s %u\n", "pipelineStatisticsQuery", f2.f[24]);
    printf("  %-34s %u\n", "shaderClipDistance", f2.f[37]);
    printf("  %-34s %u\n", "shaderCullDistance", f2.f[38]);
    printf("  %-34s %u\n", "imageCubeArray", f2.f[2]);
    printf("  %-34s %u\n", "multiDrawIndirect", f2.f[9]);
    printf("  %-34s %u\n", "drawIndirectFirstInstance", f2.f[10]);
    printf("  %-34s %u\n", "fragmentStoresAndAtomics", f2.f[26]);
    printf("  %-34s %u\n", "shaderImageGatherExtended", f2.f[28]);
    printf("  %-34s %u\n", "tessellationShader", f2.f[5]);
    printf("  %-34s %u\n", "vertexPipelineStoresAndAtomics", f2.f[25]);
    printf("  %-34s %u\n", "independentBlend", f2.f[3]);
    printf("  %-34s %u\n", "occlusionQueryPrecise", f2.f[23]);
    printf("  %-34s %u\n", "shaderDrawParameters", dp.shaderDrawParameters);
    printf("  %-34s %u / %u\n", "vertexAttribDivisor/Zero", dv.divisor, dv.zeroDivisor);
    return 0;
}

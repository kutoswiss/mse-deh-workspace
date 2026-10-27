#include <stdio.h>
#include <platform.h>
#include <spr.h>
#include <ov7670.h>
#include <perf.h>
#include <swap.h>

#include "CRC.h"
#include "crc_dma.h"

#define DISPLAY_FRAMEBUFFER (*(volatile uint32_t *)0x5000002Cu)
#define IMAGE_WIDTH 320u
#define IMAGE_HEIGHT 240u

// #define CRC32_SW_TEST
// #define CRC32_HW_TEST

// #define CRC32_SW_CAM_TEST
//  #define CRC32_HW_CAM_TEST
#define CRC32_HW_DMA_CAM_TEST

static volatile uint16_t framebuffer[IMAGE_WIDTH * IMAGE_HEIGHT];

int main(void)
{
    camParameters camera_parameters;
    uint32_t clock_hz;
    uint32_t crc32;
    uint32_t crc32_wc;
    uint32_t crc32_cycles;

    platform_init();
    perf_init();

    printf("CRC32 test starting!\n");

    clock_hz = perf_get_clock_frequency_hz();
    printf("Performance-counter clock: %u Hz\n", clock_hz);

#if defined(CRC32_SW_CAM_TEST) || defined(CRC32_HW_CAM_TEST) || defined(CRC32_HW_DMA_CAM_TEST)
    printf("Initialising the 320x240 camera...\n");
    initOv7670(QVGA, &camera_parameters);
    DISPLAY_FRAMEBUFFER = swap_u32((uint32_t)&framebuffer[0]);

    printf("Camera: %u x %u pixels\n",
           camera_parameters.nrOfPixelsPerLine,
           camera_parameters.nrOfLinesPerImage);
#endif

#ifdef CRC32_SW_CAM_TEST
    for (;;)
    {
        takeSingleImageBlocking((uint32_t)&framebuffer[0]);

        perf_start();
        crc32 = crc32_software((volatile uint8_t *)framebuffer, IMAGE_WIDTH * IMAGE_HEIGHT * 2);
        crc32_cycles = perf_finish();

        printf("CRC32 SW: %u cycles (%u.%03u ms)\n",
               crc32_cycles,
               crc32_cycles / (clock_hz / 1000u),
               ((crc32_cycles % (clock_hz / 1000u)) * 1000u) / (clock_hz / 1000u));
    }
#endif

#ifdef CRC32_HW_CAM_TEST
    for (;;)
    {
        takeSingleImageBlocking((uint32_t)&framebuffer[0]);

        perf_start();
        crc32 = CRC_compute((volatile uint8_t *)framebuffer, IMAGE_WIDTH * IMAGE_HEIGHT * 2);
        crc32_cycles = perf_finish();

        printf("CRC32 HW: %u cycles (%u.%03u ms)\n",
               crc32_cycles,
               crc32_cycles / (clock_hz / 1000u),
               ((crc32_cycles % (clock_hz / 1000u)) * 1000u) / (clock_hz / 1000u));
    }
#endif

#ifdef CRC32_HW_DMA_CAM_TEST
    for (;;)
    {
        takeSingleImageBlocking((uint32_t)&framebuffer[0]);

        perf_start();

        crc_dma_start((uint32_t)&framebuffer[0], IMAGE_WIDTH * IMAGE_HEIGHT * 2);
        crc_dma_wait_until_done();

        crc32 = crc_dma_get_result();
        crc32_cycles = perf_finish();

        printf("CRC32 HW DMA: %u cycles (%u.%03u ms)\n",
               crc32_cycles,
               crc32_cycles / (clock_hz / 1000u),
               ((crc32_cycles % (clock_hz / 1000u)) * 1000u) / (clock_hz / 1000u));
    }
#endif

#ifdef CRC32_SW_TEST
    const uint8_t test[] = "12345678";
    const uint32_t crc32_expected = 0x9AE0DAAF;

    perf_start();
    const uint32_t crc32_sw = crc32_software(test, sizeof(test) - 1);
    const uint32_t crc32_sw_cycles = perf_finish();
    const uint32_t crc32_sw_ms = (1000 * crc32_sw_cycles) / clock_hz;

    if (crc32_sw != crc32_expected)
    {
        printf("FAIL: crc32_software calculation failed. (actual:%08x, expected:%08x)\n",
               crc32_sw,
               crc32_expected);
        return 1;
    }

    printf("PASS: crc32_software (cycles: %d, time: %d ms)\n",
           crc32_sw_cycles,
           crc32_sw_ms);
#endif

#ifdef CRC32_HW_TEST
    const uint8_t test[] = "12345678";
    const uint32_t crc32_expected = 0x9AE0DAAF;

    perf_start();
    crc32 = CRC_compute(test, sizeof(test) - 1);
    crc32_cycles = perf_finish();
    crc32_wc = crc_get_word_count();

    if (crc32 != crc32_expected)
    {
        printf("FAIL: crc_compute calculation failed. (actual:%08x, expected:%08x)\n",
               crc32,
               crc32_expected);
        return 1;
    }

    if (crc32_wc != 2)
    {
        printf("FAIL: crc_compute word count failed. (actual:%08x, expected:%08x)\n",
               crc32_wc,
               2);
        return 1;
    }

    printf("PASS: crc_compute (cycles: %d, time: %d ms, wc: %d)\n",
           crc32_cycles,
           (1000 * crc32_cycles) / clock_hz,
           crc32_wc);
#endif

    return 0;
}

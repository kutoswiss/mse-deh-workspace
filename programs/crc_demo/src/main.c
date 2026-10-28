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

static volatile uint16_t framebuffer[IMAGE_WIDTH * IMAGE_HEIGHT];

void camera_init(void);

void crc32_sw_single_word_test(void);
void crc32_slave_single_word_test(void);
void crc32_all_camera_test(void);

void crc32_sw_camera_performance_test(void);
void crc32_slave_camera_performance_test(void);
void crc32_dma_camera_performance_test(void);

void main(void)
{
    platform_init();
    perf_init();

    // crc32_sw_single_word_test();
    // crc32_slave_single_word_test();
    // crc32_all_camera_test();

    // crc32_sw_camera_performance_test();
    // crc32_slave_camera_performance_test();
    crc32_dma_camera_performance_test();

    return;
}

void camera_init(void)
{
    camParameters camera_parameters;

    printf("Initialising the 320x240 camera...\n");
    initOv7670(QVGA, &camera_parameters);
    DISPLAY_FRAMEBUFFER = swap_u32((uint32_t)&framebuffer[0]);

    printf("Camera: %u x %u pixels\n",
           camera_parameters.nrOfPixelsPerLine,
           camera_parameters.nrOfLinesPerImage);
}

void crc32_sw_single_word_test()
{
    printf("crc32_sw_single_word_test starting!\n");

    const uint8_t test[] = "12345678";
    const uint32_t crc32_expected = 0x9AE0DAAF;

    const uint32_t clock_hz = perf_get_clock_frequency_hz();
    printf("Performance-counter clock: %u Hz\n", clock_hz);

    perf_start();
    const uint32_t crc32 = crc32_software(test, sizeof(test) - 1);
    const uint32_t crc32_cycles = perf_finish();
    const uint32_t crc32_ms = (1000 * crc32_cycles) / clock_hz;

    if (crc32 != crc32_expected)
    {
        printf("FAIL: crc32_software calculation failed. (actual:%08x, expected:%08x)\n",
               crc32,
               crc32_expected);
        return;
    }

    printf("PASS: crc32_software (cycles: %d, time: %d ms)\n",
           crc32_cycles,
           crc32_ms);
}

void crc32_slave_single_word_test()
{
    printf("crc32_slave_single_word_test starting!\n");

    const uint8_t test[] = "12345678";
    const uint32_t crc32_expected = 0x9AE0DAAF;

    const uint32_t clock_hz = perf_get_clock_frequency_hz();
    printf("Performance-counter clock: %u Hz\n", clock_hz);

    perf_start();
    const uint32_t crc32 = CRC_compute(test, sizeof(test) - 1);
    const uint32_t crc32_cycles = perf_finish();
    const uint32_t crc32_wc = crc_get_word_count();

    if (crc32 != crc32_expected)
    {
        printf("FAIL: crc_compute calculation failed. (actual:%08x, expected:%08x)\n",
               crc32,
               crc32_expected);
        return;
    }

    if (crc32_wc != 2)
    {
        printf("FAIL: crc_compute word count failed. (actual:%08x, expected:%08x)\n",
               crc32_wc,
               2);
        return;
    }

    printf("PASS: crc_compute (cycles: %d, time: %d ms, wc: %d)\n",
           crc32_cycles,
           (1000 * crc32_cycles) / clock_hz,
           crc32_wc);
}

void crc32_all_camera_test(void)
{
    printf("crc32_all_camera_test starting!\n");

    uint32_t crc32;
    uint32_t crc32_cycles;

    const uint32_t clock_hz = perf_get_clock_frequency_hz();
    printf("Performance-counter clock: %u Hz\n", clock_hz);

    camera_init();

    for (;;)
    {
        takeSingleImageBlocking((uint32_t)&framebuffer[0]);

        uint32_t crc32_sw = crc32_software((volatile uint8_t *)framebuffer, IMAGE_WIDTH * IMAGE_HEIGHT * 2);
        printf("CRC32 SW: %08x\n", crc32_sw);

        uint32_t crc32_slave = CRC_compute((volatile uint8_t *)framebuffer, IMAGE_WIDTH * IMAGE_HEIGHT * 2);
        printf("CRC32 SLAVE: %08x\n", crc32_slave);

        crc_dma_start((uint32_t)&framebuffer[0], IMAGE_WIDTH * IMAGE_HEIGHT * 2);
        crc_dma_wait_until_done();
        uint32_t crc32_dma = crc_dma_get_result();
        printf("CRC32 DMA: %08x\n", crc32_dma);

        if (crc32_sw != crc32_slave && crc32_sw != crc32_dma)
        {
            printf("FAIL: crc32 calculation failed.\n");
            return;
        }

        printf("PASS: crc32 calculation succeed.\n");
    }
}

void crc32_sw_camera_performance_test()
{
    printf("crc32_sw_camera_performance_test starting!\n");

    uint32_t crc32;
    uint32_t crc32_cycles;

    const uint32_t clock_hz = perf_get_clock_frequency_hz();
    printf("Performance-counter clock: %u Hz\n", clock_hz);

    camera_init();

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
}

void crc32_slave_camera_performance_test()
{
    printf("crc32_slave_camera_performance_test starting!\n");

    uint32_t crc32;
    uint32_t crc32_cycles;

    const uint32_t clock_hz = perf_get_clock_frequency_hz();
    printf("Performance-counter clock: %u Hz\n", clock_hz);

    camera_init();

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
}

void crc32_dma_camera_performance_test(void)
{
    printf("crc32_dma_camera_performance_test starting!\n");

    uint32_t crc32;
    uint32_t crc32_cycles;

    const uint32_t clock_hz = perf_get_clock_frequency_hz();
    printf("Performance-counter clock: %u Hz\n", clock_hz);

    camera_init();

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
}

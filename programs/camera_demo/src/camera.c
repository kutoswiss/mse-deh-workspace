#include <stdint.h>
#include <stdio.h>
#include <ov7670.h>
#include <perf.h>
#include <platform.h>
#include <swap.h>

#define DISPLAY_FRAMEBUFFER (*(volatile uint32_t *)0x5000002Cu)
#define IMAGE_WIDTH  320u
#define IMAGE_HEIGHT 240u

static volatile uint16_t framebuffer[IMAGE_WIDTH * IMAGE_HEIGHT];

int main(void)
{
    camParameters cameraParameters;
    uint32_t cycles;
    uint32_t clockHz;

    platform_init();
    perf_init();

    printf("Initialising the 320x240 camera...\n");
    initOv7670(QVGA, &cameraParameters);
    DISPLAY_FRAMEBUFFER = swap_u32((uint32_t)&framebuffer[0]);
    clockHz = perf_get_clock_frequency_hz();

    printf("Camera: %u x %u pixels\n",
           cameraParameters.nrOfPixelsPerLine,
           cameraParameters.nrOfLinesPerImage);
    printf("Performance-counter clock: %u Hz\n", clockHz);

    for (;;) {
        perf_start();
        takeSingleImageBlocking((uint32_t)&framebuffer[0]);
        cycles = perf_finish();

        printf("Camera DMA: %u cycles (%u.%03u ms)\n",
               cycles,
               cycles / (clockHz / 1000u),
               ((cycles % (clockHz / 1000u)) * 1000u) /
                   (clockHz / 1000u));
    }
}

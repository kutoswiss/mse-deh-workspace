/* HEPIA CoRES - GPIO exercise. MMIO words require byte swapping. */
#include <stdint.h>
#include <stdio.h>
#include <platform.h>
#include <swap.h>
#include <delay.h>

#define GPIO_BASE 0x50000100u
#define LED_MASK 0x3FFFFFFFu
enum
{
    RegDIR = 0,
    RegPIN = 1,
    RegPORT = 2,
    RegSET = 3,
    RegCLR = 4
};
static volatile uint32_t *const gpio = (volatile uint32_t *)GPIO_BASE;

static void gpio_write(unsigned reg, uint32_t value)
{
    gpio[reg] = swap_u32(value);
}

static uint32_t gpio_read(unsigned reg)
{
    return swap_u32(gpio[reg]);
}

int main(void)
{
    platform_init();
    printf("GPIO test starting\n");
    gpio_write(RegPORT, 0u);      /* Logical 0 = LED off. */
    gpio_write(RegDIR, LED_MASK); /* 30 LED channels, 2 unused channels. */
    printf("RegDIR = %08x\n", (unsigned)gpio_read(RegDIR));
    if (gpio_read(RegDIR) != LED_MASK)
    {
        printf("FAIL: direction register\n");
        return 1;
    }

    const uint32_t tests[] = {0u, 0xFFFFFFFFu, 0x55555555u, 0xAAAAAAAAu};
    for (unsigned i = 0; i < sizeof(tests) / sizeof(tests[0]); ++i)
    {
        gpio_write(RegPORT, tests[i]);
        uint32_t got = gpio_read(RegPORT);
        if (got != tests[i])
        {
            printf("FAIL: wrote %08x, read %08x\n",
                   (unsigned)tests[i], (unsigned)got);
            return 1;
        }
    }
    gpio_write(RegPORT, 0x80000001u);
    gpio_write(RegSET, 0x40000002u); /* Preserve existing bits. */
    gpio_write(RegCLR, 0x80000001u); /* Clear only the mask bits. */
    if (gpio_read(RegPORT) != 0x40000002u)
    {
        printf("FAIL: RegSET / RegCLR\n");
        return 1;
    }
    printf("32-bit register and SET/CLR tests: PASS\n");

    for (;;)
    {
        for (unsigned bit = 0; bit < 30; ++bit)
        {
            uint32_t pattern = 1u << bit;
            gpio_write(RegPORT, pattern);
            delay_blocking_usec(200000u); /* Observation delay, not profiling. */
            printf("bit %u: PORT=%08x PIN=%08x\n", bit,
                   (unsigned)gpio_read(RegPORT), (unsigned)gpio_read(RegPIN));
        }
    }
}

#include <perf.h>
#include <platform.h>
#include <swap.h>

#define PERF_REG_CONTROL   0u
#define PERF_REG_STATUS    1u
#define PERF_REG_COUNTER   2u
#define PERF_REG_CAPTURE   3u
#define PERF_REG_CLOCK_HZ  4u

#define PERF_CMD_START     (1u << 0)
#define PERF_CMD_STOP      (1u << 1)
#define PERF_CMD_CLEAR     (1u << 2)
#define PERF_CMD_CAPTURE   (1u << 3)

static volatile uint32_t *const perf =
    (volatile uint32_t *)PERF_BASE;

static inline void perf_register_write(unsigned int reg, uint32_t value)
{
    perf[reg] = swap_u32(value);
}

static inline uint32_t perf_register_read(unsigned int reg)
{
    return swap_u32(perf[reg]);
}

void perf_init(void)
{
    perf_clear();
}

void perf_start(void)
{
    perf_register_write(PERF_REG_CONTROL, PERF_CMD_START);
}

void perf_stop(void)
{
    perf_register_write(PERF_REG_CONTROL, PERF_CMD_STOP);
}

void perf_clear(void)
{
    perf_register_write(PERF_REG_CONTROL, PERF_CMD_CLEAR);
}

void perf_capture(void)
{
    perf_register_write(PERF_REG_CONTROL, PERF_CMD_CAPTURE);
}

uint32_t perf_get_status(void)
{
    return perf_register_read(PERF_REG_STATUS);
}

uint32_t perf_get_counter(void)
{
    return perf_register_read(PERF_REG_COUNTER);
}

uint32_t perf_get_capture(void)
{
    return perf_register_read(PERF_REG_CAPTURE);
}

uint32_t perf_get_clock_frequency_hz(void)
{
    return perf_register_read(PERF_REG_CLOCK_HZ);
}

perf_cycles_t perf_read_counter(unsigned int counter_id)
{
    (void)counter_id;
    return (perf_cycles_t)perf_get_capture();
}

uint32_t perf_finish(void)
{
    perf_stop();
    return perf_get_capture();
}

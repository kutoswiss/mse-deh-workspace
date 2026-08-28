#ifndef PERF_H_INCLUDED
#define PERF_H_INCLUDED

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define PERF_STATUS_RUNNING  (1u << 0)
#define PERF_STATUS_OVERFLOW (1u << 1)

typedef uint64_t perf_cycles_t;

/* Compatibility identifier for code previously using the SPR profiler. */
#define PERF_COUNTER_RUNTIME 0u

/* Initialize the MM timer to its stopped, cleared state. */
void perf_init(void);
void perf_start(void);
void perf_stop(void);
void perf_clear(void);
void perf_capture(void);

uint32_t perf_get_status(void);
uint32_t perf_get_counter(void);
uint32_t perf_get_capture(void);
uint32_t perf_get_clock_frequency_hz(void);

/* Compatibility wrapper. This MM implementation has one runtime counter. */
perf_cycles_t perf_read_counter(unsigned int counter_id);

/* Stop the timer and return its captured elapsed-cycle count. */
uint32_t perf_finish(void);

#ifdef __cplusplus
}
#endif

#endif /* PERF_H_INCLUDED */

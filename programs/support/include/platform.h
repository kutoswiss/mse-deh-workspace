#ifndef PLATFORM_H_INCLUDED
#define PLATFORM_H_INCLUDED

#ifdef __cplusplus
extern "C" {
#endif

#define UART_BASE 0x50000000
#define PERF_BASE 0x50000120

void platform_init();

#ifdef __cplusplus
}
#endif

#endif /* PLATFORM_H_INCLUDED */

#include "crc_dma.h"
#include <swap.h>
#include <delay.h>

#define CRC_DMA_BASE 0x50000160u

#define CRC_DMA_REG_CONTROL 0u
#define CRC_DMA_REG_SOURCE 1u
#define CRC_DMA_REG_LENGTH 2u
#define CRC_DMA_REG_STATUS 3u
#define CRC_DMA_REG_CRC 4u
#define CRC_DMA_REG_IRQ_CONTROL 5u

#define CRC_DMA_CONTROL_START 1u
#define CRC_DMA_STATUS_BUSY 0b01
#define CRC_DMA_STATUS_DONE 0b10
#define CRC_DMA_POLLING_DELAY_US 10 // 10 us

static volatile uint32_t *const crcDmaRegisters = (volatile uint32_t *)CRC_DMA_BASE;

/*
 * Write one CRC register.
 *
 * swap_u32() is required because the processor and the
 * memory-mapped bus use different byte orders.
 */
static inline void crc_dma_register_write(uint32_t registerIndex, uint32_t value)
{
    crcDmaRegisters[registerIndex] = swap_u32(value);
}

/*
 * Read one CRC register.
 */
static inline uint32_t crc_dma_register_read(uint32_t registerIndex)
{
    return swap_u32(crcDmaRegisters[registerIndex]);
}

void crc_dma_start(uint32_t address, uint32_t length)
{
    crc_dma_register_write(CRC_DMA_REG_SOURCE, address);
    crc_dma_register_write(CRC_DMA_REG_LENGTH, length);
    crc_dma_register_write(CRC_DMA_REG_CONTROL, CRC_DMA_CONTROL_START);
}

void crc_dma_wait_until_done(void)
{
    while (crc_dma_register_read(CRC_DMA_REG_STATUS) != CRC_DMA_STATUS_DONE)
        delay_blocking_usec(CRC_DMA_POLLING_DELAY_US);
}

uint32_t crc_dma_get_result(void)
{
    return crc_dma_register_read(CRC_DMA_REG_CRC);
}
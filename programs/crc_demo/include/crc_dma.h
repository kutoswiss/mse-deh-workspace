#ifndef CRC_DMA_H
#define CRC_DMA_H

#include <stdint.h>

#ifdef __cplusplus
extern "C"
{
#endif

    void crc_dma_start(uint32_t address, uint32_t length);
    void crc_dma_wait_until_done(void);
    uint32_t crc_dma_get_result(void);

#ifdef __cplusplus
}
#endif

#endif

#ifndef COURSE_CRC_H
#define COURSE_CRC_H
#include <stdint.h>
#ifdef __cplusplus
extern "C"
{
#endif

    /* Software reference: arbitrary byte count; does not access the peripheral. */
    uint32_t crc32_software(const volatile uint8_t *data, uint32_t length);

    /* Slave MM driver: only call after integrating the hardware at 0x50000140. */
    void crc_restart(void);
    void crc_write_word(uint32_t dataWord);
    uint32_t crc_get_result(void);
    uint32_t crc_get_word_count(void);

    /* Restart, send words, read result. Size must be a multiple of four bytes.
     * Invalid size or NULL with nonzero size returns 0 without hardware access.
     * Zero can also be a valid CRC: validate preconditions before calling.
     * The buffer must remain unchanged throughout the computation.
     */
    uint32_t CRC_compute(const volatile void *data, uint32_t sizeBytes);

#ifdef __cplusplus
}
#endif
#endif
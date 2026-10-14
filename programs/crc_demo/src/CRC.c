#include "CRC.h"
#ifndef CRC_SOFTWARE_ONLY
#include <swap.h>
#endif

////////////////////   SOFTWARE ///////////////////

/*
 * Compute the standard CRC-32 of a byte array.
 *
 * CRC parameters:
 *
 *   Polynomial:       0x04C11DB7
 *   Reflected form:   0xEDB88320
 *   Initial value:    0xFFFFFFFF
 *   Final XOR value:  0xFFFFFFFF
 *
 * This is the CRC-32 variant commonly used by ZIP, PNG and Ethernet.
 *
 * The function processes:
 *
 *   1. Every byte in the input buffer.
 *   2. Every bit of each byte, starting with the least-significant bit.
 *
 * "data" points to the first byte.
 * "length" is the number of bytes to process.
 */
uint32_t crc32_software(const volatile uint8_t *data, uint32_t length)
{
    /*
     * The CRC register starts with every bit set to 1.
     */
    uint32_t crc = 0xFFFFFFFFu;

    /*
     * Process one input byte at a time.
     */
    for (uint32_t byte_index = 0;
         byte_index < length;
         ++byte_index)
    {

        /*
         * Mix the next input byte into the lowest eight bits of
         * the CRC register.
         */
        crc ^= data[byte_index];

        /*
         * Process the eight bits of the current byte.
         *
         * This is the reflected CRC algorithm, so the
         * least-significant bit is processed first.
         */
        for (uint32_t bit_index = 0;
             bit_index < 8u;
             ++bit_index)
        {

            /*
             * Save the bit that will be shifted out of the CRC
             * register.
             */
            uint32_t least_significant_bit = crc & 1u;

            /*
             * Shift the CRC register by one bit.
             */
            crc >>= 1;

            /*
             * If the shifted-out bit was 1, apply the CRC
             * polynomial.
             *
             * 0xEDB88320 is the bit-reflected representation of
             * the CRC-32 polynomial 0x04C11DB7.
             */
            if (least_significant_bit != 0u)
            {
                crc ^= 0xEDB88320u;
            }
        }
    }

    /*
     * Invert every CRC bit to produce the final result.
     */
    return crc ^ 0xFFFFFFFFu;
}

////////////////////// HARDWARE //////////////////////////
#ifndef CRC_SOFTWARE_ONLY
#define CRC_BASE 0x50000140u

/*
 * CRC accelerator register offsets.
 */
#define CRC_REG_CONTROL 0u
#define CRC_REG_DATA 1u
#define CRC_REG_RESULT 2u
#define CRC_REG_WORD_COUNT 3u

/*
 * CONTROL register commands.
 */
#define CRC_CONTROL_RESTART (1u << 0)

/*
 * Memory-mapped CRC peripheral.
 */
static volatile uint32_t *const crcRegisters =
    (volatile uint32_t *)CRC_BASE;

/*
 * Write one CRC register.
 *
 * swap_u32() is required because the processor and the
 * memory-mapped bus use different byte orders.
 */
static inline void crc_register_write(
    uint32_t registerIndex,
    uint32_t value)
{
    crcRegisters[registerIndex] = swap_u32(value);
}

/*
 * Read one CRC register.
 */
static inline uint32_t crc_register_read(
    uint32_t registerIndex)
{
    return swap_u32(crcRegisters[registerIndex]);
}

void crc_restart(void)
{
    crc_register_write(
        CRC_REG_CONTROL,
        CRC_CONTROL_RESTART);
}

void crc_write_word(uint32_t dataWord)
{
    crc_register_write(
        CRC_REG_DATA,
        dataWord);
}

uint32_t crc_get_result(void)
{
    return crc_register_read(CRC_REG_RESULT);
}

uint32_t crc_get_word_count(void)
{
    return crc_register_read(CRC_REG_WORD_COUNT);
}

uint32_t CRC_compute(const volatile void *data, uint32_t sizeBytes)
{
    const volatile uint8_t *bytes = (const volatile uint8_t *)data;

    /*
     * This simplified accelerator only supports sizes that
     * are multiples of four bytes.
     */
    if ((sizeBytes & 3u) != 0u || (data == 0 && sizeBytes != 0u))
    {
        return 0u;
    }

    /*
     * Initialize a new CRC calculation.
     */
    crc_restart();

    /*
     * Pack every four consecutive bytes into one 32-bit word.
     *
     * The first byte is placed in bits 7:0 because the VHDL
     * CRC core processes the least-significant byte first.
     *
     * Constructing the word explicitly also avoids alignment
     * problems and makes the behavior independent of the CPU's
     * native byte order.
     */
    for (uint32_t index = 0u;
         index < sizeBytes;
         index += 4u)
    {

        uint32_t dataWord =
            ((uint32_t)bytes[index]) | ((uint32_t)bytes[index + 1u] << 8) | ((uint32_t)bytes[index + 2u] << 16) | ((uint32_t)bytes[index + 3u] << 24);

        crc_write_word(dataWord);
    }

    /*
     * Every MM write is completed before the CPU continues, so
     * no done or ready polling is necessary.
     */
    return crc_get_result();
}

#endif /* CRC_SOFTWARE_ONLY */

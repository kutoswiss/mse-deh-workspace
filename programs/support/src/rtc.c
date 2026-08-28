#include <rtc.h>
#include <stdio.h>
#include <stdint.h>

#define RTC_I2C_ADDRESS 0x68u

/*
 * Memory-mapped I2C controller
 *
 * 0x50000040 : slave address [6:0]
 * 0x50000044 : device register [7:0]
 * 0x50000048 : TX/RX data [7:0]
 * 0x5000004C : control/status
 *              write bit 0 = start write
 *              write bit 1 = start read
 *              read  bit 0 = busy
 *              read  bit 1 = done
 *              read  bit 2 = ACK error
 */
#define I2C_MMIO_BASE       0x50000040u
#define I2C_REG_SLAVE       (*(volatile uint32_t *)(I2C_MMIO_BASE + 0x00u))
#define I2C_REG_REGISTER    (*(volatile uint32_t *)(I2C_MMIO_BASE + 0x04u))
#define I2C_REG_DATA        (*(volatile uint32_t *)(I2C_MMIO_BASE + 0x08u))
#define I2C_REG_STATUS_CTRL (*(volatile uint32_t *)(I2C_MMIO_BASE + 0x0Cu))

#define I2C_CMD_WRITE       0x00000001u
#define I2C_CMD_READ        0x00000002u
#define I2C_STATUS_BUSY     0x00000001u
#define I2C_STATUS_DONE     0x00000002u
#define I2C_STATUS_ACK_ERR  0x00000004u

static inline uint32_t swap_u32(uint32_t x)
{
    return ((x & 0x000000FFu) << 24) |
           ((x & 0x0000FF00u) <<  8) |
           ((x & 0x00FF0000u) >>  8) |
           ((x & 0xFF000000u) >> 24);
}

static inline void i2c_mmio_write(unsigned int reg, uint32_t value)
{
    volatile uint32_t *i2c = (volatile uint32_t *)I2C_MMIO_BASE;
    i2c[reg] = swap_u32(value);
}

static inline uint32_t i2c_mmio_read(unsigned int reg)
{
    volatile uint32_t *i2c = (volatile uint32_t *)I2C_MMIO_BASE;
    return swap_u32(i2c[reg]);
}

static inline void i2c_wait_idle(void)
{
    while (i2c_mmio_read(3) & I2C_STATUS_BUSY) {
        /* wait */
    }
}

static inline uint32_t i2c_wait_done(void)
{
    uint32_t status;
    do {
        status = i2c_mmio_read(3);
    } while ((status & I2C_STATUS_DONE) == 0u);
    return status;
}

static inline uint32_t i2c_read_register_mmio(uint8_t slave, uint8_t reg)
{
    uint32_t status;

    i2c_wait_idle();
    i2c_mmio_write(0, (uint32_t)slave);
    i2c_mmio_write(1, (uint32_t)reg);
    i2c_mmio_write(3, I2C_CMD_READ);

    status = i2c_wait_done();
    if (status & I2C_STATUS_ACK_ERR) {
        return 0x80000000u;
    }

    return i2c_mmio_read(2) & 0xFFu;
}

static inline uint32_t i2c_write_register_mmio(uint8_t slave, uint8_t reg, uint8_t data)
{
    uint32_t status;

    i2c_wait_idle();
    i2c_mmio_write(0, (uint32_t)slave);
    i2c_mmio_write(1, (uint32_t)reg);
    i2c_mmio_write(2, (uint32_t)data);
    i2c_mmio_write(3, I2C_CMD_WRITE);

    status = i2c_wait_done();
    return (status & I2C_STATUS_ACK_ERR) ? 0x80000000u : 0u;
}


int readRtcRegister(int reg) {
  uint32_t result;
  int retry = 0;

  do {
    result = i2c_read_register_mmio(RTC_I2C_ADDRESS, (uint8_t)(reg & 0xFF));
    retry++;
  } while (retry < 4 && (result & 0x80000000u) != 0u);

  return (int)result;
}

void writeRtcRegister(int reg, int value) {
  (void)i2c_write_register_mmio(RTC_I2C_ADDRESS,
                                (uint8_t)(reg & 0xFF),
                                (uint8_t)(value & 0xFF));
}

void printTimeComplete() {
  int old,new;
  old = new = readRtcRegister(0);
  do {
    new = readRtcRegister(0);
    if (old != new) {
      printf("%02X-%02X-20%02X %02X:%02X:%02X\n", readRtcRegister(4), readRtcRegister(5), readRtcRegister(6), readRtcRegister(2), readRtcRegister(1), new);
      old = new;
    }
  } while (1);
}
# Embedded Hardware — student reference system

This repository contains the minimal reference platform for the Embedded Hardware course.
It targets the GECKO5Education board and contains:

- one OR1420 processor;
- external SDRAM and SPI flash;
- an MMIO UART for `printf`;
- an OV7670 camera controller writing 320x240 RGB565 images to SDRAM by DMA;
- a fixed 640x480 video output displaying each camera pixel as a 2x2 block;
- an MMIO performance counter at `0x50000120`;
- a 64-bit logic analyser observing camera DMA burst traffic.

GPIO and CRC peripherals are deliberately absent. They are developed incrementally during
the course.

This work is derived from the
[EPFL-LAP CS476 reference project](https://github.com/EPFL-LAP/cs476) and is distributed
under the MIT License. The original project is Copyright (c) 2025 EPFL LAP; course
adaptations are Copyright (c) 2026 HEPIA CoRES. See `LICENSE` and the retained
third-party notices for details.

## Repository layout

- `modules/`: synthesizable IP blocks required by the reference system.
- `systems/singleCore/verilog/`: top-level SystemVerilog design.
- `systems/singleCore/scripts/`: synthesis, place-and-route, programming and pin files.
- `programs/helloWorld/`: minimal UART/`printf` example.
- `programs/camera_demo/`: camera, display and performance-measurement demonstration.
- `programs/support/`: common bare-metal support library.

## Build the FPGA

The OSS CAD Suite and its Yosys GHDL plug-in must be on `PATH`.

```sh
cd systems/singleCore/sandbox
../scripts/synthesizeOr1420.sh --no-program
```

This creates `or1420SingleCore.bit`. Program the volatile FPGA configuration with:

```sh
openFPGALoader or1420SingleCore.bit
```

Alternatively, omit `--no-program` to build and program in one operation. Stop OpenOCD
before reprogramming the FPGA.

## Build the software

The patched `or1k-elf` cross-compiler and `convert_or32` must be on `PATH`.

```sh
make -C programs/helloWorld clean mem
make -C programs/camera_demo clean mem
```

The uploadable files are respectively:

```text
programs/helloWorld/build-release-or1420/hello.cmem
programs/camera_demo/build-release-or1420/camera_demo.cmem
```

Upload one `.cmem` file through the bootloader using a serial terminal configured for
115200 baud, 8 data bits, no parity and one stop bit.

## Camera demonstration

`camera_demo` initializes the camera in QVGA mode, assigns a 320x240 RGB565 framebuffer in
SDRAM to the display controller, continuously captures images, and prints each acquisition
time in cycles and milliseconds.

## Camera DMA logic-analyser channels

The LAC instance is `cameraDmaLac`. Its 64 sampled bits are:

| Bits | Signal |
|---:|---|
| 63:51 | unused |
| 50:19 | camera master address/data bus |
| 18:11 | burst size |
| 10:7 | byte enables |
| 6 | bus error |
| 5 | bus busy |
| 4 | data valid |
| 3 | end transaction |
| 2 | begin transaction |
| 1 | bus grant |
| 0 | bus request |

The desktop analyser application is not distributed in this repository pending confirmation
of its redistribution licence.

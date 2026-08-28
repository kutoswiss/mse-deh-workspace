#!/usr/bin/env python3
"""
biosgen8k.py

Replacement for the original biosgen8k utility used by the OR1K BIOS build.

It reads an ELF32 executable, extracts all PT_LOAD segments, maps them into
a ROM image starting at the lowest load address, and generates a Verilog
case-ROM compatible with the existing bios_rom.v format.

Example:
    ./biosgen8k.py -16k bios
    ./biosgen8k.py -16k bios -o bios_rom.v

The generated ROM stores each group of four ELF bytes as:
    b0 b1 b2 b3  ->  32'hb3b2b1b0

This matches the byte ordering of the original bios_rom.v supplied with
the project.

Zero-valued words are omitted; the Verilog default case returns zero.
"""

import argparse
import math
import struct
import sys
from pathlib import Path

PT_LOAD = 1


def parse_size(text: str) -> int:
    """Parse strings such as 8k, 16k, 32k, or a raw byte count."""
    s = text.lower().strip()
    multiplier = 1
    if s.endswith("k"):
        multiplier = 1024
        s = s[:-1]
    elif s.endswith("m"):
        multiplier = 1024 * 1024
        s = s[:-1]

    try:
        value = int(s, 0) * multiplier
    except ValueError as exc:
        raise argparse.ArgumentTypeError(f"invalid ROM size: {text}") from exc

    if value <= 0 or value % 4 != 0:
        raise argparse.ArgumentTypeError(
            "ROM size must be a positive multiple of 4 bytes"
        )
    return value


def read_elf32_load_image(filename: Path):
    data = filename.read_bytes()

    if len(data) < 52 or data[:4] != b"\x7fELF":
        raise ValueError(f"{filename} is not an ELF file")

    elf_class = data[4]
    elf_data = data[5]

    if elf_class != 1:
        raise ValueError("only ELF32 files are supported")

    if elf_data == 1:
        endian = "<"  # little-endian ELF metadata
    elif elf_data == 2:
        endian = ">"  # big-endian ELF metadata
    else:
        raise ValueError("invalid ELF byte-order field")

    # ELF32 header fields needed here.
    e_phoff = struct.unpack_from(endian + "I", data, 28)[0]
    e_phentsize = struct.unpack_from(endian + "H", data, 42)[0]
    e_phnum = struct.unpack_from(endian + "H", data, 44)[0]

    if e_phentsize < 32:
        raise ValueError("ELF program-header entries are unexpectedly small")

    segments = []

    for i in range(e_phnum):
        off = e_phoff + i * e_phentsize
        if off + 32 > len(data):
            raise ValueError("ELF program-header table is truncated")

        (
            p_type,
            p_offset,
            p_vaddr,
            p_paddr,
            p_filesz,
            p_memsz,
            p_flags,
            p_align,
        ) = struct.unpack_from(endian + "IIIIIIII", data, off)

        if p_type != PT_LOAD:
            continue

        if p_offset + p_filesz > len(data):
            raise ValueError("ELF PT_LOAD segment extends past end of file")

        # Prefer physical address when provided; otherwise virtual address.
        load_addr = p_paddr if p_paddr != 0 else p_vaddr
        segment_data = data[p_offset : p_offset + p_filesz]

        segments.append((load_addr, p_filesz, p_memsz, segment_data))

    if not segments:
        raise ValueError("ELF file contains no PT_LOAD segment")

    base_address = min(seg[0] for seg in segments)
    end_address = max(seg[0] + seg[2] for seg in segments)

    image = bytearray(end_address - base_address)

    for load_addr, filesz, memsz, segment_data in segments:
        start = load_addr - base_address
        image[start : start + filesz] = segment_data
        # The remainder up to p_memsz is already zero-filled.

    return base_address, bytes(image), segments


def verilog_rom(image: bytes, rom_size: int, module_name: str = "biosRom") -> str:
    if len(image) > rom_size:
        raise ValueError(
            f"BIOS image is {len(image)} bytes, larger than "
            f"the selected ROM size of {rom_size} bytes"
        )

    word_count = rom_size // 4
    address_bits = max(1, math.ceil(math.log2(word_count)))

    lines = [
        f"module {module_name} ( input wire        clock,",
        f"                 input wire [{address_bits-1}:0] address,",
        "                 output reg [31:0] romData);",
        "",
        "  always @(negedge clock)",
        "    case (address)",
    ]

    image_words = (len(image) + 3) // 4

    for word_index in range(image_words):
        chunk = image[word_index * 4 : word_index * 4 + 4]
        chunk = chunk.ljust(4, b"\x00")

        # Deliberately little-endian word assembly.  This reproduces the
        # original biosgen8k output even for the big-endian OpenRISC ELF:
        # DE AD 13 00 -> 32'h0013ADDE.
        value = int.from_bytes(chunk, byteorder="little")

        # Match the original generator: zero words are handled by default.
        if value == 0:
            continue

        addr = format(word_index, f"0{address_bits}b")
        lines.append(
            f"      {address_bits}'b{addr} : romData <= 32'h{value:08X};"
        )

    lines += [
        "      default : romData <= 32'd0;",
        "    endcase",
        "",
        "endmodule",
        "",
    ]

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Generate a Verilog BIOS ROM from an ELF32 executable."
    )

    # Compatibility with the old invocation: biosgen8k -16k bios
    size_group = parser.add_mutually_exclusive_group()
    size_group.add_argument(
        "-8k", dest="rom_size", action="store_const", const=8 * 1024,
        help="generate an 8 KiB ROM"
    )
    size_group.add_argument(
        "-16k", dest="rom_size", action="store_const", const=16 * 1024,
        help="generate a 16 KiB ROM"
    )
    size_group.add_argument(
        "-32k", dest="rom_size", action="store_const", const=32 * 1024,
        help="generate a 32 KiB ROM"
    )
    size_group.add_argument(
        "--size", dest="rom_size", type=parse_size,
        help="ROM size, e.g. 16k"
    )

    parser.set_defaults(rom_size=16 * 1024)

    parser.add_argument("elf", type=Path, help="input ELF executable")
    parser.add_argument(
        "-o", "--output", type=Path, default=Path("bios_rom.v"),
        help="output Verilog file (default: bios_rom.v)"
    )
    parser.add_argument(
        "--module-name", default="biosRom",
        help="Verilog module name (default: biosRom)"
    )

    args = parser.parse_args()

    try:
        base, image, segments = read_elf32_load_image(args.elf)
        text = verilog_rom(image, args.rom_size, args.module_name)
        args.output.write_text(text)

        print(
            f"Generated {args.output}: {args.rom_size // 1024} KiB ROM, "
            f"{args.rom_size // 4} words, load base 0x{base:08X}, "
            f"ELF image {len(image)} bytes",
            file=sys.stderr,
        )
    except (OSError, ValueError) as exc:
        print(f"biosgen8k.py: error: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

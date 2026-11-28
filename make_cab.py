#!/usr/bin/env python3
"""Build CarCalc CAB packages without external CAB tools.

Two modes are supported:

  mobile  Windows Mobile/CE install CAB with an MSCE control file. The CAB
          installs the ARM executable, databases, translations and licenses
          under \\Program Files\\CarCalc and adds a Start Menu shortcut.
  arm64   Plain CAB archive of the Windows ARM64 release directory, for
          people who prefer a single-file download. Windows desktop ARM64
          does not use Windows Mobile CAB installation semantics.

The implementation writes an uncompressed Microsoft Cabinet (NONE) and, for
the mobile mode, the classic CabWiz .000 installation description. No Wine,
lcab or CabWiz is needed.
"""

from __future__ import annotations

import argparse
import re
import struct
import sys
from pathlib import Path

ARCHITECTURES = {
    "arm920": 2336,
    "strongarm": 2577,
}

CE_DIR_VARIABLES = {
    "PROGRAMS": "%CE1%",
    "WINDOWS": "%CE2%",
    "START_PROGRAMS": "%CE11%",
}


def p16(value: int) -> bytes:
    return struct.pack("<H", value)


def p32(value: int) -> bytes:
    return struct.pack("<I", value)


def pad_string(value: str) -> bytes:
    raw = value.encode("ascii")
    padding = 4 - (len(raw) % 4)
    return raw + (b"\0" * padding)


def expand_path(value: str) -> str:
    value = value.replace("/", "\\")

    def replace(match: re.Match[str]) -> str:
        name = match.group(1)
        if name not in CE_DIR_VARIABLES:
            raise ValueError(f"unknown directory variable: {name}")
        return CE_DIR_VARIABLES[name]

    return re.sub(r"\$\((.*?)\)", replace, value)


class StringDictionary:
    def __init__(self) -> None:
        self._strings: dict[str, tuple[int, int]] = {}
        self._entries: list[tuple[int, bytes]] = []
        self.length = 0

    @property
    def count(self) -> int:
        return len(self._strings)

    def get(self, value: str) -> int:
        if value not in self._strings:
            string_id = len(self._strings) + 1
            padded = pad_string(value)
            self._strings[value] = (string_id, self.length)
            self._entries.append((string_id, padded))
            self.length += 4 + len(padded)
        return self._strings[value][0]

    def offset(self, value: str) -> int:
        return self._strings[value][1] + 4

    def blob(self) -> bytes:
        return b"".join(p16(i) + p16(len(s)) + s for i, s in self._entries)


class DirectoryList:
    def __init__(self, strings: StringDictionary) -> None:
        self.strings = strings
        self._dirs: dict[str, int] = {}
        self._entries: list[tuple[int, list[int]]] = []
        self.length = 0

    @property
    def count(self) -> int:
        return len(self._dirs)

    def find(self, path: str) -> int | None:
        return self._dirs.get(path.lower())

    def get(self, path: str) -> int:
        key = path.lower()
        if key not in self._dirs:
            directory_id = len(self._dirs) + 1
            self._dirs[key] = directory_id
            self._entries.append((directory_id, [self.strings.get(path)]))
            self.length += 6 + 2
        return self._dirs[key]

    def blob(self) -> bytes:
        out = bytearray()
        for directory_id, string_ids in self._entries:
            out += p16(directory_id)
            out += p16(2 * len(string_ids) + 2)
            for string_id in string_ids:
                out += p16(string_id)
            out += p16(0)
        return bytes(out)


class FileList:
    def __init__(self, directories: DirectoryList) -> None:
        self.directories = directories
        self._files: list[tuple[int, int, bytes, int, int]] = []
        self.length = 0

    @property
    def count(self) -> int:
        return len(self._files)

    def find(self, path: str) -> int | None:
        dirname, _, basename = path.rpartition("\\")
        directory_id = self.directories.find(dirname)
        if directory_id is None:
            return None
        padded = pad_string(basename)
        for _, file_dir, file_name, file_no, _ in self._files:
            if file_dir == directory_id and file_name == padded:
                return file_no
        return None

    def add(self, path: str, file_no: int, flags: int = 0) -> None:
        dirname, _, basename = path.rpartition("\\")
        directory_id = self.directories.get(dirname)
        padded = pad_string(basename)
        self._files.append((len(self._files) + 1, directory_id, padded, file_no, flags))
        self.length += 12 + len(padded)

    def blob(self) -> bytes:
        out = bytearray()
        for file_id, directory_id, filename, file_no, flags in self._files:
            out += p16(file_id)
            out += p16(directory_id)
            out += p16(file_no)
            out += p32(flags)
            out += p16(len(filename))
            out += filename
        return bytes(out)


class LinkList:
    def __init__(self, strings: StringDictionary, files: FileList) -> None:
        self.strings = strings
        self.files = files
        self._links: list[tuple[int, int, int, int, list[int]]] = []
        self.length = 0

    @property
    def count(self) -> int:
        return len(self._links)

    def add(self, target: str, destination: str) -> None:
        target_id = self.files.find(target)
        if target_id is None:
            raise ValueError(f"link target not in file list: {target}")

        parts = destination.split("\\")
        if parts and parts[0] == "":
            parts = parts[1:]

        match = re.match(r"^%CE(\d+)%$", parts[0])
        if match:
            base_dir = int(match.group(1))
            parts = parts[1:]
        else:
            base_dir = 0

        string_ids = [self.strings.get(part) for part in parts]
        self._links.append((len(self._links) + 1, 1, target_id, base_dir, string_ids))
        self.length += 14 + 2 * len(string_ids)

    def blob(self) -> bytes:
        out = bytearray()
        for link_id, target_type, target_id, base_dir, string_ids in self._links:
            out += p16(link_id)
            out += p16(0)
            out += p16(base_dir)
            out += p16(target_id)
            out += p16(target_type)
            out += p16(2 * len(string_ids) + 2)
            for string_id in string_ids:
                out += p16(string_id)
            out += p16(0)
        return bytes(out)


def build_msce(app_name: str, provider: str, unsupported: str,
               arch: str, files: FileList, strings: StringDictionary,
               directories: DirectoryList, links: LinkList) -> bytes:
    for special in (app_name, provider, unsupported):
        strings.get(special)

    section_lengths = [
        ("header", 100),
        ("strings", strings.length),
        ("dirs", directories.length),
        ("files", files.length),
        ("reghives", 0),
        ("regkeys", 0),
        ("links", links.length),
    ]
    offsets: dict[str, int] = {}
    position = 0
    for name, length in section_lengths:
        offsets[name] = position
        position += length
    total = position

    header = bytearray()
    header += b"MSCE"
    header += p32(0)
    header += p32(total)
    header += p32(0)
    header += p32(1)
    header += p32(ARCHITECTURES[arch])
    header += p32(0) * 6
    header += p16(strings.count)
    header += p16(directories.count)
    header += p16(files.count)
    header += p16(0)
    header += p16(0)
    header += p16(links.count)
    for name in ("strings", "dirs", "files", "reghives", "regkeys", "links"):
        header += p32(offsets[name])
    for special in (app_name, provider, unsupported):
        header += p16(offsets["strings"] + strings.offset(special))
        header += p16(len(special.encode("ascii")) + 1)
    header += p16(0)
    header += p16(0)
    if len(header) != 100:
        raise AssertionError(f"MSCE header is {len(header)} bytes, expected 100")

    blob = bytearray(header)
    blob += strings.blob()
    blob += directories.blob()
    blob += files.blob()
    blob += links.blob()
    if len(blob) != total:
        raise AssertionError(f"MSCE blob is {len(blob)} bytes, expected {total}")
    return bytes(blob)


def short_cab_name(filename: str, file_no: int) -> str:
    basename = Path(filename).name
    if "." in basename:
        basename = basename.rpartition(".")[0]
    cleaned = "".join(ch for ch in basename if ch.isalnum())[:8]
    cleaned = cleaned.rjust(8, "0")
    return f"{cleaned}.{file_no:03d}"


def cab_checksum(data: bytes) -> int:
    # MSCF data-block checksum from libmspack's cabd_checksum(): XOR of the
    # little-endian 32-bit words, the trailing bytes and the block length.
    checksum = 0
    whole = len(data) // 4 * 4
    for offset in range(0, whole, 4):
        checksum ^= int.from_bytes(data[offset:offset + 4], "little")
    # libmspack assembles the trailing bytes in reverse (big-endian) order.
    tail = 0
    for byte in data[whole:]:
        tail = (tail << 8) | byte
    checksum ^= tail
    checksum ^= len(data) | (len(data) << 16)
    return checksum & 0xFFFFFFFF


def write_cab(output: Path, entries: list[tuple[str, bytes]]) -> None:
    header_size = 36
    folder_size = 8
    file_table: list[tuple[str, bytes, int]] = []
    folder_offset = 0
    for name, data in entries:
        file_table.append((name, data, folder_offset))
        folder_offset += len(data)

    file_table_size = sum(16 + len(name.encode("ascii")) + 1 for name, _, _ in file_table)
    data_start = header_size + folder_size + file_table_size
    all_data = b"".join(data for _, data, _ in file_table)

    blocks: list[bytes] = []
    position = 0
    while position < len(all_data):
        block = all_data[position:position + 32768]
        blocks.append(block)
        position += len(block)
    if not blocks:
        blocks.append(b"")

    total_size = data_start + (8 * len(blocks)) + len(all_data)

    out = bytearray()
    out += b"MSCF"                    # signature
    out += p32(0)                      # reserved1
    out += p32(total_size)             # cbCabinet
    out += p32(0)                      # reserved2
    out += p32(header_size + folder_size)  # coffFiles (first CFFILE entry)
    out += p32(0)                      # reserved3
    out += bytes([3, 1])               # version 1.3
    out += p16(1)                      # cFolders
    out += p16(len(entries))           # cFiles
    out += p16(0)                      # flags
    out += p16(0x1234)                 # setID
    out += p16(0)                      # iCab

    out += p32(data_start)             # CFOLDER.coffCabStart
    out += p16(len(blocks))            # CFOLDER.cCFData
    out += p16(0)                      # CFOLDER.type (NONE)

    for name, data, offset in file_table:
        out += p32(len(data))          # cbFile
        out += p32(offset)             # uoffFolderStart
        out += p16(0)                  # iFolder
        out += p16(0x0021)             # date: 1980-01-01
        out += p16(0)                  # time: 00:00:00
        out += p16(0x20)               # attributes: archive
        out += name.encode("ascii") + b"\0"

    for block in blocks:
        out += p32(cab_checksum(block))
        out += p16(len(block))
        out += p16(len(block))
        out += block

    if len(out) != total_size:
        raise AssertionError(f"CAB size mismatch: {len(out)} != {total_size}")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(out)


def collect_files(source: Path) -> list[Path]:
    files = []
    for path in sorted(source.rglob("*")):
        if path.is_file() and path.suffix.lower() != ".cab":
            files.append(path)
    if not files:
        raise ValueError(f"no files found in {source}")
    return files


def build_mobile(source: Path, output: Path) -> None:
    strings = StringDictionary()
    directories = DirectoryList(strings)
    files = FileList(directories)
    links = LinkList(strings, files)

    paths = collect_files(source)
    install_paths: list[str] = []
    for path in paths:
        relative = path.relative_to(source)
        parent = relative.parent.as_posix()
        if parent == ".":
            install_paths.append(f"$(PROGRAMS)\\CarCalc\\{relative.name}")
        else:
            install_paths.append(f"$(PROGRAMS)\\CarCalc\\{parent}\\{relative.name}")

    for file_no, install_path in enumerate(install_paths, start=1):
        files.add(expand_path(install_path), file_no)

    executable = next((p for p in install_paths if p.endswith("\\CarCalc-mobile.exe")), None)
    if executable is None:
        raise ValueError("CarCalc-mobile.exe is missing from the source directory")
    links.add(expand_path(executable), expand_path("$(START_PROGRAMS)\\CarCalc"))

    control = build_msce(
        app_name="CarCalc",
        provider="C0m3b4ck",
        unsupported="",
        arch="strongarm",
        files=files,
        strings=strings,
        directories=directories,
        links=links,
    )

    entries: list[tuple[str, bytes]] = [(short_cab_name("CarCalc", 0), control)]
    for file_no, path in enumerate(paths, start=1):
        entries.append((short_cab_name(str(path), file_no), path.read_bytes()))

    # CabWiz puts the .000 control file first, then the payload files in
    # descending numeric extension order.
    entries = [entries[0]] + list(reversed(entries[1:]))
    write_cab(output, entries)


def build_arm64(source: Path, output: Path) -> None:
    entries = []
    for path in collect_files(source):
        relative = path.relative_to(source).as_posix().replace("/", "\\")
        entries.append((relative, path.read_bytes()))
    write_cab(output, entries)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("mobile", "arm64"), required=True)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    if not args.source.is_dir():
        print(f"error: source directory not found: {args.source}", file=sys.stderr)
        return 1

    try:
        if args.mode == "mobile":
            build_mobile(args.source, args.output)
        else:
            build_arm64(args.source, args.output)
    except (OSError, ValueError, AssertionError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(f"==> built {args.output} ({args.output.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

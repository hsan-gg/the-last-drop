"""Minimal PNG reader/writer (8-bit RGBA, RGB, palette) for the art import
tools, so they need nothing beyond numpy. Not a general PNG library."""
import struct
import zlib

import numpy as np


def read_png(path):
    data = open(path, "rb").read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", f"{path}: not a PNG"
    pos, idat, palette, trns = 8, b"", None, None
    width = height = depth = ctype = interlace = 0
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        if kind == b"IHDR":
            width, height, depth, ctype, _, _, interlace = struct.unpack(">IIBBBBB", body)
        elif kind == b"PLTE":
            palette = np.frombuffer(body, np.uint8).reshape(-1, 3)
        elif kind == b"tRNS":
            trns = np.frombuffer(body, np.uint8)
        elif kind == b"IDAT":
            idat += body
        pos += 12 + length
    assert depth == 8 and interlace == 0, f"{path}: only 8-bit non-interlaced PNGs are supported"
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
    stride = width * channels
    raw = zlib.decompress(idat)
    rows = np.zeros((height, stride), np.uint8)
    prev = np.zeros(stride, np.int32)
    offset = 0
    for y in range(height):
        ftype = raw[offset]
        line = np.frombuffer(raw, np.uint8, stride, offset + 1).astype(np.int32)
        offset += stride + 1
        if ftype == 1:
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 255
        elif ftype == 2:
            line = (line + prev) & 255
        elif ftype == 3:
            for i in range(stride):
                left = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + ((left + prev[i]) >> 1)) & 255
        elif ftype == 4:
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                b = prev[i]
                c = prev[i - channels] if i >= channels else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[i] = (line[i] + pred) & 255
        rows[y] = line
        prev = line
    pixels = rows.reshape(height, width, channels)
    if ctype == 6:
        return pixels.copy()
    if ctype == 2:
        return np.dstack([pixels, np.full((height, width), 255, np.uint8)])
    if ctype == 3:
        rgb = palette[pixels[:, :, 0]]
        alpha = np.full((height, width), 255, np.uint8)
        if trns is not None:
            lookup = np.full(256, 255, np.uint8)
            lookup[:len(trns)] = trns
            alpha = lookup[pixels[:, :, 0]]
        return np.dstack([rgb, alpha])
    if ctype == 0:
        return np.dstack([pixels] * 3 + [np.full((height, width), 255, np.uint8)])
    return np.dstack([pixels[:, :, :1]] * 3 + [pixels[:, :, 1:2]])


def write_png(path, pixels):
    height, width = pixels.shape[:2]
    raw = b"".join(b"\x00" + pixels[y].tobytes() for y in range(height))

    def chunk(kind, body):
        block = kind + body
        return struct.pack(">I", len(body)) + block + struct.pack(">I", zlib.crc32(block) & 0xFFFFFFFF)

    with open(path, "wb") as handle:
        handle.write(
            b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9))
            + chunk(b"IEND", b"")
        )


def scaled(pixels, factor):
    return np.repeat(np.repeat(pixels, factor, axis=0), factor, axis=1)

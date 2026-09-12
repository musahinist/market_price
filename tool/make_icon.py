import struct, zlib, math

W = 1024

def rounded_rect_sd(px, py, cx, cy, hw, hh, r):
    """İmzalı mesafe: yuvarlatılmış dikdörtgen."""
    qx = abs(px - cx) - (hw - r)
    qy = abs(py - cy) - (hh - r)
    ax, ay = max(qx, 0.0), max(qy, 0.0)
    return math.hypot(ax, ay) + min(max(qx, qy), 0.0) - r

def blend(dst, src, a):
    return tuple(int(round(d + (s - d) * a)) for d, s in zip(dst, src))

# Glifin 100 birimlik çizim uzayındaki sınırları.
GLYPH = (23.0, 20.0, 77.0, 86.0)

def render(background, fill):
    """[fill] glifin tuval yüksekliğinin ne kadarını kaplayacağı (0-1)."""
    """background None ise saydam zemin (adaptive foreground)."""
    bg = background or (0, 0, 0)
    alpha0 = 255 if background else 0
    px = [[(bg[0], bg[1], bg[2], alpha0) for _ in range(W)] for _ in range(W)]

    up = (0x16, 0xC7, 0x84)
    down = (0xEA, 0x39, 0x43)
    gx0, gy0, gx1, gy1 = GLYPH
    k = fill * 100.0 / (gy1 - gy0)
    s = W / 100.0 * k
    # Glifi tuvalin ortasına oturt.
    ox = W / 2 - (gx0 + gx1) / 2 * s
    oy = W / 2 - (gy0 + gy1) / 2 * s

    # (renk, gövde x0,y0,x1,y1, fitil x, fitil y0,y1)
    candles = [
        (up, 26, 40, 44, 74, 35, 26, 86),
        (down, 56, 30, 74, 60, 65, 20, 74),
    ]

    for color, bx0, by0, bx1, by1, wx, wy0, wy1 in candles:
        shapes = [
            (ox + wx * s, oy + (wy0 + wy1) / 2 * s,
             3.0 * s, (wy1 - wy0) / 2 * s, 3.0 * s),
            (ox + (bx0 + bx1) / 2 * s, oy + (by0 + by1) / 2 * s,
             (bx1 - bx0) / 2 * s, (by1 - by0) / 2 * s, 5.0 * s),
        ]
        for cx, cy, hw, hh, r in shapes:
            x0 = max(0, int(cx - hw) - 2)
            x1 = min(W, int(cx + hw) + 3)
            y0 = max(0, int(cy - hh) - 2)
            y1 = min(W, int(cy + hh) + 3)
            for y in range(y0, y1):
                row = px[y]
                for x in range(x0, x1):
                    d = rounded_rect_sd(x + 0.5, y + 0.5, cx, cy, hw, hh, r)
                    a = min(max(0.5 - d, 0.0), 1.0)
                    if a <= 0:
                        continue
                    r0, g0, b0, a0 = row[x]
                    na = a + a0 / 255.0 * (1 - a)
                    if na <= 0:
                        continue
                    mix = blend((r0, g0, b0), color, a / na)
                    row[x] = (mix[0], mix[1], mix[2], int(round(na * 255)))
    return px

def write_png(path, px):
    raw = bytearray()
    for row in px:
        raw.append(0)
        for r, g, b, a in row:
            raw += bytes((r, g, b, a))
    def chunk(tag, data):
        c = struct.pack('>I', len(data)) + tag + data
        return c + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)
    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', W, W, 8, 6, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(bytes(raw), 9))
    png += chunk(b'IEND', b'')
    open(path, 'wb').write(png)

base = '/Users/mshn/Documents/market_price/assets/icon'
# Klasik ikon: kenarlarda nefes payı. Adaptive foreground: araç zaten %16
# iç boşluk ekliyor, o yüzden glif kendi tuvalini neredeyse doldurmalı.
write_png(f'{base}/icon.png', render((0x10, 0x16, 0x13), fill=0.60))
write_png(f'{base}/icon_foreground.png', render(None, fill=0.92))
print('yazildi')

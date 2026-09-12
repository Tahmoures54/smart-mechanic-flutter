#!/usr/bin/env python3
"""Generate Smart Mechanic branding assets from the official mark.

Source of truth: /logo.png (circular badge: gear + padlock + wrench + screwdriver).
This script redraws a crisp vector-faithful version for launcher, splash, and in-app use.
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "branding"
ANDROID_RES = ROOT / "android" / "app" / "src" / "main" / "res"
FONT_CANDIDATES = [
    Path("/tmp/Vazirmatn-Bold.ttf"),
    Path("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"),
]

# Palette sampled from logo.png
WHITE = (250, 251, 251, 255)
BG = (18, 18, 18, 255)
BG_DEEP = (13, 13, 18, 255)  # #0D0D12 app chrome
GEAR = (72, 71, 71, 255)
GEAR_DARK = (36, 36, 36, 255)
HOLE = (22, 22, 22, 255)
GOLD_HI = (245, 223, 176, 255)
GOLD_MID = (228, 186, 86, 255)
GOLD_LO = (214, 163, 48, 255)
GOLD_EDGE = (196, 140, 32, 255)
KEYHOLE = (32, 32, 32, 255)
SHADOW = (0, 0, 0, 90)


def _lerp(a, b, t):
    return int(a + (b - a) * t)


def gold_at(t: float) -> tuple[int, int, int, int]:
    t = max(0.0, min(1.0, t))
    if t < 0.45:
        u = t / 0.45
        return (
            _lerp(GOLD_HI[0], GOLD_MID[0], u),
            _lerp(GOLD_HI[1], GOLD_MID[1], u),
            _lerp(GOLD_HI[2], GOLD_MID[2], u),
            255,
        )
    u = (t - 0.45) / 0.55
    return (
        _lerp(GOLD_MID[0], GOLD_LO[0], u),
        _lerp(GOLD_MID[1], GOLD_LO[1], u),
        _lerp(GOLD_MID[2], GOLD_LO[2], u),
        255,
    )


def polar(cx, cy, r, deg):
    a = math.radians(deg)
    return (cx + r * math.cos(a), cy + r * math.sin(a))


def rotate_pts(pts, deg, ox, oy):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    out = []
    for x, y in pts:
        dx, dy = x - ox, y - oy
        out.append((ox + dx * c - dy * s, oy + dx * s + dy * c))
    return out


def rounded_poly(draw, pts, fill, width=0, outline=None):
    ip = [(int(round(x)), int(round(y))) for x, y in pts]
    draw.polygon(ip, fill=fill, outline=outline)
    if width:
        draw.line(ip + [ip[0]], fill=outline or fill, width=width, joint="curve")


def gear_points(cx, cy, teeth, r_tip, r_root, tooth_frac=0.42, bevel=0.18):
    pts = []
    step = 360 / teeth
    half_tooth = step * tooth_frac / 2
    for i in range(teeth):
        mid = -90 + i * step
        a0 = mid - half_tooth
        a1 = mid + half_tooth
        b = half_tooth * bevel
        pts.append(polar(cx, cy, r_root, a0 - (step / 2 - half_tooth)))
        pts.append(polar(cx, cy, r_root, a0))
        pts.append(polar(cx, cy, r_tip, a0 + b))
        pts.append(polar(cx, cy, r_tip, a1 - b))
        pts.append(polar(cx, cy, r_root, a1))
    return pts


def paste_layer(base, layer):
    base.alpha_composite(layer)


def draw_mark(size: int, *, transparent_outside: bool = True) -> Image.Image:
    """Draw the circular brand mark at `size` x `size`."""
    # Super-sample
    s = max(size * 2, 512)
    scale = s / 1024.0
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0) if transparent_outside else BG_DEEP)
    d = ImageDraw.Draw(img)
    cx = cy = s / 2

    def sc(v):
        return v * scale

    r_outer = sc(500)
    r_ring_inner = sc(452)
    r_gear_tip = sc(418)
    r_gear_root = sc(348)
    r_gear_inner = sc(178)
    r_hole_ring = sc(268)

    # Soft drop shadow under the badge
    shadow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse(
        [cx - r_outer + sc(8), cy - r_outer + sc(18), cx + r_outer + sc(8), cy + r_outer + sc(18)],
        fill=(0, 0, 0, 70),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=sc(18)))
    paste_layer(img, shadow)

    # White ring + dark disc
    d.ellipse([cx - r_outer, cy - r_outer, cx + r_outer, cy + r_outer], fill=WHITE)
    d.ellipse(
        [cx - r_ring_inner, cy - r_ring_inner, cx + r_ring_inner, cy + r_ring_inner],
        fill=BG,
    )
    # Inner hairline
    d.ellipse(
        [
            cx - r_ring_inner + sc(6),
            cy - r_ring_inner + sc(6),
            cx + r_ring_inner - sc(6),
            cy + r_ring_inner - sc(6),
        ],
        outline=(40, 40, 40, 255),
        width=max(1, int(sc(4))),
    )

    # Gear
    pts = gear_points(cx, cy, 8, r_gear_tip, r_gear_root)
    rounded_poly(d, pts, GEAR)
    d.ellipse(
        [cx - r_gear_inner, cy - r_gear_inner, cx + r_gear_inner, cy + r_gear_inner],
        fill=BG,
    )
    # Inner holes between teeth
    for i in range(8):
        ang = -90 + 22.5 + i * 45
        hx, hy = polar(cx, cy, r_hole_ring, ang)
        hw, hh = sc(42), sc(56)
        hole = [
            (hx - hw, hy - hh),
            (hx + hw, hy - hh),
            (hx + hw, hy + hh),
            (hx - hw, hy + hh),
        ]
        hole = rotate_pts(hole, ang + 90, hx, hy)
        rounded_poly(d, hole, HOLE)
    # Gear inner rim
    d.ellipse(
        [
            cx - r_gear_inner - sc(14),
            cy - r_gear_inner - sc(14),
            cx + r_gear_inner + sc(14),
            cy + r_gear_inner + sc(14),
        ],
        outline=GEAR,
        width=max(2, int(sc(14))),
    )

    # Tools + lock on a dedicated layer so gold stays crisp
    tools = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    td = ImageDraw.Draw(tools)
    _draw_screwdriver(td, cx, cy, sc)
    _draw_wrench(td, cx, cy, sc, tools)
    td = ImageDraw.Draw(tools)
    _draw_lock(td, cx, cy, sc, s)
    paste_layer(img, tools)

    out = img.resize((size, size), Image.Resampling.LANCZOS)
    return out


def _gold_rect(draw, box, t0=0.0, t1=1.0):
    x0, y0, x1, y1 = box
    h = max(1, int(y1 - y0))
    for i in range(h):
        t = t0 + (t1 - t0) * (i / h)
        draw.line([(x0, y0 + i), (x1, y0 + i)], fill=gold_at(t))


def _xform(pts, cx, cy, sc, angle, origin_y):
    shifted = [(cx + x, cy + origin_y + y) for x, y in pts]
    return rotate_pts(shifted, angle, cx, cy)


def _draw_screwdriver(draw: ImageDraw.ImageDraw, cx, cy, sc):
    # Handle sits upper-left; shaft runs into the lock.
    angle = -50
    origin_y = sc(-250)

    def L(pts):
        return _xform(pts, cx, cy, sc, angle, origin_y)

    hw = sc(32)
    rounded_poly(
        draw,
        L([(-hw, 0), (hw, 0), (hw, sc(150)), (-hw, sc(150))]),
        GOLD_MID,
    )
    for band_y, col in (
        (sc(16), GOLD_HI),
        (sc(58), GOLD_EDGE),
        (sc(100), GOLD_HI),
    ):
        rounded_poly(
            draw,
            L([(-hw, band_y), (hw, band_y), (hw, band_y + sc(14)), (-hw, band_y + sc(14))]),
            col,
        )
    rounded_poly(
        draw,
        L([(-sc(20), sc(148)), (sc(20), sc(148)), (sc(20), sc(172)), (-sc(20), sc(172))]),
        (42, 42, 42, 255),
    )
    rounded_poly(
        draw,
        L([(-sc(9), sc(168)), (sc(9), sc(168)), (sc(9), sc(330)), (-sc(9), sc(330))]),
        GOLD_MID,
    )
    rounded_poly(
        draw,
        L([(-sc(16), sc(328)), (sc(16), sc(328)), (sc(5), sc(358)), (-sc(5), sc(358))]),
        GOLD_LO,
    )


def _draw_wrench(draw: ImageDraw.ImageDraw, cx, cy, sc, canvas: Image.Image):
    angle = 50
    origin_y = sc(-255)

    def L(pts):
        return _xform(pts, cx, cy, sc, angle, origin_y)

    # Handle + neck
    rounded_poly(
        draw,
        L([(-sc(20), sc(155)), (sc(20), sc(155)), (sc(20), sc(340)), (-sc(20), sc(340))]),
        GOLD_MID,
    )
    rounded_poly(
        draw,
        L([(-sc(26), sc(125)), (sc(26), sc(125)), (sc(20), sc(175)), (-sc(20), sc(175))]),
        GOLD_MID,
    )

    # Open-end head
    outer = [
        (-sc(88), sc(4)),
        (-sc(22), sc(4)),
        (-sc(22), sc(40)),
        (-sc(10), sc(78)),
        (sc(10), sc(78)),
        (sc(22), sc(40)),
        (sc(22), sc(4)),
        (sc(88), sc(4)),
        (sc(98), sc(48)),
        (sc(58), sc(132)),
        (-sc(58), sc(132)),
        (-sc(98), sc(48)),
    ]
    rounded_poly(draw, L(outer), GOLD_HI)

    # Punch a transparent opening in the jaws
    opening = [
        (-sc(48), sc(14)),
        (sc(48), sc(14)),
        (sc(28), sc(88)),
        (-sc(28), sc(88)),
    ]
    mask = Image.new("L", canvas.size, 255)
    ImageDraw.Draw(mask).polygon(
        [(int(round(x)), int(round(y))) for x, y in L(opening)],
        fill=0,
    )
    alpha = canvas.split()[-1]
    canvas.putalpha(ImageChops.multiply(alpha, mask))


def _draw_lock(draw: ImageDraw.ImageDraw, cx, cy, sc, s):
    body_w, body_h = sc(228), sc(200)
    body_top = cy - sc(8)
    shackle_t = int(sc(32))
    shackle_w = sc(148)
    x0 = cx - shackle_w / 2
    x1 = cx + shackle_w / 2
    y_arc0 = body_top - sc(118)
    y_arc1 = body_top + sc(50)
    draw.arc(
        [x0, y_arc0, x1, y_arc1],
        start=180,
        end=0,
        fill=GOLD_MID,
        width=shackle_t,
    )
    draw.rectangle(
        [x0, body_top - sc(24), x0 + shackle_t, body_top + sc(18)],
        fill=GOLD_MID,
    )
    draw.rectangle(
        [x1 - shackle_t, body_top - sc(24), x1, body_top + sc(18)],
        fill=GOLD_MID,
    )

    bx0 = cx - body_w / 2
    by0 = body_top
    bx1 = cx + body_w / 2
    by1 = body_top + body_h
    radius = int(sc(32))
    draw.rounded_rectangle([bx0, by0, bx1, by1], radius=radius, fill=GOLD_MID)
    draw.rounded_rectangle(
        [bx0 + sc(12), by0 + sc(10), bx1 - sc(12), by0 + sc(64)],
        radius=int(sc(22)),
        fill=GOLD_HI,
    )
    draw.rounded_rectangle(
        [bx0 + sc(16), by1 - sc(54), bx1 - sc(16), by1 - sc(10)],
        radius=int(sc(16)),
        fill=GOLD_LO,
    )

    kr = sc(26)
    kx, ky = cx, body_top + sc(84)
    draw.ellipse([kx - kr, ky - kr, kx + kr, ky + kr], fill=KEYHOLE)
    rounded_poly(
        draw,
        [
            (kx - sc(11), ky + sc(8)),
            (kx + sc(11), ky + sc(8)),
            (kx + sc(18), ky + sc(64)),
            (kx - sc(18), ky + sc(64)),
        ],
        KEYHOLE,
    )


def composite_on(bg_color, mark: Image.Image, fill_ratio=0.92) -> Image.Image:
    size = mark.size[0]
    canvas = Image.new("RGBA", (size, size), bg_color)
    if fill_ratio != 1:
        inner = int(size * fill_ratio)
        mark = mark.resize((inner, inner), Image.Resampling.LANCZOS)
        off = (size - inner) // 2
        canvas.alpha_composite(mark, (off, off))
    else:
        canvas.alpha_composite(mark)
    return canvas.convert("RGB").convert("RGBA")


def circle_crop(im: Image.Image) -> Image.Image:
    s = im.size[0]
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, s - 1, s - 1], fill=255)
    out = im.copy()
    out.putalpha(mask)
    return out


def save_png(im: Image.Image, path: Path, *, rgb=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    if rgb:
        bg = Image.new("RGB", im.size, BG_DEEP[:3])
        bg.paste(im, mask=im.split()[-1] if im.mode == "RGBA" else None)
        bg.save(path, "PNG", optimize=True)
    else:
        im.save(path, "PNG", optimize=True)
    print(f"wrote {path.relative_to(ROOT)}  {im.size}")


def write_svg(path: Path):
    path.write_text(
        """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
  <defs>
    <linearGradient id="gold" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#F5DFB0"/>
      <stop offset="45%" stop-color="#E4BA56"/>
      <stop offset="100%" stop-color="#D6A330"/>
    </linearGradient>
  </defs>
  <circle cx="256" cy="256" r="248" fill="#FAFBFB"/>
  <circle cx="256" cy="256" r="222" fill="#121212"/>
  <!-- Gear (simplified 8-tooth) -->
  <g fill="#484747">
    <path d="M256 56 l28 28 h40 l14 40 40 14 v40 l28 28 -28 28 v40 l-40 14 -14 40 h-40 l-28 28 -28-28 h-40 l-14-40 -40-14 v-40 l-28-28 28-28 v-40 l40-14 14-40 h40 z"/>
  </g>
  <circle cx="256" cy="256" r="78" fill="#121212"/>
  <circle cx="256" cy="256" r="92" fill="none" stroke="#484747" stroke-width="14"/>
  <!-- Screwdriver -->
  <g transform="translate(256,256) rotate(-48) translate(-256,-256)">
    <rect x="240" y="70" width="32" height="90" rx="8" fill="url(#gold)"/>
    <rect x="246" y="160" width="20" height="16" rx="3" fill="#303030"/>
    <rect x="250" y="174" width="12" height="70" rx="3" fill="url(#gold)"/>
  </g>
  <!-- Wrench -->
  <g transform="translate(256,256) rotate(48) translate(-256,-256)">
    <rect x="244" y="150" width="24" height="110" rx="10" fill="url(#gold)"/>
    <path d="M210 70 h36 v30 h20 v24 h-20 v20 h-36 v-24 h-18 v-26 h18 z" fill="url(#gold)"/>
  </g>
  <!-- Lock -->
  <path d="M206 210 a50 48 0 0 1 100 0 v28 h-22 v-28 a28 28 0 0 0 -56 0 v28 h-22 z" fill="url(#gold)"/>
  <rect x="186" y="228" width="140" height="130" rx="22" fill="url(#gold)"/>
  <circle cx="256" cy="278" r="16" fill="#202020"/>
  <path d="M248 278 l16 0 8 40 h-32 z" fill="#202020"/>
</svg>
""",
        encoding="utf-8",
    )
    print(f"wrote {path.relative_to(ROOT)}")


def load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for p in FONT_CANDIDATES:
        if p.exists():
            return ImageFont.truetype(str(p), size=size)
    return ImageFont.load_default()


def make_banner(mark: Image.Image) -> Image.Image:
    w, h = 1600, 640
    img = Image.new("RGBA", (w, h), BG_DEEP)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=48, fill=BG_DEEP)

    logo = mark.resize((420, 420), Image.Resampling.LANCZOS)
    img.alpha_composite(logo, (80, (h - 420) // 2))

    font_en = load_font(92)
    font_fa = load_font(72)
    font_tag = load_font(32)
    x = 540
    d.text((x, 160), "Smart Mechanic", font=font_en, fill=GOLD_MID)
    d.text((x, 280), "مکانیک هوشمند", font=font_fa, fill=WHITE)
    d.text((x, 390), "عیب‌یابی هوشمند خودرو", font=font_tag, fill=(176, 176, 188, 255))
    return img


def write_android_icons(app_icon: Image.Image, foreground: Image.Image, round_icon: Image.Image):
    densities = {
        "mdpi": 1,
        "hdpi": 1.5,
        "xhdpi": 2,
        "xxhdpi": 3,
        "xxxhdpi": 4,
    }
    for name, d in densities.items():
        folder = ANDROID_RES / f"mipmap-{name}"
        folder.mkdir(parents=True, exist_ok=True)
        side = int(48 * d)
        save_png(app_icon.resize((side, side), Image.Resampling.LANCZOS), folder / "ic_launcher.png", rgb=True)
        save_png(round_icon.resize((side, side), Image.Resampling.LANCZOS), folder / "ic_launcher_round.png", rgb=True)
        fg_side = int(108 * d)
        save_png(
            foreground.resize((fg_side, fg_side), Image.Resampling.LANCZOS),
            folder / "ic_launcher_foreground.png",
        )

    drawable = ANDROID_RES / "drawable"
    drawable.mkdir(parents=True, exist_ok=True)
    save_png(foreground.resize((432, 432), Image.Resampling.LANCZOS), drawable / "ic_launcher_foreground.png")
    splash = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    mark512 = draw_mark(420)
    splash.alpha_composite(mark512, ((512 - 420) // 2, (512 - 420) // 2))
    save_png(splash, drawable / "splash_logo.png")


def write_adaptive_xml():
    xml = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
"""
    anydpi = ANDROID_RES / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(xml, encoding="utf-8")
    (anydpi / "ic_launcher_round.xml").write_text(xml, encoding="utf-8")


def main():
    OUT.mkdir(parents=True, exist_ok=True)

    # Preserve the original raster
    src = ROOT / "logo.png"
    if src.exists():
        save_png(Image.open(src).convert("RGBA"), OUT / "logo_source.png")

    mark_1024 = draw_mark(1024)
    mark_512 = draw_mark(512)

    # In-app circular logo (transparent outside)
    save_png(mark_512, OUT / "logo.png")

    # Play / launcher: dark square with the badge
    app_icon = composite_on(BG_DEEP, mark_1024, fill_ratio=0.94)
    # Flatten to RGB with dark fill (no alpha — Play Store / launcher)
    save_png(app_icon, OUT / "app_icon.png", rgb=True)

    # Adaptive foreground: badge in the 66% safe zone
    fg = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    inner = mark_1024.resize((680, 680), Image.Resampling.LANCZOS)
    fg.alpha_composite(inner, ((1024 - 680) // 2, (1024 - 680) // 2))
    save_png(fg, OUT / "app_icon_foreground.png")

    adaptive = composite_on(BG_DEEP, mark_1024, fill_ratio=0.72)
    save_png(adaptive, OUT / "adaptive_icon.png", rgb=True)

    splash = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    m = draw_mark(440)
    splash.alpha_composite(m, ((512 - 440) // 2, (512 - 440) // 2))
    save_png(splash, OUT / "splash_mark.png")

    banner = make_banner(mark_1024)
    save_png(banner, OUT / "banner.png")

    play = app_icon.resize((512, 512), Image.Resampling.LANCZOS)
    save_png(play, OUT / "play_store_icon.png", rgb=True)

    write_svg(OUT / "logo.svg")
    write_svg(OUT / "app_icon.svg")
    write_svg(OUT / "adaptive_icon.svg")
    write_svg(OUT / "splash_mark.svg")
    write_svg(OUT / "app_icon_foreground.svg")
    write_svg(OUT / "banner.svg")

    round_icon = circle_crop(app_icon)
    # round png still needs opaque corners for some launchers → composite on dark
    round_rgb = Image.new("RGBA", (1024, 1024), BG_DEEP)
    round_rgb.alpha_composite(round_icon)
    write_android_icons(app_icon, fg, round_rgb)
    write_adaptive_xml()

    print("Branding assets generated.")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Generate DMG background images for MouseOn installer.

Creates a professional installer background with:
- Subtle radial gradient (near-white center, light blue-gray edges)
- Blue arrow between app icon and Applications folder positions
- "Drag to Applications to install" instruction text

Outputs:
  dmg-resources/background.png    (660x400 @1x)
  dmg-resources/background@2x.png (1320x800 @2x)

Requirements:
  pip3 install Pillow
"""

import math
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def radial_gradient(draw, width, height, center_color, edge_color):
    """Draw a radial gradient from center_color at center to edge_color at edges."""
    cx, cy = width / 2, height / 2
    max_dist = math.sqrt(cx**2 + cy**2)

    for y in range(height):
        for x in range(width):
            dist = math.sqrt((x - cx) ** 2 + (y - cy) ** 2)
            ratio = min(dist / max_dist, 1.0)
            r = int(center_color[0] + (edge_color[0] - center_color[0]) * ratio)
            g = int(center_color[1] + (edge_color[1] - center_color[1]) * ratio)
            b = int(center_color[2] + (edge_color[2] - center_color[2]) * ratio)
            draw.point((x, y), fill=(r, g, b))


def draw_arrow(draw, x_start, x_end, y_center, color, thickness, head_size):
    """Draw a horizontal arrow with a triangular head."""
    # Shaft
    shaft_end = x_end - head_size
    draw.line(
        [(x_start, y_center), (shaft_end, y_center)],
        fill=color,
        width=thickness,
    )
    # Arrowhead (triangle)
    draw.polygon(
        [
            (x_end, y_center),
            (shaft_end, y_center - head_size),
            (shaft_end, y_center + head_size),
        ],
        fill=color,
    )


def get_font(size):
    """Try to load SF Pro or Helvetica Neue; fall back to default."""
    font_paths = [
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/SFNSText.ttf",
        "/Library/Fonts/SF-Pro-Text-Regular.otf",
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for path in font_paths:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                continue
    return ImageFont.load_default()


def generate_background(width, height, scale, output_path):
    """Generate a single background image at the given dimensions."""
    img = Image.new("RGB", (width, height))
    draw = ImageDraw.Draw(img)

    # Radial gradient: near-white center -> light blue-gray edges
    center_color = (250, 250, 252)
    edge_color = (218, 224, 234)
    radial_gradient(draw, width, height, center_color, edge_color)

    # Icon positions (scaled from @1x: app at 150, Applications at 510, y=190)
    app_x = int(150 * scale)
    apps_x = int(510 * scale)
    icon_y = int(190 * scale)

    # Arrow between icons (margin clears the 64px icon radius + padding)
    arrow_color = (0, 122, 255)  # #007AFF
    arrow_margin = int(75 * scale)
    arrow_y = icon_y
    arrow_x_start = app_x + arrow_margin
    arrow_x_end = apps_x - arrow_margin
    arrow_thickness = int(3 * scale)
    head_size = int(10 * scale)

    draw_arrow(draw, arrow_x_start, arrow_x_end, arrow_y, arrow_color, arrow_thickness, head_size)

    # Instruction text
    font_size = int(16 * scale)
    font = get_font(font_size)
    text = "Drag to Applications to install"
    text_color = (80, 80, 90)

    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_x = (width - text_width) // 2
    text_y = int(295 * scale)

    draw.text((text_x, text_y), text, fill=text_color, font=font)

    img.save(output_path, "PNG")
    print(f"  Created {output_path} ({width}x{height})")


def main():
    repo_root = Path(__file__).resolve().parent.parent
    output_dir = repo_root / "dmg-resources"
    output_dir.mkdir(exist_ok=True)

    print("Generating DMG backgrounds...")
    generate_background(660, 400, 1, output_dir / "background.png")
    generate_background(1320, 800, 2, output_dir / "background@2x.png")
    print("Done.")


if __name__ == "__main__":
    main()

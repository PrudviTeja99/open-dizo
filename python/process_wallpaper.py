#!/usr/bin/env python3
"""
DIZO Watch D Wallpaper / Watch Face Image Processor
Converts any image into the exact hardware specifications for DIZO Watch D:
- Native Screen Resolution: 240 x 286 pixels (LCD Type 21)
- Color Encoding: 16-bit RGB565 (Big-Endian)
- Aspect Ratio: Center-crop to 240:286 (~0.839)
"""

import sys
import os
import argparse
from PIL import Image

TARGET_WIDTH = 240
TARGET_HEIGHT = 286

def process_wallpaper(input_path: str, output_dir: str = None, quality: int = 85):
    if not os.path.isfile(input_path):
        print(f"❌ Error: File not found: {input_path}")
        return False

    if output_dir is None:
        output_dir = os.path.dirname(input_path) or "."

    base_name = os.path.splitext(os.path.basename(input_path))[0]

    img = Image.open(input_path).convert("RGB")
    orig_w, orig_h = img.size
    print(f"\n🖼️ Processing Wallpaper: {os.path.basename(input_path)}")
    print(f"Original Dimensions: {orig_w} x {orig_h}")

    # Center crop to target aspect ratio (240 / 286)
    target_ratio = TARGET_WIDTH / TARGET_HEIGHT
    orig_ratio = orig_w / orig_h

    if orig_ratio > target_ratio:
        # Original is wider -> crop left/right
        new_w = int(orig_h * target_ratio)
        left = (orig_w - new_w) // 2
        img_cropped = img.crop((left, 0, left + new_w, orig_h))
    else:
        # Original is taller -> crop top/bottom
        new_h = int(orig_w / target_ratio)
        top = (orig_h - new_h) // 2
        img_cropped = img.crop((0, top, orig_w, top + new_h))

    # Resize with high quality Lanczos resampling
    img_resized = img_cropped.resize((TARGET_WIDTH, TARGET_HEIGHT), Image.Resampling.LANCZOS)

    # 1. Output 240x286 PNG
    png_path = os.path.join(output_dir, f"{base_name}_240x286.png")
    img_resized.save(png_path, "PNG", optimize=True)

    # 2. Output 240x286 Compressed JPEG
    jpg_path = os.path.join(output_dir, f"{base_name}_240x286.jpg")
    img_resized.save(jpg_path, "JPEG", quality=quality, optimize=True)

    # 3. Output 16-bit RGB565 Raw Binary Bitmap (for HTSmart DialWriter)
    # Formula from DialWriter.java:
    # b0 = ((r >> 3) << 3) | ((g >> 2) >> 3)
    # b1 = (((g >> 2) & 0x07) << 5) | (b >> 3)
    rgb565_bytes = bytearray()
    for y in range(TARGET_HEIGHT):
        for x in range(TARGET_WIDTH):
            r, g, b = img_resized.getpixel((x, y))
            r5 = (r >> 3) & 0x1F
            g6 = (g >> 2) & 0x3F
            b5 = (b >> 3) & 0x1F
            b0 = (r5 << 3) | (g6 >> 3)
            b1 = ((g6 & 0x07) << 5) | b5
            rgb565_bytes.append(b0)
            rgb565_bytes.append(b1)

    raw_path = os.path.join(output_dir, f"{base_name}_240x286_rgb565.raw")
    with open(raw_path, "wb") as f:
        f.write(rgb565_bytes)

    print(f"\n✅ Successfully generated:")
    print(f"  • PNG:     {png_path} ({os.path.getsize(png_path):,} bytes)")
    print(f"  • JPEG:    {jpg_path} ({os.path.getsize(jpg_path):,} bytes)")
    print(f"  • RGB565:  {raw_path} ({len(rgb565_bytes):,} bytes, exactly 240x286x2)")
    return True

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    default_img = os.path.normpath(os.path.join(script_dir, "..", "wallpapers", "wp3989732-smart-watch-wallpapers.jpg"))

    parser = argparse.ArgumentParser(description="DIZO Watch D Wallpaper Processor")
    parser.add_argument("image", nargs="?", default=default_img, help="Path to input image")
    parser.add_argument("--out-dir", default=None, help="Output directory")
    parser.add_argument("--quality", type=int, default=85, help="JPEG compression quality (1-100)")
    args = parser.parse_args()

    process_wallpaper(args.image, args.out_dir, args.quality)

if __name__ == "__main__":
    main()

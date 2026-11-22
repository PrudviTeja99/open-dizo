#!/usr/bin/env python3
"""
DIZO Watch D - Custom Dial Generator & Packager
Custom Dial Generator for DIZO Watch D (Realtek Platform Ext format)
"""

import os
import sys
import struct
import argparse
from PIL import Image

# HTSmart CRC16 Lookup Table (from DialWriter.java)
CRC_TABLE = [
    0, 49345, 49537, 320, 49921, 960, 640, 49729, 50689, 1728, 1920, 51009, 1280, 50625, 50305, 1088,
    52225, 3264, 3456, 52545, 3840, 53185, 52865, 3648, 2560, 51905, 52097, 2880, 51457, 2496, 2176, 51265,
    55297, 6336, 6528, 55617, 6912, 56257, 55937, 6720, 7680, 57025, 57217, 8000, 56577, 7616, 7296, 56385,
    5120, 54465, 54657, 5440, 55041, 6080, 5760, 54849, 53761, 4800, 4992, 54081, 4352, 53697, 53377, 4160,
    61441, 12480, 12672, 61761, 13056, 62401, 62081, 12864, 13824, 63169, 63361, 14144, 62721, 13760, 13440, 62529,
    15360, 64705, 64897, 15680, 65281, 16320, 16000, 65089, 64001, 15040, 15232, 64321, 14592, 63937, 63617, 14400,
    10240, 59585, 59777, 10560, 60161, 11200, 10880, 59969, 60929, 11968, 12160, 61249, 11520, 60865, 60545, 11328,
    58369, 9408, 9600, 58689, 9984, 59329, 59009, 9792, 8704, 58049, 58241, 9024, 57601, 8640, 8320, 57409,
    40961, 24768, 24960, 41281, 25344, 41921, 41601, 25152, 26112, 42689, 42881, 26432, 42241, 26048, 25728, 42049,
    27648, 44225, 44417, 27968, 44801, 28608, 28288, 44609, 43521, 27328, 27520, 43841, 26880, 43457, 43137, 26688,
    30720, 47297, 47489, 31040, 47873, 31680, 31360, 47681, 48641, 32448, 32640, 48961, 32000, 48577, 48257, 31808,
    46081, 29888, 30080, 46401, 30464, 47041, 46721, 30272, 29184, 45761, 45953, 29504, 45313, 29120, 28800, 45121,
    20480, 37057, 37249, 20800, 37633, 21440, 21120, 37441, 38401, 22208, 22400, 38721, 21760, 38337, 38017, 21568,
    39937, 23744, 23936, 40257, 24320, 40897, 40577, 24128, 23040, 39617, 39809, 23360, 39169, 22976, 22656, 38977,
    34817, 18624, 18816, 35137, 19200, 35777, 35457, 19008, 19968, 36545, 36737, 20288, 36097, 19904, 19584, 35905,
    17408, 33985, 34177, 17728, 34561, 18368, 18048, 34369, 33281, 17088, 17280, 33601, 16640, 33217, 32897, 16448
]

def calculate_crc16(data, crc=0):
    for b in data:
        crc = CRC_TABLE[(crc ^ b) & 0xFF] ^ (crc >> 8)
    return crc & 0xFFFF

def update_dial_crc16(bin_bytes: bytearray) -> int:
    """Updates offset 518..519 with the CRC16 checksum according to DialWriter.a(RandomAccessFile)"""
    length = len(bin_bytes)
    bArr = bytearray(bin_bytes[512:])
    for i in range(372, 404):
        bArr[i] = 0xFF
        
    i4 = length - 1520
    crc1 = calculate_crc16(bArr[12:12+740], 0)
    crc2 = calculate_crc16(bArr[1008:1008+i4], crc1)
    if crc2 == 0:
        bArr[372] = 0
        crc1 = calculate_crc16(bArr[12:12+740], 0)
        crc2 = calculate_crc16(bArr[1008:1008+i4], crc1)
        
    bin_bytes[518] = crc2 & 0xFF
    bin_bytes[519] = (crc2 >> 8) & 0xFF
    return crc2

def image_to_rgb565_rows(img: Image.Image, target_w: int, target_h: int) -> list[bytearray]:
    """
    Resizes image to target dimensions and converts each row to Big-Endian RGB565 bytearray.
    Matches WriteGUI.java lines 846-850:
      bArr2[x*2] = ((G >> 5) | (R & 0xF8))
      bArr2[x*2+1] = (((G << 3) & 0xE0) | (B >> 3))
    """
    # Resize with aspect ratio preserved (center crop)
    img = img.convert('RGBA')
    w, h = img.size
    scale = max(target_w / w, target_h / h)
    new_w = int(w * scale)
    new_h = int(h * scale)
    resized = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
    
    # Center crop to target_w, target_h
    left = (new_w - target_w) // 2
    top = (new_h - target_h) // 2
    cropped = resized.crop((left, top, left + target_w, top + target_h))
    
    rows = []
    for y in range(target_h):
        row = bytearray(target_w * 2)
        for x in range(target_w):
            r, g, b, a = cropped.getpixel((x, y))
            if a <= 90:
                r, g, b = 0, 0, 0
            # RGB565 big endian
            row[x * 2] = ((g >> 5) | (r & 0xF8)) & 0xFF
            row[x * 2 + 1] = (((g << 3) & 0xE0) | (b >> 3)) & 0xFF
        rows.append(row)
    return rows

def build_dial(template_path: str,
               image_path: str,
               output_path: str,
               time_position: str = 'bottom') -> str:
    """Injects wallpaper into template and creates a valid custom dial .bin"""
    print(f"[*] Reading base template from {template_path}...")
    with open(template_path, 'rb') as f:
        bin_data = bytearray(f.read())
        
    print(f"[*] Template size: {len(bin_data)} bytes")
    
    # 1. Parse header
    addr_offset = struct.unpack('<I', bin_data[1552:1556])[0]
    lcd_w, lcd_h = struct.unpack('<HH', bin_data[1568:1572])
    print(f"[*] LCD Resolution: {lcd_w}x{lcd_h}, addr_offset: {addr_offset}")
    
    offset_c = addr_offset + 1536
    c_bytes = bin_data[offset_c:offset_c+76]
    control_offset, control_number, control_size = struct.unpack('<IHH', c_bytes[0:8])
    bitmap_index_offset, bitmap_index_number = struct.unpack('<IH', c_bytes[8:14])
    
    # 2. Open wallpaper
    print(f"[*] Loading custom wallpaper: {image_path}...")
    input_image = Image.open(image_path)
    
    # 3. Inject Background (Bitmap 180, 240x286)
    bg_rows = image_to_rgb565_rows(input_image, 240, 286)
    addr_180 = 328328
    print("[*] Injecting 240x286 Background into Bitmap #180...")
    for y in range(286):
        ptr_offset = addr_180 + y * 4 + 1536
        row_addr = struct.unpack('<I', bin_data[ptr_offset:ptr_offset+4])[0] + 1536
        bin_data[row_addr:row_addr + 480] = bg_rows[y]
        
    # 4. Inject Preview Thumbnail (Bitmap 181, 160x190)
    preview_rows = image_to_rgb565_rows(input_image, 160, 190)
    addr_181 = 466756
    print("[*] Injecting 160x190 Preview Thumbnail into Bitmap #181...")
    for y in range(190):
        ptr_offset = addr_181 + y * 4 + 1536
        row_addr = struct.unpack('<I', bin_data[ptr_offset:ptr_offset+4])[0] + 1536
        bin_data[row_addr:row_addr + 320] = preview_rows[y]
        
    # 5. Position Digital Clock (BOTTOM, TOP, LEFT, RIGHT)
    pos_coords = {
        'bottom': (60, 198),
        'top': (60, 8),
        'left': (20, 103),
        'right': (102, 103)
    }
    target_pos = pos_coords.get(time_position.lower(), (60, 198))
    print(f"[*] Setting clock position to '{time_position.upper()}': {target_pos}...")
    
    # Update cVar.q[0]
    struct.pack_into('<hh', bin_data, addr_offset + 1536 + 38, target_pos[0], target_pos[1])
    # Update Control #4 (TIME_STYLE)
    struct.pack_into('<hh', bin_data, control_offset + 4 * control_size + 1536 + 4, target_pos[0], target_pos[1])
    
    # 6. Recalculate CRC16
    crc = update_dial_crc16(bin_data)
    print(f"[*] Recalculated CRC16: 0x{crc:04X} (written to offset 518..519)")
    
    # 7. Write output
    with open(output_path, 'wb') as f:
        f.write(bin_data)
        
    print(f"[+] Successfully generated custom dial binary at: {output_path} ({len(bin_data)} bytes)")
    return output_path

if __name__ == '__main__':
    script_dir = os.path.dirname(os.path.abspath(__file__))
    default_img = os.path.normpath(os.path.join(script_dir, "..", "wallpapers", "wp3989732-smart-watch-wallpapers.jpg"))
    default_tpl = os.path.normpath(os.path.join(script_dir, "..", "watch dial templates", "ota.bin"))
    default_out = os.path.normpath(os.path.join(script_dir, "..", "watch dial templates", "custom_wallpaper_dial.bin"))

    parser = argparse.ArgumentParser(description="DIZO Watch D Custom Dial Builder")
    parser.add_argument("--image", "-i", default=default_img, help="Path to input image")
    parser.add_argument("--template", "-t", default=default_tpl, help="Base template ota.bin")
    parser.add_argument("--output", "-o", default=default_out, help="Output .bin path")
    parser.add_argument("--position", "-p", choices=['top', 'bottom', 'left', 'right'], default='top', help="Digital clock placement")
    
    args = parser.parse_args()
    build_dial(args.template, args.image, args.output, args.position)

#!/usr/bin/env python3
"""
DIZO Watch D - Custom Watch Face Flasher
Direct BLE Flasher using Realtek Silent DFU Protocol with Hardware AES-256 Encryption.

Hardware: Realtek RTL8762D (icType: 9)
Services & Characteristics:
- Wristband Service: 000001ff-3c17-d293-8e48-14fe2e4da212
  - Write:  0000ff02-0000-1000-8000-00805f9b34fb
  - Notify: 0000ff03-0000-1000-8000-00805f9b34fb
- Realtek DFU Service:
  - Control Point: 00006487-3c17-d293-8e48-14fe2e4da212 (Write with response, Notify)
  - Data Endpoint: 00006387-3c17-d293-8e48-14fe2e4da212 (Write without response)

Encryption:
- AES-256 ECB with key: 4E46F8C5092B29E29A971A0CD1F610FB1F6763DF807A7E70960D4CD3118E601A
- 16-byte header in START_DFU (0x01) is encrypted
- 16-byte blocks in streaming sub-packets are encrypted
- Buffer check 0x0A calculates checksum over the encrypted transmitted payload
"""

import sys
import os
import time
import argparse
import struct
import ctypes
import dbus
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

DEFAULT_MAC = "CC:EA:FF:AA:42:7F"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_BIN = os.path.normpath(os.path.join(SCRIPT_DIR, "..", "watch dial templates", "custom_wallpaper_dial.bin"))

# Realtek AES-256 Encryption Setup using OpenSSL libcrypto
libcrypto = ctypes.CDLL("libcrypto.so")
libcrypto.AES_set_encrypt_key.argtypes = [ctypes.c_char_p, ctypes.c_int, ctypes.c_void_p]
libcrypto.AES_set_encrypt_key.restype = ctypes.c_int
libcrypto.AES_ecb_encrypt.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_void_p, ctypes.c_int]
libcrypto.AES_ecb_encrypt.restype = None

AES_KEY_BYTES = bytes.fromhex("4E46F8C5092B29E29A971A0CD1F610FB1F6763DF807A7E70960D4CD3118E601A")
aes_ctx = ctypes.create_string_buffer(244)
libcrypto.AES_set_encrypt_key(AES_KEY_BYTES, 256, aes_ctx)

def aes_encrypt_block(b16: bytes) -> bytes:
    """Encrypt exactly 16 bytes with AES-256 ECB"""
    out = ctypes.create_string_buffer(16)
    libcrypto.AES_ecb_encrypt(b16, out, aes_ctx, 1)
    return bytes(out.raw)

def aes_encrypt_packet(data: bytes) -> bytes:
    """Encrypt 16-byte blocks with AES-256 ECB, leaving trailing bytes < 16 unencrypted."""
    length = len(data)
    blocks = length // 16
    enc = bytearray()
    for i in range(blocks):
        enc.extend(aes_encrypt_block(data[i*16 : (i+1)*16]))
    if length % 16 != 0:
        enc.extend(data[blocks*16 : length])
    return bytes(enc)

# HTSmart CRC16 Lookup Table
CRC16_TABLE = [
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

def htsmart_crc16(data: bytes) -> int:
    crc = 0
    for b in data:
        crc = (crc >> 8) ^ CRC16_TABLE[(b ^ crc) & 0xFF]
    return crc & 0xFFFF

def build_htsmart_packet(cmd_id: int, key_id: int, payload: bytes = b'', seq: int = 1) -> bytes:
    key_packet = bytes([key_id, (len(payload) >> 8) & 0xFF, len(payload) & 0xFF]) + payload
    cmd_packet = bytes([cmd_id, 0x00]) + key_packet
    length = len(cmd_packet)
    crc = htsmart_crc16(cmd_packet)
    header = bytes([0xAB, 0x00, (length >> 8) & 0xFF, length & 0xFF, (crc >> 8) & 0xFF, crc & 0xFF, (seq >> 8) & 0xFF, seq & 0xFF])
    return header + cmd_packet

def rtk_dfu_checksum(data: bytes) -> int:
    """Realtek 16-bit word XOR checksum as defined in BaseDfuTask.a()"""
    s = 0
    for i in range(len(data) // 2):
        val = data[i * 2] | (data[i * 2 + 1] << 8)
        s = (s ^ val) & 0xFFFF
    return ((s & 0xFF) << 8) | ((s & 0xFF00) >> 8)

class DizoFlasher:
    def __init__(self, mac: str = DEFAULT_MAC, packet_size: int = 240, inter_packet_delay: float = 0.005):
        self.mac = mac
        self.mac_clean = mac.replace(":", "_")
        self.packet_size = packet_size
        self.delay = inter_packet_delay
        self.bus = None
        self.ff02 = None
        self.ff03 = None
        self.c6487 = None
        self.c6387 = None
        self.c6487_events = []
        self.ff03_events = []

    def init_dbus(self):
        DBusGMainLoop(set_as_default=True)
        self.bus = dbus.SystemBus()
        mgr = dbus.Interface(self.bus.get_object("org.bluez", "/"), "org.freedesktop.DBus.ObjectManager")
        objects = mgr.GetManagedObjects()

        for path, ifaces in objects.items():
            if self.mac_clean in path and "org.bluez.GattCharacteristic1" in ifaces:
                uuid = str(ifaces["org.bluez.GattCharacteristic1"]["UUID"]).lower()
                obj = self.bus.get_object("org.bluez", path)
                if "ff02" in uuid:
                    self.ff02 = dbus.Interface(obj, "org.bluez.GattCharacteristic1")
                elif "ff03" in uuid:
                    self.ff03 = dbus.Interface(obj, "org.bluez.GattCharacteristic1")
                elif "6487" in uuid:
                    self.c6487 = dbus.Interface(obj, "org.bluez.GattCharacteristic1")
                elif "6387" in uuid:
                    self.c6387 = dbus.Interface(obj, "org.bluez.GattCharacteristic1")

        if not all([self.ff02, self.ff03, self.c6487, self.c6387]):
            raise RuntimeError(f"Missing required BLE GATT characteristics for {self.mac}. Ensure device is paired & connected.")

        self.bus.add_signal_receiver(
            self._on_prop_changed,
            dbus_interface="org.freedesktop.DBus.Properties",
            signal_name="PropertiesChanged"
        )

        try:
            self.ff03.StartNotify()
        except Exception:
            pass

        try:
            self.c6487.StartNotify()
        except Exception:
            pass

    def _on_prop_changed(self, iface, changed, invalidated):
        if "Value" in changed:
            val = bytes(changed["Value"])
            if len(val) >= 2 and val[0] == 0xAB:
                self.ff03_events.append(val)
            elif len(val) >= 7 and val[0] == 0x01 and val[1] == 0x00:
                self.ff03_events.append(val)
            elif len(val) >= 2 and val[0] == 0x10:
                self.c6487_events.append(val)
                print(f"  [DFU NOTIF] {val.hex().upper()}")

    def pump(self, timeout_s: float = 1.0):
        ctx = GLib.MainContext.default()
        start = time.time()
        while time.time() - start < timeout_s:
            while ctx.pending():
                ctx.iteration(False)
            time.sleep(0.005)

    def wait_for_c6487_opcode(self, opcode: int, timeout_s: float = 5.0) -> bytes:
        ctx = GLib.MainContext.default()
        start = time.time()
        while time.time() - start < timeout_s:
            while ctx.pending():
                ctx.iteration(False)
            for i, ev in enumerate(self.c6487_events):
                if len(ev) >= 2 and ev[0] == 0x10 and ev[1] == opcode:
                    return self.c6487_events.pop(i)
            time.sleep(0.01)
        return None

    def flash_dial(self, bin_path: str):
        if not os.path.exists(bin_path):
            raise FileNotFoundError(f"Dial bin file not found: {bin_path}")

        with open(bin_path, "rb") as f:
            full_bin = f.read()

        file_size = len(full_bin)
        if file_size <= 524:
            raise ValueError(f"Bin file size ({file_size} bytes) too small!")

        # In Realtek Silent DFU:
        # Bytes 0..512: Multi-Pack Header
        # Bytes 512..524: 12-byte Image Header (armed via START_DFU opcode 0x01 with AES encryption)
        # Bytes 524..end: 529,336 bytes stream payload (streamed via 00006387 with AES encryption)
        image_header = full_bin[512:524]
        stream_data = full_bin[524:]
        total_stream_bytes = len(stream_data)

        print(f"📦 Dial Image: {os.path.basename(bin_path)}")
        print(f"📊 Total File Size: {file_size:,} bytes")
        print(f"🧩 Image Header: {image_header.hex(' ').upper()}")
        print(f"🚀 Stream Payload Size: {total_stream_bytes:,} bytes")
        print(f"⚡ MTU Packet Size: {self.packet_size} bytes | Inter-packet Delay: {self.delay*1000:.1f}ms")
        print("🔐 AES-256 Hardware Encryption: ENABLED (Key Loaded)")

        # Step 1: Handshake 1 - HTSmart Enter OTA
        print("\n[1/5] 🤝 Requesting Watch OTA Mode (HTSmart)...")
        self.ff03_events.clear()
        self.c6487_events.clear()
        ota_req = build_htsmart_packet(0x01, 0x01)
        self.ff02.WriteValue(list(ota_req), {})
        self.pump(1.2)

        # Check for enter OTA response
        ota_ready = False
        for ev in self.ff03_events:
            if len(ev) >= 7 and ev[0] == 0x01 and ev[1] == 0x00 and ev[2] == 0x02 and ev[6] == 0x00:
                ota_ready = True
                break
            if len(ev) >= 2 and ev[0] == 0xAB and ev[1] == 0x10:
                ota_ready = True

        if not ota_ready:
            print("  ⚠️ Note: Enter OTA ACK not explicitly seen, continuing...")
        else:
            print("  ✅ Watch accepted OTA request.")

        # Step 2: Handshake 2 - Enable Buffer Check Mode (0x09)
        print("[2/5] ⚙️  Enabling Realtek Buffer Check Mode (0x09)...")
        self.c6487.WriteValue([0x09], {})
        res_09 = self.wait_for_c6487_opcode(0x09, timeout_s=3.0)
        if res_09:
            status = res_09[2]
            max_buf = struct.unpack("<H", res_09[3:5])[0] if len(res_09) >= 5 else 4096
            mtu = struct.unpack("<H", res_09[5:7])[0] if len(res_09) >= 7 else 247
            print(f"  ✅ Buffer Check Enabled: Status={status}, MaxBuf={max_buf}B, MTU={mtu}B")
        else:
            print("  ⚠️ No response to 0x09, assuming default 4096B buffer.")

        # Step 3: Handshake 3 & 4 - Start DFU (0x01) & Receive FW Image (0x02)
        print("[3/5] 📋 Preparing DFU Session (0x01, 0x02)...")
        image_id = 0x27A1  # Platform Ext / Dial Image ID

        # Send 0x01: START_DFU (12-byte image header + 4 zeroes, AES-256 encrypted)
        print("  🚀 Sending START_DFU (0x01) with AES-Encrypted Image Header...")
        hdr16 = image_header + bytes(4)
        enc_hdr = aes_encrypt_block(hdr16)
        start_dfu_cmd = [0x01] + list(enc_hdr)
        self.c6487.WriteValue(start_dfu_cmd, {})
        res_01 = self.wait_for_c6487_opcode(0x01, timeout_s=3.0)
        if res_01 and len(res_01) >= 3 and res_01[2] == 0x01:
            print("  ✅ Watch accepted START_DFU (0x01: Header Staged & Decrypted).")
        else:
            status_01 = f"0x{res_01[2]:02X}" if res_01 and len(res_01) >= 3 else "No reply"
            raise RuntimeError(f"Watch rejected START_DFU (status: {status_01})!")

        # Send 0x02: RECEIVE_FW_IMAGE (imageId, offset = 12)
        offset_val = 12
        receive_cmd = [0x02, image_id & 0xFF, (image_id >> 8) & 0xFF,
                       offset_val & 0xFF, (offset_val >> 8) & 0xFF, (offset_val >> 16) & 0xFF, (offset_val >> 24) & 0xFF]
        self.c6487.WriteValue(receive_cmd, {})
        self.pump(0.1)

        # Step 4: Stream Dial Image in 4KB sector-aligned buffers
        print(f"\n[4/5] 📡 Streaming Watch Face ({total_stream_bytes:,} bytes, AES-256 encrypted)...")
        # Chunk 0: 4084 bytes (brings 12 to 4096 sector boundary)
        # Subsequent chunks: 4096 bytes each
        # Last chunk: 952 bytes
        chunks = []
        chunks.append(stream_data[0:4084])
        pos = 4084
        while pos < total_stream_bytes:
            end = min(pos + 4096, total_stream_bytes)
            chunks.append(stream_data[pos:end])
            pos = end

        total_chunks = len(chunks)
        t_start = time.time()
        bytes_sent = 0

        for chunk_idx, chunk in enumerate(chunks):
            chunk_len = len(chunk)
            max_retries = 3
            success = False

            for attempt in range(1, max_retries + 1):
                enc_chunk = bytearray()
                # Send chunk across 00006387 in sub-packets with AES-256 encryption
                for sub_offset in range(0, chunk_len, self.packet_size):
                    sub = chunk[sub_offset : min(sub_offset + self.packet_size, chunk_len)]
                    enc_sub = aes_encrypt_packet(sub)
                    enc_chunk.extend(enc_sub)
                    self.c6387.WriteValue(list(enc_sub), {"type": "command"})
                    if self.delay > 0:
                        time.sleep(self.delay)

                self.pump(0.05)

                # Send buffer check opcode 0x0A (CRC over encrypted transmitted chunk)
                sA = rtk_dfu_checksum(bytes(enc_chunk))
                buf_check = [0x0A, chunk_len & 0xFF, (chunk_len >> 8) & 0xFF, sA & 0xFF, (sA >> 8) & 0xFF]
                self.c6487.WriteValue(buf_check, {})

                # Wait for response 10 0A ...
                resp = self.wait_for_c6487_opcode(0x0A, timeout_s=4.0)
                if resp and len(resp) >= 3 and resp[2] == 0x01:
                    success = True
                    break
                else:
                    err_status = resp[2] if resp and len(resp) >= 3 else "Timeout"
                    print(f"\n  ⚠️ Buffer check retry {attempt}/{max_retries} for chunk {chunk_idx+1} (status: {err_status})...")
                    time.sleep(0.1)

            if not success:
                raise RuntimeError(f"Buffer check failed for chunk {chunk_idx+1}/{total_chunks} after {max_retries} retries!")

            bytes_sent += chunk_len
            pct = (bytes_sent / total_stream_bytes) * 100.0
            elapsed = time.time() - t_start
            speed = (bytes_sent / 1024.0) / elapsed if elapsed > 0 else 0
            eta = (total_stream_bytes - bytes_sent) / (speed * 1024.0) if speed > 0 else 0

            # Progress bar
            bar_len = 30
            filled = int(bar_len * (bytes_sent / total_stream_bytes))
            bar = "█" * filled + "░" * (bar_len - filled)
            sys.stdout.write(f"\r  [{bar}] {pct:5.1f}% | {bytes_sent:,}/{total_stream_bytes:,} B | {speed:5.1f} KB/s | ETA: {eta:4.1f}s")
            sys.stdout.flush()

        total_time = time.time() - t_start
        avg_speed = (total_stream_bytes / 1024.0) / total_time
        print(f"\n  ✅ Data transfer complete in {total_time:.1f}s ({avg_speed:.1f} KB/s)!")

        # Step 5: Validate & Activate Image
        print("\n[5/5] 🔒 Validating & Activating Custom Watch Face...")
        print(f"  ⏳ Sending VALIDATE_FW_IMAGE (0x03) for Image ID 0x{image_id:04X}...")
        print("  ⏳ Waiting up to 25s for watch bootloader flash CRC verification...")
        self.c6487_events.clear()
        self.c6487.WriteValue([0x03, image_id & 0xFF, (image_id >> 8) & 0xFF], {})
        res_03 = self.wait_for_c6487_opcode(0x03, timeout_s=25.0)

        if not res_03:
            raise TimeoutError("❌ Flash Validation TIMED OUT after 25s! Watch did not reply to opcode 0x03.")

        status = res_03[2] if len(res_03) >= 3 else 0xFF
        if status == 0x01:
            print("  ✅ Watch Firmware Image Validation: SUCCESS (Status 0x01: CRC Verified)!")
        elif status == 0x05:
            raise RuntimeError(f"❌ Flash Validation FAILED: CRC check error (Status 0x05)! Image corrupted or invalid.")
        else:
            raise RuntimeError(f"❌ Flash Validation FAILED with unexpected status: 0x{status:02X} (Raw: {res_03.hex().upper()})")

        # 0x04: ACTIVE_IMAGE_RESET (single byte 0x04 as in RTL8762D DFU SDK)
        print("  🔄 Sending ACTIVE_IMAGE_RESET (0x04) to reboot watch...")
        try:
            self.c6487.WriteValue([0x04], {})
            self.pump(1.5)
        except Exception:
            # Device reset triggers connection drop
            pass

        print("  ⏳ Waiting 6 seconds for DIZO Watch D to reboot...")
        time.sleep(6.0)

        # Reconnect to activate dial
        print("  🔄 Reconnecting to DIZO Watch D to verify / switch watch face...")
        os.system(f"bluetoothctl connect {self.mac} > /dev/null 2>&1")
        time.sleep(2.0)

        print("\n🎉 ======================================================= 🎉")
        print("🎉 SUCCESS: Custom watch face has been flashed and validated!")
        print("🎉 ======================================================= 🎉\n")

def main():
    parser = argparse.ArgumentParser(description="Flash custom watch face to DIZO Watch D over BLE")
    parser.add_argument("--file", "-f", default=DEFAULT_BIN, help="Path to custom dial .bin file")
    parser.add_argument("--mac", "-m", default=DEFAULT_MAC, help="Watch MAC address")
    parser.add_argument("--packet-size", "-p", type=int, default=240, help="MTU sub-packet size in bytes (default: 240)")
    parser.add_argument("--delay", "-d", type=float, default=0.005, help="Delay between sub-packets in seconds (default: 0.005)")
    args = parser.parse_args()

    flasher = DizoFlasher(mac=args.mac, packet_size=args.packet_size, inter_packet_delay=args.delay)
    print(f"Connecting to DIZO Watch D ({args.mac})...")
    flasher.init_dbus()
    flasher.flash_dial(args.file)

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
DIZO Watch D Bluetooth Utility & Protocol Tool
Bluetooth LE protocol client for DIZO Watch D (HTSmart / Realtek BLE).

Supported operations:
- Time Sync: sync current host time or set a custom time
- Watch Face (Dial): switch watch faces (0..N) or query watch face info
- Battery Status: read battery percentage, charging state, and voltage
- Find Watch: trigger vibration on the watch

GATT Services & Characteristics:
- Primary Service:       000001ff-3c17-d293-8e48-14fe2e4da212
- Write Characteristic:  0000ff02-0000-1000-8000-00805f9b34fb
- Notify Characteristic: 0000ff03-0000-1000-8000-00805f9b34fb
"""

import sys
import time
import argparse
import datetime
import dbus
from gi.repository import GLib
from dbus.mainloop.glib import DBusGMainLoop

MAC_ADDRESS = "CC:EA:FF:AA:42:7F"

# CRC16 Lookup Table from HTSmart SDK (CRC16-IBM / Arc variant)
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

def crc16(data: bytes) -> int:
    crc = 0
    for b in data:
        crc = (crc >> 8) ^ CRC16_TABLE[(b ^ crc) & 0xFF]
    return crc & 0xFFFF

def build_htsmart_packet(cmd_id: int, key_id: int, payload: bytes = b"", seq: int = 1) -> bytes:
    """Builds a standard 8-byte header + CmdPacket + KeyPacket HTSmart frame."""
    key_packet = bytes([key_id, (len(payload) >> 8) & 0xFF, len(payload) & 0xFF]) + payload
    cmd_packet = bytes([cmd_id, 0x00]) + key_packet
    length = len(cmd_packet)
    crc = crc16(cmd_packet)
    header = bytes([
        0xAB,
        0x00,
        (length >> 8) & 0xFF,
        length & 0xFF,
        (crc >> 8) & 0xFF,
        crc & 0xFF,
        (seq >> 8) & 0xFF,
        seq & 0xFF,
    ])
    return header + cmd_packet

def build_time_payload(dt: datetime.datetime) -> bytes:
    year_val = dt.year - 2000
    month = dt.month
    day = dt.day
    hour = dt.hour
    minute = dt.minute
    second = dt.second

    # 4-byte packed date/time
    b0 = ((year_val << 2) | (month >> 2)) & 0xFF
    b1 = ((month << 6) | (day << 1) | (hour >> 4)) & 0xFF
    b2 = ((hour << 4) | (minute >> 2)) & 0xFF
    b3 = ((minute << 6) | second) & 0xFF
    return bytes([b0, b1, b2, b3])

class DizoWatchClient:
    def __init__(self, mac: str = MAC_ADDRESS):
        self.mac = mac
        self.mac_clean = mac.replace(":", "_")
        self.write_char = None
        self.notify_char = None
        self.bus = None
        self.seq = 1

    def connect_dbus(self) -> bool:
        DBusGMainLoop(set_as_default=True)
        self.bus = dbus.SystemBus()
        mgr = dbus.Interface(self.bus.get_object("org.bluez", "/"), "org.freedesktop.DBus.ObjectManager")
        objects = mgr.GetManagedObjects()

        for path, ifaces in objects.items():
            if self.mac_clean in path and "org.bluez.GattCharacteristic1" in ifaces:
                uuid = str(ifaces["org.bluez.GattCharacteristic1"]["UUID"]).lower()
                if "ff02" in uuid:
                    self.write_char = dbus.Interface(self.bus.get_object("org.bluez", path), "org.bluez.GattCharacteristic1")
                elif "ff03" in uuid:
                    self.notify_char = dbus.Interface(self.bus.get_object("org.bluez", path), "org.bluez.GattCharacteristic1")

        if not self.write_char:
            print(f"❌ Error: Could not find characteristic FF02 for {self.mac}.")
            print("Please ensure the watch is paired/connected in bluetoothctl.")
            return False

        if self.notify_char:
            try:
                self.notify_char.StartNotify()
            except Exception:
                pass
        return True

    def send_and_wait(self, packet: bytes, timeout_s: float = 2.0, callback=None) -> bool:
        loop = GLib.MainLoop()
        ack_received = [False]

        def on_prop_changed(iface, changed, invalidated):
            if "Value" in changed:
                val = bytes(changed["Value"])
                if len(val) >= 2 and val[0] == 0xAB and val[1] in (0x10, 0x30):
                    ack_received[0] = True
                if callback:
                    callback(val)

        handler = self.bus.add_signal_receiver(
            on_prop_changed,
            dbus_interface="org.freedesktop.DBus.Properties",
            signal_name="PropertiesChanged"
        )

        # Write packet
        self.write_char.WriteValue([dbus.Byte(b) for b in packet], dbus.Dictionary({}, signature="sv"))
        GLib.timeout_add(int(timeout_s * 1000), loop.quit)
        loop.run()
        handler.remove()
        return ack_received[0]

    def sync_time(self, target_dt: datetime.datetime = None) -> bool:
        if target_dt is None:
            target_dt = datetime.datetime.now()

        payload = build_time_payload(target_dt)
        packet = build_htsmart_packet(cmd_id=0x02, key_id=0x01, payload=payload, seq=self.seq)
        self.seq += 1

        print(f"\n--- Syncing DIZO Watch D Time ---")
        print(f"Target Time:    {target_dt.strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"Hex Packet:     {packet.hex().upper()} ({len(packet)} bytes)")

        def on_notify(val: bytes):
            if len(val) >= 2 and val[0] == 0xAB and val[1] in (0x10, 0x30):
                print(f"✅ Watch ACK:   {val.hex().upper()} (Time successfully updated!)")

        ack = self.send_and_wait(packet, timeout_s=2.0, callback=on_notify)
        return ack

    def switch_dial(self, dial_index: int) -> bool:
        payload = bytes([dial_index & 0xFF])
        # cmdId = 0x02, keyId = 0x70 (112: setDialComponents)
        packet = build_htsmart_packet(cmd_id=0x02, key_id=0x70, payload=payload, seq=self.seq)
        self.seq += 1

        print(f"\n--- Switching Watch Face (Dial #{dial_index}) ---")
        print(f"Target Dial:    {dial_index}")
        print(f"Hex Packet:     {packet.hex().upper()}")

        def on_notify(val: bytes):
            if len(val) >= 2 and val[0] == 0xAB and val[1] in (0x10, 0x30):
                print(f"✅ Watch ACK:   {val.hex().upper()} (Watch face switched!)")

        ack = self.send_and_wait(packet, timeout_s=2.0, callback=on_notify)
        return ack

    def get_dial_info(self):
        print(f"\n--- Querying Watch Face Information ---")
        # 1. Query DialUiInfo (cmd=2, key=0x43 / 67)
        pkt1 = build_htsmart_packet(cmd_id=0x02, key_id=0x43, payload=b"", seq=self.seq)
        self.seq += 1

        def on_ui_info(val: bytes):
            if len(val) >= 11 and val[0] == 0x02 and val[2] == 0x44:
                # KeyPacket: cmd=2, key=0x44 (68)
                ui_num = (val[5] << 8) | val[6]
                ui_serial = (val[7] << 8) | val[8]
                style_index = (val[9] << 8) | val[10]
                print(f"Active UI Number:    {ui_num}")
                print(f"Active UI Serial:    {ui_serial}")
                print(f"Active Style Index:  {style_index}")

        self.send_and_wait(pkt1, timeout_s=1.5, callback=on_ui_info)

        # 2. Query DialBinInfo (cmd=2, key=0x52 / 82)
        pkt2 = build_htsmart_packet(cmd_id=0x02, key_id=0x52, payload=b"", seq=self.seq)
        self.seq += 1

        def on_bin_info(val: bytes):
            if len(val) >= 14 and val[0] == 0x02 and val[2] == 0x53:
                # KeyPacket: cmd=2, key=0x53 (83)
                ui_num = (val[5] << 8) | val[6]
                ui_serial = (val[7] << 8) | val[8]
                dial_num = (val[9] << 8) | val[10]
                dial_pos = val[11]
                lcd_type = val[12]
                tool_ver = f"{val[13]}.{val[14]}" if len(val) > 14 else "N/A"
                sub_dials = val[15] if len(val) > 15 else 0
                print(f"Installed Sub-Dials: {sub_dials}")
                print(f"Current Dial Num:    {dial_num} (Pos: {dial_pos})")
                print(f"LCD Hardware Type:   {lcd_type}")
                print(f"Dial Tool Version:   {tool_ver}")

        self.send_and_wait(pkt2, timeout_s=1.5, callback=on_bin_info)

    def get_battery(self):
        # cmd=2, key=27 / 0x1B
        packet = build_htsmart_packet(cmd_id=0x02, key_id=0x1B, payload=b"", seq=self.seq)
        self.seq += 1

        print(f"\n--- Querying Battery Status ---")
        battery_data = {}

        def on_notify(val: bytes):
            if len(val) >= 8 and val[0] == 0x02 and val[2] == 0x1C:
                is_charging = (val[5] == 1)
                level = val[6]
                percentage = val[7]
                battery_data["charging"] = is_charging
                battery_data["level"] = level
                battery_data["percent"] = percentage
                print(f"Battery Percentage:  {percentage}%")
                print(f"Charging State:      {'⚡ Charging' if is_charging else '🔋 Discharging'}")
                print(f"Battery Level Bar:   {level} / 4")

        self.send_and_wait(packet, timeout_s=1.5, callback=on_notify)

    def find_watch(self):
        # cmd=2, key=59 / 0x3B (findWristband)
        packet = build_htsmart_packet(cmd_id=0x02, key_id=0x3B, payload=b"", seq=self.seq)
        self.seq += 1

        print(f"\n--- Finding Watch (Vibrate) ---")
        def on_notify(val: bytes):
            if len(val) >= 2 and val[0] == 0xAB and val[1] in (0x10, 0x30):
                print("✅ Watch is vibrating!")

        self.send_and_wait(packet, timeout_s=2.0, callback=on_notify)

def main():
    parser = argparse.ArgumentParser(description="DIZO Watch D Bluetooth Utility & Protocol Tool")
    parser.add_argument("time_arg", nargs="?", default=None, help="Custom time to set (e.g. 16:20 or 16:20:00)")
    parser.add_argument("--sync-time", action="store_true", help="Sync watch with current host system time")
    parser.add_argument("--time", dest="custom_time", help="Set specific time (HH:MM or HH:MM:SS)")
    parser.add_argument("--dial", type=int, metavar="INDEX", help="Switch watch face to specified index (0, 1, 2, ...)")
    parser.add_argument("--dial-info", action="store_true", help="Query active watch face and dial storage information")
    parser.add_argument("--battery", action="store_true", help="Query current battery percentage and charging state")
    parser.add_argument("--find-watch", "--vibrate", action="store_true", help="Vibrate the watch (find device)")
    parser.add_argument("--mac", default=MAC_ADDRESS, help=f"Watch Bluetooth MAC address (default: {MAC_ADDRESS})")

    args = parser.parse_args()

    client = DizoWatchClient(mac=args.mac)
    if not client.connect_dbus():
        sys.exit(1)

    # Dial commands
    if args.dial is not None:
        client.switch_dial(args.dial)
        return

    if args.dial_info:
        client.get_dial_info()
        return

    # Battery
    if args.battery:
        client.get_battery()
        return

    # Find watch
    if args.find_watch:
        client.find_watch()
        return

    # Custom or current time
    target_time_str = args.custom_time or args.time_arg
    if target_time_str:
        parts = [int(p) for p in target_time_str.split(":")]
        h = parts[0]
        m = parts[1]
        s = parts[2] if len(parts) > 2 else 0
        now = datetime.datetime.now()
        target_dt = now.replace(hour=h, minute=m, second=s)
        client.sync_time(target_dt)
    else:
        # Default behavior: sync current time
        client.sync_time()

if __name__ == "__main__":
    main()

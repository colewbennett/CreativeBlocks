# creativeblocks_mpr121.py

import time
import board
import busio
import adafruit_mpr121
from pythonosc.udp_client import SimpleUDPClient

# ================================
# CONFIG
# ================================

SC_IP = "127.0.0.1"      # SuperCollider on same Raspberry Pi
SC_PORT = 57121          # must match SuperCollider ~myPort

POLL_DELAY = 0.05        # seconds

# MPR121 pad mapping:
# Pad 0 / Song 1 = electrodes 0, 1
# Pad 1 / Song 2 = electrodes 2, 3
# Pad 2 / Song 3 = electrodes 4, 5

PAD_SLOTS = {
    0: (0, 1),
    1: (2, 3),
    2: (4, 5),
}

USED_ELECTRODES = [0, 1, 2, 3, 4, 5]

# ================================
# SETUP
# ================================

print("Starting CreativeBlocks MPR121 reader...")

i2c = busio.I2C(board.SCL, board.SDA)
mpr121 = adafruit_mpr121.MPR121(i2c)

client = SimpleUDPClient(SC_IP, SC_PORT)

print(f"Sending OSC to {SC_IP}:{SC_PORT}")
print("Pad 0 uses MPR pins 0 and 1")
print("Pad 1 uses MPR pins 2 and 3")
print("Pad 2 uses MPR pins 4 and 5")
print("OSC format: /mpr slot on")
print("Example: /mpr 0 1")

# Store previous state so we only send changes
previous_states = {electrode: False for electrode in USED_ELECTRODES}

# ================================
# HELPERS
# ================================

def send_mpr(electrode, is_touched):
    value = 1 if is_touched else 0
    client.send_message("/mpr", [electrode, value])

    state_text = "ON" if is_touched else "OFF"
    print(f"Sent /mpr {electrode} {value}  ({state_text})")


def print_pad_state(states):
    print("Current pad states:")

    for pad, (left, right) in PAD_SLOTS.items():
        left_on = states[left]
        right_on = states[right]

        if left_on and right_on:
            detected = "DRUMS"
        elif left_on:
            detected = "VOCALS"
        elif right_on:
            detected = "MELODY"
        else:
            detected = "EMPTY"

        print(
            f"  Pad {pad}: "
            f"left pin {left}={left_on}, "
            f"right pin {right}={right_on} -> {detected}"
        )

    print("-" * 40)


# ================================
# MAIN LOOP
# ================================

try:
    print("Listening for touches...")
    print("-" * 40)

    while True:
        current_states = {}

        for electrode in USED_ELECTRODES:
            touched = mpr121[electrode].value
            current_states[electrode] = touched

            if touched != previous_states[electrode]:
                send_mpr(electrode, touched)
                previous_states[electrode] = touched

        print_pad_state(current_states)

        time.sleep(POLL_DELAY)

except KeyboardInterrupt:
    print("\nStopping CreativeBlocks MPR121 reader...")

    # Tell SuperCollider all used electrodes are off
    for electrode in USED_ELECTRODES:
        client.send_message("/mpr", [electrode, 0])
        print(f"Sent /mpr {electrode} 0")

    print("Done.")

import time
import board
import busio

from adafruit_mpr121 import MPR121
from pythonosc.udp_client import SimpleUDPClient

# =====================================================
# SUPERCOLLIDER OSC TARGET
# =====================================================

SC_IP = "127.0.0.1"
SC_PORT = 57121

sc = SimpleUDPClient(SC_IP, SC_PORT)

# =====================================================
# MPR121 SETUP
# =====================================================

i2c = busio.I2C(board.SCL, board.SDA)
mpr121 = MPR121(i2c)

# Pad 0 / Song 1 = slots 0 and 1
# Pad 1 / Song 2 = slots 2 and 3
# Pad 2 / Song 3 = slots 4 and 5
#
# SuperCollider decides:
# left only  = vocals
# right only = melody
# both       = drums

WATCHED_PINS = [0, 1, 2, 3, 4, 5]

last_states = {pin: False for pin in WATCHED_PINS}

# =====================================================
# STARTUP PRINTS
# =====================================================

print("====================================================")
print("CREATIVEBLOCKS MPR121 PYTHON SENDER")
print("====================================================")
print("Watching MPR121 pins 0, 1, 2, 3, 4, 5")
print("")
print("Pad 0 / Song 1 = pins 0 and 1")
print("Pad 1 / Song 2 = pins 2 and 3")
print("Pad 2 / Song 3 = pins 4 and 5")
print("")
print("Sending OSC messages in this format:")
print("/mpr slot on")
print("")
print(f"Sending OSC to {SC_IP}:{SC_PORT}")
print("====================================================")

# =====================================================
# MAIN LOOP
# =====================================================

while True:
    try:
        for pin in WATCHED_PINS:
            touched = mpr121[pin].value

            if touched != last_states[pin]:
                if touched:
                    print(f"Pin {pin} Touched")
                    sc.send_message("/mpr", [pin, 1])
                else:
                    print(f"Pin {pin} Released")
                    sc.send_message("/mpr", [pin, 0])

                last_states[pin] = touched

        time.sleep(0.01)

    except KeyboardInterrupt:
        print("\nExiting.")
        sc.send_message("/stopall", [1])
        break

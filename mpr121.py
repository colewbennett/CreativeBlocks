import time
import board
import RPi.GPIO as GPIO
import busio

from adafruit_mpr121 import MPR121
from pythonosc.udp_client import SimpleUDPClient

# SuperCollider OSC target
SC_IP = "127.0.0.1"
SC_PORT = 57120

# Which MPR121 electrode to watch
ELECTRODE = 0

# Create OSC client to SuperCollider
sc = SimpleUDPClient(SC_IP, SC_PORT)

#GPIO.setmode(GPIO.BCM)
#SCL_PIN = 9
#SDA_PIN = 8
#GPIO.setup(SCL_PIN, GPIO.IN)
# Set up I2C and MPR121
#i2c = busio.I2C(1, 0)
i2c = busio.I2C(board.SCL, board.SDA)
mpr121 = MPR121(i2c)

last_state = False

print(f"Watching electrode E{ELECTRODE}...")
print(f"Sending OSC to {SC_IP}:{SC_PORT}")

while True:
    try:
        touched = mpr121[ELECTRODE].value

        if touched != last_state:
            if touched:
                print("Touched")
                sc.send_message("/gate", 0)
            else:
                print("Released")
                sc.send_message("/gate", 1)

            last_state = touched

        time.sleep(0.01)

    except KeyboardInterrupt:
        print("\nExiting.")
        break
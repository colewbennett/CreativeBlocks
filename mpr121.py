import time
import board
import RPi.GPIO as GPIO
import busio

from adafruit_mpr121 import MPR121
from pythonosc.udp_client import SimpleUDPClient

# SuperCollider OSC target
SC_IP = "127.0.0.1"
SC_PORT = 57121

# Which MPR121 electrode to watch
pin0 = 0
pin1 = 1
pin2 = 2
pin3 = 3

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

last_state_0 = False
last_state_1 = False
last_state_2 = False
last_state_3 = False

print(f"Watching pins 0 1 2 3...")
print(f"Sending OSC to {SC_IP}:{SC_PORT}")

while True:
    try:
        touched0 = mpr121[pin0].value
        touched1 = mpr121[pin1].value
        touched2 = mpr121[pin2].value
        touched3 = mpr121[pin3].value

        if touched0 != last_state_0:
            if touched0:
                print("Pin 0 Touched")
                sc.send_message("/pad", [0, 0, 1])
            else:
                print("Pin 0 Released")
                sc.send_message("/pad", [0, 0, 0])

            last_state_0 = touched0
            
        if touched1 != last_state_1:
            if touched1:
                print("Pin 1 Touched")
                sc.send_message("/pad", [0, 1, 1])
            else:
                print("Pin 1 Released")
                sc.send_message("/pad", [0, 1, 0])

            last_state_1 = touched1
            
        if touched2 != last_state_2:
            if touched2:
                print("Pin 2 Touched")
                sc.send_message("/pad", [1, 0, 1])
            else:
                print("Pin 2 Released")
                sc.send_message("/pad", [1, 0, 0])

            last_state_2 = touched2

        if touched3 != last_state_3:
            if touched3:
                print("Pin 3 Touched")
                sc.send_message("/pad", [1, 1, 1])
            else:
                print("Pin 3 Released")
                sc.send_message("/pad", [1, 1, 0])

            last_state_3 = touched3

        time.sleep(0.01)

    except KeyboardInterrupt:
        print("\nExiting.")
        break

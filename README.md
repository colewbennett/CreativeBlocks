# creativeBlocks

<a target="_blank" href="https://cookiecutter-data-science.drivendata.org/">
    <img src="https://img.shields.io/badge/CCDS-Project%20template-328F97?logo=cookiecutter" />
</a>

Making a physical audio workstation.

## Project overview

Our system consists of four blocks that can be placed on four different pads to make different combinations of samples. Blocks can also be stacked, which expands the creative output of the physical audio workstation. Each block has two knobs that changes the reverb and delay levels of its designated sample.

## Requirements

### Hardware Requirements

- Raspberry Pi 3 Model B
- Keyboard
- Mouse
- Monitor
- HDMI cable
- Micro USB power supply cable
- Micro SD card
- Micro SD card reader
- Behringer U-PHORIA UMC202HD Audio Interface
- Quarter inch jack
- Speakers

Per block:

- Arduino Nano ESP32
- Adafruit MPR121
- 2 Potentiometers
- 4-AA battery pack
- DC barrel power jack
- Conductive tape

### Software Requirements

- Git
- Arduino IDE
- Raspberry Pi Imager
- SuperCollider (installed on RPi - see Software Setup)

## Software Setup

### Raspberry Pi OS

Follow the instructions on this website to install the RPi OS on the micro SD card using the RPi Imager software:
<https://www.raspberrypi.com/documentation/computers/getting-started.html#installing-the-operating-system>

After the Rpi is running, you’ll want to have it automatically connect to Colby Guest Access. First, get the MAC address of your RPi by typing this into the terminal:

ifconfig eth0

Then, follow the instructions on this website to register the RPi for Colby Guest Access:
<https://colby.teamdynamix.com/TDClient/1928/Portal/KB/ArticleDet?ID=146945>

### Enable I2C on Raspberry Pi

The MPR121 uses I2C, so I2C must be enabled before the touch sensor will work.

In the terminal, run:

`sudo raspi-config`

Then go to: Interface Options -> I2C -> Enable

After enabling I2C, reboot the Raspberry Pi if prompted.

To confirm the sensor can be detected later, run:

`i2cdetect -y 1`

If the MPR121 is connected correctly, it should usually appear at address 0x5a.

### SuperCollider on RPi

Follow the instructions in this link to install SuperCollider on RPi: <https://github.com/redFrik/supercolliderStandaloneRPI64>

### Arduino IDE

Follow this link to install the latest Arduino IDE software: <https://www.arduino.cc/en/software/>

Install these from the Arduino IDE:

- Boards Manager
  - Arduino ESP32 Boards by Arduino
- Library Manager
  - OSC by Adrian Freed
  - Adafruit MPR121 by Adafruit

## Test Code Instructions (WIP)

For each device include test code (in the repo) to check that the component is set up and/or wired correctly and working. Provide instructions on how to run test code for each component.

## Demo Operating Instructions

Connect the Arduino, MPR121, and potentiometers as outlined in the circuit diagram.

Run Arduino IDE on your computer and open the file called `nanoESP32.ino`. Make sure the ssid, passphrase, and outIP are configured correctly depending on your WiFi and IP address. Upload the updated code to the Arduino.

Download the file `amen-break-120bpm.mp3`. Run SuperCollider on the RPi and open the file called `pi.scd`. Make sure the path to the mp3 file is correct. While the cursor is hovering over `s.boot;` on line 1, press ctrl-enter. Once the SC server is booted, hover over the space right before the first open parenthesis on line 4, and press ctrl-enter.

If everything went well, you should hear the amen break sample. The two potentiometers should affect the reverb and delay of the sample, and touching the MPR121 should mute the sample.

## Potential Improvements

Using the Colby operated WiFi/ethernet network seems to cause lots of problems. A temporary fix is to use a personal hotspot on your phone, and configure the code to connect to that hotspot.

The SuperCollider code can be run on a computer other than a RPi. The only thing that wouldn't be possible is using the MPR121 connected to the RPi.

## References

Installing RPi OS: <https://www.raspberrypi.com/documentation/computers/getting-started.html#installing-the-operating-system>

Adding device to Colby Guest Access: <https://colby.teamdynamix.com/TDClient/1928/Portal/KB/ArticleDet?ID=146945>

SuperCollider on RPi: <https://github.com/redFrik/supercolliderStandaloneRPI64>

Arduino IDE: <https://www.arduino.cc/en/software/>

## Project Organization

```
├── LICENSE            <- Open-source license if one is chosen
├── Makefile           <- Makefile with convenience commands like `make data` or `make train`
├── README.md          <- The top-level README for developers using this project.
├── data
│   ├── external       <- Data from third party sources.
│   ├── interim        <- Intermediate data that has been transformed.
│   ├── processed      <- The final, canonical data sets for modeling.
│   └── raw            <- The original, immutable data dump.
│
├── docs               <- A default mkdocs project; see www.mkdocs.org for details
│
├── models             <- Trained and serialized models, model predictions, or model summaries
│
├── notebooks          <- Jupyter notebooks. Naming convention is a number (for ordering),
│                         the creator's initials, and a short `-` delimited description, e.g.
│                         `1.0-jqp-initial-data-exploration`.
│
├── pyproject.toml     <- Project configuration file with package metadata for 
│                         creativeblocks and configuration for tools like black
│
├── references         <- Data dictionaries, manuals, and all other explanatory materials.
│
├── reports            <- Generated analysis as HTML, PDF, LaTeX, etc.
│   └── figures        <- Generated graphics and figures to be used in reporting
│
├── requirements.txt   <- The requirements file for reproducing the analysis environment, e.g.
│                         generated with `pip freeze > requirements.txt`
│
├── setup.cfg          <- Configuration file for flake8
│
└── creativeblocks   <- Source code for use in this project.
    │
    ├── __init__.py             <- Makes creativeblocks a Python module
    │
    ├── config.py               <- Store useful variables and configuration
    │
    ├── dataset.py              <- Scripts to download or generate data
    │
    ├── features.py             <- Code to create features for modeling
    │
    ├── modeling                
    │   ├── __init__.py 
    │   ├── predict.py          <- Code to run model inference with trained models          
    │   └── train.py            <- Code to train models
    │
    └── plots.py                <- Code to create visualizations
```

--------

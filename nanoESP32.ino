#include <WiFi.h>
#include <WiFiUdp.h>
#include <OSCMessage.h>
#include "Adafruit_MPR121.h"

#ifndef _BV
#define _BV(bit) (1 << (bit))
#endif

// const char* ssid = "Colby Guest Access";
// Tristan's phone hotspot:
const char* ssid = "tristan";
const char* passphrase = "password";

WiFiUDP Udp;

Adafruit_MPR121 cap = Adafruit_MPR121();

// pins
const int reverbPin = A0;
const int delayPin = A1;

// optional smoothing / change threshold
float lastReverb = -1.0f;
float lastDelay = -1.0f;
const float changeThreshold = 0.01f;

// Keeps track of the last pins touched
// so we know when buttons are 'released'
uint16_t lasttouched = 0;
uint16_t currtouched = 0;

// Raspberry Pi running SuperCollider
// IPAddress outIp(137, 146, 183, 226);
// IPAddress outIp(10, 137, 224, 121);  // Tristan hotspot IP
IPAddress outIp(10, 137, 224, 160);  // RPi hotspot IP
const unsigned int outPort = 57121;

void sendOSCFloat(const char* address, float value) {
  OSCMessage msg(address);
  msg.add(value);
  Udp.beginPacket(outIp, outPort);
  msg.send(Udp);
  Udp.endPacket();
  msg.empty();
}

void sendOSCFloat(const char* address, float value1, float value2, float value3) {
  OSCMessage msg(address);
  msg.add(value1);
  msg.add(value2);
  msg.add(value3);
  Udp.beginPacket(outIp, outPort);
  msg.send(Udp);
  Udp.endPacket();
  msg.empty();
}

void checkTouch(uint16_t pin, bool print) {
  // it if *is* touched and *wasnt* touched before, alert!
  if ((currtouched & _BV(pin)) && !(lasttouched & _BV(pin)) ) {
    if (print) {
      Serial.println("ON");
    }
    // sendOSCFloat("/stack", 0, pin, 1);  // block 0
    sendOSCFloat("/stack", 1, pin, 1);  // block 1
  }
  // if it *was* touched and now *isnt*, alert!
  if (!(currtouched & _BV(pin)) && (lasttouched & _BV(pin)) ) {
    if (print) {
      Serial.println("OFF");
    }
    // sendOSCFloat("/stack", 0, pin, 0);  // block 0
    sendOSCFloat("/stack", 1, pin, 0);  // block 1
  }
  if ((currtouched & _BV(pin)) && (lasttouched & _BV(pin)) ) {
    if (print) {
      Serial.println("ON");
    }
  }
  if (!(currtouched & _BV(pin)) && !(lasttouched & _BV(pin)) ) {
    if (print) {
      Serial.println("OFF");
    }
  }
  if (!print) {
    Serial.println();
  }
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("Adafruit MPR121 Capacitive Touch sensor test");

  // Default address is 0x5A, if tied to 3.3V its 0x5B
  // If tied to SDA its 0x5C and if SCL then 0x5D
  if (!cap.begin(0x5A)) {
    Serial.println("MPR121 not found, check wiring?");
    while (1);
  }
  Serial.println("MPR121 found!");

  // This is generally recommended since it seems to work well for most setups.
  // Can remove if wanting to manually configure touch channels (CDC and CDT).
  Serial.println("Running auto configuration.");
  cap.setAutoconfig(true);

  Serial.println("Initialization complete.");

  Serial.println("Connecting to WiFi...");
  WiFi.mode(WIFI_STA);
  // WiFi.begin(ssid);  // use this if no passphrase needed
  WiFi.begin(ssid, passphrase);

  int tries = 0;
  while (WiFi.status() != WL_CONNECTED && tries < 60) {
    delay(500);
    Serial.print(".");
    tries++;
  }

  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("Connected!");
    Serial.print("ESP32 IP: ");
    Serial.println(WiFi.localIP());
    delay(3000);
  } else {
    Serial.print("WiFi failed, status = ");
    Serial.println(WiFi.status());
  }

  Udp.begin(8888);  // local UDP port on ESP32
}

void loop() {
  static unsigned long last = 0;

  if (WiFi.status() == WL_CONNECTED && millis() - last > 50) {
    last = millis();

    int rawReverb = analogRead(reverbPin);
    int rawDelay = analogRead(delayPin);

    float reverbNorm = rawReverb / 4095.0f;
    float delayNorm = rawDelay / 4095.0f;

    // Get the currently touched pads
    currtouched = cap.touched();

    // serial monitor output
    Serial.print("A0 raw: \t");
    Serial.print(rawReverb);
    Serial.print("\t reverb: \t");
    Serial.print(reverbNorm, 3);

    Serial.print("\t | A1 raw: \t");
    Serial.print(rawDelay);
    Serial.print("\t delay: \t");
    Serial.print(delayNorm, 3);
    Serial.print("\t cap: \t");

    checkTouch(0, 1);
    checkTouch(1, 1);
    checkTouch(2, 1);

    // reset our state
    lasttouched = currtouched;

    // send reverb only if it changed enough
    if (fabs(reverbNorm - lastReverb) > changeThreshold) {
      sendOSCFloat("/reverb", reverbNorm);
      lastReverb = reverbNorm;
    }

    // send delay only if it changed enough
    if (fabs(delayNorm - lastDelay) > changeThreshold) {
      sendOSCFloat("/delay", delayNorm);
      lastDelay = delayNorm;
    }
  }
}
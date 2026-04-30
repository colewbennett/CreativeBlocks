#include <WiFi.h>
#include <WiFiUdp.h>
#include <OSCMessage.h>
#include "Adafruit_MPR121.h"

#ifndef _BV
#define _BV(bit) (1 << (bit))
#endif

// =====================================================
// BLOCK ID — COMMENT OUT TWO OF THESE EACH UPLOAD
// =====================================================

// const int BLOCK_ID = 0; // DRUM BLOCK
// const int BLOCK_ID = 1; // VOCAL BLOCK
// const int BLOCK_ID = 2; // MEL BLOCK

// =====================================================
// WIFI
// =====================================================

const char* ssid = "tristan";
const char* passphrase = "password";

WiFiUDP Udp;
Adafruit_MPR121 cap = Adafruit_MPR121();

// Potentiometers
const int reverbPin = A0;
const int tempoPin = A1;

// Raspberry Pi running SuperCollider
IPAddress outIp(172, 17, 199, 160);
const unsigned int outPort = 57121;

// Smoothing
float lastReverb = -1.0f;
float lastTempo = -1.0f;
const float changeThreshold = 0.01f;

// Touch state
uint16_t lasttouched = 0;
uint16_t currtouched = 0;

// =====================================================
// OSC HELPERS
// =====================================================

void sendOSCFloat(const char* address, float value1, float value2) {
  OSCMessage msg(address);
  msg.add(value1);
  msg.add(value2);

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

// =====================================================
// TOUCH CHECK
// =====================================================

void checkTouch(uint16_t pin, bool print) {
  if ((currtouched & _BV(pin)) && !(lasttouched & _BV(pin))) {
    if (print) {
      Serial.print("Pin ");
      Serial.print(pin);
      Serial.println(" ON");
    }

    sendOSCFloat("/stack", BLOCK_ID, pin, 1);
  }

  if (!(currtouched & _BV(pin)) && (lasttouched & _BV(pin))) {
    if (print) {
      Serial.print("Pin ");
      Serial.print(pin);
      Serial.println(" OFF");
    }

    sendOSCFloat("/stack", BLOCK_ID, pin, 0);
  }
}

// =====================================================
// SETUP
// =====================================================

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("====================================================");
  Serial.println("CREATIVEBLOCKS ESP32 BLOCK");
  Serial.println("====================================================");

  Serial.print("BLOCK_ID = ");
  Serial.println(BLOCK_ID);

  if (BLOCK_ID == 0) Serial.println("This block is DRUMS");
  if (BLOCK_ID == 1) Serial.println("This block is VOCALS");
  if (BLOCK_ID == 2) Serial.println("This block is MELODY");

  Serial.println("Starting MPR121...");

  if (!cap.begin(0x5A)) {
    Serial.println("MPR121 not found, check wiring?");
    while (1);
  }

  Serial.println("MPR121 found!");
  cap.setAutoconfig(true);

  Serial.println("Connecting to WiFi...");
  WiFi.mode(WIFI_STA);
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
  } else {
    Serial.print("WiFi failed, status = ");
    Serial.println(WiFi.status());
  }

  Udp.begin(8888);

  Serial.println("Ready.");
  Serial.println("====================================================");
}

// =====================================================
// LOOP
// =====================================================

void loop() {
  static unsigned long last = 0;

  if (WiFi.status() == WL_CONNECTED && millis() - last > 50) {
    last = millis();

    int rawReverb = analogRead(reverbPin);
    int rawTempo = analogRead(tempoPin);

    float reverbNorm = rawReverb / 4095.0f;
    float tempoNorm = rawTempo / 4095.0f;

    currtouched = cap.touched();

    Serial.print("Block ");
    Serial.print(BLOCK_ID);

    Serial.print(" | reverb: ");
    Serial.print(reverbNorm, 3);

    Serial.print(" | tempo: ");
    Serial.print(tempoNorm, 3);

    Serial.print(" | touch: ");

    checkTouch(0, true);
    checkTouch(1, true);
    checkTouch(2, true);

    lasttouched = currtouched;

    // Send reverb with block ID
    if (fabs(reverbNorm - lastReverb) > changeThreshold) {
      sendOSCFloat("/reverb", BLOCK_ID, reverbNorm);
      lastReverb = reverbNorm;

      Serial.print("Sent /reverb ");
      Serial.print(BLOCK_ID);
      Serial.print(" ");
      Serial.println(reverbNorm, 3);
    }

    // Send tempo with block ID
    if (fabs(tempoNorm - lastTempo) > changeThreshold) {
      sendOSCFloat("/tempo", BLOCK_ID, tempoNorm);
      lastTempo = tempoNorm;

      Serial.print("Sent /tempo ");
      Serial.print(BLOCK_ID);
      Serial.print(" ");
      Serial.println(tempoNorm, 3);
    }
  }
}
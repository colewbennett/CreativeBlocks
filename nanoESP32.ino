#include <WiFi.h>
#include <WiFiUdp.h>
#include <OSCMessage.h>

const char* ssid = "Colby Guest Access";

// Raspberry Pi running SuperCollider
IPAddress outIp(137, 146, 183, 226);
const unsigned int outPort = 57120;

WiFiUDP Udp;

// pins
const int reverbPin = A0;
const int spatialPin = A1;

// optional smoothing / change threshold
float lastReverb = -1.0f;
float lastSpatial = -1.0f;
const float changeThreshold = 0.01f;

void sendOSCFloat(const char* address, float value) {
  OSCMessage msg(address);
  msg.add(value);
  Udp.beginPacket(outIp, outPort);
  msg.send(Udp);
  Udp.endPacket();
  msg.empty();
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("Connecting...");
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid);

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

  Udp.begin(8888);  // local UDP port on ESP32
}

void loop() {
  static unsigned long last = 0;

  if (WiFi.status() == WL_CONNECTED && millis() - last > 50) {
    last = millis();

    int rawReverb = analogRead(reverbPin);
    int rawSpatial = analogRead(spatialPin);

    float reverbNorm = rawReverb / 4095.0f;
    float spatialNorm = rawSpatial / 4095.0f;

    // serial monitor output
    Serial.print("A0 raw: \t");
    Serial.print(rawReverb);
    Serial.print("\t reverb: \t");
    Serial.print(reverbNorm, 3);

    Serial.print("\t | A1 raw: \t");
    Serial.print(rawSpatial);
    Serial.print("\t spatial: \t");
    Serial.println(spatialNorm, 3);

    // send reverb only if it changed enough
    if (fabs(reverbNorm - lastReverb) > changeThreshold) {
      sendOSCFloat("/reverb", reverbNorm);
      lastReverb = reverbNorm;
    }

    // send spatial only if it changed enough
    if (fabs(spatialNorm - lastSpatial) > changeThreshold) {
      sendOSCFloat("/delay", spatialNorm);
      lastSpatial = spatialNorm;
    }
  }
}
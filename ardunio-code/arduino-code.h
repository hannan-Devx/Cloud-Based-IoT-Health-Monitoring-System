#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <Wire.h>
#include "MAX30105.h"
#include "spo2_algorithm.h"
#include "heartRate.h"
#include <WebServer.h>
#include <time.h>

MAX30105 particleSensor;


const char* awsEndpoint = ""; 

const char* certificatePemCrt = R"EOF(
-----BEGIN CERTIFICATE-----

-----END CERTIFICATE-----
)EOF";

const char* privatePemKey = R"EOF(
-----BEGIN RSA PRIVATE KEY-----

-----END RSA PRIVATE KEY-----
)EOF";

const char* caPemCrt = R"EOF(
-----BEGIN CERTIFICATE-----

-----END CERTIFICATE-----
)EOF";

WiFiClientSecure net;
PubSubClient client(net);

const char* apSSID = "ESP32_Config";
const char* apPassword = "12345678";

WebServer server(80);

char ssid[32] = {0};
char password[64] = {0};
bool connectRequested = false;
bool wifiConnected = false;

const char* htmlForm = R"rawliteral(
<!DOCTYPE html>
<html>
<body>
<h2>Enter Wi-Fi Credentials</h2>
<form action="/connect" method="POST">
  SSID:<br>
  <input type="text" name="ssid"><br>
  Password:<br>
  <input type="password" name="password"><br><br>
  <input type="submit" value="Connect">
</form>
</body>
</html>
)rawliteral";

#define BUFFER_SIZE 100
uint32_t irBuffer[BUFFER_SIZE];
uint32_t redBuffer[BUFFER_SIZE];

int32_t spo2;
int8_t  validSPO2;
int32_t heartRate;
int8_t  validHeartRate;

static float bpmFiltered = 70;

void handleRoot() {
  server.send(200, "text/html", htmlForm);
}

void handleConnect() {
  if (server.hasArg("ssid") && server.hasArg("password")) {
    server.arg("ssid").toCharArray(ssid, sizeof(ssid));
    server.arg("password").toCharArray(password, sizeof(password));
    server.send(200, "text/html", "<h3>Trying to connect to Wi-Fi...</h3>");
    connectRequested = true;
    Serial.println(F("Wi-Fi connect requested!"));
  }
}

void connectAWS() {
  Serial.println("Setting up TLS credentials...");
  net.setCACert(caPemCrt);
  net.setCertificate(certificatePemCrt);
  net.setPrivateKey(privatePemKey);
  client.setServer(awsEndpoint, 8883);
  Serial.print("Connecting to AWS IoT...");
  while (!client.connected()) {
    if (client.connect("ESP32Client")) {
      Serial.println(" connected!");
    } else {
      Serial.print(".");
      delay(1000);
    }
  }
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println(F("Starting SoftAP..."));
  WiFi.softAP(apSSID, apPassword);
  Serial.print(F("SoftAP IP: "));
  Serial.println(WiFi.softAPIP());

  server.on("/", handleRoot);
  server.on("/connect", HTTP_POST, handleConnect);
  server.begin();
  Serial.println(F("HTTP server started. Open browser to 192.168.4.1"));

  Wire.begin(21, 22);
  if (!particleSensor.begin(Wire, I2C_SPEED_STANDARD)) {
    Serial.println("MAX30102 not found. Check wiring!");
    while (1);
  }
  particleSensor.setup(0x3F, 4, 2, 100, 411, 16384);
  particleSensor.setPulseAmplitudeRed(0xFF);
  particleSensor.setPulseAmplitudeIR(0xFF);
  particleSensor.setPulseAmplitudeGreen(0);
  Serial.println("MAX30102 sensor initialized!");
}

void loop() {
  server.handleClient();

  if (connectRequested) {
    Serial.print(F("Connecting to SSID: "));
    Serial.println(ssid);
    WiFi.begin(ssid, password);
    unsigned long startTime = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - startTime < 15000) {
      delay(500);
      Serial.print(F("."));
    }

    if (WiFi.status() == WL_CONNECTED) {
      Serial.println(F("\nConnected!"));
      Serial.println(WiFi.localIP());
      wifiConnected = true;
      connectAWS();
      configTime(0, 0, "pool.ntp.org");
      Serial.print("Syncing NTP time");
      while (time(nullptr) < 1000000000) {
      delay(500);
      Serial.print(".");
    }
      Serial.println(" done!");
    } else {
      Serial.println(F("\nFailed to connect."));
      wifiConnected = false;
    }

    connectRequested = false;
  }

  if (wifiConnected && client.connected()) {
    client.loop();

    if (particleSensor.check() > 0) {
      long irValue = particleSensor.getFIFOIR();
      long redValue = particleSensor.getFIFORed();

      static int bufIndex = 0;
      irBuffer[bufIndex] = irValue;
      redBuffer[bufIndex] = redValue;
      bufIndex++;

      if (bufIndex >= BUFFER_SIZE) {
        maxim_heart_rate_and_oxygen_saturation(
          irBuffer, BUFFER_SIZE,
          redBuffer,
          &spo2, &validSPO2,
          &heartRate, &validHeartRate
        );

        if (validHeartRate && heartRate > 40 && heartRate < 180) {
          if (abs(heartRate - bpmFiltered) < 40) {
            bpmFiltered = 0.85 * bpmFiltered + 0.15 * heartRate;
          }
        }

        // ===== DISPLAY VITALS =====
        Serial.println("\n================================");
        Serial.print("BPM: ");
        if (validHeartRate) {
          Serial.print((int)bpmFiltered);
          Serial.println(" bpm");
        } else {
          Serial.println("-- (no valid reading)");
        }

        Serial.print("SpO2: ");
        if (validSPO2 && spo2 > 80 && spo2 < 101) {
          Serial.print(spo2);
          Serial.println(" %");
        } else {
          Serial.println("-- (no valid reading)");
        }
        Serial.println("================================\n");

        // JSON Payload
        String payload = "{";
        payload += "\"device_id\":\"esp32-01\",";
        payload += "\"timestamp\":" + String((long)time(nullptr)) + ",";
        payload += "\"spo2\":";
        if (validSPO2 && spo2 > 80 && spo2 < 101) payload += String(spo2);
        else payload += "null";
        payload += ",\"bpm\":";
        if (validHeartRate) payload += String((int)bpmFiltered);
        else payload += "null";
        payload += "}";

        // Sirf valid data publish karo
        if (validHeartRate && validSPO2 && spo2 > 80 && spo2 < 101 && (int)bpmFiltered > 40) {
        client.publish("ESP32_VITALS", payload.c_str());
        client.publish("health-monitor/vitals", payload.c_str());
        client.publish("esp32/health-vitals", payload.c_str());
        Serial.println("✅ Published to AWS!");
} else {
    Serial.println("⚠️ Skipped - invalid readings, not publishing");
}

        bufIndex = 0;
      }
    }
  }
}
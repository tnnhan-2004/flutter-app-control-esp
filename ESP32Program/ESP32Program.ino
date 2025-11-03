#include <WiFi.h>
#include <WiFiUdp.h>
#include <ArduinoJson.h>
#include "DHT.h"

// ==========================================================
// ==== THAY ĐỔI CÁC THÔNG SỐ NÀY CHO PHÙ HỢP ==============
// ==========================================================

// --- WiFi của bạn ---
const char* ssid = "CamWifi";
const char* password = "12345678";

// --- Các chân GPIO cho thiết bị ---
const int LED_PIN_1 = 2; // Đèn 1
const int LED_PIN_2 = 12; // Đèn 2
const int FAN_PIN = 14;   // Quạt
const int ML_PIN = 27;    // Máy lạnh (ví dụ)

// --- Chân cảm biến DHT ---
#define DHTPIN 4
#define DHTTYPE DHT22

// ==========================================================
// ==== PHẦN CODE LOGIC ====================
// ==========================================================

// --- UDP Config ---
WiFiUDP udp;
const int localPort = 5005; // Cổng ESP32 lắng nghe
IPAddress appIP;            // Biến lưu IP của app
int appPort = 0;            // Biến lưu port của app

// --- DHT Config ---
DHT dht(DHTPIN, DHTTYPE);

void setup() {
  Serial.begin(115200);
  
  // Cài đặt chân cho các thiết bị
  pinMode(LED_PIN_1, OUTPUT);
  pinMode(LED_PIN_2, OUTPUT);
  pinMode(FAN_PIN, OUTPUT);
  pinMode(ML_PIN, OUTPUT);

  // Tắt hết thiết bị lúc khởi động
  digitalWrite(LED_PIN_1, LOW);
  digitalWrite(LED_PIN_2, LOW);
  digitalWrite(FAN_PIN, LOW);
  digitalWrite(ML_PIN, LOW);

  // Kết nối WiFi
  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nConnected!");
  Serial.print("ESP32 IP: ");
  Serial.println(WiFi.localIP());

  // Bắt đầu lắng nghe UDP
  udp.begin(localPort);
  Serial.printf("UDP listening on port %d\n", localPort);
  Serial.println("Waiting for a command from the app to get its IP...");

  // Khởi động cảm biến DHT
  dht.begin();
}

// Hàm điều khiển thiết bị
void controlDevice(const String& deviceId, bool isOn) {
    int pin = -1;
    if (deviceId == "led1") pin = LED_PIN_1;
    else if (deviceId == "led2") pin = LED_PIN_2;
    else if (deviceId == "fan") pin = FAN_PIN;
    else if (deviceId == "ml") pin = ML_PIN;
    
    if (pin != -1) {
        digitalWrite(pin, isOn ? HIGH : LOW);
        Serial.printf("Device '%s' turned %s\n", deviceId.c_str(), isOn ? "ON" : "OFF");
    }
}

// Gửi dữ liệu cảm biến về App
void sendSensorData(const String& sensorId, const String& type, float value) {
  if (appPort == 0) return; // Chưa biết địa chỉ app, không gửi

  StaticJsonDocument<128> doc;
  doc["type"] = "sensor_data";
  doc["sensor_id"] = sensorId;
  doc["value"] = value;

  char buffer[128];
  size_t n = serializeJson(doc, buffer);
  
  udp.beginPacket(appIP, appPort);
  udp.write((const uint8_t*)buffer, n);
  udp.endPacket();

  Serial.printf("Sent to App: %s\n", buffer);
}


void loop() {
  // 1. Lắng nghe lệnh từ App
  int packetSize = udp.parsePacket();
  if (packetSize) {
    // Lưu lại địa chỉ IP và Port của App
    appIP = udp.remoteIP();
    appPort = udp.remotePort();
    
    char buffer[256];
    int len = udp.read(buffer, 255);
    if (len > 0) {
      buffer[len] = 0;
      Serial.printf("UDP from %s:%d -> %s\n", appIP.toString().c_str(), appPort, buffer);

      StaticJsonDocument<256> doc;
      if (deserializeJson(doc, buffer) == DeserializationError::Ok) {
        String cmd = doc["cmd"] | "";

        // Lệnh PING để ESP lấy địa chỉ IP của App
        if (cmd == "ping") {
          udp.beginPacket(appIP, appPort);
          udp.write((const uint8_t*)"{\"response\":\"pong\"}", 19);
          udp.endPacket();
        }
        // Lệnh điều khiển thiết bị
        else if (cmd == "control_device") {
          String deviceId = doc["device_id"];
          bool isOn = doc["is_on"];
          controlDevice(deviceId, isOn);
        }
      }
    }
  }

  // 2. Đọc và gửi dữ liệu cảm biến mỗi 5 giây
  static unsigned long lastRead = 0;
  if (millis() - lastRead > 5000) {
    lastRead = millis();
    float h = dht.readHumidity();
    float t = dht.readTemperature();

    if (!isnan(h)) {
      sendSensorData("dht_humid", "humid", h);
    }
    if (!isnan(t)) {
      sendSensorData("dht_temp", "temp", t);
    }
  }
}

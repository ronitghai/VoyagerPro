#include <WiFi.h>
#include <WebServer.h>
#include <WiFiManager.h>    // captive-portal config
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <HX711_ADC.h>
#include <TinyGPS++.h>
#include <ESPmDNS.h>

// —— HTTP & Wi-Fi globals ——
WebServer server(80);
String wifiData = "";
WiFiManager wm;
bool portalRequested = false;
bool wifiInitialized = false;

// —— Sensor globals ——
#define HX711_DT 4
#define HX711_SCK 5
#define GPS_BAUDRATE 9600
HX711_ADC   hx711(HX711_DT, HX711_SCK);
TinyGPSPlus gps;
float currentWeight = 0.0;


// —— BLE UUIDs & globals ——
#define SERVICE_UUID "549BC4EF-AEA1-217E-B975-1C0FA4488D47"
#define TX_UUID "6E400003-B5A3-F393-E0A9-E50E24DCCA9A"
#define RX_UUID "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
BLEServer *pServer = nullptr;
BLECharacteristic *pTxCharacteristic = nullptr;
BLECharacteristic *pRxCharacteristic = nullptr;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// —— Forward declarations ——
void handleRoot();
void handleResetVoyager();

// — HTTP handlers ——
void handleRoot() {
  server.send(200, "text/plain", wifiData);
}
void handleResetVoyager() {
  server.send(200, "text/plain", "Resetting Voyager Pro...");
  Serial.println("↻ Factory reset via HTTP");
  wm.resetSettings();
  hx711.tare();
  currentWeight = 0.0;
  delay(100);
  ESP.restart();
}

// —— BLE callbacks ——
class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *s)    override { deviceConnected = true;  Serial.println("Client connected."); }
  void onDisconnect(BLEServer *s) override { deviceConnected = false; Serial.println("Client disconnected."); }
};
class MyRxCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *c) override {
    size_t len = c->getLength();
    if (len == 0) return;
    String cmd;
    auto* data = c->getData();
    for (size_t i = 0; i < len; i++) cmd += char(data[i]);
    Serial.print("RX cmd: "); Serial.println(cmd);
    
    if (cmd == "CONFIG_WIFI") {
      portalRequested = true;
    }
    else if (cmd == "RESET_WIFI") {
      Serial.println("↻ Resetting Wi-Fi credentials...");
      wm.resetSettings();
      delay(100);
      ESP.restart();
    }
    else if (cmd == "TARE") {
      Serial.println("↻ Taring scale...");
      hx711.tare();
    }
    else if (cmd == "RESET_VOYAGER") {
      Serial.println("↻ Factory reset via BLE...");
      wm.resetSettings();
      hx711.tare();
      currentWeight = 0.0;
      delay(100);
      ESP.restart();
    }
    else {
      Serial.println("⚠️ Unknown BLE cmd.");
    }
  }
};

void setup() {
  Serial.begin(115200);
  // —— 1) Initialize BLE immediately ——
  BLEDevice::init("Voyager Pro");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  auto svc = pServer->createService(SERVICE_UUID);
  pTxCharacteristic = svc->createCharacteristic(TX_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  pTxCharacteristic->addDescriptor(new BLE2902());
  pRxCharacteristic = svc->createCharacteristic(RX_UUID, BLECharacteristic::PROPERTY_WRITE);
  pRxCharacteristic->setCallbacks(new MyRxCallbacks());
  svc->start();
  pServer->getAdvertising()->addServiceUUID(SERVICE_UUID);
  pServer->getAdvertising()->start();
  Serial.println("✅ BLE advertising started.");

  // —— 2) Initialize sensors ——
  Serial2.begin(GPS_BAUDRATE, SERIAL_8N1, 16, 17);
  Serial.println("GPS module initialized.");
  hx711.begin();
  hx711.start(2000);
  hx711.setCalFactor(19.66);
  Serial.println("HX711 initialized.");

  // Note: We do NOT auto-join Wi-Fi here.  BLE is up & running instantly.
}

void loop() {
  // --- Always: read weight ---
  if (hx711.update()) {
    currentWeight = 9.78 + (hx711.getData() / 1000.0) * 2.20462;
    //Serial.println("Weight: " + String(currentWeight, 2));
  }
  // --- Always: Process GPS Data ---
  while (Serial2.available() > 0) {
    gps.encode(Serial2.read());
  }

  // --- Always: Build combined data string ---
  String dataToSend = "";
  dataToSend += "W:" + String(currentWeight, 2) + "; ";

  if (gps.location.isValid()) {
    dataToSend += "GPS:lat=" + String(gps.location.lat(), 6) +
                  ",lon=" + String(gps.location.lng(), 6);

    Serial.print(F("- Satellites:"));
    if (gps.satellites.isValid()) Serial.println(gps.satellites.value());
    else                          Serial.println(F("INVALID"));

    if (gps.altitude.isValid())
      dataToSend += ",alt=" + String(gps.altitude.meters());
    else
      dataToSend += ",alt=INV";

    if (gps.speed.isValid())
      dataToSend += ",spd=" + String(gps.speed.kmph());
    else
      dataToSend += ",spd=INV";

    if (gps.date.isValid() && gps.time.isValid()) {
      dataToSend += ",dt=" + String(gps.date.year()) + "-" +
                    String(gps.date.month()) + "-" +
                    String(gps.date.day()) + " " +
                    String(gps.time.hour()) + ":" +
                    String(gps.time.minute()) + ":" +
                    String(gps.time.second());
    } else {
      dataToSend += ",dt=INV";
    }
  } else {
    dataToSend += "GPS:INVALID";
  }

  // — Always: update wifiData for HTTP clients
  wifiData = dataToSend;

  // --- BLE notify if connected ---
  if (deviceConnected) {
    pTxCharacteristic->setValue(dataToSend.c_str());
    pTxCharacteristic->notify();
    Serial.println("Sent BLE data: " + dataToSend);
  }

  // --- Handle BLE disconnect/advertise restart ---
  if (!deviceConnected && oldDeviceConnected) {
    delay(100);
    pServer->startAdvertising();
  }
  oldDeviceConnected = deviceConnected;

  // --- Serve HTTP if Wi-Fi is up & initialized ---
  if (wifiInitialized && WiFi.status() == WL_CONNECTED) {
    server.handleClient();
  }

  // --- On-demand Wi-Fi portal launch ---
  if (portalRequested) {
    Serial.println("🔧 Starting Wi-Fi config portal...");
    if (wm.startConfigPortal("Voyager Pro Setup")) {
      Serial.println("Config portal closed, joined: " + WiFi.SSID());
      // Now bring up mDNS + HTTP server once
      if (!wifiInitialized) {
        if (MDNS.begin("voyager")) {
          MDNS.addService("http","tcp",80);
          Serial.println("mDNS responder: voyager.local");
        }
        server.on("/", handleRoot);
        server.on("/reset-voyager", handleResetVoyager);
        server.on("/tare", HTTP_GET, []() {
          server.send(200, "text/plain", "Taring scale...");
          Serial.println("↻ Taring scale via HTTP");
          hx711.tare();
        });
        server.begin();
        Serial.println("HTTP server started.");
        wifiInitialized = true;
      }
    } else {
      Serial.println("Config portal failed or timed out.");
    }
    portalRequested = false;
  }

  delay(500);
}

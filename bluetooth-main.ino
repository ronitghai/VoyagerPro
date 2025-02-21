#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <HX711_ADC.h> // Library for HX711

// Define BLE UUIDs
#define SERVICE_UUID "549BC4EF-AEA1-217E-B975-1C0FA4488D47"
#define TX_UUID "6E400003-B5A3-F393-E0A9-E50E24DCCA9A" // TX UUID (Notify)
#define RX_UUID "6E400002-B5A3-F393-E0A9-E50E24DCCA9E" // RX UUID (Write)

// Define HX711 pins
#define HX711_DT 4  // Data pin connected to ESP32 GPIO4
#define HX711_SCK 5 // Clock pin connected to ESP32 GPIO5

HX711_ADC hx711(HX711_DT, HX711_SCK);

BLEServer *pServer = NULL;
BLECharacteristic *pTxCharacteristic = NULL;
BLECharacteristic *pRxCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// BLE Server Callbacks
class MyServerCallbacks : public BLEServerCallbacks {
    void onConnect(BLEServer *pServer) {
        deviceConnected = true;
        Serial.println("Client connected.");
    }
    void onDisconnect(BLEServer *pServer) {
        deviceConnected = false;
        Serial.println("Client disconnected.");
    }
};

class MyRxCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
        // Get the raw data and its length
        uint8_t* data = pCharacteristic->getData();
        size_t length = pCharacteristic->getLength();

        if (data != nullptr && length > 0) {
            // Convert raw data to Arduino String
            String receivedData = "";
            for (size_t i = 0; i < length; i++) {
                receivedData += (char)data[i];
            }

            // Debug: Log the received data
            Serial.println("Data received from client: " + receivedData);
        } else {
            Serial.println("No data received from client.");
        }
    }
};



void setup() {
    Serial.begin(115200);

    // Initialize BLE
    BLEDevice::init("Voyager Pro");
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new MyServerCallbacks());

    // Create BLE Service
    BLEService *pService = pServer->createService(SERVICE_UUID);

    // Create TX Characteristic (Notify)
    pTxCharacteristic = pService->createCharacteristic(
        TX_UUID,
        BLECharacteristic::PROPERTY_NOTIFY
    );
    pTxCharacteristic->addDescriptor(new BLE2902()); // Required for notifications

    // Create RX Characteristic (Write)
    pRxCharacteristic = pService->createCharacteristic(
        RX_UUID,
        BLECharacteristic::PROPERTY_WRITE
    );
    pRxCharacteristic->setCallbacks(new MyRxCallbacks());

    // Start BLE Service
    pService->start();

    // Start Advertising
    pServer->getAdvertising()->addServiceUUID(SERVICE_UUID);
    pServer->getAdvertising()->start();
    Serial.println("BLE advertising started.");

    // Initialize HX711
    Serial.println("Initializing HX711...");
    hx711.begin();
    hx711.start(2000); // Allow HX711 to stabilize
    hx711.setCalFactor(0.9); // Set calibration factor (adjust this for your load cell)
    Serial.println("HX711 Initialized.");
}

// Define a variable to store the highest weight
float maxWeight = 0.0;

void loop() {
    if (deviceConnected) {
        // Check if HX711 is ready to provide data
        if (hx711.update()) {
            // Get weight data in grams and convert to kilograms
            float weightInKg = (hx711.getData() / 1000.0) * 2.20462;

            // Update maxWeight if the current weight is higher
            if (weightInKg > maxWeight) {
                maxWeight = weightInKg;

                // Format maxWeight data as a string
                String maxWeightString = String(maxWeight, 2); // Two decimal places

                // Send max weight data over BLE
                pTxCharacteristic->setValue(maxWeightString.c_str());
                pTxCharacteristic->notify();

                // Debug log
                Serial.println("New max weight recorded: " + maxWeightString);
            } else {
                Serial.println("Current weight lower than max. No update sent.");
            }
        } else {
            Serial.println("No data from HX711...");
        }

        delay(500); // Stability delay
    }

    // Handle device disconnection and restart advertising if needed
    if (!deviceConnected && oldDeviceConnected) {
        delay(100);
        pServer->startAdvertising();
        Serial.println("Restarting BLE advertising...");
        oldDeviceConnected = deviceConnected;
    }

    if (deviceConnected && !oldDeviceConnected) {
        oldDeviceConnected = deviceConnected;
    }
}


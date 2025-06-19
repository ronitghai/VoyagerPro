# Voyager Pro

### Overview
**Voyager Pro** is an intelligent suitcase platform designed to help travelers avoid overweight baggage fees and know where their suitcase is by tracking real-time weight and GPS location via BLE/WiFi.

### Tech Stack
- **Firmware**: C/C++ with Arduino IDE
- **Microcontroller**: ESP32
- **Sensors**: HX711 (load cell amplifier), NEO-6M (GPS module)
- **App**: SwiftUI for iOS
- **Communication**: BLE (Bluetooth Low Energy) and Wi-Fi
- **Hardware**: 4 Load Cells, 3.7V 2200 maH Lithium ion battery, schottky diode

### Key Features
- Accurate weight calibration (±0.5 kg) using load cell and amplifier.
- Real-time GPS tracking.
- Wi-Fi/BLE-based communication between ESP32 and iOS app.
- Custom PCB design using KiCAD.

### Development Summary
- Designed and programmed embedded firmware for ESP32 to manage sensor data and connectivity.
- Built SwiftUI iOS app with Wi-Fi/BLE communication and live UI updates.
- Developed custom BLE protocol for efficient and secure data transmission.
- Created a Wi-Fi task manager and Server URL domain for efficient and secure data transmission.
- Handled PCB design and soldering for all hardware components.

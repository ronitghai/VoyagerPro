//
//  ContentView.swift
//  VoyagerProApp
//
//

import SwiftUI

struct ContentView: View {
    var bluetooth = Bluetooth.shared
    @StateObject private var wifiManager = WiFiManager()
    @State private var isPresented = false
    @State private var devicesList = [Bluetooth.Device]()
    @State private var isConnected: Bool = false
    @State private var weight: Double? = nil // Weight in lbs
    @State private var rssi: Int = 0
    @State private var useWiFi = false // Toggle for Wi-Fi/Bluetooth
    @State private var travelClass: String = "Economy" // Default class
    @State private var showGrid: Bool = false
    @State private var selectedOption: String? = nil
    @State private var message: String? = nil // Temporary message to show for other options
    @State private var isLbs: Bool = true // Toggle for lbs/kg
    @State private var selectedAirline: String? = nil // Selected airline

    @State var isConnectedBluetooth: Bool = Bluetooth.shared.current != nil
    @State var isConnectedWiFi: Bool = false
    @State var connectionType: ConnectionType = .none

    enum ConnectionType {
        case none, bluetooth, wifi
    }
   
     private func checkConnection() {
        if isConnectedBluetooth {
            connectionType = .bluetooth
            showGrid = true // Show grid when connected to Bluetooth
        } else if wifiManager.isConnected {
            connectionType = .wifi
            showGrid = true // Show grid when connected to Bluetooth
        } else {
            connectionType = .none
            showGrid = false // Show grid when connected to Bluetooth
        }
    }
    
     private var connectionTypeText: String {
        switch connectionType {
        case .none:
            return "None"
        case .bluetooth:
            return "Bluetooth"
        case .wifi:
            return "Wi-Fi"
        }
    }
    
     private var connectionColor: Color {
        switch connectionType {
        case .none:
            return .gray
        case .bluetooth:
            return .blue
        case .wifi:
            return .green
        }
    }
    var body: some View {
            NavigationView {
                ZStack {
                    // Modern Gradient Background
                    LinearGradient(gradient: Gradient(colors: [Color.black.opacity(0.8), Color.purple.opacity(0.8)]),
                                   startPoint: .top,
                                   endPoint: .bottom)
                        .ignoresSafeArea()

                    // Existing UI logic
                    VStack {
                        // Logo and Title Section
                        VStack(spacing: 20) {
                            Image(systemName: "suitcase.fill")
                                .resizable()
                                .frame(width: 80, height: 80)
                                .foregroundColor(.white)

                            Text("Voyager Pro")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.bottom, 40)

                        // Class Picker with Dynamic Styling
                        Picker("Travel Class", selection: $travelClass) {
                            Text("Economy").tag("Economy")
                            Text("Business").tag("Business")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(15)
                        .padding(.horizontal, 20)
                        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
                        
                        Menu {
                            ForEach(["JetBlue", "Delta", "United", "American Airlines", "Air India", "Air Canada", "Air France", "Emirates", "British Airways", "Qatar Airways"], id: \.self) { airline in
                                Button(action: {
                                    selectedAirline = airline
                                }) {
                                    Text(airline)
                                }
                            }
                        } label: {
                            Text(selectedAirline ?? "Select Airline")
                                .foregroundColor(.white)
                                .font(.headline)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(15)
                                .padding(.horizontal, 20)
                                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
                        }
                        // Wi-Fi Toggle
                        Toggle(isOn: $useWiFi) {
                            Text("Use Wi-Fi")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(15)
                        .padding(.horizontal, 20)
                        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)

                        Spacer()
                        
                        // Lbs to Kg Toggle
                        Toggle(isOn: $isLbs) {
                            Text("Display Weight in \(isLbs ? "Lbs" : "Kg")")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(15)
                        .padding(.horizontal, 20)
                        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)

                        Spacer()
                        
                        if let message = message {
                        // Show the temporary message for non-weight options
                            VStack {
                                Text(message)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()

                                Text("Returning to menu...")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            }
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    resetToStart() // Reset after showing the message
                                }
                            }
                        } else if let selectedOption = selectedOption {
                            switch selectedOption {
                            case "Weight":
                                weightDisplayView
                            default:
                                Text("Invalid selection.")
                            }
                        } else if isConnected || useWiFi {
                            GridMenuView { option in
                                handleGridSelection(option) // Handle grid selection
                            }
                        } else {
                            scanButton
                        }


                        Spacer()
                    }
                    .padding()
                    .navigationBarHidden(true)
                    .sheet(isPresented: $isPresented) {
                        ScanView(bluetooth: bluetooth, presented: $isPresented, list: $devicesList, isConnected: $isConnected)
                    }
                    .onAppear {
                        requestNotificationPermissions()
                        if useWiFi {
                            fetchWeightFromWiFi()
                        } else {
                            bluetooth.delegate = self
                        }
                    }
                        
                    
                }
            }
        }
    var scanButton: some View {
        VStack {
            Image(systemName: "magnifyingglass.circle.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.white)
                .padding()

            Button(action: { isPresented.toggle() }) {
                Text("Scan for Devices")
                    .font(.headline)
                    .padding()
                    .background(Color.white.opacity(0.8))
                    .foregroundColor(.blue)
                    .cornerRadius(10)
            }
        }
    }

    var weightDisplayView: some View {
        VStack {
            Text(useWiFi ? "Connected via Wi-Fi" : "Connected to: \(bluetooth.current?.name ?? "Unknown")")
                .font(.headline)
                .foregroundColor(.white)
                .padding()

            Spacer()

            weightMeter

            if weight == nil {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .padding()
            }

            Spacer()

            Button("Disconnect") {
                disconnect()
            }
                .font(.headline)
                .padding()
                .background(Color.red.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }

    var weightMeter: some View {
        let threshold = travelClass == "Economy" ? 50.0 : 70.0
        let greenZone = threshold * 0.6 // 60% of the threshold
        let yellowZone = threshold * 0.2 // 20% of the threshold
        let redZone = threshold * 0.2 //Remaining 20%

        return VStack {
            if let weight = weight {
                let displayWeight = isLbs ? weight : weight * 0.453592
                Text("\(displayWeight, specifier: "%.2f") \(isLbs ? "lbs" : "kg")")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                    .padding()
            } else {
                Text("Fetching weight...")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            ZStack(alignment: .leading) {
                // Weight Zones
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: UIScreen.main.bounds.width * CGFloat(greenZone / threshold), height: 20)
                    Rectangle()
                        .fill(Color.yellow)
                        .frame(width: UIScreen.main.bounds.width * CGFloat(yellowZone / threshold), height: 20)
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: UIScreen.main.bounds.width * CGFloat(redZone / threshold), height: 20)
                }
                .cornerRadius(10)

                // Weight Indicator
                if let weight = weight {
                    let meterWidth = UIScreen.main.bounds.width - 40
                    let weightPosition = CGFloat(weight / threshold) * meterWidth

                    Circle()
                        .fill(Color.white)
                        .frame(width: 15, height: 15)
                        .offset(x: max(0, min(weightPosition - 7.5, meterWidth - 15)))
                }
            }
            .padding()

            // Axis Labels (5 lbs increments)
            HStack(spacing: 0) {
                ForEach(0..<(Int(threshold) / 5 + 1), id: \.self) { index in
                    Text("\(index * 5)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(width: (UIScreen.main.bounds.width - 40) / CGFloat(threshold / 5), alignment: .center)
                }
            }
            .padding(.horizontal, 20)
        }
        .onChange(of: weight) { newValue in
            if let newWeight = newValue {
                checkWeightAndNotify(weight: newWeight, threshold: threshold)
            }
        }
    }
    
    // Helper function for checking weight and sending notifications
    private func checkWeightAndNotify(weight: Double, threshold: Double) {
        if weight > threshold {
            print("Weight exceeds threshold. Triggering notification...")
            sendOverweightNotification(for: weight)
        }
    }
    
    func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            if success {
                print("Notification permission granted.")
            } else if let error = error {
                print("Error requesting notification permissions: \(error)")
            }
        }
    }

    func sendOverweightNotification(for weight: Double) {
        let threshold = travelClass == "Economy" ? 50.0 : 70.0
        print("Sending notification for weight: \(weight), threshold: \(threshold)")
        let content = UNMutableNotificationContent()
        content.title = "Overweight Warning"
        content.body = "Your luggage is \(weight) lbs, exceeding the \(threshold) lbs limit for \(travelClass) class."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending notification: \(error)")
            }
            else {
                print("Notification scheduled successfully.")
            }
        }
    }
    func fetchWeightFromWiFi() {
        // Simulated Wi-Fi weight fetch
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            //weight = Double.random(in: 5.0...80.0) // Simulate Wi-Fi data
        }
    }
    func handleGridSelection(_ option: String) {
            if option == "Weight" {
                selectedOption = option // Show weight view
            } else {
                message = "\(option) feature has not been implemented yet!" // Show temporary message
            }
        }

    func resetToStart() {
        // Reset all states to go back to the starting scan button
        message = nil
        selectedOption = nil
        isConnected = false
        useWiFi = false
    }
    func disconnect() {
        bluetooth.disconnect() // Disconnect Bluetooth if applicable
        resetToStart()
    }

}

extension ContentView: BluetoothProtocol {
    func state(state: Bluetooth.State) {
        isConnected = (state == .connected)
        if isConnected {
            // Reset weight on successful connection
            weight = nil
        } else {
            // Clear weight when disconnected
            weight = nil
        }
    }

    func list(list: [Bluetooth.Device]) {
        devicesList = list
    }

    func value(data: Data) {
        print("Raw Data Received: \(data as NSData)")
        
        if let weightString = String(data: data, encoding: .utf8) {
            print("Decoded String: \(weightString)")
            
            if let weightValue = Double(weightString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                DispatchQueue.main.async {
                    self.weight = weightValue
                    print("Weight Updated: \(weightValue)")
                }
            } else {
                print("Failed to convert string to Double. String: \(weightString)")
            }
        } else {
            print("Failed to decode UTF-8 string.")
        }
    }



    func rssi(value: Int) {
        rssi = value
    }
}



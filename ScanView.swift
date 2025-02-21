
//
//  ScanView.swift
//  SmartSuitcaseApp
//
//

import SwiftUI

struct ScanView: View {
    var bluetooth: Bluetooth
    @Binding var presented: Bool
    @Binding var list: [Bluetooth.Device]
    @Binding var isConnected: Bool

    var body: some View {
        VStack {
            HStack {
                Spacer()
                if isConnected {
                    Text("Connected to \(bluetooth.current?.name ?? "Unknown")")
                        .font(.subheadline)
                        .padding()
                }
                Spacer()
                Button(action: { presented.toggle() }) {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .frame(width: 25, height: 25)
                        .foregroundColor(.red)
                        .padding()
                }
            }

            if isConnected {
                Button(action: { bluetooth.disconnect() }) {
                    Text("Disconnect")
                        .font(.headline)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding()
                }
            }

            List(list) { device in
                Button(action: { bluetooth.connect(device.peripheral) }) {
                    VStack(alignment: .leading) {
                        Text(device.peripheral.name ?? "Unknown Device")
                            .font(.headline)
                        Text("UUID: \(device.uuid)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .onAppear { bluetooth.startScanning() }
            .onDisappear { bluetooth.stopScanning() }
        }
        .padding()
    }
}


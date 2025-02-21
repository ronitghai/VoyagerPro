//
//  GridMenuView.swift
//  Voyager Pro
//
//


import SwiftUI

struct GridMenuView: View {
    var onOptionSelected: (String) -> Void

    private let options = [
        "Weight",
        "GPS",
        "Theft Detection",
        "Tampering Detection",
        "Battery",
        "Settings"
    ]

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack {
            Text("Menu")
                .font(.largeTitle)
                .padding()

            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(options, id: \.self) { option in
                    Button(action: {
                        onOptionSelected(option)
                    }) {
                        Text(option)
                            .frame(maxWidth: .infinity, maxHeight: 100)
                            .padding()
                            .background(Color.blue.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            }
            .padding()
        }
    }
}

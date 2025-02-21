import Foundation
import Combine

class WiFiManager: ObservableObject {
    @Published var weight: String = "N/A"
    @Published var isConnected: Bool = false
    @Published var errorMessage: String? = nil

    let esp32IPAddress = "192.168.1.100" // Replace with your ESP32's actual IP
    let weightEndpoint = "/weight"      // The API endpoint for weight data

    // Function to check connectivity
    func connectToESP32() {
        let urlString = "http://\(esp32IPAddress)\(weightEndpoint)"
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL."
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Connection failed: \(error.localizedDescription)"
                    self.isConnected = false
                    return
                }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let weightValue = json["weight"] as? Double else {
                    self.errorMessage = "Invalid response from ESP32."
                    self.isConnected = false
                    return
                }
                self.weight = String(format: "%.2f kg", weightValue)
                self.isConnected = true
                self.errorMessage = nil
            }
        }.resume()
    }
}

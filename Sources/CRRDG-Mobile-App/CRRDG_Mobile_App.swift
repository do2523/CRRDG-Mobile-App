import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif



// MARK: - Load .env file manually
func loadDotEnv(from path: String) {
    guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
        print("⚠️ Could not read .env file at: \(path)")
        return
    }

    for rawLine in contents.split(whereSeparator: \.isNewline) {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty, !line.hasPrefix("#") else { continue }

        let parts = line.split(separator: "=", maxSplits: 1)
        guard parts.count == 2 else { continue }

        let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        var value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)

        if value.hasPrefix("\""), value.hasSuffix("\"") {
            value.removeFirst()
            value.removeLast()
        }

        #if os(Windows)
        _putenv_s(key, value)
        #else
        setenv(key, value, 1)
        #endif
    }

    print("✅ Loaded .env from: \(path)")
}


// ✅ Change this to match your actual .env location
let envPath = "C:\\Users\\do262\\projects\\CRRDG-Mobile-App\\.env"
loadDotEnv(from: envPath)


// MARK: - Helper for environment variables
func env(_ key: String) -> String? {
    ProcessInfo.processInfo.environment[key]
}

// MARK: - Load and validate API credentials
guard let apiKey = env("CR_API_KEY"), !apiKey.isEmpty else {
    print("❌ ERROR: Missing or empty CR_API_KEY in environment or .env file.")
    exit(1)
}

guard let playerTag = env("CR_TAG"), !playerTag.isEmpty else {
    print("❌ ERROR: Missing or empty CR_TAG in environment or .env file.")
    exit(1)
}

// MARK: - Build Clash Royale API request
let encodedTag = playerTag.replacingOccurrences(of: "#", with: "%23")

let urlString = "https://api.clashroyale.com/v1/players/\(encodedTag)"
print("🌐 URL: \(urlString)")

guard let url = URL(string: urlString) else {
    print("❌ ERROR: Invalid URL.")
    exit(1)
}

// MARK: - Make HTTP request
var request = URLRequest(url: url)
request.httpMethod = "GET"
request.setValue("application/json", forHTTPHeaderField: "Accept")
request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

let semaphore = DispatchSemaphore(value: 0)

let task = URLSession.shared.dataTask(with: request) { data, response, error in
    defer { semaphore.signal() }

    if let error = error {
        print("❌ Request failed: \(error)")
        return
    }

    guard let httpResponse = response as? HTTPURLResponse else {
        print("❌ Invalid response")
        return
    }

    

    if !(200...299).contains(httpResponse.statusCode) {
    print("❌ HTTP error: \(httpResponse.statusCode)")

    if let data = data,
       let body = String(data: data, encoding: .utf8) {
        print("🌐 Server response body: \(body)")
    } else {
        print("⚠️ No error body received.")
    }

    return
}

    

    guard let data = data else {
        print("❌ No data received")
        return
    }

   if let body = String(data: data, encoding: .utf8) {
    print("Server response: \(body)")
}

    
    // MARK: - Decode JSON
    do {
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let name = json["name"] as? String ?? "<unknown>"
            let trophies = json["trophies"] as? Int ?? 0

            print("🏆 Name: \(name)")
            print("Trophies: \(trophies)")
            print("Deck:")

            if let deck = json["currentDeck"] as? [[String: Any]] {
                for card in deck {
                    let cardName = card["name"] as? String ?? "<unknown>"
                    let level = card["level"] as? Int ?? -1
                    print(" - \(cardName) (Lvl \(level))")
                }
            }
        } else {
            print("⚠️ Unexpected JSON format.")
        }
    } catch {
        print("❌ Failed to decode JSON: \(error)")
    }
}

task.resume()
semaphore.wait()

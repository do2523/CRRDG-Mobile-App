import Foundation

// Helper to read environment variables
func env(_ key: String) -> String? {
    return ProcessInfo.processInfo.environment[key]
}

// Load your environment vars
guard let apiKey = env("CR_API_KEY") else {
    print("ERROR: Missing CR_API_KEY")
    exit(1)
}

guard let playerTag = env("CR_TAG") else {
    print("ERROR: Missing CR_TAG")
    exit(1)
}

// URL-encode the tag
let encodedTag = playerTag.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? playerTag
let urlString = "https://api.clashroyale.com/v1/players/\(encodedTag)"
print("URL: \(urlString)")

guard let url = URL(string: urlString) else {
    print("ERROR: Invalid URL.")
    exit(1)
}

// Build request
var request = URLRequest(url: url)
request.httpMethod = "GET"
request.setValue("application/json", forHTTPHeaderField: "Accept")
request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

let semaphore = DispatchSemaphore(value: 0)

let task = URLSession.shared.dataTask(with: request) { data, response, error in
    defer { semaphore.signal() }

    if let error = error {
        print("Request failed: \(error)")
        return
    }

    guard let httpResponse = response as? HTTPURLResponse else {
        print("Invalid response")
        return
    }

    guard (200...299).contains(httpResponse.statusCode) else {
        print("HTTP error: \(httpResponse.statusCode)")
        return
    }

    guard let data = data else {
        print("No data received")
        return
    }

    // Decode JSON
    do {
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let name = json["name"] as? String ?? "<unknown>"
            let trophies = json["trophies"] as? Int ?? 0

            print("Name: \(name)")
            print("Trophies: \(trophies)")
            print("Current Deck:")

            if let deck = json["currentDeck"] as? [[String: Any]] {
                for card in deck {
                    let cardName = card["name"] as? String ?? "<unknown>"
                    let level = card["level"] as? Int ?? -1
                    print(" - \(cardName) (Lvl \(level))")
                }
            }
        }
    } catch {
        print("Failed to decode JSON: \(error)")
    }
}

task.resume()
semaphore.wait()

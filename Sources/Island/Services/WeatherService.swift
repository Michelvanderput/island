import Foundation
import CoreLocation

struct Weather: Equatable {
    var temperature: Double
    var high: Double
    var low: Double
    var code: Int
    var isDay: Bool
    var place: String

    var symbol: String {
        switch code {
        case 0: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...57: return "cloud.drizzle.fill"
        case 61...67, 80...82: return "cloud.rain.fill"
        case 71...77, 85, 86: return "cloud.snow.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    var summary: String {
        switch code {
        case 0: return "Helder"
        case 1: return "Licht bewolkt"
        case 2: return "Half bewolkt"
        case 3: return "Bewolkt"
        case 45, 48: return "Mist"
        case 51...57: return "Motregen"
        case 61...67: return "Regen"
        case 71...77: return "Sneeuw"
        case 80...82: return "Buien"
        case 85, 86: return "Sneeuwbuien"
        case 95...99: return "Onweer"
        default: return "—"
        }
    }
}

/// Weer via Open-Meteo (gratis, geen sleutel). Locatie: globale CoreLocation-positie of een ingestelde stad.
final class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var weather: Weather?
    @Published private(set) var locationDenied = false

    private let manager = CLLocationManager()
    private var timer: Timer?
    private var lastCity = ""

    func start() {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced
        lastCity = UserDefaults.standard.string(forKey: Pref.weatherCity) ?? ""
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in self?.refresh() }
        timer?.tolerance = 60

        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            let city = UserDefaults.standard.string(forKey: Pref.weatherCity) ?? ""
            if city != self.lastCity {
                self.lastCity = city
                self.refresh()
            }
        }
    }

    func refresh() {
        guard Pref.bool(Pref.weatherEnabled) else { weather = nil; return }
        let city = lastCity.trimmingCharacters(in: .whitespaces)
        if !city.isEmpty {
            geocode(city)
            return
        }
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            locationDenied = true
        default:
            manager.requestLocation()
        }
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationDenied = manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted
        if manager.authorizationStatus != .notDetermined, !locationDenied, lastCity.isEmpty {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        CLGeocoder().reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
            let name = placemarks?.first?.locality ?? ""
            self?.fetch(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude, place: name)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        NSLog("Island weer: locatie mislukt: \(error.localizedDescription)")
    }

    // MARK: Open-Meteo

    private func geocode(_ city: String) {
        var comps = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        comps.queryItems = [
            URLQueryItem(name: "name", value: city),
            URLQueryItem(name: "count", value: "1"),
            URLQueryItem(name: "language", value: "nl"),
        ]
        URLSession.shared.dataTask(with: comps.url!) { [weak self] data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let first = (json["results"] as? [[String: Any]])?.first,
                  let lat = first["latitude"] as? Double,
                  let lon = first["longitude"] as? Double else { return }
            self?.fetch(lat: lat, lon: lon, place: first["name"] as? String ?? city)
        }.resume()
    }

    private func fetch(lat: Double, lon: Double, place: String) {
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            URLQueryItem(name: "latitude", value: String(lat)),
            URLQueryItem(name: "longitude", value: String(lon)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "1"),
        ]
        URLSession.shared.dataTask(with: comps.url!) { [weak self] data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let current = json["current"] as? [String: Any],
                  let temp = (current["temperature_2m"] as? NSNumber)?.doubleValue else { return }
            let daily = json["daily"] as? [String: Any]
            let high = ((daily?["temperature_2m_max"] as? [NSNumber])?.first?.doubleValue) ?? temp
            let low = ((daily?["temperature_2m_min"] as? [NSNumber])?.first?.doubleValue) ?? temp
            let w = Weather(
                temperature: temp, high: high, low: low,
                code: (current["weather_code"] as? NSNumber)?.intValue ?? 0,
                isDay: ((current["is_day"] as? NSNumber)?.intValue ?? 1) == 1,
                place: place)
            DispatchQueue.main.async { self?.weather = w }
        }.resume()
    }

    static func format(_ celsius: Double) -> String {
        let value = Pref.bool(Pref.useFahrenheit) ? celsius * 9 / 5 + 32 : celsius
        return "\(Int(value.rounded()))°"
    }
}

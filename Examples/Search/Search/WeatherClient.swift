import ComposableArchitecture
import Foundation

// MARK: - API models

struct Search: Decodable, Equatable {
  var results: [Result]

  struct Result: Decodable, Equatable, Identifiable {
    var country: String
    var latitude: Double
    var longitude: Double
    var id: Int
    var name: String
    var admin1: String?
  }
}

struct Forecast: Decodable, Equatable {
  var daily: Daily
  var dailyUnits: DailyUnits

  struct Daily: Decodable, Equatable {
    var temperatureMax: [Double]
    var temperatureMin: [Double]
    var time: [Date]
  }

  struct DailyUnits: Decodable, Equatable {
    var temperatureMax: String
    var temperatureMin: String
  }
}

// MARK: - API client interface

// Typically this interface would live in its own module, separate from the live implementation.
// This allows the search feature to compile faster since it only depends on the interface.

struct WeatherClient {
  var forecast: (Search.Result) -> Effect<Forecast, Failure>
  var search: (String) -> Effect<Search, Failure>

  struct Failure: Error, Equatable {}
}

// MARK: - Live API implementation

extension WeatherClient {
  static let live = WeatherClient(
    forecast: { result in
      var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
      components.queryItems = [
        .init(name: "latitude", value: "\(result.latitude)"),
        .init(name: "longitude", value: "\(result.longitude)"),
        .init(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
        .init(name: "timezone", value: TimeZone.autoupdatingCurrent.identifier),
      ]

      return URLSession.shared.dataTaskPublisher(for: components.url!)
        .map { data, _ in data }
        .decode(type: Forecast.self, decoder: jsonDecoder)
        .mapError { _ in Failure() }
        .eraseToEffect()
    },
    search: { query in
      var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
      components.queryItems = [.init(name: "name", value: query)]

      return URLSession.shared.dataTaskPublisher(for: components.url!)
        .map { data, _ in data }
        .decode(type: Search.self, decoder: jsonDecoder)
        .mapError { _ in Failure() }
        .eraseToEffect()
    }
  )
}

// MARK: - Mock API implementations

extension WeatherClient {
  static let failing = Self(
    forecast: { _ in .failing("\(Self.self).forecast") },
    search: { _ in .failing("\(Self.self).search") }
  )
}

extension Forecast {
  static let mock = Self(
    daily: .init(
      temperatureMax: [90, 70, 100],
      temperatureMin: [70, 50, 80],
      time: [0, 86_400, 172_800].map(Date.init(timeIntervalSince1970:))
    ),
    dailyUnits: .init(temperatureMax: "°F", temperatureMin: "°F")
  )
}

extension Search {
  static let mock = Self(
    results: [
      Search.Result(
        country: "United States",
        latitude: 40.6782,
        longitude: -73.9442,
        id: 1,
        name: "Brooklyn",
        admin1: nil
      ),
      Search.Result(
        country: "United States",
        latitude: 34.0522,
        longitude: -118.2437,
        id: 2,
        name: "Los Angeles",
        admin1: nil
      ),
      Search.Result(
        country: "United States",
        latitude: 37.7749,
        longitude: -122.4194,
        id: 3,
        name: "San Francisco",
        admin1: nil
      ),
    ]
  )
}

// MARK: - Private helpers

private let jsonDecoder: JSONDecoder = {
  let decoder = JSONDecoder()
  let formatter = DateFormatter()
  formatter.calendar = Calendar(identifier: .iso8601)
  formatter.dateFormat = "yyyy-MM-dd"
  formatter.timeZone = TimeZone(secondsFromGMT: 0)
  formatter.locale = Locale(identifier: "en_US_POSIX")
  decoder.dateDecodingStrategy = .formatted(formatter)
  return decoder
}()

extension Forecast {
  private enum CodingKeys: String, CodingKey {
    case daily
    case dailyUnits = "daily_units"
  }
}

extension Forecast.Daily {
  private enum CodingKeys: String, CodingKey {
    case temperatureMax = "temperature_2m_max"
    case temperatureMin = "temperature_2m_min"
    case time
  }
}

extension Forecast.DailyUnits {
  private enum CodingKeys: String, CodingKey {
    case temperatureMax = "temperature_2m_max"
    case temperatureMin = "temperature_2m_min"
  }
}

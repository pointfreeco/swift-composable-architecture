import ComposableArchitecture
import Foundation

// MARK: - API models

struct Location: Decodable, Equatable {
  var id: Int
  var title: String
}

struct LocationWeather: Decodable, Equatable {
  var consolidatedWeather: [ConsolidatedWeather]
  var id: Int

  struct ConsolidatedWeather: Decodable, Equatable {
    var applicableDate: Date
    var maxTemp: Double
    var minTemp: Double
    var theTemp: Double
    var weatherStateName: String?
  }
}

// MARK: - API client interface

// Typically this interface would live in its own module, separate from the live implementation.
// This allows the search feature to compile faster since it only depends on the interface.

struct WeatherClient {
  var searchLocation: (String) async throws -> [Location]
  var weather: (Int) async throws -> LocationWeather
}

// MARK: - Live API implementation

// Example endpoints:
//   https://www.metaweather.com/api/location/search/?query=san
//   https://www.metaweather.com/api/location/2487956/

extension WeatherClient {
  static let live = WeatherClient(
    searchLocation: { query in
      var components = URLComponents(string: "https://www.metaweather.com/api/location/search")!
      components.queryItems = [URLQueryItem(name: "query", value: query)]
      let (data, _) = try await URLSession.shared.data(from: components.url!)
      return try jsonDecoder.decode([Location].self, from: data)
    },
    weather: { id in
      let url = URL(string: "https://www.metaweather.com/api/location/\(id)")!
      let (data, _) = try await URLSession.shared.data(from: url)
      return try jsonDecoder.decode(LocationWeather.self, from: data)
    })
}

// MARK: - Mock API implementations

extension WeatherClient {
  static let failing = Self(
    searchLocation: { _ in
      throw UnimplementedError(message: "WeatherClient.searchLocation")
    },
    weather: { _ in
      throw UnimplementedError(message: "WeatherClient.weather")
    }
  )
}

struct UnimplementedError: Error {
  let message: String
}

// MARK: - Private helpers

private let jsonDecoder: JSONDecoder = {
  let d = JSONDecoder()
  let formatter = DateFormatter()
  formatter.dateFormat = "yyyy-MM-dd"
  formatter.calendar = Calendar(identifier: .iso8601)
  formatter.timeZone = TimeZone(secondsFromGMT: 0)
  formatter.locale = Locale(identifier: "en_US_POSIX")
  d.dateDecodingStrategy = .formatted(formatter)
  return d
}()

extension Location {
  private enum CodingKeys: String, CodingKey {
    case id = "woeid"
    case title
  }
}

extension LocationWeather {
  private enum CodingKeys: String, CodingKey {
    case consolidatedWeather = "consolidated_weather"
    case id = "woeid"
  }
}

extension LocationWeather.ConsolidatedWeather {
  private enum CodingKeys: String, CodingKey {
    case applicableDate = "applicable_date"
    case maxTemp = "max_temp"
    case minTemp = "min_temp"
    case theTemp = "the_temp"
    case weatherStateName = "weather_state_name"
  }
}

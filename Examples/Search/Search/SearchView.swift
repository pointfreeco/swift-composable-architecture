import ComposableArchitecture
import SwiftUI

private let readMe = """
  This application demonstrates live-searching with the Composable Architecture. As you type the \
  events are debounced for 300 milliseconds, and when you stop typing an API request is made to \
  load locations. Then tapping on a location will load weather.
  """

@Reducer
struct Search {
  @ObservableState
  struct State: Equatable {
    var results: [GeocodingSearch.Result] = []
    var resultForecastRequestInFlight: GeocodingSearch.Result?
    var searchQuery = ""
    var weather: Weather?

    struct Weather: Equatable {
      var id: GeocodingSearch.Result.ID
      var days: [Day]

      struct Day: Equatable {
        var date: Date
        var temperatureMax: Double
        var temperatureMaxUnit: String
        var temperatureMin: Double
        var temperatureMinUnit: String
      }
    }
  }

  enum Action {
    case forecastResponse(GeocodingSearch.Result.ID, Result<Forecast, any Error>)
    case searchQueryChanged(String)
    case searchQueryChangeDebounced
    case searchResponse(Result<GeocodingSearch, any Error>)
    case searchResultTapped(GeocodingSearch.Result)
  }

  @Dependency(\.weatherClient) var weatherClient
  private enum CancelID { case location, weather }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .forecastResponse(_, .failure):
        state.weather = nil
        state.resultForecastRequestInFlight = nil
        return .none

      case let .forecastResponse(id, .success(forecast)):
        state.weather = State.Weather(
          id: id,
          days: forecast.daily.time.indices.map {
            State.Weather.Day(
              date: forecast.daily.time[$0],
              temperatureMax: forecast.daily.temperatureMax[$0],
              temperatureMaxUnit: forecast.dailyUnits.temperatureMax,
              temperatureMin: forecast.daily.temperatureMin[$0],
              temperatureMinUnit: forecast.dailyUnits.temperatureMin
            )
          }
        )
        state.resultForecastRequestInFlight = nil
        return .none

      case let .searchQueryChanged(query):
        state.searchQuery = query

        // When the query is cleared we can clear the search results, but we have to make sure to
        // cancel any in-flight search requests too, otherwise we may get data coming in later.
        guard !state.searchQuery.isEmpty else {
          state.results = []
          state.weather = nil
          return .cancel(id: CancelID.location)
        }
        return .none

      case .searchQueryChangeDebounced:
        guard !state.searchQuery.isEmpty else {
          return .none
        }
        return .run { [query = state.searchQuery] send in
          await send(.searchResponse(Result { try await self.weatherClient.search(query: query) }))
        }
        .cancellable(id: CancelID.location)

      case .searchResponse(.failure):
        state.results = []
        return .none

      case let .searchResponse(.success(response)):
        state.results = response.results
        return .none

      case let .searchResultTapped(location):
        state.resultForecastRequestInFlight = location

        return .run { send in
          await send(
            .forecastResponse(
              location.id,
              Result { try await self.weatherClient.forecast(location: location) }
            )
          )
        }
        .cancellable(id: CancelID.weather, cancelInFlight: true)
      }
    }
  }
}

struct SearchView: View {
  @Bindable var store: StoreOf<Search>

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading) {
        Text(readMe)
          .padding()

        HStack {
          Image(systemName: "magnifyingglass")
          TextField(
            "New York, San Francisco, ...", text: $store.searchQuery.sending(\.searchQueryChanged)
          )
          .textFieldStyle(.roundedBorder)
          .autocapitalization(.none)
          .disableAutocorrection(true)
        }
        .padding(.horizontal, 16)

        List {
          ForEach(store.results) { location in
            VStack(alignment: .leading) {
              Button {
                store.send(.searchResultTapped(location))
              } label: {
                HStack {
                  Text(location.name)

                  if store.resultForecastRequestInFlight?.id == location.id {
                    ProgressView()
                  }
                }
              }

              if location.id == store.weather?.id {
                weatherView(locationWeather: store.weather)
              }
            }
          }
        }

        Button("Weather API provided by Open-Meteo") {
          UIApplication.shared.open(URL(string: "https://open-meteo.com/en")!)
        }
        .foregroundColor(.gray)
        .padding(.all, 16)
      }
      .navigationTitle("Search")
    }
    .task(id: store.searchQuery) {
      do {
        try await Task.sleep(for: .milliseconds(300))
        await store.send(.searchQueryChangeDebounced).finish()
      } catch {}
    }
  }

  @ViewBuilder
  func weatherView(locationWeather: Search.State.Weather?) -> some View {
    if let locationWeather {
      let days = locationWeather.days
        .enumerated()
        .map { idx, weather in formattedWeather(day: weather, isToday: idx == 0) }

      VStack(alignment: .leading) {
        ForEach(days, id: \.self) { day in
          Text(day)
        }
      }
      .padding(.leading, 16)
    }
  }
}

private func formattedWeather(day: Search.State.Weather.Day, isToday: Bool) -> String {
  let date =
    isToday
    ? "Today"
    : dateFormatter.string(from: day.date).capitalized
  let min = "\(day.temperatureMin)\(day.temperatureMinUnit)"
  let max = "\(day.temperatureMax)\(day.temperatureMaxUnit)"

  return "\(date), \(min) – \(max)"
}

private let dateFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.dateFormat = "EEEE"
  return formatter
}()

#Preview {
  SearchView(
    store: Store(initialState: Search.State()) {
      Search()
    }
  )
}

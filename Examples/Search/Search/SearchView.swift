import ComposableArchitecture
import SwiftUI

private let readMe = """
  This application demonstrates live-searching with the Composable Architecture. As you type the \
  events are debounced for 300ms, and when you stop typing an API request is made to load \
  locations. Then tapping on a location will load weather.
  """

// MARK: - Search feature domain

struct Search: ReducerProtocol {
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

  enum Action: Equatable {
    case forecastResponse(GeocodingSearch.Result.ID, TaskResult<Forecast>)
    case searchQueryChanged(String)
    case searchQueryChangeDebounced
    case searchResponse(TaskResult<GeocodingSearch>)
    case searchResultTapped(GeocodingSearch.Result)
  }

  @Dependency(\.weatherClient) var weatherClient
  private enum SearchLocationID {}
  private enum SearchWeatherID {}

  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
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

      // When the query is cleared we can clear the search results, but we have to make sure to cancel
      // any in-flight search requests too, otherwise we may get data coming in later.
      guard !query.isEmpty else {
        state.results = []
        state.weather = nil
        return .cancel(id: SearchLocationID.self)
      }
      return .none

    case .searchQueryChangeDebounced:
      guard !state.searchQuery.isEmpty else {
        return .none
      }
      return .task { [query = state.searchQuery] in
        await .searchResponse(TaskResult { try await self.weatherClient.search(query) })
      }
      .cancellable(id: SearchLocationID.self)

    case .searchResponse(.failure):
      state.results = []
      return .none

    case let .searchResponse(.success(response)):
      state.results = response.results
      return .none

    case let .searchResultTapped(location):
      state.resultForecastRequestInFlight = location

      return .task {
        await .forecastResponse(
          location.id,
          TaskResult { try await self.weatherClient.forecast(location) }
        )
      }
      .cancellable(id: SearchWeatherID.self, cancelInFlight: true)
    }
  }
}

// MARK: - Search feature view

struct SearchView: View {
  let store: StoreOf<Search>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      NavigationView {
        VStack(alignment: .leading) {
          Text(readMe)
            .padding()

          HStack {
            Image(systemName: "magnifyingglass")
            TextField(
              "New York, San Francisco, ...",
              text: viewStore.binding(
                get: \.searchQuery, send: Search.Action.searchQueryChanged
              )
            )
            .textFieldStyle(.roundedBorder)
            .autocapitalization(.none)
            .disableAutocorrection(true)
          }
          .padding(.horizontal, 16)

          List {
            ForEach(viewStore.results) { location in
              VStack(alignment: .leading) {
                Button(action: { viewStore.send(.searchResultTapped(location)) }) {
                  HStack {
                    Text(location.name)

                    if viewStore.resultForecastRequestInFlight?.id == location.id {
                      ProgressView()
                    }
                  }
                }

                if location.id == viewStore.weather?.id {
                  self.weatherView(locationWeather: viewStore.weather)
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
      .navigationViewStyle(.stack)
      .task(id: viewStore.searchQuery) {
        do {
          try await Task.sleep(nanoseconds: NSEC_PER_SEC / 3)
          await viewStore.send(.searchQueryChangeDebounced).finish()
        } catch {}
      }
    }
  }

  func weatherView(locationWeather: Search.State.Weather?) -> some View {
    guard let locationWeather = locationWeather else {
      return AnyView(EmptyView())
    }

    let days = locationWeather.days
      .enumerated()
      .map { idx, weather in formattedWeatherDay(weather, isToday: idx == 0) }

    return AnyView(
      VStack(alignment: .leading) {
        ForEach(days, id: \.self) { day in
          Text(day)
        }
      }
      .padding(.leading, 16)
    )
  }
}

// MARK: - Private helpers

private func formattedWeatherDay(_ day: Search.State.Weather.Day, isToday: Bool)
  -> String
{
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

// MARK: - SwiftUI previews

struct SearchView_Previews: PreviewProvider {
  static var previews: some View {
    let store = Store(
      initialState: Search.State(),
      reducer: Search()
    )
  }
}

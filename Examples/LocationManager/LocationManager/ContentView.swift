import ComposableArchitecture
import MapKit
import SwiftUI

struct AppState: Equatable {
  var alert: String?
  var currentPointOfInterestCategory: MKPointOfInterestCategory?
  var currentRegion: CoordinateRegion?
  var isLocationRequestInFlight = false

  static let pointOfInterestCategories: [MKPointOfInterestCategory] = [
    .cafe,
    .museum,
    .nightlife,
    .park,
    .restaurant
  ]
}

enum AppAction: Equatable {
  case categoryButtonTapped(MKPointOfInterestCategory)
  case currentLocationButtonTapped
  case dismissAlertButtonTapped
  case localSearchResponse(Result<LocalSearchResponse, LocalSearchError>)
  case locationManager(LocationManagerAction)
  case onAppear
  case updateRegion(CoordinateRegion?)
}

struct AppEnvironment {
  var localSearch: LocalSearchClient
  var locationManager: LocationManagerClient
}

private struct LocationManagerId: Hashable {}

let appReducer = Reducer<AppState, AppAction, AppEnvironment> { state, action, environment in
  switch action {
  case let .categoryButtonTapped(category):

    let request = MKLocalSearch.Request.init()
    request.pointOfInterestFilter = MKPointOfInterestFilter(including: [category])
    if let region = state.currentRegion?.asMKCoordinateRegion {
      request.region = region
    }
    return environment.localSearch
      .search(request)
      .catchToEffect()
      .map(AppAction.localSearchResponse)

  case .currentLocationButtonTapped:
    guard environment.locationManager.locationServicesEnabled() else {
      state.alert = "Location services are turned off."
      return .none
    }

    switch environment.locationManager.authorizationStatus() {
    case .notDetermined:
      state.isLocationRequestInFlight = true
      return environment.locationManager
        .requestWhenInUseAuthorization(id: LocationManagerId())
        .fireAndForget()
    case .restricted:
      state.alert = "Please give us access to your location in settings."
      return .none
    case .denied:
      state.alert = "Please give us access to your location in settings."
      return .none
    case .authorizedAlways, .authorizedWhenInUse:
      return environment.locationManager
        .requestLocation(id: LocationManagerId())
        .fireAndForget()
    @unknown default:
      return .none
    }

  case .dismissAlertButtonTapped:
    state.alert = nil
    return .none

  case let .localSearchResponse(response):
    return .none

  case .locationManager(_):
    return .none

  case .onAppear:
    return environment.locationManager.create(id: LocationManagerId())
      .map(AppAction.locationManager)

  case let .updateRegion(region):
    state.currentRegion = region
    return .none
  }
}
.combined(
  with: locationManagerReducer
    .pullback(state: \.self, action: /AppAction.locationManager, environment: { $0 })
)
  .debug()

let locationManagerReducer = Reducer<AppState, LocationManagerAction, AppEnvironment> { state, action, environment in
  switch action {

  case .didChangeAuthorization(.authorizedAlways),
       .didChangeAuthorization(.authorizedWhenInUse):
    if state.isLocationRequestInFlight {
      return environment.locationManager
        .requestLocation(id: LocationManagerId())
        .fireAndForget()
    }
    return .none

  case .didChangeAuthorization(.denied):
    if state.isLocationRequestInFlight {
      state.alert = "Location makes this app better. Please consider giving us access."
    }
    return .none

  case let .didUpdateLocations(locations):
    state.isLocationRequestInFlight = false
    guard let location = locations.first else { return .none }
    state.currentRegion = CoordinateRegion(
      center: location.coordinate,
      span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    return .none

  case .didChangeAuthorization,
       .didCreate,
       .didFailWithError,
       .didVisit:
    return .none
  }
}

struct ContentView: View {
  @Environment(\.colorScheme) var colorScheme
  let store: Store<AppState, AppAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      ZStack {
        MapView(region: viewStore.binding(get: \.currentRegion, send: AppAction.updateRegion))
          .edgesIgnoringSafeArea([.all])

        VStack(alignment: .trailing) {
          Spacer()

          Button(action: { viewStore.send(.currentLocationButtonTapped) }) {
            Image(systemName: "location")
              .foregroundColor(self.colorScheme == .dark ? Color.white : Color.black)
              .frame(width: 44, height: 44)
              .background(self.colorScheme == .dark ? Color.black : Color.white)
              .clipShape(Circle())
              .padding([.trailing], 16)
              .padding([.bottom], 8)
          }

          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
              ForEach(AppState.pointOfInterestCategories, id: \.rawValue) { category in
                Button(category.displayName) { viewStore.send(.categoryButtonTapped(category)) }
                  .padding([.all], 10)
                  .background(self.colorScheme == .dark ? Color.black : Color.white)
                  .cornerRadius(8)
              }
            }
            .padding()
          }
        }
      }
      .alert(
        item: viewStore.binding(
          get: { $0.alert.map(AppAlert.init(title:)) },
          send: AppAction.dismissAlertButtonTapped
        )
      ) { alert in
        Alert(title: Text(alert.title))
      }
      .onAppear { viewStore.send(.onAppear) }
    }
  }
}

struct AppAlert: Identifiable {
  var title: String

  var id: String { self.title }
}

extension MKPointOfInterestCategory {
  fileprivate var displayName: String {
    switch self {
    case .cafe:
      return "Cafe"
    case .museum:
      return "Museum"
    case .nightlife:
      return "Nightlife"
    case .park:
      return "Park"
    case .restaurant:
      return "Restaurant"
    default:
      return "N/A"
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView(
      store: Store(
        initialState: AppState(),
        reducer: appReducer,
        environment: AppEnvironment(
          localSearch: .live,
          locationManager: .live
        )
      )
    )
  }
}

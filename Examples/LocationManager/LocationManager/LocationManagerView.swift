import Combine
import ComposableArchitecture
import MapKit
import SwiftUI

private let readMe = """
  This application demonstrates how to work with CLLocationManager for getting the user's current \
  location, and MKLocalSearch for searching points of interest on the map.

  Zoom into any part of the map and tap a category to search for points of interest nearby. The \
  markers are also updated live if you drag the map around.
  """

struct PointOfInterest: Equatable {
  let coordinate: CLLocationCoordinate2D
  let subtitle: String?
  let title: String?
}

struct AppState: Equatable {
  var alert: String?
  var isRequestingCurrentLocation = false
  var pointOfInterestCategory: MKPointOfInterestCategory?
  var pointsOfInterest: [PointOfInterest] = []
  var region: CoordinateRegion?

  static let pointOfInterestCategories: [MKPointOfInterestCategory] = [
    .cafe,
    .museum,
    .nightlife,
    .park,
    .restaurant,
  ]
}

enum AppAction: Equatable {
  case categoryButtonTapped(MKPointOfInterestCategory)
  case currentLocationButtonTapped
  case dismissAlertButtonTapped
  case localSearchResponse(Result<LocalSearchResponse, LocalSearchClient.Error>)
  case locationManager(LocationManagerClient.Action)
  case onAppear
  case updateRegion(CoordinateRegion?)
}

struct AppEnvironment {
  var localSearch: LocalSearchClient
  var locationManager: LocationManagerClient
}

private struct LocationManagerId: Hashable {}
private struct CancelSearchId: Hashable {}

let appReducer = Reducer<AppState, AppAction, AppEnvironment> { state, action, environment in
  switch action {
  case let .categoryButtonTapped(category):
    guard category != state.pointOfInterestCategory else {
      state.pointOfInterestCategory = nil
      state.pointsOfInterest = []
      return .cancel(id: CancelSearchId())
    }

    state.pointOfInterestCategory = category

    let request = MKLocalSearch.Request()
    request.pointOfInterestFilter = MKPointOfInterestFilter(including: [category])
    if let region = state.region?.asMKCoordinateRegion {
      request.region = region
    }
    return environment.localSearch
      .search(request)
      .catchToEffect()
      .map(AppAction.localSearchResponse)
      .cancellable(id: CancelSearchId(), cancelInFlight: true)

  case .currentLocationButtonTapped:
    guard environment.locationManager.locationServicesEnabled() else {
      state.alert = "Location services are turned off."
      return .none
    }

    switch environment.locationManager.authorizationStatus() {
    case .notDetermined:
      state.isRequestingCurrentLocation = true
      return environment.locationManager
        .requestWhenInUseAuthorization(LocationManagerId())
        .fireAndForget()

    case .restricted:
      state.alert = "Please give us access to your location in settings."
      return .none

    case .denied:
      state.alert = "Please give us access to your location in settings."
      return .none

    case .authorizedAlways, .authorizedWhenInUse:
      return environment.locationManager
        .requestLocation(LocationManagerId())
        .fireAndForget()

    @unknown default:
      return .none
    }

  case .dismissAlertButtonTapped:
    state.alert = nil
    return .none

  case let .localSearchResponse(.success(response)):
    state.pointsOfInterest = response.mapItems.map { item in
      PointOfInterest(
        coordinate: item.placemark.coordinate,
        subtitle: item.placemark.subtitle,
        title: item.name
      )
    }
    return .none

  case .localSearchResponse(.failure):
    state.alert = "Could not perform search. Please try again."
    return .none

  case .locationManager:
    return .none

  case .onAppear:
    return environment.locationManager.create(LocationManagerId())
      .map(AppAction.locationManager)

  case let .updateRegion(region):
    state.region = region

    guard
      let category = state.pointOfInterestCategory,
      let region = state.region?.asMKCoordinateRegion
    else { return .none }

    let request = MKLocalSearch.Request()
    request.pointOfInterestFilter = MKPointOfInterestFilter(including: [category])
    request.region = region
    return environment.localSearch
      .search(request)
      .catchToEffect()
      .map(AppAction.localSearchResponse)
      .cancellable(id: CancelSearchId(), cancelInFlight: true)
  }
}
.combined(
  with:
    locationManagerReducer
    .pullback(state: \.self, action: /AppAction.locationManager, environment: { $0 })
)
.debug()

let locationManagerReducer = Reducer<AppState, LocationManagerClient.Action, AppEnvironment> {
  state, action, environment in

  switch action {
  case .didChangeAuthorization(.authorizedAlways),
    .didChangeAuthorization(.authorizedWhenInUse):
    if state.isRequestingCurrentLocation {
      return environment.locationManager
        .requestLocation(LocationManagerId())
        .fireAndForget()
    }
    return .none

  case .didChangeAuthorization(.denied):
    if state.isRequestingCurrentLocation {
      state.alert = "Location makes this app better. Please consider giving us access."
      state.isRequestingCurrentLocation = false
    }
    return .none

  case let .didUpdateLocations(locations):
    state.isRequestingCurrentLocation = false
    guard let location = locations.first else { return .none }
    state.region = CoordinateRegion(
      center: location.coordinate,
      span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    return .none

  case .didChangeAuthorization,
    .didCreate,
    .didFailWithError:
    return .none
  }
}

struct LocationManagerView: View {
  @Environment(\.colorScheme) var colorScheme
  let store: Store<AppState, AppAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      ZStack {
        MapView(
          pointsOfInterest: viewStore.pointsOfInterest,
          region: viewStore.binding(get: { $0.region }, send: AppAction.updateRegion)
        )
        .edgesIgnoringSafeArea([.all])

        VStack(alignment: .trailing) {
          Spacer()

          Button(action: { viewStore.send(.currentLocationButtonTapped) }) {
            Image(systemName: "location")
              .foregroundColor(Color.white)
              .frame(width: 60, height: 60)
              .background(Color.secondary)
              .clipShape(Circle())
              .padding([.trailing], 16)
              .padding([.bottom], 16)
          }

          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
              ForEach(AppState.pointOfInterestCategories, id: \.rawValue) { category in
                Button(category.displayName) { viewStore.send(.categoryButtonTapped(category)) }
                  .padding([.all], 16)
                  .background(
                    category == viewStore.pointOfInterestCategory ? Color.blue : Color.secondary
                  )
                  .foregroundColor(.white)
                  .cornerRadius(8)
              }
            }
            .padding([.leading, .trailing])
            .padding([.bottom], 32)
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

extension PointOfInterest {
  // NB: CLLocationCoordinate2D doesn't conform to Equatable
  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.coordinate.latitude == rhs.coordinate.latitude
      && lhs.coordinate.longitude == rhs.coordinate.longitude
      && lhs.subtitle == rhs.subtitle
      && lhs.title == rhs.title
  }
}

struct ContentView: View {
  var body: some View {
    NavigationView {
      Form {
        Section(
          header: Text(readMe)
            .font(.body)
            .padding([.bottom])
        ) {
          NavigationLink(
            "Go to demo",
            destination: LocationManagerView(
              store: Store(
                initialState: AppState(),
                reducer: appReducer,
                environment: AppEnvironment(localSearch: .live, locationManager: .live)
              )
            )
          )
        }
      }
      .navigationBarTitle("Location Manager")
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    // NB: CLLocationManager mostly does not work in SwiftUI previews, so we provide a mock
    //     client that has all authorization allowed and mocks the device's current location
    //     to Brooklyn, NY.
    let mockLocation = Location(
      altitude: 0,
      coordinate: CLLocationCoordinate2D(latitude: 40.6501, longitude: -73.94958),
      course: 0,
      courseAccuracy: 0,
      floor: nil,
      horizontalAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
      timestamp: Date(timeIntervalSince1970: 1_234_567_890),
      verticalAccuracy: 0
    )
    let locationManagerSubject = PassthroughSubject<LocationManagerClient.Action, Never>()
    let locationManager = LocationManagerClient.mock(
      authorizationStatus: { .authorizedAlways },
      create: { _ in locationManagerSubject.eraseToEffect() },
      locationServicesEnabled: { true },
      requestLocation: { _ in
        .fireAndForget { locationManagerSubject.send(.didUpdateLocations([mockLocation])) }
      },
      requestWhenInUseAuthorization: { _ in .fireAndForget {} }
    )

    let appView = LocationManagerView(
      store: Store(
        initialState: AppState(),
        reducer: appReducer,
        environment: AppEnvironment(
          localSearch: .live,
          locationManager: locationManager
        )
      )
    )

    return Group {
      ContentView()
      appView
      appView
        .environment(\.colorScheme, .dark)
    }
  }
}

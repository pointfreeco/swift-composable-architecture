import ComposableArchitecture
import ComposableCoreLocation
import MapKit

public struct PointOfInterest: Equatable, Hashable {
  public let coordinate: CLLocationCoordinate2D
  public let subtitle: String?
  public let title: String?

  public init(
    coordinate: CLLocationCoordinate2D,
    subtitle: String?,
    title: String?
  ) {
    self.coordinate = coordinate
    self.subtitle = subtitle
    self.title = title
  }
}

public struct AppState: Equatable {
  public var alert: AlertState<AppAction>?
  public var isRequestingCurrentLocation = false
  public var pointOfInterestCategory: MKPointOfInterestCategory?
  public var pointsOfInterest: [PointOfInterest] = []
  public var region: CoordinateRegion?

  public init(
    alert: AlertState<AppAction>? = nil,
    isRequestingCurrentLocation: Bool = false,
    pointOfInterestCategory: MKPointOfInterestCategory? = nil,
    pointsOfInterest: [PointOfInterest] = [],
    region: CoordinateRegion? = nil
  ) {
    self.alert = alert
    self.isRequestingCurrentLocation = isRequestingCurrentLocation
    self.pointOfInterestCategory = pointOfInterestCategory
    self.pointsOfInterest = pointsOfInterest
    self.region = region
  }

  public static let pointOfInterestCategories: [MKPointOfInterestCategory] = [
    .cafe,
    .museum,
    .nightlife,
    .park,
    .restaurant,
  ]
}

public enum AppAction: Equatable {
  case categoryButtonTapped(MKPointOfInterestCategory)
  case currentLocationButtonTapped
  case dismissAlertButtonTapped
  case localSearchResponse(Result<LocalSearchResponse, LocalSearchClient.Error>)
  case locationManager(LocationManager.Action)
  case onAppear
  case onDisappear
  case updateRegion(CoordinateRegion?)
}

public struct AppEnvironment {
  public var localSearch: LocalSearchClient
  public var locationManager: LocationManager

  public init(
    localSearch: LocalSearchClient,
    locationManager: LocationManager
  ) {
    self.localSearch = localSearch
    self.locationManager = locationManager
  }
}

private struct LocationManagerId: Hashable {}
private struct CancelSearchId: Hashable {}

public let appReducer = Reducer<AppState, AppAction, AppEnvironment> { state, action, environment in
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
      state.alert = .init(title: "Location services are turned off.")
      return .none
    }

    switch environment.locationManager.authorizationStatus() {
    case .notDetermined:
      state.isRequestingCurrentLocation = true
      #if os(macOS)
        return environment.locationManager
          .requestAlwaysAuthorization(id: LocationManagerId())
          .fireAndForget()
      #else
        return environment.locationManager
          .requestWhenInUseAuthorization(id: LocationManagerId())
          .fireAndForget()
      #endif

    case .restricted:
      state.alert = .init(title: "Please give us access to your location in settings.")
      return .none

    case .denied:
      state.alert = .init(title: "Please give us access to your location in settings.")
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
    state.alert = .init(title: "Could not perform search. Please try again.")
    return .none

  case .locationManager:
    return .none

  case .onAppear:
    return environment.locationManager.create(id: LocationManagerId())
      .map(AppAction.locationManager)

  case .onDisappear:
    return environment.locationManager.destroy(id: LocationManagerId())
      .fireAndForget()

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
.signpost()
.debug()

private let locationManagerReducer = Reducer<AppState, LocationManager.Action, AppEnvironment> {
  state, action, environment in

  switch action {
  case .didChangeAuthorization(.authorizedAlways),
    .didChangeAuthorization(.authorizedWhenInUse):
    if state.isRequestingCurrentLocation {
      return environment.locationManager
        .requestLocation(id: LocationManagerId())
        .fireAndForget()
    }
    return .none

  case .didChangeAuthorization(.denied):
    if state.isRequestingCurrentLocation {
      state.alert = .init(
        title: "Location makes this app better. Please consider giving us access."
      )
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

  default:
    return .none
  }
}

extension PointOfInterest {
  // NB: CLLocationCoordinate2D doesn't conform to Equatable
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.coordinate.latitude == rhs.coordinate.latitude
      && lhs.coordinate.longitude == rhs.coordinate.longitude
      && lhs.subtitle == rhs.subtitle
      && lhs.title == rhs.title
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(coordinate.latitude)
    hasher.combine(coordinate.longitude)
    hasher.combine(title)
    hasher.combine(subtitle)
  }
}

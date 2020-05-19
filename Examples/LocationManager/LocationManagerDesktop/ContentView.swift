import Combine
import ComposableArchitecture
import ComposableCoreLocation
import LocationManagerCore
import LocalSearchClient
import MapKit
import SwiftUI

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

        VStack(alignment: .center) {
          Spacer()

          HStack(spacing: 16) {
            ForEach(AppState.pointOfInterestCategories, id: \.rawValue) { category in
              Button(category.displayName) { viewStore.send(.categoryButtonTapped(category)) }
            }

            Spacer()

            Button(action: { viewStore.send(.currentLocationButtonTapped) }) {
              Text("📍")
                .font(.body)
                .foregroundColor(Color.white)
                .frame(width: 44, height: 44)
                .background(Color.secondary)
                .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())

          }
          .padding([.leading, .trailing])
          .padding([.bottom], 16)
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
      requestAlwaysAuthorization: { _ in .fireAndForget {} },
      requestLocation: { _ in
        .fireAndForget { locationManagerSubject.send(.didUpdateLocations([mockLocation])) }
      }
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
      appView
      appView
        .environment(\.colorScheme, .dark)
    }
  }
}

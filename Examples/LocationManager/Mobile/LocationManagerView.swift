import Combine
import ComposableArchitecture
import ComposableCoreLocation
import MapKit
import SwiftUI

private let readMe = """
  This application demonstrates how to work with CLLocationManager for getting the user's current \
  location, and MKLocalSearch for searching points of interest on the map.

  Zoom into any part of the map and tap a category to search for points of interest nearby. The \
  markers are also updated live if you drag the map around.
  """

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
      .alert(self.store.scope(state: { $0.alert }), dismiss: .dismissAlertButtonTapped)
      .onAppear { viewStore.send(.onAppear) }
      .onDisappear { viewStore.send(.onDisappear) }
    }
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
    .navigationViewStyle(StackNavigationViewStyle())
  }
}

#if DEBUG
  struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
      // NB: CLLocationManager mostly does not work in SwiftUI previews, so we provide a mock
      //     manager that has all authorization allowed and mocks the device's current location
      //     to Brooklyn, NY.
      let mockLocation = Location(
        coordinate: CLLocationCoordinate2D(latitude: 40.6501, longitude: -73.94958)
      )
      let locationManagerSubject = PassthroughSubject<LocationManager.Action, Never>()
      let locationManager = LocationManager.mock(
        authorizationStatus: { .authorizedAlways },
        create: { _ in locationManagerSubject.eraseToEffect() },
        locationServicesEnabled: { true },
        requestLocation: { _ in
          .fireAndForget { locationManagerSubject.send(.didUpdateLocations([mockLocation])) }
        })

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
#endif

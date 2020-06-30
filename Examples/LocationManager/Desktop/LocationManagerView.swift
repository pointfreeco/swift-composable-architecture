import Combine
import ComposableArchitecture
import ComposableCoreLocation
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
                .buttonStyle(PlainButtonStyle())
                .padding([.all], 12)
                .background(
                  category == viewStore.pointOfInterestCategory ? Color.blue : Color.secondary
                )
                .foregroundColor(.white)
                .cornerRadius(8)
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
      .alert(self.store.scope(state: { $0.alert }), dismiss: .dismissAlertButtonTapped)
      .onAppear { viewStore.send(.onAppear) }
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    let appView = LocationManagerView(
      store: Store(
        initialState: AppState(),
        reducer: appReducer,
        environment: AppEnvironment(
          localSearch: .live,
          locationManager: .live
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

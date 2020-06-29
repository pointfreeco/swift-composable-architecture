import Combine
import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates how one can create reusable components in the Composable Architecture.

  The "download component" is a component that can be added to any view to enhance it with the \
  concept of downloading offline content. It facilitates downloading the data, displaying a \
  progress view while downloading, canceling an active download, and deleting previously \
  downloaded data.

  Tap the download icon to start a download, and tap again to cancel an in-flight download or to \
  remove a finished download. While a file is downloading you can tap a row to go to another \
  screen to see that the state is carried over.
  """

struct CityMap: Equatable, Identifiable {
  var blurb: String
  var downloadVideoUrl: URL
  let id: UUID
  var title: String
}

struct CityMapState: Equatable, Identifiable {
  var downloadAlert: AlertState<DownloadComponentAction.AlertAction>?
  var downloadMode: Mode
  var cityMap: CityMap

  var id: UUID { self.cityMap.id }

  var downloadComponent: DownloadComponentState<UUID> {
    get {
      DownloadComponentState(
        alert: self.downloadAlert,
        id: self.cityMap.id,
        mode: self.downloadMode,
        url: self.cityMap.downloadVideoUrl
      )
    }
    set {
      self.downloadAlert = newValue.alert
      self.downloadMode = newValue.mode
    }
  }
}

enum CityMapAction {
  case downloadComponent(DownloadComponentAction)
}

struct CityMapEnvironment {
  var downloadClient: DownloadClient
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

let cityMapReducer = Reducer<CityMapState, CityMapAction, CityMapEnvironment> {
  state, action, environment in
  switch action {
  case let .downloadComponent(.downloadClient(.success(.response(data)))):
    // TODO: save to disk
    return .none

  case .downloadComponent(.alert(.deleteButtonTapped)):
    // TODO: delete file from disk
    return .none

  case .downloadComponent:
    return .none
  }
}
.downloadable(
  state: \.downloadComponent,
  action: /CityMapAction.downloadComponent,
  environment: {
    DownloadComponentEnvironment(
      downloadClient: $0.downloadClient,
      mainQueue: $0.mainQueue
    )
  }
)
.signpost()

struct CityMapRowView: View {
  let store: Store<CityMapState, CityMapAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      HStack {
        NavigationLink(
          destination: CityMapDetailView(store: self.store)
        ) {
          HStack {
            Image(systemName: "map")
            Text(viewStore.cityMap.title)
          }
          .layoutPriority(1)

          Spacer()

          DownloadComponent(
            store: self.store.scope(
              state: { $0.downloadComponent },
              action: CityMapAction.downloadComponent
            )
          )
          .padding([.trailing], 8)
        }
      }
    }
  }
}

struct CityMapDetailView: View {
  let store: Store<CityMapState, CityMapAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      VStack(spacing: 32) {
        Text(viewStore.cityMap.blurb)

        HStack {
          if viewStore.downloadMode == .notDownloaded {
            Text("Download for offline viewing")
          } else if viewStore.downloadMode == .downloaded {
            Text("Downloaded")
          } else {
            Text("Downloading \(Int(100 * viewStore.downloadComponent.mode.progress))%")
          }

          Spacer()

          DownloadComponent(
            store: self.store.scope(
              state: { $0.downloadComponent },
              action: CityMapAction.downloadComponent
            )
          )
        }

        Spacer()
      }
      .navigationBarTitle(viewStore.cityMap.title)
      .padding()
    }
  }
}

struct MapAppState {
  var cityMaps: [CityMapState]
}

enum MapAppAction {
  case cityMaps(index: Int, action: CityMapAction)
}

struct MapAppEnvironment {
  var downloadClient: DownloadClient
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

let mapAppReducer: Reducer<MapAppState, MapAppAction, MapAppEnvironment> = cityMapReducer.forEach(
  state: \MapAppState.cityMaps,
  action: /MapAppAction.cityMaps(index:action:),
  environment: {
    CityMapEnvironment(
      downloadClient: $0.downloadClient,
      mainQueue: $0.mainQueue
    )
  }
).debug()

struct CitiesView: View {
  let store: Store<MapAppState, MapAppAction>

  var body: some View {
    Form {
      Section(
        header: Text(readMe)
      ) {
        ForEachStore(
          self.store.scope(state: { $0.cityMaps }, action: MapAppAction.cityMaps(index:action:))
        ) { cityMapStore in
          CityMapRowView(store: cityMapStore)
            .buttonStyle(BorderlessButtonStyle())
        }
      }
    }
    .navigationBarTitle("Offline Downloads")
  }
}

struct DownloadList_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      NavigationView {
        CitiesView(
          store: Store(
            initialState: .init(cityMaps: .mocks),
            reducer: mapAppReducer,
            environment: .init(
              downloadClient: .live,
              mainQueue: DispatchQueue.main.eraseToAnyScheduler()
            )
          )
        )
      }

      NavigationView {
        CityMapDetailView(
          store: Store(
            initialState: [CityMapState].mocks.first!,
            reducer: .empty,
            environment: ()
          )
        )
      }
    }
  }
}

extension Array where Element == CityMapState {
  static let mocks: Self = [
    .init(
      downloadMode: .notDownloaded,
      cityMap: .init(
        blurb: """
          New York City (NYC), known colloquially as New York (NY) and officially as the City of \
          New York, is the most populous city in the United States. With an estimated 2018 \
          population of 8,398,748 distributed over about 302.6 square miles (784 km2), New York \
          is also the most densely populated major city in the United States.
          """,
        downloadVideoUrl: URL(string: "http://ipv4.download.thinkbroadband.com/50MB.zip")!,
        id: UUID(),
        title: "New York, NY"
      )
    ),
    .init(
      downloadMode: .notDownloaded,
      cityMap: .init(
        blurb: """
          Los Angeles, officially the City of Los Angeles and often known by its initials L.A., \
          is the largest city in the U.S. state of California. With an estimated population of \
          nearly four million people, it is the country's second most populous city (after New \
          York City) and the third most populous city in North America (after Mexico City and \
          New York City). Los Angeles is known for its Mediterranean climate, ethnic diversity, \
          Hollywood entertainment industry, and its sprawling metropolis.
          """,
        downloadVideoUrl: URL(string: "http://ipv4.download.thinkbroadband.com/50MB.zip")!,
        id: UUID(),
        title: "Los Angeles, LA"
      )
    ),
    .init(
      downloadMode: .notDownloaded,
      cityMap: .init(
        blurb: """
          Paris is the capital and most populous city of France, with a population of 2,148,271 \
          residents (official estimate, 1 January 2020) in an area of 105 square kilometres (41 \
          square miles). Since the 17th century, Paris has been one of Europe's major centres of \
          finance, diplomacy, commerce, fashion, science and arts.
          """,
        downloadVideoUrl: URL(string: "http://ipv4.download.thinkbroadband.com/50MB.zip")!,
        id: UUID(),
        title: "Paris, France"
      )
    ),
    .init(
      downloadMode: .notDownloaded,
      cityMap: .init(
        blurb: """
          Tokyo, officially Tokyo Metropolis (東京都, Tōkyō-to), is the capital of Japan and the \
          most populous of the country's 47 prefectures. Located at the head of Tokyo Bay, the \
          prefecture forms part of the Kantō region on the central Pacific coast of Japan's main \
          island, Honshu. Tokyo is the political, economic, and cultural center of Japan, and \
          houses the seat of the Emperor and the national government.
          """,
        downloadVideoUrl: URL(string: "http://ipv4.download.thinkbroadband.com/50MB.zip")!,
        id: UUID(),
        title: "Tokyo, Japan"
      )
    ),
    .init(
      downloadMode: .notDownloaded,
      cityMap: .init(
        blurb: """
          Buenos Aires is the capital and largest city of Argentina. The city is located on the \
          western shore of the estuary of the Río de la Plata, on the South American continent's \
          southeastern coast. "Buenos Aires" can be translated as "fair winds" or "good airs", \
          but the former was the meaning intended by the founders in the 16th century, by the \
          use of the original name "Real de Nuestra Señora Santa María del Buen Ayre", named \
          after the Madonna of Bonaria in Sardinia.
          """,
        downloadVideoUrl: URL(string: "http://ipv4.download.thinkbroadband.com/50MB.zip")!,
        id: UUID(),
        title: "Buenos Aires, Argentina"
      )
    ),
  ]
}

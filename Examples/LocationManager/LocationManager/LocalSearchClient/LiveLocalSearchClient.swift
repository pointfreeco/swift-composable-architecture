import Combine
import ComposableArchitecture
import MapKit

extension LocalSearchClient {
  static let live = LocalSearchClient(
    search: { request in
      Effect.future { callback in
        MKLocalSearch(request: request).start { response, error in
          switch (response, error) {
          case let (.some(response), _):
            callback(
              .success(
                LocalSearchResponse(
                  mapItems: response.mapItems.map(MapItem.init(rawValue:)),
                  boundingRegion: response.boundingRegion
                )
              )
            )

          case (_, .some):
            callback(.failure(LocalSearchClient.Error()))

          case (.none, .none):
            fatalError("It should not be possible that response and error are both nil.")
          }
        }
      }
    })
}

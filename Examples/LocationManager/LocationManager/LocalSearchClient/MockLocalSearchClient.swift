import ComposableArchitecture
import MapKit

extension LocalSearchClient {
  static func mock(
    search: @escaping (MKLocalSearch.Request) -> Effect<LocalSearchResponse, LocalSearchError> =
      { _ in fatalError() }
  ) -> Self {
    Self(search: search)
  }
}

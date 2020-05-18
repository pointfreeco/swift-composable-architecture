import ComposableArchitecture
import MapKit

extension LocalSearchClient {
  static func mock(
    search: @escaping (MKLocalSearch.Request) -> Effect<
      LocalSearchResponse, LocalSearchClient.Error
    > = { _ in fatalError() }
  ) -> Self {
    Self(search: search)
  }
}

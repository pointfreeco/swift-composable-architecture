import ComposableArchitecture

struct NumberFactClient {
  var fetch: (Int) async throws -> String
}

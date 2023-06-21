import Benchmark
import Combine
import ComposableArchitecture
import Foundation

let viewStoreSuite = BenchmarkSuite(name: "ViewStore") {
  let store = Store<Int, Void>(initialState: 0) {}

  $0.benchmark("Create view store to send action") {
    doNotOptimizeAway(ViewStore(store).send(()))
  }

  let viewStore = ViewStore(store)

  $0.benchmark("Send action to pre-created view store") {
    doNotOptimizeAway(viewStore.send(()))
  }
}

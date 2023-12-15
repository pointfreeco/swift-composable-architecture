import Benchmark
import ComposableArchitecture
import Foundation

@available(macOS 14.0, *)
let observationSuite = BenchmarkSuite(name: "Observation") {
  var stateWithObservation: StateWithObservation!
  $0.benchmark("ObservableState: Mutate count") {
    doNotOptimizeAway(stateWithObservation.count += 1)
  } setUp: {
    stateWithObservation = StateWithObservation()
  } tearDown: {
    stateWithObservation = nil
  }
  $0.benchmark("ObservableState: Mutate name") {
    doNotOptimizeAway(stateWithObservation.name += "!!!")
  } setUp: {
    stateWithObservation = StateWithObservation()
  } tearDown: {
    stateWithObservation = nil
  }
  $0.benchmark("ObservableState: Append item") {
    doNotOptimizeAway(stateWithObservation.items.append(Item()))
  } setUp: {
    stateWithObservation = StateWithObservation()
  } tearDown: {
    stateWithObservation = nil
  }
  $0.benchmark("ObservableState: Mutate item") {
    doNotOptimizeAway(stateWithObservation.items[0].name += "!!!")
  } setUp: {
    stateWithObservation = StateWithObservation()
  } tearDown: {
    stateWithObservation = nil
  }

  var stateWithoutObservation: StateWithoutObservation!
  $0.benchmark("State: Mutate count") {
    doNotOptimizeAway(stateWithoutObservation.count += 1)
  } setUp: {
    stateWithoutObservation = StateWithoutObservation()
  } tearDown: {
    stateWithoutObservation = nil
  }
  $0.benchmark("State: Mutate name") {
    doNotOptimizeAway(stateWithoutObservation.name += "!!!")
  } setUp: {
    stateWithoutObservation = StateWithoutObservation()
  } tearDown: {
    stateWithoutObservation = nil
  }
  $0.benchmark("State: Append item") {
    doNotOptimizeAway(stateWithoutObservation.items.append(Item()))
  } setUp: {
    stateWithoutObservation = StateWithoutObservation()
  } tearDown: {
    stateWithoutObservation = nil
  }
  $0.benchmark("State: Mutate item") {
    doNotOptimizeAway(stateWithoutObservation.items[0].name += "!!!")
  } setUp: {
    stateWithoutObservation = StateWithoutObservation()
  } tearDown: {
    stateWithoutObservation = nil
  }

  var objectWithObservation: ObjectWithObservation!
  $0.benchmark("Observable: Mutate count") {
    doNotOptimizeAway(objectWithObservation.count += 1)
  } setUp: {
    objectWithObservation = ObjectWithObservation()
  } tearDown: {
    objectWithObservation = nil
  }
  $0.benchmark("Observable: Mutate name") {
    doNotOptimizeAway(objectWithObservation.name += "!!!")
  } setUp: {
    objectWithObservation = ObjectWithObservation()
  } tearDown: {
    objectWithObservation = nil
  }
  $0.benchmark("Observable: Append item") {
    doNotOptimizeAway(objectWithObservation.items.append(Item()))
  } setUp: {
    objectWithObservation = ObjectWithObservation()
  } tearDown: {
    objectWithObservation = nil
  }
  $0.benchmark("Observable: Mutate item") {
    doNotOptimizeAway(objectWithObservation.items[0].name += "!!!")
  } setUp: {
    objectWithObservation = ObjectWithObservation()
  } tearDown: {
    objectWithObservation = nil
  }

  var objectWithoutObservation: ObjectWithoutObservation!
  $0.benchmark("Class: Mutate count") {
    doNotOptimizeAway(objectWithoutObservation.count += 1)
  } setUp: {
    objectWithoutObservation = ObjectWithoutObservation()
  } tearDown: {
    objectWithoutObservation = nil
  }
  $0.benchmark("Class: Mutate name") {
    doNotOptimizeAway(objectWithoutObservation.name += "!!!")
  } setUp: {
    objectWithoutObservation = ObjectWithoutObservation()
  } tearDown: {
    objectWithoutObservation = nil
  }
  $0.benchmark("Class: Append item") {
    doNotOptimizeAway(objectWithoutObservation.items.append(Item()))
  } setUp: {
    objectWithoutObservation = ObjectWithoutObservation()
  } tearDown: {
    objectWithoutObservation = nil
  }
  $0.benchmark("Class: Mutate item") {
    doNotOptimizeAway(objectWithoutObservation.items[0].name += "!!!")
  } setUp: {
    objectWithoutObservation = ObjectWithoutObservation()
  } tearDown: {
    objectWithoutObservation = nil
  }
}

@ObservableState
private struct StateWithObservation {
  var count = 0
  var name = ""
  var items: IdentifiedArrayOf<Item> = .items
}

private struct StateWithoutObservation {
  var count = 0
  var name = ""
  var items: IdentifiedArrayOf<Item> = .items
}

@available(macOS 14.0, *)
@Observable
private class ObjectWithObservation {
  var count = 0
  var name = ""
  var items: IdentifiedArrayOf<Item> = .items
}

private class ObjectWithoutObservation {
  var count = 0
  var name = ""
  var items: IdentifiedArrayOf<Item> = .items
}

@ObservableState
private struct Item: Identifiable {
  let id = UUID()
  var name = ""
  var isInStock = false
}

extension IdentifiedArrayOf<Item> {
  fileprivate static var items: IdentifiedArrayOf<Item> {
    [
      Item(name: "Computer", isInStock: true),
      Item(name: "Monitor", isInStock: true),
      Item(name: "Keyboard", isInStock: true),
      Item(name: "Mouse", isInStock: true),
    ]
  }
}

import Benchmark
import ComposableArchitecture

@available(macOS 14.0, *)
let observationSuite = BenchmarkSuite(name: "Observation") {
  var stateWithObservation: StateWithObservation!
  $0.benchmark("Increment with observation") {
    doNotOptimizeAway(stateWithObservation.count += 1)
  } setUp: {
    stateWithObservation = StateWithObservation()
  } tearDown: {
    stateWithObservation = nil
  }

  var stateWithoutObservation: StateWithoutObservation!
  $0.benchmark("Increment without observation") {
    doNotOptimizeAway(stateWithoutObservation.count += 1)
  } setUp: {
    stateWithoutObservation = StateWithoutObservation()
  } tearDown: {
    stateWithoutObservation = nil
  }

  var objectWithObservation: ObjectWithObservation!
  $0.benchmark("Increment without object observation") {
    doNotOptimizeAway(objectWithObservation.count += 1)
  } setUp: {
    objectWithObservation = ObjectWithObservation()
  } tearDown: {
    objectWithObservation = nil
  }

  var objectWithoutObservation: ObjectWithoutObservation!
  $0.benchmark("Increment without object observation") {
    doNotOptimizeAway(objectWithoutObservation.count += 1)
  } setUp: {
    objectWithoutObservation = ObjectWithoutObservation()
  } tearDown: {
    objectWithoutObservation = nil
  }
}

import Foundation
@ObservableState
struct StateWithObservation {
  var count = 0
}

struct StateWithoutObservation {
  var count = 0
}

@available(macOS 14.0, *)
@Observable
class ObjectWithObservation {
  var count = 0
}

class ObjectWithoutObservation {
  var count = 0
}

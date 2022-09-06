import Benchmark
import ComposableArchitecture


enum Globals {
  static var value = 42
}

enum Locals {
  @TaskLocal static var value = 42
}

benchmark("Locals.value") {
  precondition(Locals.value == 42)
}
benchmark("Globals.value") {
  precondition(Globals.value == 42)
}
benchmark("Locals.$value.withValue") {
  Locals.$value.withValue(1729) {
    precondition(Locals.value == 1729)
  }
}
benchmark("Globals.value mutate") {
  Globals.value = 1729
  precondition(Globals.value == 1729)
}
benchmark("Locals.$value.withValue × 2") {
  Locals.$value.withValue(1729) {
    Locals.$value.withValue(42) {
      precondition(Locals.value == 42)
    }
  }
}
benchmark("Globals.value mutate × 2") {
  Globals.value = 1729
  Globals.value = 42
  precondition(Globals.value == 42)
}
benchmark("Locals.$value.withValue × 3") {
  Locals.$value.withValue(1729) {
    Locals.$value.withValue(42) {
      Locals.$value.withValue(1729) {
        precondition(Locals.value == 1729)
      }
    }
  }
}
benchmark("Globals.value mutate × 3") {
  Globals.value = 1729
  Globals.value = 42
  Globals.value = 1729
  precondition(Globals.value == 1729)
}
benchmark("Locals.$value.withValue × 4") {
  Locals.$value.withValue(1729) {
    Locals.$value.withValue(42) {
      Locals.$value.withValue(1729) {
        Locals.$value.withValue(42) {
          precondition(Locals.value == 42)
        }
      }
    }
  }
}
benchmark("Globals.value mutate × 4") {
  Globals.value = 1729
  Globals.value = 42
  Globals.value = 1729
  Globals.value = 42
  precondition(Globals.value == 42)
}

Benchmark.main()

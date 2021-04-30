import Foundation

func isPrime (_ p: Int) -> Bool {
  if p <= 1 { return false }
  if p <= 3 { return true }
  for i in 2...Int(sqrtf(Float(p))) {
    if p % i == 0 { return false }
  }
  return true
}

struct State: Equatable {
  var count = 1_000_000
  var extra = Array(1...1_000)
  var sub: [State]
}

struct ViewState: Equatable {
  let count: Int
  let primes: [Int]
  let jumbled: [Int]

  init(state: State) {
    self.count = state.count
    self.primes = state.extra.filter(isPrime)
    self.jumbled = state.extra.shuffled().sorted()
  }
}

let initialState = State(
  sub: [
    .init(
      sub: [
        .init(
          sub: [
            .init(
              sub: [
                .init(sub: []
                )
              ]
            )
          ]
        )
      ]
    )
  ]
)

func reducer(state: inout State, action: Void, environment: Void) {
  state.count += 1
}

import Benchmark
import ComposableArchitecture

struct AppState: Equatable {
  var a: String = .init(repeating: " ", count: 1000)
  var b: [UInt8] = .init(repeating: 0, count: 1000)
  var c = 42
  var d = LoginState()

  struct LoginState: Equatable {
    var email = "blob@blob"
    var password = "blobrules"
    var token = 0xdeadbeef
  }
}

/*
 name        time         std        iterations
 ----------------------------------------------
 Scoping (1)  8442.000 ns ±  41.79 %     127968
 Scoping (2) 11996.000 ns ±  43.70 %      99731
 Scoping (3) 14975.000 ns ±  37.66 %      74890
 Scoping (4) 18241.000 ns ±  36.12 %      64842

 Scoping (1)  4502.000 ns ±  54.01 %     283260
 Scoping (2)  8835.000 ns ±  42.94 %     143761
 Scoping (3) 12961.000 ns ±  35.80 %      87881
 Scoping (4) 16621.000 ns ±  36.64 %      73050

 Scoping (1)  3452.000 ns ±  62.07 %     365492
 Scoping (2)  7202.000 ns ±  55.61 %     174679
 Scoping (3) 10539.000 ns ±  42.94 %     100569
 Scoping (4) 13859.000 ns ±  40.99 %      83692
 */

let counterReducer = Reducer<AppState, Bool, Void> { state, action, _ in
  if action {
//    state += 1
  } else {
//    state = 0
  }
  return .none
}

let store1 = Store(initialState: .init(), reducer: counterReducer, environment: ())
let store2 = store1.scope { $0 }
let store3 = store2.scope { $0 }
let store4 = store3.scope { $0 }

let viewStore1 = ViewStore(store1)
let viewStore2 = ViewStore(store2)
let viewStore3 = ViewStore(store3)
let viewStore4 = ViewStore(store4)

benchmark("Scoping (1)") {
  viewStore1.send(true)
}
viewStore1.send(false)

benchmark("Scoping (2)") {
  viewStore2.send(true)
}
viewStore1.send(false)

benchmark("Scoping (3)") {
  viewStore3.send(true)
}
viewStore1.send(false)

benchmark("Scoping (4)") {
  viewStore4.send(true)
}

Benchmark.main()

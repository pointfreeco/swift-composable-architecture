import ComposableArchitecture

let counterReducer = Reducer<Int, Bool, Void> { state, action, _ in
  if action {
    state += 1
  } else {
    state = 0
  }
  return .none
}

benchmarkSuite("Scoping") { suite in
  
  suite.addStudy("Deep scoping") { study in
    
    study.setBaseline("No scope") { measure in
      let store1 = Store(initialState: 0, reducer: counterReducer, environment: ())
      let viewStore = ViewStore(store1)
      measure(.start)
      viewStore.send(true)
    }
    
    study.addCase("Scope (1)") { measure in
      let store1 = Store(initialState: 0, reducer: counterReducer, environment: ())
      let store2 = store1.scope { $0 }

      let viewStore = ViewStore(store2)
      measure(.start)
      viewStore.send(true)
    }
    
    study.addCase("Scope (2)") { measure in
      let store1 = Store(initialState: 0, reducer: counterReducer, environment: ())
      let store2 = store1.scope { $0 }
      let store3 = store2.scope { $0 }

      let viewStore = ViewStore(store3)
      measure(.start)
      viewStore.send(true)
    }
    
    study.addCase("Scope (3)") { measure in
      let store1 = Store(initialState: 0, reducer: counterReducer, environment: ())
      let store2 = store1.scope { $0 }
      let store3 = store2.scope { $0 }
      let store4 = store3.scope { $0 }

      let viewStore = ViewStore(store4)
      measure(.start)
      viewStore.send(true)
    }
  }
}

Benchmark.main()

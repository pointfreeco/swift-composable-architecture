import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates navigation that depends on loading optional state.

  Tapping "Load optional counter" fires off an effect that will load the counter state a second \
  later. When the counter state is present, you will be programmatically navigated to the screen \
  that depends on this data.
  """

struct LazyNavigationState: Equatable {
  var optionalCounter: CounterState?
  var isActivityIndicatorVisible = false

  var isNavigationActive: Bool { self.optionalCounter != nil }
}

enum LazyNavigationAction: Equatable {
  case optionalCounter(CounterAction)
  case setNavigation(isActive: Bool)
  case setNavigationIsActiveDelayCompleted
}

struct LazyNavigationEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

let lazyNavigationReducer = Reducer<
  LazyNavigationState, LazyNavigationAction, LazyNavigationEnvironment
>.combine(
  Reducer { state, action, environment in
    switch action {
    case .setNavigation(isActive: true):
      state.isActivityIndicatorVisible = true
      return Effect(value: .setNavigationIsActiveDelayCompleted)
        .delay(for: 1, scheduler: environment.mainQueue)
        .eraseToEffect()

    case .setNavigation(isActive: false):
      state.optionalCounter = nil
      return .none

    case .setNavigationIsActiveDelayCompleted:
      state.isActivityIndicatorVisible = false
      state.optionalCounter = CounterState()
      return .none

    case .optionalCounter:
      return .none
    }
  },
  counterReducer.optional.pullback(
    state: \.optionalCounter,
    action: /LazyNavigationAction.optionalCounter,
    environment: { _ in CounterEnvironment() }
  )
)

struct LazyNavigationView: View {
  let store: Store<LazyNavigationState, LazyNavigationAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section(header: Text(readMe)) {
          NavigationLink(
            destination: IfLetStore(
              self.store.scope(
                state: { $0.optionalCounter }, action: LazyNavigationAction.optionalCounter),
              then: CounterView.init(store:)
            ),
            isActive: viewStore.binding(
              get: { $0.isNavigationActive },
              send: LazyNavigationAction.setNavigation(isActive:)
            )
          ) {
            HStack {
              Text("Load optional counter")
              if viewStore.isActivityIndicatorVisible {
                Spacer()
                ActivityIndicator()
              }
            }
          }
        }
      }
    }
    .navigationBarTitle("Load then navigate")
  }
}

enum LazyCounterState2: Equatable {
  case loggedOut
  case loggedIn(CounterState)
}

struct LazyNavigationState2: Equatable {
  var optionalCounter: LazyCounterState2 = .loggedOut
  var isActivityIndicatorVisible = false

  var isNavigationActive: Bool { self.optionalCounter != .loggedOut }
}

struct CounterView2: View {
  @Binding var state: CounterState

  var body: some View {
    HStack {
      Button("-") { self.state.count -= 1 }
      Text("\(self.state.count)")
      Button("+") { self.state.count += 1 }
    }
  }
}

extension Binding {
  func ifLet<Unwrapped, R>(then f: (Binding<Unwrapped>) -> R, else g: () -> R) -> R where Value == Unwrapped? {
//    if let value = self.wrappedValue {
//      return f(
//        Binding<Unwrapped>(
//          get: { value },
//          set: { self.wrappedValue = $0 }
//        )
//      )
//    } else {
//      return g()
//    }
    ifCaseLet(/Optional.some, then: f, else: g)
  }

  func ifCaseLet<Unwrapped, R>(
    _ path: CasePath<Value, Unwrapped>,
    then f: (Binding<Unwrapped>) -> R,
    else g: () -> R
  ) -> R {
    if let value = path.extract(from: self.wrappedValue) {
      return f(
        Binding<Unwrapped>(
          get: { value },
          set: { self.wrappedValue = path.embed($0) }
        )
      )
    } else {
      return g()
    }
  }
}

struct IfCaseLet<Value, SomeValue, SomeContent: View, NoneContent: View>: View {
  let path: CasePath<Value, SomeValue>
  let binding: Binding<Value>
  let someContent: (Binding<SomeValue>) -> SomeContent
  let noneContent: NoneContent

  init(
    _ binding: Binding<Value>,
    matches path: CasePath<Value, SomeValue>,
    then someContent: @escaping (Binding<SomeValue>) -> SomeContent,
    else noneContent: NoneContent
  ) {
    self.binding = binding
    self.path = path
    self.someContent = someContent
    self.noneContent = noneContent
  }

  var body: some View {
    self.binding.ifCaseLet(
      self.path,
      then: { ViewBuilder.buildEither(first: self.someContent($0)) },
      else: { ViewBuilder.buildEither(second: self.noneContent) }
    )
  }
}

extension IfCaseLet where NoneContent == EmptyView {
  init(
    _ binding: Binding<Value>,
    matches path: CasePath<Value, SomeValue>,
    then someContent: @escaping (Binding<SomeValue>) -> SomeContent
  ) {
    self.binding = binding
    self.path = path
    self.someContent = someContent
    self.noneContent = EmptyView()
  }
}

extension Binding {
  subscript<Subject>(case: CasePath<Value, Subject>) -> Binding<Subject>? {
    `case`.extract(from: self.wrappedValue).map { subject in
      Binding<Subject>(
        get: { subject },
        set: { self.wrappedValue = `case`.embed($0) }
      )
    }
  }
}

extension Binding {
  // (KP<A, B>) -> (B<A?>) -> B<B?>
  func map<R, V>(_ keyPath: WritableKeyPath<R, V>) -> Binding<V?> where Value == R? {
    .init(
      get: { self.wrappedValue?[keyPath: keyPath] },
      set: { if let value = $0 { self.wrappedValue?[keyPath: keyPath] = value } }
    )
  }
}


struct LazyNavigationView2: View {
  @State var state: LazyNavigationState2

  var body: some View {
      Form {
        Section(header: Text(readMe)) {
          NavigationLink(
            destination:

            IfCaseLet(
              self.$state.optionalCounter,
              matches: /LazyCounterState2.loggedIn,
              then: CounterView2.init(state:)
            ),


//            self.$state.optionalCounter.ifCaseLet(
//              /LazyCounterState2.loggedIn,
//              then: { AnyView(CounterView2(state: $0)) },
//              else: { AnyView(EmptyView()) }
//            ),

//            self.$state.optionalCounter[/LazyCounterState2.loggedIn]
//              .map { AnyView(CounterView2(state: $0)) }
//              ?? AnyView(EmptyView()),

            //self.state.optionalCounter.map { AnyView(CounterView2(state: <#T##Binding<CounterState>#>)) },

            isActive: Binding(
              get: { self.state.isNavigationActive },
              set: {
                guard $0 else {
                  self.state.optionalCounter = .loggedOut
                  return
                }
                self.state.isActivityIndicatorVisible = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                  self.state.isActivityIndicatorVisible = false
                  self.state.optionalCounter = .loggedIn(.init())
                }
            }
            )
          ) {
            HStack {
              Text("Load optional counter")
              if state.isActivityIndicatorVisible {
                Spacer()
                ActivityIndicator()
              }
            }
          }
        }
    }
    .navigationBarTitle("Load then navigate")
  }
}


struct LazyNavigationView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      LazyNavigationView2(
        state: LazyNavigationState2()
      )
    }
    .navigationViewStyle(StackNavigationViewStyle())
  }
}

import ComposableArchitecture
import SwiftUI

@Reducer
struct DragDistance {
  @ObservableState
  struct State {
    var distance: CGFloat = 0.0
    var location = CGPoint.zero
  }
  enum Action {
    case dragChanged(CGPoint)
    case dragEnded(CGPoint)
    case delegate(Delegate)

    enum Delegate {
      case dragEnded(CGFloat)
    }
  }
  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case let .dragChanged(location):
        state.distance += state.location.distance(to: location)
        state.location = location
        return .none
      case let .dragEnded(location):
        state.distance += state.location.distance(to: location)
        state.location = location
        return .send(.delegate(.dragEnded(state.distance)))
      case .delegate:
        return .none
      }
    }
  }
}

extension CGPoint {
  func distance(to other: Self) -> CGFloat {
    abs(sqrt((x - other.x) * (x - other.x) + (y - other.y) * (y - other.y)))
  }
}

struct DragDistanceView: View {
  let store: StoreOf<DragDistance>

  var body: some View {
    Rectangle()
      .fill(.white)
      .ignoresSafeArea()
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { gesture in
            // withAnimation(.bouncy) {
            _ = store.send(.dragChanged(gesture.location))
            // }
          }
          .onEnded { gesture in
            withAnimation(.bouncy) {
              _ = store.send(.dragEnded(gesture.predictedEndLocation))
            }
          }
      )
      .overlay {
        Text("Distance: \(Int(store.distance))")
          .animation(.default, value: store.distance)
          .monospacedDigit()
          .contentTransition(.numericText())

        GeometryReader { proxy in
          Circle()
            .fill(.black)
            .frame(width: 50, height: 50)
            .position(store.location)
        }
        .allowsHitTesting(false)
      }
  }
}

struct VanillaDragDistanceView: View {
  @State var distance = CGFloat.zero
  @State var location = CGPoint.zero

  var body: some View {
    Rectangle()
      .fill(.white)
      .ignoresSafeArea()
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { gesture in
            distance += location.distance(to: gesture.location)
            location = gesture.location
          }
          .onEnded { gesture in
            distance += location.distance(to: gesture.location)
            location = gesture.location
          }
      )
      .overlay {
        Text("Distance: \(Int(distance))")
          .animation(.default, value: distance)
          .monospacedDigit()
          .contentTransition(.numericText())

        GeometryReader { proxy in
          Circle()
            .fill(.black)
            .frame(width: 50, height: 50)
            .position(location)
        }
        .allowsHitTesting(false)
      }
  }
}


#Preview {
  DragDistanceView(
    store: Store(initialState: DragDistance.State()) {
      DragDistance()
    }
  )
}

@Reducer
struct Parent {
  @Reducer
  enum Destination {
    case alert(AlertState<Never>)
    case dragDistance(DragDistance)
  }

  @ObservableState
  struct State {
    @Presents var destination: Destination.State?
  }
  enum Action {
    case destination(PresentationAction<Destination.Action>)
    case tap
  }
  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case let .destination(.presented(.dragDistance(.delegate(.dragEnded(distance))))):
        state.destination = .alert(
          AlertState {
            TextState("You dragged the circle \(Int(distance)) points!")
          }
        )
        return .none
      case .destination:
        return .none
      case .tap:
        state.destination = .dragDistance(DragDistance.State())
        return .none
      }
    }
    .ifLet(\.$destination, action: \.destination)
  }
}

struct ParentView: View {
  @Bindable var store: StoreOf<Parent>

  var body: some View {
    if let store = store
      .scope(state: \.destination?.dragDistance, action: \.destination.dragDistance)
    {
      DragDistanceView(store: store)
    } else {
      Button("Tap") {
        store.send(.tap)
      }
      .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
    }
  }
}

@Reducer
struct Parent2 {
  @Reducer
  enum Destination {
    @ReducerCaseIgnored
    case dragDistance(DragDistance.State)
    case alert(AlertState<Never>)
  }

  @ObservableState
  struct State {
    @Presents var destination: Destination.State?
  }
  enum Action {
    case destination(PresentationAction<Destination.Action>)
    case dragDelegate(DragDistance.Action.Delegate)
    case tap
  }
  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case let .dragDelegate(.dragEnded(distance)):
        state.destination = .alert(
          AlertState {
            TextState("You dragged the circle \(Int(distance)) points!")
          }
        )
        return .none
      case .destination:
        return .none
      case .tap:
        state.destination = .dragDistance(DragDistance.State())
        return .none
      }
    }
    .ifLet(\.$destination, action: \.destination)
  }
}


struct ParentView2: View {
  @Bindable var store: StoreOf<Parent2>

  var body: some View {
    // if let store = store.detach(
    //   state: \.destination?.dragDistance,
    //   action: \.dragDelegate,
    //   delegate: \.delegate,
    //   reducer: DragDistance()
    // ) {
    //   DragDistanceView(store: store)
    if let store = store.scope(state: \.destination?.dragDistance, action: \.dragDelegate) {
      DragDistanceView(
        store: store.detached(delegate: \.delegate) {
          DragDistance()
        }
      )
    } else {
      Button("Tap") {
        store.send(.tap)
      }
      .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
    }
  }
}

#Preview {
  ParentView(
    store: Store(initialState: Parent.State()) {
      Parent()
    }
  )
}

import ComposableArchitecture
import SwiftUI

@Reducer
struct AppFeature {
  @Reducer(state: .equatable)
  enum Path {
    case detail(SyncUpDetail)
    case meeting(Meeting, syncUp: SyncUp)
    case record(RecordMeeting)
    @ReducerCaseIgnored
    case someFeature
  }

  @ObservableState
  struct State: Equatable {
    var path = StackState<Path.State>()
    var syncUpsList = SyncUpsList.State()
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case path(StackActionOf<Path>)
    case syncUpsList(SyncUpsList.Action)
  }

  @Dependency(\.continuousClock) var clock
  @Dependency(\.date.now) var now
  @Dependency(\.dataManager.save) var saveData
  @Dependency(\.uuid) var uuid

  private enum CancelID {
    case saveDebounce
  }

  var body: some ReducerOf<Self> {
    BindingReducer()
    Scope(state: \.syncUpsList, action: \.syncUpsList) {
      SyncUpsList()
    }
    Reduce<State, Action> { state, action in
      switch action {
      case .binding:
        return .none

      case let .path(.element(id, .detail(.delegate(delegateAction)))):
        guard case let .some(.detail(detailState)) = state.path[id: id]
        else { return .none }

        switch delegateAction {
        case .deleteSyncUp:
          state.syncUpsList.syncUps.remove(id: detailState.syncUp.id)
          return .none

        case let .syncUpUpdated(syncUp):
          state.syncUpsList.syncUps[id: syncUp.id] = syncUp
          return .none

        case .startMeeting:
          state.path.append(.record(RecordMeeting.State(syncUp: detailState.syncUp)))
          return .none

        case .goToMeeting(let meeting, syncUp: let syncUp):
          state.path.append(.meeting(meeting, syncUp: syncUp))
          return .none
        }

      case let .path(.element(_, .record(.delegate(delegateAction)))):
        switch delegateAction {
        case let .save(transcript: transcript):
          guard let id = state.path.ids.dropLast().last
          else {
            XCTFail(
              """
              Record meeting is the only element in the stack. A detail feature should precede it.
              """
            )
            return .none
          }

          state.path[id: id]?.detail?.syncUp.meetings.insert(
            Meeting(
              id: Meeting.ID(self.uuid()),
              date: self.now,
              transcript: transcript
            ),
            at: 0
          )
          guard let syncUp = state.path[id: id]?.detail?.syncUp
          else { return .none }
          state.syncUpsList.syncUps[id: syncUp.id] = syncUp
          return .none
        }

      case .path:
        return .none

      case .syncUpsList(.syncUpTapped(let syncUp)):
        state.path.append(.detail(SyncUpDetail.State.init(syncUp: syncUp)))
        return .none

      case .syncUpsList:
        return .none
      }
    }
    .forEach(\.path, action: \.path)

    Reduce { state, action in
      return .run { [syncUps = state.syncUpsList.syncUps] _ in
        try await withTaskCancellation(id: CancelID.saveDebounce, cancelInFlight: true) {
          try await self.clock.sleep(for: .seconds(1))
          try await self.saveData(JSONEncoder().encode(syncUps), .syncUps)
        }
      } catch: { _, _ in
      }
    }
  }
}

struct AppView: View {
  @Bindable var store: StoreOf<AppFeature>

  var body: some View {
    NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
      SyncUpsListView(
        store: store.scope(state: \.syncUpsList, action: \.syncUpsList)
      )
    } destination: { store in
      switch store.case {
      case let .detail(store):
        SyncUpDetailView(store: store)
      case let .meeting(meeting, syncUp):
        MeetingView(meeting: meeting, syncUp: syncUp)
      case let .record(store):
        RecordMeetingView(store: store)
      case .someFeature:
        EmptyView()
      }
    }
  }
}

extension URL {
  static let syncUps = Self.documentsDirectory.appending(component: "sync-ups.json")
}

class AppViewController: StackNavigationControllerOf<AppFeature.Path> {
}

struct AppViewRepresentable: UIViewControllerRepresentable {
  let store: StoreOf<AppFeature>

  func makeUIViewController(context: Context) -> some UIViewController {
    StackNavigationController(store: store.scope(state: \.path, action: \.path)) {
      UIHostingController(
        rootView: SyncUpsListView(store: store.scope(state: \.syncUpsList, action: \.syncUpsList))
      )
    } destination: { store in
      switch store.case {
      case let .detail(store):
        UIHostingController(rootView: SyncUpDetailView(store: store))
      case let .meeting(meeting, syncUp: syncUp):
        UIHostingController(rootView: MeetingView(meeting: meeting, syncUp: syncUp))
      case let .record(store):
        UIHostingController(rootView: RecordMeetingView(store: store))
      case .someFeature:
        SomeFeatureViewController()
      }
    }
  }

  func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
  }
}

class SomeFeatureViewController: UIViewController {
  override func viewDidLoad() {
    let button = UIButton(type: .system)
    button.setTitle("Go to detail", for: .normal)
    button.frame = .init(x: 100, y: 100, width: 200, height: 200)
    button.addAction(
      UIAction.init(handler: {
        [weak self] _ in
        guard let self else { return }
        self.navigationController?.push(
          state: AppFeature.Path.State.detail(
            SyncUpDetail.State.init(syncUp: .mock)
          )
        )
      }),
      for: .touchUpInside
    )
    view.addSubview(button)
  }
}

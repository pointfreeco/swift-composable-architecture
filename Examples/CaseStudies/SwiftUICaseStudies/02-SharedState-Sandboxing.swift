import ComposableArchitecture
import SwiftUI

private let readMe = """
  This case study demonstrates how you can use the `\\.defaultAppStorage` and \
  `\\.defaultFileStorage` dependencies in order to control how state is persisted with the \
  `@Shared` property wrapper.

  The changes made in this screen will be persisted across app launches, but the presented sheet \
  will get a sandboxed storage system so that changes in that view do not affect other parts of \
  the app. This can be handy for demo'ing parts of your application, such as in onboarding, \
  without the external storage system being changed.
  """
private let sheetReadMe = """
  In this sheet the user defaults and file system have been sandboxed from the parent view. Any \
  changes made to this state will not be saved to the real user defaults or file system.
  """

@Reducer
struct SharedStateSandboxing {
  @ObservableState
  struct State: Equatable {
    @Shared(.appStorageCount) var appStorageCount = 0
    @Shared(.fileStorageCount) var fileStorageCount = 0
    @Presents var sandboxed: SharedStateSandboxing.State?
  }
  enum Action {
    case incrementAppStorage
    case incrementFileStorage
    case presentButtonTapped
    case sandboxed(PresentationAction<SharedStateSandboxing.Action>)
  }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .incrementAppStorage:
        state.appStorageCount += 1
        return .none
      case .incrementFileStorage:
        state.fileStorageCount += 1
        return .none
      case .presentButtonTapped:
        state.sandboxed = withDependencies {
          let suiteName = "sandbox"
          let defaultAppStorage = UserDefaults(suiteName: suiteName)!
          defaultAppStorage.removePersistentDomain(forName: suiteName)
          $0.defaultAppStorage = defaultAppStorage
          $0.defaultFileStorage = InMemoryFileStorage()
        } operation: {
          SharedStateSandboxing.State()
        }
        return .none
      case .sandboxed:
        return .none
      }
    }
    .ifLet(\.$sandboxed, action: \.sandboxed) {
      SharedStateSandboxing()
        .transformDependency(\.self) {
          _ = $0  // TODO
        }
    }
  }
}

struct SharedStateSandboxingView: View {
  @Environment(\.dismiss) private var dismiss
  var isPresented = false
  @Bindable var store = Store(initialState: SharedStateSandboxing.State()) {
    SharedStateSandboxing()
  }

  var body: some View {
    Form {
      if !isPresented {
        Text(template: readMe, .caption)
      } else {
        Text(template: sheetReadMe, .caption)
      }

      Section {
        HStack {
          Text(store.appStorageCount.description)
          Spacer()
          Button("Increment") { store.send(.incrementAppStorage) }
        }
      } header: {
        Text("App storage")
      }

      Section {
        HStack {
          Text(store.fileStorageCount.description)
          Spacer()
          Button("Increment") { store.send(.incrementFileStorage) }
        }
      } header: {
        Text("File storage")
      }

      if !isPresented {
        Section {
          Button("Present sandbox") { store.send(.presentButtonTapped) }
        }
        .sheet(item: $store.scope(state: \.sandboxed, action: \.sandboxed)) { store in
          NavigationStack {
            SharedStateSandboxingView(isPresented: true, store: store)
          }
        }
      }
    }
    .toolbar {
      if isPresented {
        ToolbarItem {
          Button("Dismiss") { dismiss() }
        }
      }
    }
  }
}

extension PersistenceReaderKey where Self == AppStorageKey<Int> {
  static var appStorageCount: Self {
    Self("appStorageCount")
  }
}
extension PersistenceReaderKey where Self == FileStorageKey<Int> {
  static var fileStorageCount: Self {
    Self(url: URL.documentsDirectory.appending(path: "fileStorageCount.json"))
  }
}

#Preview {
  SharedStateSandboxingView()
}

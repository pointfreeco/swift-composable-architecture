@_spi(Internals) @_spi(Logging) import ComposableArchitecture
import SwiftUI

struct ObservableSharedStateView: View {
  @Perception.Bindable private var store = Store(initialState: Feature.State()) {
    Feature()
  }

  var body: some View {
    WithPerceptionTracking {
      let _ = Logger.shared.log("\(Self.self).body")
      Form {
        Section {
          HStack {
            Button("Toggle") { store.isAppStorageOn1.toggle() }
              .accessibilityIdentifier("isAppStorageOn1")
            Text("App Storage #1 " + (store.isAppStorageOn1 ? "✅" : "❌"))
          }
          HStack {
            Button("Toggle") { store.isAppStorageOn2.toggle() }
              .accessibilityIdentifier("isAppStorageOn2")
            Text("App Storage #2 " + (store.isAppStorageOn2 ? "✅" : "❌"))
          }
          Button("Write directly to user defaults") {
            store.send(.writeToUserDefaultsButtonTapped)
          }
          Button("Delete user default") {
            store.send(.deleteUserDefaultButtonTapped)
          }
        } header: {
          Text("App storage")
        }

        Section {
          HStack {
            Button("Toggle") { store.fileStorage1.isOn.toggle() }
              .accessibilityIdentifier("isFileStorageOn1")
            Text("File Storage #1 " + (store.fileStorage1.isOn ? "✅" : "❌"))
          }
          HStack {
            Button("Toggle") { store.fileStorage2.isOn.toggle() }
              .accessibilityIdentifier("isFileStorageOn2")
            Text("File Storage #2 " + (store.fileStorage2.isOn ? "✅" : "❌"))
          }
          Button("Write directly to file system") {
            store.send(.writeToFileStorageButtonTapped)
          }
          Button("Delete file") {
            store.send(.deleteFileButtonTapped)
          }
        } header: {
          Text("File storage")
        }

        Section {
          HStack {
            Button("Toggle") { store.isInMemoryOn1.toggle() }
              .accessibilityIdentifier("isInMemoryOn1")
            Text("In-memory Storage #1 " + (store.isInMemoryOn1 ? "✅" : "❌"))
          }
          HStack {
            Button("Toggle") { store.isInMemoryOn2.toggle() }
              .accessibilityIdentifier("isInMemoryOn2")
            Text("In-memory Storage #2 " + (store.isInMemoryOn2 ? "✅" : "❌"))
          }
        } header: {
          Text("In-memory")
        }

        Section {
          Button("Reset") {
            store.send(.resetButtonTapped)
          }
        }
      }
    }
  }
}

@Reducer
private struct Feature {
  @ObservableState
  struct State {
    @Shared(.appStorage("isOn")) var isAppStorageOn1 = false
    @Shared(.appStorage("isOn")) var isAppStorageOn2 = false
    @Shared(.inMemory("isOn")) var isInMemoryOn1 = false
    @Shared(.inMemory("isOn")) var isInMemoryOn2 = false
    @Shared(.fileStorage(storageURL)) var fileStorage1 = Settings()
    @Shared(.fileStorage(storageURL)) var fileStorage2 = Settings()
  }
  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case deleteFileButtonTapped
    case deleteUserDefaultButtonTapped
    case resetButtonTapped
    case writeToFileStorageButtonTapped
    case writeToUserDefaultsButtonTapped
  }
  @Dependency(\.defaultAppStorage) var defaults
  var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce<State, Action> { state, action in
      switch action {
      case .binding(_):
        return .none
      case .deleteFileButtonTapped:
        return .run { _ in
          try FileManager.default.removeItem(at: storageURL)
        }
      case .deleteUserDefaultButtonTapped:
        return .run { _ in
          defaults.removeObject(forKey: "isOn")
        }
      case .resetButtonTapped:
        state.isAppStorageOn1 = false
        state.isAppStorageOn2 = false
        state.fileStorage1.isOn = false
        state.fileStorage2.isOn = false
        state.isInMemoryOn1 = false
        state.isInMemoryOn2 = false
        return .none
      case .writeToFileStorageButtonTapped:
        return .run { [isOn = state.fileStorage1.isOn] _ in
          try JSONEncoder().encode(Settings(isOn: !isOn)).write(to: storageURL)
        }
      case .writeToUserDefaultsButtonTapped:
        return .run { [isOn = state.isAppStorageOn1] _ in
          defaults.setValue(!isOn, forKey: "isOn")
        }
      }
    }
  }
}

private let storageURL = URL.documentsDirectory.appending(component: "file.json")

private struct Settings: Codable, Equatable {
  var isOn = false
}

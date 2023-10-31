@_spi(Reflection) import CasePaths
import SwiftUI

/// A view that observes when enum state held in a store changes cases, and provides stores to
/// ``CaseLet`` views.
///
/// An application may model parts of its state with enums. For example, app state may differ if a
/// user is logged-in or not:
///
/// ```swift
/// @Reducer
/// struct AppFeature {
///   enum State {
///     case loggedIn(LoggedInState)
///     case loggedOut(LoggedOutState)
///   }
///   // ...
/// }
/// ```
///
/// In the view layer, a store on this state can switch over each case using a ``SwitchStore`` and
/// a ``CaseLet`` view per case:
///
/// ```swift
/// struct AppView: View {
///   let store: StoreOf<AppFeature>
///
///   var body: some View {
///     SwitchStore(self.store) { state in
///       switch state {
///       case .loggedIn:
///         CaseLet(
///           /AppFeature.State.loggedIn, action: AppFeature.Action.loggedIn
///         ) { loggedInStore in
///           LoggedInView(store: loggedInStore)
///         }
///       case .loggedOut:
///         CaseLet(
///           /AppFeature.State.loggedOut, action: AppFeature.Action.loggedOut
///         ) { loggedOutStore in
///           LoggedOutView(store: loggedOutStore)
///         }
///       }
///     }
///   }
/// }
/// ```
///
/// > Important: The `SwitchStore` view builder is only evaluated when the case of state passed to
/// > it changes. As such, you should not rely on this value for anything other than checking the
/// > current case, _e.g._ by switching on it and routing to an appropriate `CaseLet`.
///
/// See ``Reducer/ifCaseLet(_:action:then:fileID:line:)-3k4yb`` and
/// ``Scope/init(state:action:child:fileID:line:)-7yj7l`` for embedding reducers that operate on
/// each case of an enum in reducers that operate on the entire enum.
public struct SwitchStore<State, Action, Content: View>: View {
  public let store: Store<State, Action>
  public let content: (State) -> Content

  public init(
    _ store: Store<State, Action>,
    @ViewBuilder content: @escaping (_ initialState: State) -> Content
  ) {
    self.store = store
    self.content = content
  }

  public var body: some View {
    WithViewStore(
      self.store, observe: { $0 }, removeDuplicates: { enumTag($0) == enumTag($1) }
    ) { viewStore in
      self.content(viewStore.state)
        .environmentObject(StoreObservableObject(store: self.store))
    }
  }
}

/// A view that handles a specific case of enum state in a ``SwitchStore``.
public struct CaseLet<EnumState, EnumAction, CaseState, CaseAction, Content: View>: View {
  public let toCaseState: (EnumState) -> CaseState?
  public let fromCaseAction: (CaseAction) -> EnumAction
  public let content: (Store<CaseState, CaseAction>) -> Content

  private let fileID: StaticString
  private let line: UInt

  @EnvironmentObject private var store: StoreObservableObject<EnumState, EnumAction>

  /// Initializes a ``CaseLet`` view that computes content depending on if a store of enum state
  /// matches a particular case.
  ///
  /// - Parameters:
  ///   - toCaseState: A function that can extract a case of switch store state, which can be
  ///     specified using case path literal syntax, _e.g._ `/State.case`.
  ///   - fromCaseAction: A function that can embed a case action in a switch store action.
  ///   - content: A function that is given a store of the given case's state and returns a view
  ///     that is visible only when the switch store's state matches.
  public init(
    _ toCaseState: @escaping (EnumState) -> CaseState?,
    action fromCaseAction: @escaping (CaseAction) -> EnumAction,
    @ViewBuilder then content: @escaping (_ store: Store<CaseState, CaseAction>) -> Content,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.toCaseState = toCaseState
    self.fromCaseAction = fromCaseAction
    self.content = content
    self.fileID = fileID
    self.line = line
  }

  public var body: some View {
    IfLetStore(
      self.store.wrappedValue.scope(
        state: self.toCaseState,
        action: self.fromCaseAction
      ),
      then: self.content,
      else: {
        _CaseLetMismatchView<EnumState, EnumAction>(
          fileID: self.fileID,
          line: self.line
        )
      }
    )
  }
}

extension CaseLet where EnumAction == CaseAction {
  /// Initializes a ``CaseLet`` view that computes content depending on if a store of enum state
  /// matches a particular case.
  ///
  /// - Parameters:
  ///   - toCaseState: A function that can extract a case of switch store state, which can be
  ///     specified using case path literal syntax, _e.g._ `/State.case`.
  ///   - content: A function that is given a store of the given case's state and returns a view
  ///     that is visible only when the switch store's state matches.
  public init(
    state toCaseState: @escaping (EnumState) -> CaseState?,
    @ViewBuilder then content: @escaping (_ store: Store<CaseState, CaseAction>) -> Content
  ) {
    self.init(
      toCaseState,
      action: { $0 },
      then: content
    )
  }
}

public struct _CaseLetMismatchView<State, Action>: View {
  @EnvironmentObject private var store: StoreObservableObject<State, Action>
  let fileID: StaticString
  let line: UInt

  public var body: some View {
    #if DEBUG
      let message = """
        Warning: A "CaseLet" at "\(self.fileID):\(self.line)" was encountered when state was set \
        to another case:

            \(debugCaseOutput(self.store.wrappedValue.withState { $0 }))

        This usually happens when there is a mismatch between the case being switched on and the \
        "CaseLet" view being rendered.

        For example, if ".screenA" is being switched on, but the "CaseLet" view is pointed to \
        ".screenB":

            case .screenA:
              CaseLet(
                /State.screenB, action: Action.screenB
              ) { /* ... */ }

        Look out for typos to ensure that these two cases align.
        """
      return VStack(spacing: 17) {
        #if os(macOS)
          Text("⚠️")
        #else
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.largeTitle)
        #endif

        Text(message)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .foregroundColor(.white)
      .padding()
      .background(Color.red.edgesIgnoringSafeArea(.all))
      .onAppear { runtimeWarn(message) }
    #else
      return EmptyView()
    #endif
  }
}

private final class StoreObservableObject<State, Action>: ObservableObject {
  let wrappedValue: Store<State, Action>

  init(store: Store<State, Action>) {
    self.wrappedValue = store
  }
}

private func enumTag<Case>(_ `case`: Case) -> UInt32? {
  EnumMetadata(Case.self)?.tag(of: `case`)
}

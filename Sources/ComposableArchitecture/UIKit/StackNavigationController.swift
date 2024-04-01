import UIKit

public typealias StackNavigationControllerOf<R: Reducer> 
  = StackNavigationController<R.State, R.Action>

open class StackNavigationController<State, Action>: UINavigationController, UINavigationControllerDelegate, _StackNavigationControllerProtocol {
  let store: Store<StackState<State>, StackAction<State, Action>>
  let destination: (Store<State, Action>) -> UIViewController

  public init(
    store: Store<StackState<State>, StackAction<State, Action>>,
    root: () -> UIViewController,
    destination: @escaping (Store<State, Action>) -> UIViewController
  ) {
    self.store = store
    self.destination = destination
    super.init(nibName: nil, bundle: nil)
    self.delegate = self
    self.viewControllers = [root()]
  }

  public required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override open func viewDidLoad() {
    super.viewDidLoad()

    observe { [weak self] in
      guard let self else { return }

      guard viewControllers.compactMap(\.stackElementID) != Array(store.currentState.ids)
      else { return }

      setViewControllers(
        [viewControllers[0]]
        + zip(store.currentState.ids, store.currentState).map { id, element in
          if
            let existingViewController = self.viewControllers
              .first(where: { $0.stackElementID == id })
          {
            return existingViewController
          }

          var element = element
          let controller = self.destination(
            self.store.scope(
              id: self.store.id(state: \.[id:id], action: \.[id:id]),
              state: ToState {
                element = $0[id: id] ?? element
                return element
              },
              action: { .element(id: id, action: $0) },
              isInvalid: { !$0.ids.contains(id) }
            )
          )
          controller.stackElementID = id
          return controller
        },
        animated: true
      )
    }
  }

  public func navigationController(
    _ navigationController: UINavigationController,
    didShow viewController: UIViewController,
    animated: Bool
  ) {
    if store.currentState.count > (viewControllers.count - 1) {
      // feature    [id2, id1, id]
      // controller [id1, id2, detached, id]
      store.send(.popFrom(id: store.currentState.ids[viewControllers.count - 1]))
    }
  }
}

@available(iOS 16.0.0, *)
extension UINavigationController {
  public func push<State>(
    state: State,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    func open(_ controller: some _StackNavigationControllerProtocol<State>) {
      @Dependency(\.stackElementID) var stackElementID
      controller.store.send(.push(id: stackElementID(), state: state))
    }
    guard let self = self as? any _StackNavigationControllerProtocol<State>
    else {
      // TODO: finesse runtime warning
      runtimeWarn("""
        A navigation link at "\(file):\(line)" is unpresentable. …
        """)
      return
    }
    open(self)
  }
}

import ObjectiveC

extension UIViewController {
  fileprivate var stackElementID: StackElementID? {
    get {
      return objc_getAssociatedObject(self, &stackElementIDKey) as? StackElementID
    }
    set {
      objc_setAssociatedObject(
        self,
        &stackElementIDKey,
        newValue,
        objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC
      )
    }
  }
}
private var stackElementIDKey: UInt8 = 0

private protocol _StackNavigationControllerProtocol<State> {
  associatedtype State
  associatedtype Action
  var store: Store<StackState<State>, StackAction<State, Action>> { get }
}

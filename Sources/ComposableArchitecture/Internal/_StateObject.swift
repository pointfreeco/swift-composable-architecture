import Combine
import SwiftUI

@propertyWrapper
struct _StateObject<Object: ObservableObject>: DynamicProperty {
  private final class Observed: ObservableObject {
    lazy var objectWillChange = ObservableObjectPublisher()
    init() {}
  }

  private final class Storage {
    var initially: (() -> Object)!
    lazy var object: Object = initially()
    private var objectWillChange: ObservableObjectPublisher?
    private var subscription: AnyCancellable?

    func forwardObjectWillChange(to objectWillChange: ObservableObjectPublisher) {
      self.objectWillChange = objectWillChange

      if subscription == nil {
        subscription = object.objectWillChange.sink { [weak self] _ in
          guard let objectWillChange = self?.objectWillChange else { return }
          objectWillChange.send()
        }
      }
    }

    init() {}
  }

  @ObservedObject private var observedObject = Observed()
  @State private var storage = Storage()

  init(wrappedValue: @autoclosure @escaping () -> Object) {
    storage.initially = wrappedValue
  }

  func update() {
    storage.forwardObjectWillChange(to: observedObject.objectWillChange)
  }

  var wrappedValue: Object {
    storage.object
  }
}

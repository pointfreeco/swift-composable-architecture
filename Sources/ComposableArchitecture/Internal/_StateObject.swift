import Combine
import SwiftUI

@propertyWrapper
struct _StateObject<Object: ObservableObject>: DynamicProperty {
  private final class Observed: ObservableObject {
    lazy var objectWillChange = ObservableObjectPublisher()
  }

  private final class Storage {
    var initially: (() -> Object)!
    lazy var object: Object = initially()
    private var objectWillChange: ObservableObjectPublisher?
    private var subscription: AnyCancellable?

    func forwardObjectWillChange(to objectWillChange: ObservableObjectPublisher) {
      self.objectWillChange = objectWillChange

      if self.subscription == nil {
        self.subscription = self.object.objectWillChange.sink { [weak self] _ in
          self?.objectWillChange?.send()
        }
      }
    }
  }

  @ObservedObject private var observedObject = Observed()
  @State private var storage = Storage()

  init(wrappedValue: @autoclosure @escaping () -> Object) {
    self.storage.initially = wrappedValue
  }

  func update() {
    self.storage.forwardObjectWillChange(to: self.observedObject.objectWillChange)
  }

  var wrappedValue: Object {
    self.storage.object
  }
}

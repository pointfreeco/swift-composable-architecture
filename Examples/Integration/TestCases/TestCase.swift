public enum TestCase: String, CaseIterable, Identifiable, RawRepresentable {
  case escapedWithViewStore = "Escaped WithViewStore"
  case forEachBinding = "ForEach Binding"
  case navigationStack = "NavigationStack"
  case navigationStackBinding = "NavigationStack Binding"
  case presentation = "Presentation APIs"
  case presentationItem = "Presentation Item"
  case switchStore = "SwitchStore/CaseLet Warning"
  case bindingLocal = "BindingLocal Warning"

  public var id: Self { self }
}

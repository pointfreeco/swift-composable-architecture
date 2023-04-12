public enum TestCase: String, CaseIterable, Identifiable, RawRepresentable {
  case escapedWithViewStore = "Escaped WithViewStore"
  case forEachBinding = "ForEach Binding"
  case navigationStackBinding = "NavigationStack Binding"
  case presentation = "Presentation APIs"
  case switchStore = "SwitchStore/CaseLet Warning"

  public var id: Self { self }
}

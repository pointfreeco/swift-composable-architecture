import ComposableArchitecture
import Speech

extension SFSpeechRecognizerAuthorizationStatus: CustomDebugOutputConvertible {
  public var debugOutput: String {
    switch self {
    case .notDetermined:
      return "notDetermined"
    case .denied:
      return "denied"
    case .restricted:
      return "restricted"
    case .authorized:
      return "authorized"
    @unknown default:
      return "unknown"
    }
  }
}

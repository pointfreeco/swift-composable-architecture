import ComposableArchitecture

@Reducer
struct RecordMeeting {
  @ObservableState
  struct State: Equatable {
    var secondsElapsed = 0
    var speakerIndex = 0
    @Shared var syncUp: SyncUp
    var transcript = ""

    var durationRemaining: Duration {
      syncUp.duration - .seconds(secondsElapsed)
    }
  }

  enum Action {
    case endMeetingButtonTapped
    case nextButtonTapped
  }
}

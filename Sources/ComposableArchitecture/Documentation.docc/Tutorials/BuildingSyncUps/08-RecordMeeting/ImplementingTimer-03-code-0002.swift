import ComposableArchitecture

@Reducer
struct RecordMeeting {
  @ObservableState
  struct State: Equatable {
    @Presents var alert: AlertState<Action.Alert>?
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
    case onAppear
    case timerTick
  }

  @Dependency(\.continuousClock) var clock
  @Dependency(\.dismiss) var dismiss
  @Dependency(\.date.now) var now
  @Dependency(\.uuid) var uuid

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .endMeetingButtonTapped:
        // TODO: Alert to confirm ending meeting
        return .none

      case .nextButtonTapped:
        guard state.speakerIndex < state.syncUp.attendees.count - 1
        else {
          // TODO: Alert to confirm ending meeting
          return .none
        }
        state.speakerIndex += 1
        state.secondsElapsed = state.speakerIndex * Int(state.syncUp.durationPerAttendee.components.seconds)
        return .none

      case .onAppear:
        return .run { send in
          for await _ in clock.timer(interval: .seconds(1)) {
            await send(.timerTick)
          }
        }

      case .timerTick:
        state.secondsElapsed += 1
        let secondsPerAttendee = Int(state.syncUp.durationPerAttendee.components.seconds)
        if state.secondsElapsed.isMultiple(of: secondsPerAttendee) {
          if state.secondsElapsed == state.syncUp.duration.components.seconds {
            state.$syncUp.withLock {
              _ = $0.meetings.insert(
                Meeting(id: uuid(), date: now, transcript: state.transcript),
                at: 0
              )
            }
            return .run { _ in await dismiss() }
          }
          state.speakerIndex += 1
        }
        return .none
      }
    }
  }
}

struct RecordMeetingView: View {
  @Bindable var store: StoreOf<RecordMeeting>

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 16)
        .fill(store.syncUp.theme.mainColor)

      VStack {
        MeetingHeaderView(
          secondsElapsed: store.secondsElapsed,
          durationRemaining: store.durationRemaining,
          theme: store.syncUp.theme
        )
        MeetingTimerView(
          syncUp: store.syncUp,
          speakerIndex: store.speakerIndex
        )
        MeetingFooterView(
          syncUp: store.syncUp,
          nextButtonTapped: {
            store.send(.nextButtonTapped)
          },
          speakerIndex: store.speakerIndex
        )
      }
    }
    .padding()
    .foregroundStyle(store.syncUp.theme.accentColor)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("End meeting") {
          store.send(.endMeetingButtonTapped)
        }
      }
    }
    .navigationBarBackButtonHidden(true)
    .onAppear { store.send(.onAppear) }
  }
}

struct MeetingHeaderView: View {
  let secondsElapsed: Int
  let durationRemaining: Duration
  let theme: Theme

  var body: some View {
    VStack {
      ProgressView(value: progress)
        .progressViewStyle(MeetingProgressViewStyle(theme: theme))
      HStack {
        VStack(alignment: .leading) {
          Text("Time Elapsed")
            .font(.caption)
          Label(
            Duration.seconds(secondsElapsed).formatted(.units()),
            systemImage: "hourglass.bottomhalf.fill"
          )
        }
        Spacer()
        VStack(alignment: .trailing) {
          Text("Time Remaining")
            .font(.caption)
          Label(durationRemaining.formatted(.units()), systemImage: "hourglass.tophalf.fill")
            .font(.body.monospacedDigit())
            .labelStyle(.trailingIcon)
        }
      }
    }
    .padding([.top, .horizontal])
  }

  private var totalDuration: Duration {
    .seconds(secondsElapsed) + durationRemaining
  }

  private var progress: Double {
    guard totalDuration > .seconds(0) else { return 0 }
    return Double(secondsElapsed) / Double(totalDuration.components.seconds)
  }
}

struct MeetingProgressViewStyle: ProgressViewStyle {
  var theme: Theme

  func makeBody(configuration: Configuration) -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: 10)
        .fill(theme.accentColor)
        .frame(height: 20)

      ProgressView(configuration)
        .tint(theme.mainColor)
        .frame(height: 12)
        .padding(.horizontal)
    }
  }
}

struct MeetingTimerView: View {
  let syncUp: SyncUp
  let speakerIndex: Int

  var body: some View {
    Circle()
      .strokeBorder(lineWidth: 24)
      .overlay {
        VStack {
          Group {
            if speakerIndex < syncUp.attendees.count {
              Text(syncUp.attendees[speakerIndex].name)
            } else {
              Text("Someone")
            }
          }
          .font(.title)
          Text("is speaking")
          Image(systemName: "mic.fill")
            .font(.largeTitle)
            .padding(.top)
        }
        .foregroundStyle(syncUp.theme.accentColor)
      }
      .overlay {
        ForEach(Array(syncUp.attendees.enumerated()), id: \.element.id) { index, attendee in
          if index < speakerIndex + 1 {
            SpeakerArc(totalSpeakers: syncUp.attendees.count, speakerIndex: index)
              .rotation(Angle(degrees: -90))
              .stroke(syncUp.theme.mainColor, lineWidth: 12)
          }
        }
      }
      .padding(.horizontal)
  }
}

struct SpeakerArc: Shape {
  let totalSpeakers: Int
  let speakerIndex: Int

  func path(in rect: CGRect) -> Path {
    let diameter = min(rect.size.width, rect.size.height) - 24
    let radius = diameter / 2
    let center = CGPoint(x: rect.midX, y: rect.midY)
    return Path { path in
      path.addArc(
        center: center,
        radius: radius,
        startAngle: startAngle,
        endAngle: endAngle,
        clockwise: false
      )
    }
  }

  private var degreesPerSpeaker: Double {
    360 / Double(totalSpeakers)
  }
  private var startAngle: Angle {
    Angle(degrees: degreesPerSpeaker * Double(speakerIndex) + 1)
  }
  private var endAngle: Angle {
    Angle(degrees: startAngle.degrees + degreesPerSpeaker - 1)
  }
}

struct MeetingFooterView: View {
  let syncUp: SyncUp
  var nextButtonTapped: () -> Void
  let speakerIndex: Int

  var body: some View {
    VStack {
      HStack {
        if speakerIndex < syncUp.attendees.count - 1 {
          Text("Speaker \(speakerIndex + 1) of \(syncUp.attendees.count)")
        } else {
          Text("No more speakers.")
        }
        Spacer()
        Button(action: nextButtonTapped) {
          Image(systemName: "forward.fill")
        }
      }
    }
    .padding([.bottom, .horizontal])
  }
}

#Preview {
  NavigationStack {
    RecordMeetingView(
      store: Store(initialState: RecordMeeting.State(syncUp: Shared(value: .mock))) {
        RecordMeeting()
      }
    )
  }
}

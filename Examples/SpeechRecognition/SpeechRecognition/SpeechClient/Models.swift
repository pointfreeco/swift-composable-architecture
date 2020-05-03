import Speech

// The core data types in the Speech framework are reference types and are not constructible by us,
// and so they aren't super testable out the box. We define struct versions of those types to make
// them easier to use and test.

struct SpeechRecognitionResult: Equatable {
  var bestTranscription: Transcription
  var transcriptions: [Transcription]
  var isFinal: Bool
}

struct Transcription: Equatable {
  var averagePauseDuration: TimeInterval
  var formattedString: String
  var segments: [TranscriptionSegment]
  var speakingRate: Double
}

struct TranscriptionSegment: Equatable {
  var alternativeSubstrings: [String]
  var confidence: Float
  var duration: TimeInterval
  var substring: String
  var substringRange: NSRange
  var timestamp: TimeInterval
  var voiceAnalytics: VoiceAnalytics?
}

struct VoiceAnalytics: Equatable {
  var jitter: AcousticFeature
  var pitch: AcousticFeature
  var shimmer: AcousticFeature
  var voicing: AcousticFeature
}

struct AcousticFeature: Equatable {
  var acousticFeatureValuePerFrame: [Double]
  var frameDuration: TimeInterval
}

extension SpeechRecognitionResult {
  init(_ speechRecognitionResult: SFSpeechRecognitionResult) {
    self.bestTranscription = Transcription(speechRecognitionResult.bestTranscription)
    self.transcriptions = speechRecognitionResult.transcriptions.map(Transcription.init)
    self.isFinal = speechRecognitionResult.isFinal
  }
}

extension Transcription {
  init(_ transcription: SFTranscription) {
    self.averagePauseDuration = transcription.averagePauseDuration
    self.formattedString = transcription.formattedString
    self.segments = transcription.segments.map(TranscriptionSegment.init)
    self.speakingRate = transcription.speakingRate
  }
}

extension TranscriptionSegment {
  init(_ transcriptionSegment: SFTranscriptionSegment) {
    self.alternativeSubstrings = transcriptionSegment.alternativeSubstrings
    self.confidence = transcriptionSegment.confidence
    self.duration = transcriptionSegment.duration
    self.substring = transcriptionSegment.substring
    self.substringRange = transcriptionSegment.substringRange
    self.timestamp = transcriptionSegment.timestamp
    self.voiceAnalytics = transcriptionSegment.voiceAnalytics.map(VoiceAnalytics.init)
  }
}

extension VoiceAnalytics {
  init(_ voiceAnalytics: SFVoiceAnalytics) {
    self.jitter = AcousticFeature(voiceAnalytics.jitter)
    self.pitch = AcousticFeature(voiceAnalytics.pitch)
    self.shimmer = AcousticFeature(voiceAnalytics.shimmer)
    self.voicing = AcousticFeature(voiceAnalytics.voicing)
  }
}

extension AcousticFeature {
  init(_ acousticFeature: SFAcousticFeature) {
    self.acousticFeatureValuePerFrame = acousticFeature.acousticFeatureValuePerFrame
    self.frameDuration = acousticFeature.frameDuration
  }
}

# Speech Recognition

This application demonstrates how to work with a complex dependency in the Composable Architecture. It uses the `SFSpeechRecognizer` API from the `Speech` framework to listen to audio on the device and live-transcribe it to the UI.

The `SFSpeechRecognizer` class is a complex dependency, and if we used it freely in our application we wouldn't be able to test any of that code. So, instead, we wrap the API in a `SpeechClient` type that exposes `Effect`s for accessing the underlying `SFSpeechRecognizer` class. Then we can use it in the reducer in an understandable way, _and_ we can write tests for the reducer.

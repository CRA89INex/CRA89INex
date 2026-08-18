import Foundation
import Observation
import Speech
import AVFoundation

/// Minimal push-to-talk dictation so an intention can be spoken while
/// walking (§9), without pulling in the system keyboard's own mic button
/// (which would leave the app less able to auto-submit on silence, etc.).
@MainActor
@Observable
final class DictationController {
    private(set) var isRecording = false
    private(set) var transcript = ""

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    func toggle() {
        isRecording ? stop() : start()
    }

    func start() {
        guard !isRecording, let recognizer, recognizer.isAvailable else { return }

        Task {
            let speechStatus = await requestSpeechAuthorization()
            let micStatus = await requestMicrophoneAuthorization()
            guard speechStatus, micStatus else { return }
            beginRecording(with: recognizer)
        }
    }

    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        isRecording = false
    }

    private func beginRecording(with recognizer: SFSpeechRecognizer) {
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        // The Simulator (and occasionally a device with no recording route
        // available yet) can hand back a zero-channel/zero-sample-rate
        // format here, which installTap crashes on rather than failing
        // gracefully. Bail out instead — dictation just silently isn't
        // available in that state; the keyboard still works.
        guard format.channelCount > 0, format.sampleRate > 0 else { return }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            self.request = nil
            return
        }
        isRecording = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                self.transcript = result.bestTranscription.formattedString
            }
            if error != nil || result?.isFinal == true {
                self.stop()
            }
        }
    }

    private func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func requestMicrophoneAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

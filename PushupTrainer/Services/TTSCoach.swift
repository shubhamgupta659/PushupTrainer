//
//  TTSCoach.swift
//  PushupTrainer
//

import Foundation
import AVFoundation

final class TTSCoach {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.48
        synthesizer.speak(utterance)
    }
}



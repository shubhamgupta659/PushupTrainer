//
//  TTSCoach.swift
//  PushupTrainer
//

import Foundation
import AVFoundation

final class TTSCoach {
    private let synthesizer = AVSpeechSynthesizer()
    
    init() {
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Use playback category to ensure audio plays even in silent mode
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true)
        } catch {
            print("[TTS] Failed to configure audio session: \(error)")
        }
    }

    func speak(_ text: String) {
        // Ensure audio session is active before speaking
        do {
            let audioSession = AVAudioSession.sharedInstance()
            if !audioSession.isOtherAudioPlaying {
                try audioSession.setActive(true)
            }
        } catch {
            print("[TTS] Failed to activate audio session: \(error)")
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.48
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }
    
    func deactivateAfterSpeaking() {
        // Deactivate TTS audio session after speaking to allow speech recognition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("[TTS] Failed to deactivate audio session: \(error)")
            }
        }
    }
}



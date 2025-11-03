//
//  SpeechRecognizer.swift
//  PushupTrainer
//
//  Created for voice mode workout counting
//

import Foundation
import Speech
import AVFoundation
import Combine

final class SpeechRecognizer: NSObject, ObservableObject {
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    
    @Published var isAuthorized: Bool = false
    @Published var isListening: Bool = false
    @Published var errorMessage: String? {
        didSet {
            // Notify observers when error changes
            if errorMessage != nil {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("SpeechRecognizerError"), object: self.errorMessage)
                }
            }
        }
    }
    
    var onNumberRecognized: ((Int) -> Void)?

    // Closure called when stop command is detected
    var onStopCommand: (() -> Void)?

    override init() {
        // Use device's locale for speech recognition
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        super.init()
        requestAuthorization()
    }
    
    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    if #available(iOS 17.0, *) {
                        AVAudioApplication.requestRecordPermission { [weak self] granted in
                            DispatchQueue.main.async {
                                self?.isAuthorized = granted
                                if !granted {
                                    self?.errorMessage = "Microphone access is required for voice mode."
                                }
                            }
                        }
                    } else {
                        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                            DispatchQueue.main.async {
                                self?.isAuthorized = granted
                                if !granted {
                                    self?.errorMessage = "Microphone access is required for voice mode."
                                }
                            }
                        }
                    }
                case .denied, .restricted:
                    self?.isAuthorized = false
                    self?.errorMessage = "Speech recognition permission denied. Please enable it in Settings."
                case .notDetermined:
                    self?.isAuthorized = false
                @unknown default:
                    self?.isAuthorized = false
                }
            }
        }
    }
    
    func startListening() {
        guard isAuthorized else {
            errorMessage = "Speech recognition not authorized. Please grant permissions in Settings."
            requestAuthorization()
            return
        }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition is not available."
            return
        }
        
        // Stop any existing recognition task
        stopListening()
        
        // Configure audio session for recording BEFORE creating audio engine components
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Failed to configure audio session: \(error.localizedDescription)"
            return
        }
        
        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request
        
        // Create a fresh audio engine for this session
        let audioEngine = AVAudioEngine()
        self.audioEngine = audioEngine
        
        // Set up audio input with input node's native format
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.inputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            errorMessage = "Failed to start audio engine: \(error.localizedDescription)"
            // Clean up on error
            inputNode.removeTap(onBus: 0)
            self.audioEngine = nil
            return
        }
        
        isListening = true
        errorMessage = nil
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                isFinal = result.isFinal
                let recognizedText = result.bestTranscription.formattedString.lowercased()
                
                #if DEBUG
                print("[SpeechRecognizer] Recognized: '\(recognizedText)' (final: \(isFinal))")
                #endif
                
                // Parse numbers from recognized text
                self.parseNumbers(from: recognizedText)
            }
            
            if error != nil || isFinal {
                // Task completed or errored
                if let error = error {
                    // Don't report cancellation errors as they're intentional
                    let nsError = error as NSError
                    if nsError.code == 216 { // Cancelled
                        #if DEBUG
                        print("[SpeechRecognizer] Recognition task cancelled (intentional)")
                        #endif
                    } else {
                        DispatchQueue.main.async {
                            self.errorMessage = "Recognition error: \(error.localizedDescription)"
                            // Don't call stopListening here to avoid infinite loop
                            NotificationCenter.default.post(name: NSNotification.Name("SpeechRecognizerError"), object: error.localizedDescription)
                        }
                    }
                }
            }
        }
    }
    
    func stopListening() {
        recognitionTask?.cancel()
        recognitionTask = nil
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // Stop and remove tap from audio engine
        if let audioEngine = audioEngine {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            self.audioEngine = nil // Release the engine
        }
        
        // Reset audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("[SpeechRecognizer] Failed to deactivate audio session: \(error)")
        }
        
        isListening = false
        lastRecognizedNumber = nil // Reset tracking when stopping
        successText = "" // Reset success text when stopping
        
        // Clear any error message when stopping
        DispatchQueue.main.async {
            self.errorMessage = nil
        }
    }
    
    private var lastRecognizedNumber: Int? = nil
    private var successText: String = "" // Tracks the text that successfully incremented the counter

    private func parseNumbers(from text: String) {
        // Check for stop command first
        if text.lowercased().contains("stop") {
            #if DEBUG
            print("[SpeechRecognizer] 🎯 Stop command detected!")
            #endif
            DispatchQueue.main.async {
                self.onStopCommand?()
            }
            return
        }

        // Ignore TTS feedback by checking if the text contains TTS prompts
        let ttsKeywords = ["voice mode activated", "say your rep count", "say your rep", "activated say"]
        if ttsKeywords.contains(where: { text.lowercased().contains($0) }) {
            #if DEBUG
            print("[SpeechRecognizer] Ignoring TTS feedback: '\(text)'")
            #endif
            return
        }

        #if DEBUG
        print("[SpeechRecognizer] 📝 Full input: '\(text)'")
        print("[SpeechRecognizer] 📋 Success text: '\(successText)'")
        #endif

        // Step 1: Remove success text from the input to get NEW speech only
        var newText = text
        if !successText.isEmpty && text.hasPrefix(successText) {
            let beforeTrim = String(text.dropFirst(successText.count))
            newText = beforeTrim.trimmingCharacters(in: .whitespacesAndNewlines)
            #if DEBUG
            print("[SpeechRecognizer] ✂️ After removing success text (before trim): '\(beforeTrim)'")
            print("[SpeechRecognizer] 🆕 After trimming whitespace: '\(newText)'")
            #endif
        } else {
            #if DEBUG
            print("[SpeechRecognizer] ℹ️ No success text to remove, using full input")
            #endif
        }

        // If there's no new text, nothing to process
        if newText.isEmpty {
            #if DEBUG
            print("[SpeechRecognizer] ⚠️ New text is empty after processing, skipping")
            #endif
            return
        }

        // Step 2: Determine what the next expected number is
        let currentCount = lastRecognizedNumber ?? 0
        let nextNumber = currentCount + 1

        if nextNumber > 1000 {
            return // Don't go beyond 1000
        }

        #if DEBUG
        print("[SpeechRecognizer] 🔍 Looking for next number: \(nextNumber)")
        #endif

        // Step 3: Check if the next number is in the NEW text (as word or digit)
        let numberWords: [String: Int] = [
            "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
            "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
            "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15,
            "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19, "twenty": 20,
            "twenty one": 21, "twentyone": 21, "twenty two": 22, "twentytwo": 22,
            "twenty three": 23, "twentythree": 23, "twenty four": 24, "twentyfour": 24,
            "twenty five": 25, "twentyfive": 25, "twenty six": 26, "twentysix": 26,
            "twenty seven": 27, "twentyseven": 27, "twenty eight": 28, "twentyeight": 28,
            "twenty nine": 29, "twentynine": 29, "thirty": 30,
            "thirty one": 31, "thirtyone": 31, "thirty two": 32, "thirtytwo": 32,
            "thirty three": 33, "thirtythree": 33, "thirty four": 34, "thirtyfour": 34,
            "thirty five": 35, "thirtyfive": 35, "thirty six": 36, "thirtysix": 36,
            "thirty seven": 37, "thirtyseven": 37, "thirty eight": 38, "thirtyeight": 38,
            "thirty nine": 39, "thirtynine": 39, "forty": 40,
            "forty one": 41, "fortyone": 41, "forty two": 42, "fortytwo": 42,
            "forty three": 43, "fortythree": 43, "forty four": 44, "fortyfour": 44,
            "forty five": 45, "fortyfive": 45, "forty six": 46, "fortysix": 46,
            "forty seven": 47, "fortyseven": 47, "forty eight": 48, "fortyeight": 48,
            "forty nine": 49, "fortynine": 49, "fifty": 50,
            "fifty one": 51, "fiftyone": 51, "fifty two": 52, "fiftytwo": 52,
            "fifty three": 53, "fiftythree": 53, "fifty four": 54, "fiftyfour": 54,
            "fifty five": 55, "fiftyfive": 55, "fifty six": 56, "fiftysix": 56,
            "fifty seven": 57, "fiftyseven": 57, "fifty eight": 58, "fiftyeight": 58,
            "fifty nine": 59, "fiftynine": 59, "sixty": 60,
            "sixty one": 61, "sixtyone": 61, "sixty two": 62, "sixtytwo": 62,
            "sixty three": 63, "sixtythree": 63, "sixty four": 64, "sixtyfour": 64,
            "sixty five": 65, "sixtyfive": 65, "sixty six": 66, "sixtysix": 66,
            "sixty seven": 67, "sixtyseven": 67, "sixty eight": 68, "sixtyeight": 68,
            "sixty nine": 69, "sixtynine": 69, "seventy": 70,
            "seventy one": 71, "seventyone": 71, "seventy two": 72, "seventytwo": 72,
            "seventy three": 73, "seventythree": 73, "seventy four": 74, "seventyfour": 74,
            "seventy five": 75, "seventyfive": 75, "seventy six": 76, "seventysix": 76,
            "seventy seven": 77, "seventyseven": 77, "seventy eight": 78, "seventyeight": 78,
            "seventy nine": 79, "seventynine": 79, "eighty": 80,
            "eighty one": 81, "eightyone": 81, "eighty two": 82, "eightytwo": 82,
            "eighty three": 83, "eightythree": 83, "eighty four": 84, "eightyfour": 84,
            "eighty five": 85, "eightyfive": 85, "eighty six": 86, "eightysix": 86,
            "eighty seven": 87, "eightyseven": 87, "eighty eight": 88, "eightyeight": 88,
            "eighty nine": 89, "eightynine": 89, "ninety": 90,
            "ninety one": 91, "ninetyone": 91, "ninety two": 92, "ninetytwo": 92,
            "ninety three": 93, "ninetythree": 93, "ninety four": 94, "ninetyfour": 94,
            "ninety five": 95, "ninetyfive": 95, "ninety six": 96, "ninetysix": 96,
            "ninety seven": 97, "ninetyseven": 97, "ninety eight": 98, "ninetyeight": 98,
            "ninety nine": 99, "ninetynine": 99, "one hundred": 100, "hundred": 100,
            "one thousand": 1000, "thousand": 1000
        ]

        // Find the word representation(s) of the next number
        let nextNumberWords = numberWords.filter { $0.value == nextNumber }.map { $0.key }
        
        var foundInNewText = false
        
        // Check for number words (prioritize longer phrases first)
        let sortedWords = nextNumberWords.sorted { $0.count > $1.count }
        for word in sortedWords {
            if newText.lowercased().contains(word) {
                foundInNewText = true
                #if DEBUG
                print("[SpeechRecognizer] ✅ Found next number as word '\(word)' in new text")
                #endif
                break
            }
        }
        
        // If not found as word, check as digit
        if !foundInNewText {
            let nextNumberString = String(nextNumber)
            if newText.contains(nextNumberString) {
                foundInNewText = true
                #if DEBUG
                print("[SpeechRecognizer] ✅ Found next number as digit '\(nextNumberString)' in new text")
                #endif
            }
        }

        // Step 4: If found, increment and update success text to the FULL input
        if foundInNewText {
            lastRecognizedNumber = nextNumber
            successText = text // The entire input becomes the new success text
            
            #if DEBUG
            print("[SpeechRecognizer] ✅ SUCCESS! Incrementing to \(nextNumber)")
            print("[SpeechRecognizer] 💾 Updated success text to: '\(successText)'")
            #endif

            DispatchQueue.main.async {
                self.onNumberRecognized?(nextNumber)
            }
        } else {
            #if DEBUG
            print("[SpeechRecognizer] ❌ Next number \(nextNumber) not found in new text")
            #endif
        }
    }
}


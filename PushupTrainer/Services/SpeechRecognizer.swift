//
//  SpeechRecognizer.swift
//  PushupTrainer
//

import Speech
import SwiftUI
import AVFoundation
import Combine

final class SpeechRecognizer: NSObject, ObservableObject {
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    
    var onNumberRecognized: ((Int) -> Void)?
    var onStopCommand: (() -> Void)?
    
    @Published var isAuthorized: Bool = false
    @Published var isListening: Bool = false
    @Published var isUsingBluetooth: Bool = false
    @Published var currentInputName: String? = nil
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
    
    override init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        super.init()
        
        Task {
            do {
                guard SFSpeechRecognizer.authorizationStatus() == .notDetermined else {
                    await MainActor.run {
                        self.isAuthorized = (SFSpeechRecognizer.authorizationStatus() == .authorized)
                    }
                    return
                }
                
                SFSpeechRecognizer.requestAuthorization { status in
                    DispatchQueue.main.async {
                        self.isAuthorized = (status == .authorized)
                    }
                }
            }
        }
    }
    
    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.isAuthorized = (status == .authorized)
                if status != .authorized {
                    switch status {
                    case .denied:
                        self?.errorMessage = "Speech recognition access was denied. Please enable it in Settings."
                    case .restricted:
                        self?.errorMessage = "Speech recognition is restricted on this device."
                    case .notDetermined:
                        self?.errorMessage = "Speech recognition authorization not determined."
                    default:
                        self?.errorMessage = "Speech recognition is not available."
                    }
                }
            }
        }
    }
    
    func startListening() {
        #if DEBUG
        print("[SpeechRecognizer] 🎤 startListening() called")
        print("[SpeechRecognizer] - isAuthorized: \(isAuthorized)")
        #endif
        
        // Clear any previous errors when starting fresh
        DispatchQueue.main.async {
            self.errorMessage = nil
        }
        
        guard isAuthorized else {
            errorMessage = "Speech recognition not authorized. Please grant permissions in Settings."
            #if DEBUG
            print("[SpeechRecognizer] ❌ Not authorized")
            #endif
            requestAuthorization()
            return
        }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition is not available."
            #if DEBUG
            print("[SpeechRecognizer] ❌ Speech recognizer not available")
            #endif
            return
        }
        
        #if DEBUG
        print("[SpeechRecognizer] ✅ Checks passed, configuring audio...")
        #endif
        
        // Stop any existing recognition task
        stopListening()
        
        // Configure audio session for recording BEFORE creating audio engine components
        #if DEBUG
        print("[SpeechRecognizer] 🔧 Configuring audio session...")
        #endif
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            #if DEBUG
            print("[SpeechRecognizer] Current audio category: \(audioSession.category.rawValue)")
            print("[SpeechRecognizer] Current audio mode: \(audioSession.mode.rawValue)")
            #endif
            
            // Use .playAndRecord to allow both TTS and speech recognition
            // This is required because TTS has already set up .playback
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            #if DEBUG
            print("[SpeechRecognizer] ✅ Audio category set (.playAndRecord, .default)")
            #endif
            
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            #if DEBUG
            print("[SpeechRecognizer] ✅ Audio session activated")
            #endif
        } catch {
            errorMessage = "Failed to configure audio session: \(error.localizedDescription)"
            #if DEBUG
            print("[SpeechRecognizer] ❌ Audio session configuration failed: \(error.localizedDescription)")
            #endif
            return
        }
        
        // Prefer Bluetooth audio routes if available (e.g., AirPods) - separate try-catch so it doesn't block if unavailable
        #if DEBUG
        print("[SpeechRecognizer] 🎧 Setting preferred audio input...")
        #endif
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            let availableInputs = audioSession.availableInputs
            
            #if DEBUG
            print("[SpeechRecognizer] Available inputs: \(availableInputs?.count ?? 0)")
            if let inputs = availableInputs {
                for input in inputs {
                    print("[SpeechRecognizer]   - \(input.portName) (type: \(input.portType.rawValue))")
                }
            }
            #endif
            
            if let bluetoothInput = availableInputs?.first(where: { $0.portType == .bluetoothLE || $0.portType == .bluetoothHFP || $0.portType == .bluetoothA2DP }) {
                try audioSession.setPreferredInput(bluetoothInput)
                DispatchQueue.main.async {
                    self.isUsingBluetooth = true
                    self.currentInputName = bluetoothInput.portName
                }
                #if DEBUG
                print("[SpeechRecognizer] ✅ Using Bluetooth input: \(bluetoothInput.portName)")
                #endif
            } else {
                // No Bluetooth available, ensure we're using the built-in microphone
                if let builtInMic = availableInputs?.first(where: { $0.portType == .builtInMic }) {
                    try audioSession.setPreferredInput(builtInMic)
                    DispatchQueue.main.async {
                        self.isUsingBluetooth = false
                        self.currentInputName = "iPhone Microphone"
                    }
                    #if DEBUG
                    print("[SpeechRecognizer] ✅ Using built-in microphone: \(builtInMic.portName)")
                    #endif
                } else {
                    DispatchQueue.main.async {
                        self.isUsingBluetooth = false
                        self.currentInputName = nil
                    }
                    #if DEBUG
                    print("[SpeechRecognizer] ⚠️ No specific input found, using default audio input")
                    #endif
                }
            }
        } catch {
            // If input preference fails, just continue with default input
            DispatchQueue.main.async {
                self.isUsingBluetooth = false
                self.currentInputName = nil
            }
            #if DEBUG
            print("[SpeechRecognizer] ⚠️ Could not set input preference: \(error.localizedDescription), continuing with default input")
            #endif
        }
        
        // Create recognition request
        #if DEBUG
        print("[SpeechRecognizer] 📝 Creating recognition request...")
        #endif
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request
        
        #if DEBUG
        print("[SpeechRecognizer] 🎛️ Setting up audio engine...")
        #endif
        
        // Create a fresh audio engine for this session
        let audioEngine = AVAudioEngine()
        self.audioEngine = audioEngine
        
        // Set up audio input with input node's native format
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.inputFormat(forBus: 0)
        
        #if DEBUG
        print("[SpeechRecognizer] 🎚️ Installing audio tap (format: \(recordingFormat))")
        #endif
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        
        // Start audio engine
        #if DEBUG
        print("[SpeechRecognizer] 🔧 Preparing audio engine...")
        #endif
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
            
            #if DEBUG
            print("[SpeechRecognizer] ✅ Audio engine started successfully")
            #endif
            
            // Verify which input is actually being used
            #if DEBUG
            let audioSession = AVAudioSession.sharedInstance()
            if let currentRoute = audioSession.currentRoute.inputs.first {
                let portType = currentRoute.portType
                let isBluetooth = (portType == .bluetoothLE || portType == .bluetoothHFP || portType == .bluetoothA2DP)
                DispatchQueue.main.async {
                    self.isUsingBluetooth = isBluetooth
                    self.currentInputName = currentRoute.portName
                }
                print("[SpeechRecognizer] ✅ Using input: \(currentRoute.portName) (type: \(portType.rawValue), Bluetooth: \(isBluetooth))")
            } else {
                DispatchQueue.main.async {
                    self.isUsingBluetooth = false
                    self.currentInputName = nil
                }
                print("[SpeechRecognizer] ⚠️ Audio engine started but no input route detected")
            }
            #endif
        } catch {
            errorMessage = "Failed to start audio engine: \(error.localizedDescription)"
            #if DEBUG
            print("[SpeechRecognizer] ❌ Audio engine failed to start: \(error.localizedDescription)")
            #endif
            // Clean up on error
            inputNode.removeTap(onBus: 0)
            self.audioEngine = nil
            return
        }
        
        isListening = true
        errorMessage = nil
        
        #if DEBUG
        print("[SpeechRecognizer] 🎙️ Now listening, isListening: \(isListening)")
        #endif
        
        // Start recognition task
        #if DEBUG
        print("[SpeechRecognizer] 🚀 Starting recognition task...")
        #endif
        
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                isFinal = result.isFinal
                let recognizedText = result.bestTranscription.formattedString.lowercased()
                
                #if DEBUG
                print("[SpeechRecognizer] 🎤 Recognized: '\(recognizedText)' (final: \(isFinal))")
                #endif
                
                // Parse numbers from recognized text
                self.parseNumbers(from: recognizedText)
            }
            
            if error != nil || isFinal {
                // Task completed or errored
                if let error = error {
                    // Don't report cancellation errors or "no speech" errors as they're intentional/expected
                    let nsError = error as NSError
                    if nsError.code == 216 || nsError.code == 203 || nsError.code == 1110 { // Cancelled, interrupted, or no speech detected
                        #if DEBUG
                        print("[SpeechRecognizer] Recognition task ended (intentional/expected, code: \(nsError.code))")
                        #endif
                        // Clear error message for intentional cancellations and expected conditions
                        DispatchQueue.main.async {
                            self.errorMessage = nil
                        }
                    } else {
                        #if DEBUG
                        print("[SpeechRecognizer] ❌ Recognition error: \(error.localizedDescription), code: \(nsError.code)")
                        #endif
                        DispatchQueue.main.async {
                            self.errorMessage = "Recognition error: \(error.localizedDescription)"
                            // Don't call stopListening here to avoid infinite loop
                            NotificationCenter.default.post(name: NSNotification.Name("SpeechRecognizerError"), object: error.localizedDescription)
                        }
                    }
                }
            }
        }
        
        #if DEBUG
        print("[SpeechRecognizer] ✅ Recognition task started, ready to recognize speech")
        #endif
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
        
        // Reset Bluetooth status
        DispatchQueue.main.async {
            self.isUsingBluetooth = false
            self.currentInputName = nil
        }
        
        // Clear any error message when stopping
        DispatchQueue.main.async {
            self.errorMessage = nil
        }
        
        #if DEBUG
        print("[SpeechRecognizer] 🛑 Stopped listening, cleared all state and errors")
        #endif
    }
    
    private var lastRecognizedNumber: Int? = nil
    private var successText: String = "" // Tracks the text that successfully incremented the counter
    private var shouldIgnoreNumbers: Bool = false // When true, numbers are detected but state is not updated
    
    // Public method to enable/disable number state updates (used during pause)
    func setIgnoreNumbers(_ ignore: Bool) {
        shouldIgnoreNumbers = ignore
        #if DEBUG
        print("[SpeechRecognizer] 🔄 shouldIgnoreNumbers set to: \(ignore)")
        #endif
    }

    private func parseNumbers(from text: String) {
        #if DEBUG
        print("[SpeechRecognizer] 📝 parseNumbers called with text: '\(text)'")
        #endif
        
        let lowercasedText = text.lowercased()
        
        // First, check if we have new text beyond the success text
        // Only check for commands in the NEW portion of the text
        var textToCheck = lowercasedText
        if !successText.isEmpty && lowercasedText.hasPrefix(successText.lowercased()) {
            let afterSuccess = String(lowercasedText.dropFirst(successText.count)).trimmingCharacters(in: .whitespaces)
            textToCheck = afterSuccess
            #if DEBUG
            print("[SpeechRecognizer] 🔍 Checking only new text for commands: '\(textToCheck)'")
            #endif
        }
        
        // Check for voice commands in the NEW text only (only "stop" command)
        // Use word boundaries with spaces to avoid false positives
        
        // Helper function to check if a command exists as a standalone word
        func containsCommand(_ command: String, in text: String) -> String.Index? {
            let pattern = "(^|\\s)\(command)(\\s|$)"
            if let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive, .backwards]) {
                // Return the position of the command word itself, not the pattern match
                let matchText = String(text[range])
                if let commandRange = matchText.range(of: command, options: .caseInsensitive) {
                    return text.index(range.lowerBound, offsetBy: text.distance(from: matchText.startIndex, to: commandRange.lowerBound))
                }
            }
            return nil
        }
        
        // Check for "stop" command only
        if let _ = containsCommand("stop", in: textToCheck) {
            #if DEBUG
            print("[SpeechRecognizer] 🛑 Stop command detected in new text!")
            #endif
            DispatchQueue.main.async {
                self.onStopCommand?()
            }
            return // Stop listening, don't look for numbers
        }

        // Ignore TTS feedback by checking if the text contains TTS prompts
        let ttsKeywords = ["voice mode activated", "say your rep count", "say your rep", "activated say"]
        if ttsKeywords.contains(where: { lowercasedText.contains($0) }) {
            #if DEBUG
            print("[SpeechRecognizer] ⚠️ Ignoring TTS feedback: '\(text)'")
            #endif
            return
        }

        #if DEBUG
        print("[SpeechRecognizer] 📝 Full input: '\(text)'")
        print("[SpeechRecognizer] 📋 Success text: '\(successText)'")
        print("[SpeechRecognizer] 📋 Last recognized number: \(lastRecognizedNumber ?? -1)")
        #endif

        // Step 1: Remove success text from the input to get NEW speech only
        var newText = text
        if !successText.isEmpty && text.hasPrefix(successText) {
            let beforeTrim = String(text.dropFirst(successText.count))
            newText = beforeTrim.trimmingCharacters(in: .whitespaces)
            #if DEBUG
            print("[SpeechRecognizer] 🔍 Stripped success text, new text: '\(newText)'")
            #endif
        }
        
        // Step 2: Determine the next expected number
        let nextNumber = (lastRecognizedNumber ?? 0) + 1
        #if DEBUG
        print("[SpeechRecognizer] 🎯 Looking for next number: \(nextNumber)")
        #endif

        // Step 3: Check if nextNumber appears in newText (word or digit)
        var foundInNewText = false
        let nextNumberString = "\(nextNumber)"
        
        // Check for word form (e.g., "one", "two", etc.)
        if let wordForm = numberWordMap[nextNumber], newText.lowercased().contains(wordForm) {
            foundInNewText = true
            #if DEBUG
            print("[SpeechRecognizer] ✅ Found next number as word '\(wordForm)' in new text")
            #endif
        }
        
        // Check for digit form (e.g., "1", "2", etc.)
        if !foundInNewText && newText.contains(nextNumberString) {
            foundInNewText = true
            #if DEBUG
            print("[SpeechRecognizer] ✅ Found next number as digit '\(nextNumberString)' in new text")
            #endif
        }

        // Step 4: If found, update state (unless ignoring) and trigger callback
        if foundInNewText {
            if shouldIgnoreNumbers {
                // Number was detected but we're ignoring it (e.g., during pause)
                // Don't update lastRecognizedNumber or successText
                #if DEBUG
                print("[SpeechRecognizer] ⏸️ Number \(nextNumber) detected but IGNORED (shouldIgnoreNumbers=true)")
                print("[SpeechRecognizer] 📋 State unchanged: lastNum=\(lastRecognizedNumber ?? -1)")
                #endif
                
                // Still call the callback so WorkoutViewModel can log it
                DispatchQueue.main.async {
                    self.onNumberRecognized?(nextNumber)
                    #if DEBUG
                    print("[SpeechRecognizer] 🔔 Callback invoked for ignored number \(nextNumber)")
                    #endif
                }
            } else {
                // Normal flow: update state and increment counter
                lastRecognizedNumber = nextNumber
                successText = text // The entire input becomes the new success text
                
                #if DEBUG
                print("[SpeechRecognizer] ✅ SUCCESS! Incrementing to \(nextNumber)")
                print("[SpeechRecognizer] 💾 Updated success text to: '\(successText)'")
                print("[SpeechRecognizer] 🔔 Calling onNumberRecognized callback with \(nextNumber)")
                #endif

                DispatchQueue.main.async {
                    self.onNumberRecognized?(nextNumber)
                    #if DEBUG
                    print("[SpeechRecognizer] ✅ onNumberRecognized callback invoked for \(nextNumber)")
                    #endif
                }
            }
        } else {
            #if DEBUG
            print("[SpeechRecognizer] ❌ Next number \(nextNumber) not found in new text")                                                                      
            #endif
        }
    }

    private let numberWordMap: [Int: String] = [
        1: "one", 2: "two", 3: "three", 4: "four", 5: "five",
        6: "six", 7: "seven", 8: "eight", 9: "nine", 10: "ten",
        11: "eleven", 12: "twelve", 13: "thirteen", 14: "fourteen", 15: "fifteen",
        16: "sixteen", 17: "seventeen", 18: "eighteen", 19: "nineteen", 20: "twenty",
        21: "twenty-one", 22: "twenty-two", 23: "twenty-three", 24: "twenty-four", 25: "twenty-five",
        26: "twenty-six", 27: "twenty-seven", 28: "twenty-eight", 29: "twenty-nine", 30: "thirty",
        31: "thirty-one", 32: "thirty-two", 33: "thirty-three", 34: "thirty-four", 35: "thirty-five",
        36: "thirty-six", 37: "thirty-seven", 38: "thirty-eight", 39: "thirty-nine", 40: "forty",
        41: "forty-one", 42: "forty-two", 43: "forty-three", 44: "forty-four", 45: "forty-five",
        46: "forty-six", 47: "forty-seven", 48: "forty-eight", 49: "forty-nine", 50: "fifty",
        51: "fifty-one", 52: "fifty-two", 53: "fifty-three", 54: "fifty-four", 55: "fifty-five",
        56: "fifty-six", 57: "fifty-seven", 58: "fifty-eight", 59: "fifty-nine", 60: "sixty",
        61: "sixty-one", 62: "sixty-two", 63: "sixty-three", 64: "sixty-four", 65: "sixty-five",
        66: "sixty-six", 67: "sixty-seven", 68: "sixty-eight", 69: "sixty-nine", 70: "seventy",
        71: "seventy-one", 72: "seventy-two", 73: "seventy-three", 74: "seventy-four", 75: "seventy-five",
        76: "seventy-six", 77: "seventy-seven", 78: "seventy-eight", 79: "seventy-nine", 80: "eighty",
        81: "eighty-one", 82: "eighty-two", 83: "eighty-three", 84: "eighty-four", 85: "eighty-five",
        86: "eighty-six", 87: "eighty-seven", 88: "eighty-eight", 89: "eighty-nine", 90: "ninety",
        91: "ninety-one", 92: "ninety-two", 93: "ninety-three", 94: "ninety-four", 95: "ninety-five",
        96: "ninety-six", 97: "ninety-seven", 98: "ninety-eight", 99: "ninety-nine", 100: "hundred"
    ]
}

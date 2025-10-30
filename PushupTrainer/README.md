## Push-Up Trainer iOS App

Modern, minimalistic push-up trainer with a liquid-glass theme, smooth animations, and a foundation for premium AI and health integrations.

### Overview
- **Platform**: iOS 16+
- **Language**: Swift
- **UI**: SwiftUI
- **Architecture**: MVVM-ish (observable view models, environment objects), async-friendly
- **Persistence (current)**: Lightweight on-device via `UserDefaults`
- **Persistence (planned)**: Core Data (+ optional CloudKit)
- **Purchases**: StoreKit 2 (lifetime) – planned
- **Speech/Voice**: Apple Speech – planned
- **Health**: HealthKit – planned
- **Audio/TTS**: AVFoundation (TTS coach in place)

### Features (Current)
- **Liquid-Glass Theme**: System/Light/Dark with frosted cards and subtle strokes
- **Onboarding**: Collects gender, age, height, weight, target reps, and current max
- **Home**: Greeting, weekly stats placeholder, quick links, and a floating + to start workouts
- **Workout**: Manual and timer-style shell; big circular tap target; haptics; TTS encouragements; live heart rate (premium + HealthKit)
- **Activity**: Day-grouped session list with reps, duration, and kcal
- **Settings**: Theme switch, basic goal edits, premium toggle placeholder, analytics opt-in
- **Health (Premium)**: Toggle Health sync; live heart rate during session; session stores avg/max bpm; writes workouts to Apple Health; 60s recovery HR drop

### Roadmap (Planned)
- **Premium**: Voice-based rep counting, AI coach upgrades, in-app music control, Health/Cloud sync
- **StoreKit 2**: One-time lifetime unlock, gating Voice/Health/Cloud features
- **Core Data**: Replace `UserDefaults` for sessions/profile with migration; optional CloudKit sync
- **HealthKit**: Read/write workouts and calories
- **Analytics (opt-in)**: Local event logging with optional export
- **Notifications**: Daily reminders, streaks
- **Accessibility & Localization**: VoiceOver, Dynamic Type, EN default with structure for more locales

---

## Getting Started

### Requirements
- Xcode 16+ (iOS 16+ SDK)
- Swift 5.9+

### Build & Run
1. Open the project in Xcode: `PushupTrainer.xcodeproj` or the workspace if you create one
2. Select an iOS 16+ simulator or device
3. Run (Cmd+R)

On first launch, the app presents Onboarding. After saving, you land on Home. Start a workout from the floating + button.

### Project Structure
```
PushupTrainer/
  PushupTrainerApp.swift      // App entry – injects themed RootView
  RootView.swift              // Onboarding vs Main tabs (Home, Workout, Calendar, Settings)
  Theme/
    AppTheme.swift            // Theme model + glass modifier
  Models/
    UserProfile.swift         // Profile model + simple store
    WorkoutSession.swift      // Session model + simple store
  Utils/
    Calculations.swift        // BMI and MET calories
  Services/
    TTSCoach.swift            // AVSpeechSynthesizer wrapper
    HealthKitService.swift    // HealthKit auth + live heart rate streaming
  Views/
    OnboardingView.swift
    HomeView.swift
    WorkoutView.swift
    CalendarView.swift
    SettingsView.swift
```

---

## Architecture

### Pattern
- **SwiftUI + ObservableObjects** for state
- **Environment Objects** for app-wide theme
- **MVVM-ish**: Views bind to simple ViewModels where state is non-trivial (e.g., `WorkoutViewModel`)

### Data Layer (Current)
- `UserDefaults` storage helpers (`ProfileStore`, `SessionStore`) keep the app runnable now
- `Calculations` contains BMI and calories logic:
  - Calories: `MET * weightKg * durationHours` (gentle: 3.8, moderate: 5.0, vigorous: 8.0)

### Data Layer (Planned)
- **Core Data** entities for `UserProfile` and `WorkoutSession`
- **CloudKit** optional sync for premium users
- Migration from `UserDefaults` on first Core Data build

---

## Theming & Design
- **Liquid-Glass** look using `.ultraThinMaterial` with soft strokes and rounded corners
- Theme options: System / Light / Dark via `ThemeManager`
- Smooth transitions using SwiftUI animations

---

## Permissions & Privacy

Add the following keys to `Info.plist` when enabling respective features:
- `NSMicrophoneUsageDescription`: "Required for voice counting mode."
- `NSCameraUsageDescription`: "Used for nose press detection (optional)."
- `NSHealthShareUsageDescription`: "To sync workouts with Apple Health."
 - `NSHealthUpdateUsageDescription`: "To save workouts to Apple Health." (future)

Privacy principles:
- All data remains on-device unless user enables sync (CloudKit planned)
- Local analytics only if user opts-in

---

## Premium & Integrations

### StoreKit 2
- Single lifetime purchase unlocks: Voice Mode, AI upgrades, Health/Cloud sync, and music controls

### Speech Framework
- On-device counting to increment reps in Voice Mode

### HealthKit
- Read live heart rate during workouts (premium)
- Session stores average and max BPM
- Write workouts with active energy to Apple Health (premium)
- Future: Optionally read more body metrics

### AI Coach
- Currently: TTS encouragements at start and milestones
- Future: Adaptive prompts based on history

---

## Testing & QA

### Unit Tests (Planned initial coverage)
- Calculations: BMI and MET calories correctness
- Storage: Profile/session encode/decode and save/load

### UI Tests (Planned)
- Onboarding: end-to-end flow
- Workout: manual counting, pause/resume/end, session save
- Purchase: StoreKit sandbox lifetime unlock

### Accessibility
- Ensure large tap targets (workout circle)
- Dynamic Type and VoiceOver labels for major controls

---

## Developer Notes

### Enabling Voice Mode & HealthKit
1. Add permissions strings to `Info.plist`
2. Add Speech and Health entitlements/capabilities in the target
3. For Health: enable Premium in Settings, then enable Health sync; grant permissions on prompt
4. Start a workout to see live BPM. Implement the voice detector under premium flags as you add Voice mode.
5. When ending a workout with Health enabled, the app waits 60s to compute recovery HR drop, then saves the workout to Apple Health.

### StoreKit Configuration
1. Create a one-time in-app purchase in App Store Connect
2. Use StoreKit 2 to fetch and transact
3. Persist entitlement status securely (Keychain)

---

## Acceptance Criteria Mapping
- Builds and runs on iOS 16+
- Theme switching (System/Light/Dark) with liquid-glass visuals
- Onboarding collects and persists user details
- Manual workout counting works with haptics and TTS encouragement
- Timer-mode shell available (full interval logic can be expanded)
- Calendar lists completed sessions with reps, time, and calories
- Settings allows theme and goal edits, premium placeholder, analytics opt-in
- Permissions copy documented here; implementation toggles planned
- Unit/UI test scaffolding described for next milestones

---

## Contributing
Pull requests welcome. Please keep code readable (clear names, minimal deep nesting) and favor explicitness over cleverness. Match SwiftUI idioms and existing formatting.

---

## License
Proprietary – all rights reserved. Contact the author to discuss licensing.



//
//  AppTheme.swift
//  PushupTrainer
//

import SwiftUI
import Combine

enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil  // nil tells SwiftUI to follow device appearance
        case .light: return .light
        case .dark: return .dark
        }
    }
    
    var displayName: String {
        rawValue.capitalized
    }
}

enum AccentColor: String, CaseIterable, Identifiable, Codable {
    case blue = "Blue"
    case purple = "Purple"
    case green = "Green"
    case orange = "Orange"
    case pink = "Pink"
    case red = "Red"
    case teal = "Teal"
    case indigo = "Indigo"
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .purple: return .purple
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .pink: return .pink
        case .red: return .red
        case .teal: return .teal
        case .indigo: return .indigo
        }
    }
    
    var icon: String {
        return "circle.fill"
    }
}

final class ThemeManager: ObservableObject {
    private let themeStorageKey = "appTheme"
    private let accentStorageKey = "accentColor"
    private let appGroupID = "group.com.coder.ai.PushupTrainer"

    @Published var theme: AppTheme {
        didSet { 
            UserDefaults.standard.set(theme.rawValue, forKey: themeStorageKey)
            // Also save to App Group for widgets
            if let sharedDefaults = UserDefaults(suiteName: appGroupID) {
                sharedDefaults.set(theme.rawValue, forKey: themeStorageKey)
            }
        }
    }
    
    @Published var accentColor: AccentColor {
        didSet { 
            UserDefaults.standard.set(accentColor.rawValue, forKey: accentStorageKey)
            // Also save to App Group for widgets
            if let sharedDefaults = UserDefaults(suiteName: appGroupID) {
                sharedDefaults.set(accentColor.rawValue, forKey: accentStorageKey)
                #if DEBUG
                print("[ThemeManager] 💾 Saved accent color '\(accentColor.rawValue)' to App Group")
                #endif
            }
        }
    }

    init() {
        let themeRaw = UserDefaults.standard.string(forKey: themeStorageKey) ?? AppTheme.system.rawValue
        theme = AppTheme(rawValue: themeRaw) ?? .system
        
        let accentRaw = UserDefaults.standard.string(forKey: accentStorageKey) ?? AccentColor.blue.rawValue
        accentColor = AccentColor(rawValue: accentRaw) ?? .blue
        
        // Ensure App Group is in sync on init
        if let sharedDefaults = UserDefaults(suiteName: appGroupID) {
            sharedDefaults.set(theme.rawValue, forKey: themeStorageKey)
            sharedDefaults.set(accentColor.rawValue, forKey: accentStorageKey)
        }
    }
}

struct GlassBackground: ViewModifier {
    let cornerRadius: CGFloat
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            )
    }
}

extension View {
    func glass(cornerRadius: CGFloat = 20) -> some View { modifier(GlassBackground(cornerRadius: cornerRadius)) }
}



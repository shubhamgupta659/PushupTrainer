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
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

final class ThemeManager: ObservableObject {
    private let storageKey = "appTheme"

    @Published var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: storageKey) }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? AppTheme.system.rawValue
        theme = AppTheme(rawValue: raw) ?? .system
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



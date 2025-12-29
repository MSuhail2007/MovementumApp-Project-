import SwiftUI

// Centralized theme tokens for the app — updated to support both light and dark modes.
// Keep all tokens here; views use Theme.* so switching themes works globally.
struct Theme {
    // MARK: - Core palette
    static let accent = Color(red: 0.86, green: 0.18, blue: 0.16) // vivid red
    static let accentDark = Color(red: 0.62, green: 0.08, blue: 0.06)

    // Backgrounds (dynamic for light/dark)
    static var backgroundTop: Color {
        Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1) // near-black
            default:
                return UIColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1) // very light gray
            }
        })
    }
    static var backgroundBottom: Color {
        Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(red: 0.02, green: 0.02, blue: 0.02, alpha: 1)
            default:
                return UIColor(red: 0.92, green: 0.92, blue: 0.94, alpha: 1)
            }
        })
    }

    // Surfaces (cards, panels)
    static var surface: Color {
        Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark: return UIColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1)
            default: return UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)
            }
        })
    }
    static var surfaceElevated: Color {
        Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark: return UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1)
            default: return UIColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1)
            }
        })
    }

    // Subtle containers (pills, chips)
    static var pillBackground: Color {
        Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark: return UIColor(red: 0.09, green: 0.09, blue: 0.09, alpha: 1)
            default: return UIColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1)
            }
        })
    }
    static var pillBorder: Color {
        Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark: return UIColor.white.withAlphaComponent(0.03)
            default: return UIColor.black.withAlphaComponent(0.06)
            }
        })
    }

    // Muted accents / icons
    static var muted: Color {
        Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark: return UIColor(white: 1.0, alpha: 0.60)
            default: return UIColor(white: 0.12, alpha: 0.80)
            }
        })
    }
    static var faint: Color {
        Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark: return UIColor(white: 1.0, alpha: 0.04)
            default: return UIColor(white: 0.0, alpha: 0.03)
            }
        })
    }

    // Borders & strokes
    static var border: Color {
        Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark: return UIColor.white.withAlphaComponent(0.03)
            default: return UIColor.black.withAlphaComponent(0.06)
            }
        })
    }

    // Text colors (fix: return dark text for light mode, white for dark mode)
    static var primaryText: Color {
        Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark: return UIColor(white: 1.0, alpha: 1.0)
            default: return UIColor(white: 0.06, alpha: 1.0) // dark text
            }
        })
    }

    static var secondaryText: Color {
        Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark: return UIColor(white: 1.0, alpha: 0.72)
            default: return UIColor(white: 0.18, alpha: 0.85)
            }
        })
    }

    // Helper semantic colors
    static let danger = accent
    static let success = Color(red: 0.16, green: 0.74, blue: 0.42)

    // MARK: - Backwards-compatible aliases
    static var backgroundColor: Color { backgroundTop }
    static var accentColor: Color { accent }
    static var secondaryBackgroundColor: Color { surface }
    static var textColor: Color { primaryText }
    static var secondaryTextColor: Color { secondaryText }
    static var calorieColor: Color { Color.orange }

    // MARK: - Typography presets
    struct FontStyle {
        static let title = Font.system(size: 46, weight: .heavy, design: .rounded)
        static let headline = Font.system(size: 28, weight: .semibold, design: .rounded)
        static let stat = Font.system(size: 42, weight: .heavy, design: .rounded)
        static let body = Font.system(size: 16, weight: .regular, design: .rounded)
        static let caption = Font.system(size: 12, weight: .medium, design: .rounded)
    }

    // MARK: - Layout tokens
    struct Layout {
        static let cornerRadius: CGFloat = 18
        static let cardCornerRadius: CGFloat = 34
        static let pillCornerRadius: CGFloat = 18
        static let smallPadding: CGFloat = 8
        static let defaultPadding: CGFloat = 16
    }

    // MARK: - Shadows
    static var cardShadow: Color {
        // Return white shadow for dark mode, black shadow for light mode
        Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark: return UIColor.white.withAlphaComponent(0.08)
            default: return UIColor.black.withAlphaComponent(0.12)
            }
        })
    }
    static var softShadow: Color {
        Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark: return UIColor.white.withAlphaComponent(0.06)
            default: return UIColor.black.withAlphaComponent(0.06)
            }
        })
    }

    // MARK: - Gradients and convenience
    static var backgroundGradient: LinearGradient {
        LinearGradient(gradient: Gradient(colors: [backgroundTop, backgroundBottom]), startPoint: .top, endPoint: .bottom)
    }

    static var accentGradient: LinearGradient {
        LinearGradient(gradient: Gradient(colors: [accent, accentDark]), startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: - Chart tokens and helpers
    struct Chart {
        static let lineColor = Theme.accent
        static let lineWidth: CGFloat = 2.5

        static var areaGradient: LinearGradient {
            LinearGradient(gradient: Gradient(stops: [
                .init(color: Theme.accent.opacity(0.18), location: 0),
                .init(color: Theme.accent.opacity(0.02), location: 1)
            ]), startPoint: .top, endPoint: .bottom)
        }

        static let markerSize: CGFloat = 6
        static let highlightMarkerSize: CGFloat = 9
        static let entranceAnimation: Animation = .easeOut(duration: 0.9)

        static func path(for points: [Double], in rect: CGRect, smooth: Bool = false) -> Path {
            var path = Path()
            guard points.count > 0 else { return path }

            let pts = scaledPoints(points, in: rect)
            if pts.count == 1 {
                path.move(to: pts[0])
                return path
            }

            if smooth && pts.count > 2 {
                path.move(to: pts[0])
                for i in 1..<pts.count {
                    let mid = CGPoint(x: (pts[i].x + pts[i-1].x)/2, y: (pts[i].y + pts[i-1].y)/2)
                    path.addQuadCurve(to: mid, control: controlPoint(p1: pts[i-1], p2: pts[i]))
                }
                if let last = pts.last { path.addLine(to: last) }
            } else {
                path.move(to: pts[0])
                for p in pts.dropFirst() { path.addLine(to: p) }
            }

            return path
        }

        static func scaledPoints(_ points: [Double], in rect: CGRect) -> [CGPoint] {
            guard points.count > 0 else { return [] }
            let maxVal = points.max() ?? 1
            let minVal = points.min() ?? 0
            let range = max(1e-6, maxVal - minVal)
            let step = rect.width / CGFloat(max(1, points.count - 1))

            return points.enumerated().map { idx, val in
                let x = rect.minX + CGFloat(idx) * step
                let yNorm = CGFloat((val - minVal) / range)
                let y = rect.maxY - yNorm * rect.height
                return CGPoint(x: x, y: y)
            }
        }

        private static func controlPoint(p1: CGPoint, p2: CGPoint) -> CGPoint {
            CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
        }
    }
}

// Convenience extensions
extension Color {
    var gradient: LinearGradient {
        LinearGradient(gradient: Gradient(colors: [self, self.opacity(0.85)]), startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension View {
    func cardBackground() -> some View {
        self.background(Theme.surface)
            .cornerRadius(Theme.Layout.cardCornerRadius)
            .shadow(color: Theme.cardShadow, radius: 18, x: 0, y: 10)
    }
}

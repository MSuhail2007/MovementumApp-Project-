import SwiftUI

// This is our new, adaptive theme. It automatically changes based on Light/Dark Mode.
struct Theme {
    // These now reference the custom colors you created in the Asset Catalog.
    
    /// The main background color for all screens.
    static let backgroundColor = Color("AppBackgroundColor")
    
    /// The primary interactive color for buttons, tints, and highlights.
    static let accentColor = Color("AppAccentColor")
    
    /// The background color for cards and other secondary surfaces.
    static let secondaryBackgroundColor = Color("AppSecondaryBackgroundColor")
    
    /// The color for primary text, like titles.
    static let textColor = Color("AppTextColor")
    
    /// The color for secondary text, like subtitles.
    static let secondaryTextColor = Color("AppSecondaryTextColor")
    
    /// A specific color used for calorie-related UI elements. This can stay the same.
    static let calorieColor = Color.orange
}

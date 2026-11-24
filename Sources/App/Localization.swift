import Foundation

/// Tellio's text comes from the Apple TV app's String Catalog plus this app's own
/// (Resources/Localizable.xcstrings), turned into .lproj files by Scripts/localize.py.
/// iOS picks the language: Settings › Apps › Tellio › Language, or the iPhone's own.
///
/// SwiftUI looks up literals (Text("…"), Button("…")) by itself. The Settings building blocks
/// take a String, so they look theirs up with this, which leaves text with no translation,
/// such as a channel or account name, as it is.
extension String {
    var localizedUI: String {
        Bundle.main.localizedString(forKey: self, value: self, table: nil)
    }
}

import Carbon.HIToolbox

public enum SecureInput {
    /// True while a password field or similar holds secure input.
    /// Event taps receive no key events in that state, so modes must not activate.
    public static var isEnabled: Bool {
        IsSecureEventInputEnabled()
    }
}

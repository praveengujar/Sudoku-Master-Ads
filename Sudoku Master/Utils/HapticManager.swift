import UIKit

/// Shared haptic feedback manager to optimize performance
/// Prevents creating new feedback generators on each use
class HapticManager {
    static let shared = HapticManager()
    
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    private init() {
        // Pre-prepare generators for better performance
        lightImpact.prepare()
        mediumImpact.prepare()
        selectionFeedback.prepare()
    }
    
    func lightImpactOccurred() {
        lightImpact.impactOccurred()
        lightImpact.prepare() // Prepare for next use
    }
    
    func mediumImpactOccurred() {
        mediumImpact.impactOccurred()
        mediumImpact.prepare() // Prepare for next use
    }
    
    func heavyImpactOccurred() {
        heavyImpact.impactOccurred()
        heavyImpact.prepare() // Prepare for next use
    }
    
    func selectionChanged() {
        selectionFeedback.selectionChanged()
        selectionFeedback.prepare() // Prepare for next use
    }
    
    func notificationOccurred(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationFeedback.notificationOccurred(type)
        notificationFeedback.prepare() // Prepare for next use
    }
}
import Foundation
import SwiftUI
import Combine
import os.log

// MARK: - Performance Monitoring System

@MainActor
class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    // Published metrics for debugging
    @Published var currentMetrics: PerformanceMetrics = PerformanceMetrics()
    @Published var isMonitoringEnabled = false
    
    // Internal tracking
    private var startTimes: [String: CFAbsoluteTime] = [:]
    private var measurements: [String: [Double]] = [:]
    private var memoryReadings: [Double] = []
    private var frameRateReadings: [Double] = []
    
    // Logging
    private let logger = Logger(subsystem: "com.sudoku.performance", category: "monitoring")
    
    // Memory monitoring
    private var memoryTimer: Timer?
    private let memoryQueue = DispatchQueue(label: "memory.monitor", qos: .background)
    
    // Frame rate monitoring
    private var displayLink: CADisplayLink?
    private var frameTimestamps: [CFTimeInterval] = []
    
    private init() {
        #if DEBUG
        isMonitoringEnabled = true
        setupMemoryMonitoring()
        setupFrameRateMonitoring()
        #endif
    }
    
    deinit {
        memoryTimer?.invalidate()
        memoryTimer = nil
        displayLink?.invalidate()
        displayLink = nil
    }
    
    // MARK: - Public API
    
    func startOperation(_ name: String) {
        guard isMonitoringEnabled else { return }
        
        startTimes[name] = CFAbsoluteTimeGetCurrent()
        logger.debug("Started operation: \(name)")
    }
    
    func endOperation(_ name: String) {
        guard isMonitoringEnabled,
              let startTime = startTimes[name] else { return }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        recordMeasurement(name: name, duration: duration)
        startTimes.removeValue(forKey: name)
        
        logger.debug("Completed operation: \(name) in \(duration * 1000, privacy: .public)ms")
    }
    
    func measureAsync<T>(_ name: String, operation: () async throws -> T) async rethrows -> T {
        guard isMonitoringEnabled else {
            return try await operation()
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            recordMeasurement(name: name, duration: duration)
            logger.debug("Async operation: \(name) completed in \(duration * 1000, privacy: .public)ms")
        }
        
        return try await operation()
    }
    
    func measureSync<T>(_ name: String, operation: () throws -> T) rethrows -> T {
        guard isMonitoringEnabled else {
            return try operation()
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            recordMeasurement(name: name, duration: duration)
            logger.debug("Sync operation: \(name) completed in \(duration * 1000, privacy: .public)ms")
        }
        
        return try operation()
    }
    
    func recordCustomMetric(name: String, value: Double, unit: String = "ms") {
        guard isMonitoringEnabled else { return }
        
        recordMeasurement(name: name, duration: value)
        logger.debug("Custom metric: \(name) = \(value, privacy: .public)\(unit)")
    }
    
    func getMetricsSummary() -> [String: OperationMetrics] {
        guard isMonitoringEnabled else { return [:] }
        
        var summary: [String: OperationMetrics] = [:]
        
        for (name, durations) in measurements {
            guard !durations.isEmpty else { continue }
            
            let sorted = durations.sorted()
            let count = durations.count
            let sum = durations.reduce(0, +)
            
            summary[name] = OperationMetrics(
                name: name,
                count: count,
                totalTime: sum,
                averageTime: sum / Double(count),
                minTime: sorted.first ?? 0,
                maxTime: sorted.last ?? 0,
                medianTime: sorted[count / 2],
                p95Time: sorted[min(Int(Double(count) * 0.95), count - 1)],
                p99Time: sorted[min(Int(Double(count) * 0.99), count - 1)]
            )
        }
        
        return summary
    }
    
    func exportMetrics() -> String {
        guard isMonitoringEnabled else { return "Monitoring disabled" }
        
        let summary = getMetricsSummary()
        let currentMem = getCurrentMemoryUsage()
        let avgFrameRate = frameRateReadings.isEmpty ? 0 : frameRateReadings.reduce(0, +) / Double(frameRateReadings.count)
        
        var report = "=== Sudoku Master Performance Report ===\n"
        report += "Generated: \(Date())\n"
        report += "Memory Usage: \(currentMem.formatted(.byteCount(style: .memory)))\n"
        report += "Average Frame Rate: \(String(format: "%.1f", avgFrameRate)) FPS\n\n"
        
        report += "=== Operation Metrics ===\n"
        for (_, metrics) in summary.sorted(by: { $0.value.averageTime > $1.value.averageTime }) {
            report += "\(metrics.name):\n"
            report += "  Count: \(metrics.count)\n"
            report += "  Average: \(String(format: "%.2f", metrics.averageTime * 1000))ms\n"
            report += "  Min: \(String(format: "%.2f", metrics.minTime * 1000))ms\n"
            report += "  Max: \(String(format: "%.2f", metrics.maxTime * 1000))ms\n"
            report += "  P95: \(String(format: "%.2f", metrics.p95Time * 1000))ms\n"
            report += "  P99: \(String(format: "%.2f", metrics.p99Time * 1000))ms\n\n"
        }
        
        return report
    }
    
    func resetMetrics() {
        guard isMonitoringEnabled else { return }
        
        measurements.removeAll()
        memoryReadings.removeAll()
        frameRateReadings.removeAll()
        currentMetrics = PerformanceMetrics()
        
        logger.info("Performance metrics reset")
    }
    
    func startMonitoring() {
        isMonitoringEnabled = true
        setupMemoryMonitoring()
        setupFrameRateMonitoring()
        logger.info("Performance monitoring started")
    }
    
    func stopMonitoring() {
        isMonitoringEnabled = false
        memoryTimer?.invalidate()
        memoryTimer = nil
        displayLink?.invalidate()
        displayLink = nil
        logger.info("Performance monitoring stopped")
    }
    
    // MARK: - Internal Implementation
    
    private func recordMeasurement(name: String, duration: Double) {
        if measurements[name] == nil {
            measurements[name] = []
        }
        measurements[name]?.append(duration)
        
        // Update current metrics
        updateCurrentMetrics()
    }
    
    private func updateCurrentMetrics() {
        Task { @MainActor in
            let summary = getMetricsSummary()
            let memoryUsage = getCurrentMemoryUsage()
            let avgFrameRate = frameRateReadings.isEmpty ? 0 : frameRateReadings.reduce(0, +) / Double(frameRateReadings.count)
            
            currentMetrics = PerformanceMetrics(
                memoryUsage: memoryUsage,
                averageFrameRate: avgFrameRate,
                operationMetrics: summary,
                totalOperations: summary.values.reduce(0) { $0 + $1.count },
                timestamp: Date()
            )
        }
    }
    
    private func setupMemoryMonitoring() {
        guard isMonitoringEnabled else { return }
        
        memoryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let usage = self.getCurrentMemoryUsage()
            self.memoryReadings.append(Double(usage))
            
            // Keep only recent readings
            if self.memoryReadings.count > 100 {
                self.memoryReadings.removeFirst()
            }
            
            self.updateCurrentMetrics()
        }
    }
    
    private func setupFrameRateMonitoring() {
        guard isMonitoringEnabled else { return }
        
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkTick))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func displayLinkTick(displayLink: CADisplayLink) {
        frameTimestamps.append(displayLink.timestamp)
        
        // Keep only recent frames (last 60 frames for 1 second at 60fps)
        if frameTimestamps.count > 60 {
            frameTimestamps.removeFirst()
        }
        
        // Calculate frame rate
        if frameTimestamps.count >= 2 {
            let timeDiff = frameTimestamps.last! - frameTimestamps.first!
            let frameRate = Double(frameTimestamps.count - 1) / timeDiff
            frameRateReadings.append(frameRate)
            
            if frameRateReadings.count > 30 {
                frameRateReadings.removeFirst()
            }
        }
    }
    
    private func getCurrentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int(info.resident_size)
        } else {
            return 0
        }
    }
}

// MARK: - Data Structures

struct PerformanceMetrics {
    let memoryUsage: Int
    let averageFrameRate: Double
    let operationMetrics: [String: OperationMetrics]
    let totalOperations: Int
    let timestamp: Date
    
    init(
        memoryUsage: Int = 0,
        averageFrameRate: Double = 0,
        operationMetrics: [String: OperationMetrics] = [:],
        totalOperations: Int = 0,
        timestamp: Date = Date()
    ) {
        self.memoryUsage = memoryUsage
        self.averageFrameRate = averageFrameRate
        self.operationMetrics = operationMetrics
        self.totalOperations = totalOperations
        self.timestamp = timestamp
    }
    
    var formattedMemoryUsage: String {
        ByteCountFormatter.string(fromByteCount: Int64(memoryUsage), countStyle: .memory)
    }
}

struct OperationMetrics {
    let name: String
    let count: Int
    let totalTime: Double
    let averageTime: Double
    let minTime: Double
    let maxTime: Double
    let medianTime: Double
    let p95Time: Double
    let p99Time: Double
    
    var isSlowOperation: Bool {
        averageTime > 0.1 // 100ms threshold
    }
    
    var formattedAverageTime: String {
        String(format: "%.2fms", averageTime * 1000)
    }
}

// MARK: - Performance Measurement Extensions

extension PerformanceMonitor {
    // Convenience methods for common operations
    func measurePuzzleGeneration<T>(_ operation: () async throws -> T) async rethrows -> T {
        return try await measureAsync("puzzle_generation", operation: operation)
    }
    
    func measureValidation<T>(_ operation: () async throws -> T) async rethrows -> T {
        return try await measureAsync("move_validation", operation: operation)
    }
    
    func measureSolving<T>(_ operation: () async throws -> T) async rethrows -> T {
        return try await measureAsync("puzzle_solving", operation: operation)
    }
    
    func measureUIUpdate<T>(_ operation: () throws -> T) rethrows -> T {
        return try measureSync("ui_update", operation: operation)
    }
    
    func measureStorageOperation<T>(_ operation: () async throws -> T) async rethrows -> T {
        return try await measureAsync("storage_operation", operation: operation)
    }
    
    func measureAPICall<T>(_ operation: () async throws -> T) async rethrows -> T {
        return try await measureAsync("api_call", operation: operation)
    }
}

// MARK: - SwiftUI Integration

#if DEBUG
struct PerformanceOverlay: View {
    @ObservedObject var monitor = PerformanceMonitor.shared
    @State private var isExpanded = false
    
    var body: some View {
        if monitor.isMonitoringEnabled {
            VStack {
                HStack {
                    Spacer()
                    Button(action: { isExpanded.toggle() }) {
                        HStack {
                            Image(systemName: "speedometer")
                            if isExpanded {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(monitor.currentMetrics.formattedMemoryUsage)
                                        .font(.caption2)
                                    Text("\(String(format: "%.0f", monitor.currentMetrics.averageFrameRate)) FPS")
                                        .font(.caption2)
                                }
                            }
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                
                if isExpanded {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Performance Metrics")
                            .font(.headline)
                        
                        ForEach(Array(monitor.currentMetrics.operationMetrics.keys.sorted()), id: \.self) { key in
                            if let metrics = monitor.currentMetrics.operationMetrics[key] {
                                HStack {
                                    Text(metrics.name)
                                        .font(.caption)
                                    Spacer()
                                    Text(metrics.formattedAverageTime)
                                        .font(.caption)
                                        .foregroundColor(metrics.isSlowOperation ? .red : .green)
                                }
                            }
                        }
                        
                        HStack {
                            Button("Reset") {
                                monitor.resetMetrics()
                            }
                            Button("Export") {
                                let report = monitor.exportMetrics()
                                print(report)
                            }
                        }
                        .font(.caption)
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
        }
    }
}
#endif

// MARK: - Performance Utilities

extension Task where Success == Void, Failure == Never {
    @discardableResult
    static func detachedWithMonitoring(
        priority: TaskPriority? = nil,
        operation: @Sendable @escaping () async -> Void
    ) -> Task<Void, Never> {
        return Task.detached(priority: priority) {
            await PerformanceMonitor.shared.measureAsync("background_task") {
                await operation()
            }
        }
    }
}

// MARK: - Memory Leak Detection

class LeakDetector {
    private static var allocatedObjects: [String: Int] = [:]
    private static let queue = DispatchQueue(label: "leak.detector", attributes: .concurrent)
    
    static func trackAllocation(_ objectType: String) {
        queue.async(flags: .barrier) {
            allocatedObjects[objectType, default: 0] += 1
        }
    }
    
    static func trackDeallocation(_ objectType: String) {
        queue.async(flags: .barrier) {
            allocatedObjects[objectType, default: 0] -= 1
        }
    }
    
    static func getLeakReport() -> [String: Int] {
        return queue.sync {
            return allocatedObjects.filter { $0.value > 0 }
        }
    }
    
    static func printLeakReport() {
        let leaks = getLeakReport()
        if !leaks.isEmpty {
            print("🚨 Potential Memory Leaks Detected:")
            for (type, count) in leaks {
                print("  \(type): \(count) objects")
            }
        } else {
            print("✅ No memory leaks detected")
        }
    }
}
import QuartzCore

/// Physics ticks with the display. Low Power drops the ceiling; Reduce Motion does not.
enum DisplayCadence {
    static var frameRateRange: CAFrameRateRange {
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            return CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        }
        return CAFrameRateRange(minimum: 48, maximum: 120, preferred: 120)
    }

    static func apply(_ link: CADisplayLink) {
        link.preferredFrameRateRange = frameRateRange
    }
}

import Foundation

/// Minimal time controller for a single VRMC_vrm_animation clip.
///
/// `VRMAPlayer` does not mutate a VRM model directly. Call `update(deltaTime:)`
/// or `sample`, then pass the returned `VRMASample` to a renderer-specific
/// avatar such as `VRMNode.apply(vrmaSample:)` or `VRMEntity.apply(vrmaSample:)`.
public struct VRMAPlayer {
    public let clip: VRMAClip
    public private(set) var currentTime: Float
    public var isPlaying: Bool
    public var isLooping: Bool
    public var playbackSpeed: Float

    public var duration: Float {
        return clip.duration
    }

    public var sample: VRMASample {
        return clip.evaluate(at: currentTime)
    }

    public init(clip: VRMAClip,
                currentTime: Float = 0,
                isPlaying: Bool = false,
                isLooping: Bool = true,
                playbackSpeed: Float = 1) {
        self.clip = clip
        self.currentTime = Self.clamped(time: currentTime, duration: clip.duration)
        self.isPlaying = isPlaying
        self.isLooping = isLooping
        self.playbackSpeed = playbackSpeed
    }

    public mutating func play() {
        isPlaying = true
    }

    public mutating func pause() {
        isPlaying = false
    }

    public mutating func stop() {
        isPlaying = false
        currentTime = 0
    }

    public mutating func seek(to time: Float) {
        currentTime = Self.clamped(time: time, duration: duration)
    }

    @discardableResult
    public mutating func update(deltaTime: Float) -> VRMASample {
        guard isPlaying, duration > 0 else { return sample }

        let advancedTime = currentTime + deltaTime * playbackSpeed
        if isLooping {
            currentTime = Self.looped(time: advancedTime, duration: duration)
        } else {
            currentTime = Self.clamped(time: advancedTime, duration: duration)
            if advancedTime <= 0 || advancedTime >= duration {
                isPlaying = false
            }
        }

        return sample
    }
}

private extension VRMAPlayer {
    static func clamped(time: Float, duration: Float) -> Float {
        guard duration > 0 else { return 0 }
        return max(0, min(time, duration))
    }

    static func looped(time: Float, duration: Float) -> Float {
        guard duration > 0 else { return 0 }
        let remainder = time.truncatingRemainder(dividingBy: duration)
        return remainder >= 0 ? remainder : remainder + duration
    }
}

import Foundation

/// Minimal public loader for VRMC_vrm_animation assets.
///
/// This loader only parses the extension and builds a sampled clip from the
/// first glTF animation. It does not include renderer-facing playback APIs.
public final class VRMAAnimationLoader {
    public init() {}

    public func load(withData data: Data) throws -> VRMA {
        return try VRMA(data: data)
    }

    public func load(withURL url: URL) throws -> VRMA {
        let data = try Data(contentsOf: url)
        return try load(withData: data)
    }

    public func loadClip(from vrma: VRMA, animationIndex: Int = 0) throws -> VRMAClip {
        return try VRMAClip(from: vrma, animationIndex: animationIndex)
    }
}

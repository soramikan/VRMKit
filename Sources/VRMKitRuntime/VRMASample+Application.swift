import simd
import VRMKit

package extension Humanoid {
    /// Convenience accessor for bones keyed by a VRMA bone name.
    ///
    /// VRMA bone names share their raw values with ``Humanoid/Bones``, so this
    /// maps directly without any runtime lookup table. The method name is
    /// explicit to avoid overload ambiguity with `node(for:)`.
    func node(forVRMABone bone: VRMA.BoneName) -> Node? {
        guard let humanoidBone = Bones(rawValue: bone.rawValue) else { return nil }
        return node(for: humanoidBone)
    }
}

package extension ExpressionPreset {
    /// Builds an ``ExpressionKey`` for a VRMA expression name, preferring the
    /// preset initializer when the name matches a VRM 1.0 expression preset.
    static func expressionKey(for name: String) -> ExpressionKey {
        if let preset = ExpressionPreset(name: name) {
            return .preset(preset)
        }
        return .custom(name)
    }
}

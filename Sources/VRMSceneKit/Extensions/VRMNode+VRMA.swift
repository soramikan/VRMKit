import SceneKit
import simd
import VRMKit
import VRMKitRuntime

public extension VRMNode {
    /// Captures this avatar's current humanoid rest rotations for VRMA retargeting.
    ///
    /// Build this before mutating the avatar into an example pose, then reuse it
    /// while applying samples from the same clip.
    func makeVRMARetargetingContext(for clip: VRMAClip) -> VRMARetargetingContext {
        var localRotations: [VRMA.BoneName: simd_quatf] = [:]
        var worldRotations: [VRMA.BoneName: simd_quatf] = [:]
        let rootRotationInverse = simd_inverse(simdWorldOrientation)
        for boneName in VRMA.BoneName.allCases {
            guard let node = humanoid.node(forVRMABone: boneName) else { continue }
            localRotations[boneName] = node.utx.localRotation
            worldRotations[boneName] = rootRotationInverse * node.utx.rotation
        }
        return VRMARetargetingContext(clip: clip,
                                      targetRestLocalRotations: localRotations,
                                      targetRestWorldRotations: worldRotations)
    }

    /// Applies a renderer-neutral VRMA sample to this VRM avatar.
    ///
    /// Matching humanoid bones receive the sampled local rotation. The hips bone
    /// additionally receives the sampled local translation when present. The
    /// model's root transform and scale are left untouched.
    ///
    /// Expression weights are routed through the existing expression API. Preset
    /// names are resolved to ``ExpressionPreset`` when possible; otherwise they
    /// are treated as custom expression names. ``VRMASample/lookAtRotation`` is
    /// intentionally ignored until LookAt retargeting is implemented safely.
    func apply(vrmaSample sample: VRMASample) {
        apply(vrmaSample: sample, retargetingContext: nil)
    }

    /// Applies a renderer-neutral VRMA sample using a precomputed retargeting context.
    func apply(vrmaSample sample: VRMASample, retargetingContext: VRMARetargetingContext?) {
        for (boneName, rotation) in sample.humanoidRotations {
            guard let node = humanoid.node(forVRMABone: boneName) else { continue }
            if let retargetingContext {
                node.utx.localRotation = retargetingContext.retargetedLocalRotation(
                    for: boneName,
                    sourceLocalRotation: rotation,
                    sampleSourceRestLocalRotations: sample.sourceRestLocalRotations,
                    sampleSourceRestWorldRotations: sample.sourceRestWorldRotations
                )
            } else {
                node.utx.localRotation = rotation.simdQuaternion
            }
        }

        if let hipsTranslation = sample.hipsTranslation,
           let hipsNode = humanoid.node(forVRMABone: .hips) {
            hipsNode.utx.localPosition = SIMD3<Float>(hipsTranslation.x,
                                                      hipsTranslation.y,
                                                      hipsTranslation.z)
        }

        for (name, weight) in sample.expressionWeights {
            let key = ExpressionPreset.expressionKey(for: name)
            setExpression(value: CGFloat(weight), for: key)
        }

        // LookAt retargeting is intentionally left unimplemented in this slice.
        _ = sample.lookAtRotation
    }
}

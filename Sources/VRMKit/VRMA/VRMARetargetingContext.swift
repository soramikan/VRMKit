import simd

/// Rest-pose data used to retarget VRMC_vrm_animation humanoid rotations.
///
/// VRM 1.0 allows arbitrary rest rotations, so applying VRMA local rotations
/// directly to a destination avatar can produce incorrect head and limb
/// directions. Build this once for a loaded destination avatar and reuse it
/// while playing a clip.
public struct VRMARetargetingContext {
    package let sourceRestLocalRotations: [VRMA.BoneName: GLTF.Vector4]
    package let sourceRestWorldRotations: [VRMA.BoneName: GLTF.Vector4]
    package let targetRestLocalRotations: [VRMA.BoneName: simd_quatf]
    package let targetRestWorldRotations: [VRMA.BoneName: simd_quatf]

    public init(clip: VRMAClip,
                targetRestLocalRotations: [VRMA.BoneName: simd_quatf],
                targetRestWorldRotations: [VRMA.BoneName: simd_quatf]) {
        self.sourceRestLocalRotations = clip.sourceRestLocalRotations
        self.sourceRestWorldRotations = clip.sourceRestWorldRotations
        self.targetRestLocalRotations = targetRestLocalRotations.mapValues(\.vrmaNormalized)
        self.targetRestWorldRotations = targetRestWorldRotations.mapValues(\.vrmaNormalized)
    }

    package func retargetedLocalRotation(for boneName: VRMA.BoneName,
                                         sourceLocalRotation: GLTF.Vector4,
                                         sampleSourceRestLocalRotations: [VRMA.BoneName: GLTF.Vector4],
                                         sampleSourceRestWorldRotations: [VRMA.BoneName: GLTF.Vector4]) -> simd_quatf {
        let sourceRestLocalRotations = self.sourceRestLocalRotations.merging(sampleSourceRestLocalRotations) { current, _ in current }
        let sourceRestWorldRotations = self.sourceRestWorldRotations.merging(sampleSourceRestWorldRotations) { current, _ in current }

        guard let sourceRestLocal = sourceRestLocalRotations[boneName]?.simdQuaternion.vrmaNormalized,
              let sourceRestWorld = sourceRestWorldRotations[boneName]?.simdQuaternion.vrmaNormalized,
              let targetRestLocal = targetRestLocalRotations[boneName],
              let targetRestWorld = targetRestWorldRotations[boneName] else {
            return sourceLocalRotation.simdQuaternion.vrmaNormalized
        }

        let sourcePose = sourceLocalRotation.simdQuaternion.vrmaNormalized
        let normalizedLocalRotation = sourceRestWorld
            * simd_inverse(sourceRestLocal)
            * sourcePose
            * simd_inverse(sourceRestWorld)
        return (targetRestLocal
            * simd_inverse(targetRestWorld)
            * normalizedLocalRotation
            * targetRestWorld).vrmaNormalized
    }
}

package extension GLTF.Vector4 {
    init(_ quaternion: simd_quatf) {
        let normalized = quaternion.vrmaNormalized
        self.init(x: normalized.vector.x,
                  y: normalized.vector.y,
                  z: normalized.vector.z,
                  w: normalized.vector.w)
    }

    /// Interprets the vector as a glTF quaternion `(x, y, z, w)`.
    var simdQuaternion: simd_quatf {
        if x == 0, y == 0, z == 0, w == 0 {
            return .vrmaIdentity
        }
        return simd_quatf(vector: SIMD4<Float>(x, y, z, w)).vrmaNormalized
    }
}

package extension GLTF.Matrix {
    var rotation: simd_quatf {
        guard values.count == 16 else { return .vrmaIdentity }
        let x = simd_normalize(SIMD3<Float>(values[0], values[1], values[2]))
        let y = simd_normalize(SIMD3<Float>(values[4], values[5], values[6]))
        let z = simd_normalize(SIMD3<Float>(values[8], values[9], values[10]))
        return simd_quatf(simd_float3x3(columns: (x, y, z))).vrmaNormalized
    }
}

package extension simd_quatf {
    static var vrmaIdentity: simd_quatf {
        simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
    }

    var vrmaNormalized: simd_quatf {
        let length = simd_length(vector)
        guard length > 0 else { return .vrmaIdentity }
        return simd_quatf(vector: vector / length)
    }
}

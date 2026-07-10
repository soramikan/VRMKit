#if canImport(RealityKit)
import Foundation
import RealityKit
import simd
import Testing
@testable import VRMKit
import VRMKitRuntime
@testable import VRMRealityKit

@Suite
@MainActor
struct VRMEntityVRMATests {

    @Test
    func testApplySampleSetsHumanoidLocalRotationAndHipsTranslation() throws {
        guard #available(iOS 18.0, macOS 15.0, visionOS 2.0, *) else { return }
        let url = try #require(Bundle.module.url(forResource: "Seed-san", withExtension: "vrm"),
                               "Failed to load Seed-san.vrm resource from test bundle.")
        let loader = try VRMEntityLoader(withURL: url, isMToonEnabled: false)
        let vrmEntity = try loader.loadEntity()

        let sample = VRMASample(
            humanoidRotations: [
                .hips: GLTF.Vector4(x: 0, y: 1, z: 0, w: 0),
                .head: GLTF.Vector4(x: 0, y: 0, z: 0, w: 1)
            ],
            hipsTranslation: GLTF.Vector3(x: 0.1, y: 0.2, z: 0.3),
            expressionWeights: [:],
            lookAtRotation: nil
        )

        let hips = try #require(vrmEntity.humanoid.node(forVRMABone: .hips), "hips bone not found")
        let head = try #require(vrmEntity.humanoid.node(forVRMABone: .head), "head bone not found")

        vrmEntity.apply(vrmaSample: sample)

        let hipsRotation = hips.utx.localRotation
        #expect(abs(hipsRotation.vector.x) < 1e-6)
        #expect(abs(hipsRotation.vector.y - 1) < 1e-6)
        #expect(abs(hipsRotation.vector.z) < 1e-6)
        #expect(abs(hipsRotation.vector.w) < 1e-6)

        let headRotation = head.utx.localRotation
        #expect(abs(headRotation.vector.x) < 1e-6)
        #expect(abs(headRotation.vector.y) < 1e-6)
        #expect(abs(headRotation.vector.z) < 1e-6)
        #expect(abs(headRotation.vector.w - 1) < 1e-6)

        let hipsPosition = hips.utx.localPosition
        #expect(abs(hipsPosition.x - 0.1) < 1e-6)
        #expect(abs(hipsPosition.y - 0.2) < 1e-6)
        #expect(abs(hipsPosition.z - 0.3) < 1e-6)
    }

    @Test
    func testApplySampleLeavesRootEntityTransformUnchanged() throws {
        guard #available(iOS 18.0, macOS 15.0, visionOS 2.0, *) else { return }
        let url = try #require(Bundle.module.url(forResource: "Seed-san", withExtension: "vrm"),
                               "Failed to load Seed-san.vrm resource from test bundle.")
        let loader = try VRMEntityLoader(withURL: url, isMToonEnabled: false)
        let vrmEntity = try loader.loadEntity()

        let rootPosition = vrmEntity.entity.utx.localPosition
        let rootRotation = vrmEntity.entity.utx.localRotation
        let rootScale = vrmEntity.entity.utx.lossyScale

        let sample = VRMASample(
            humanoidRotations: [.head: GLTF.Vector4(x: 0, y: 0, z: 1, w: 0)],
            hipsTranslation: nil,
            expressionWeights: [:],
            lookAtRotation: nil
        )
        vrmEntity.apply(vrmaSample: sample)

        #expect(abs(vrmEntity.entity.utx.localPosition.x - rootPosition.x) < 1e-6)
        #expect(abs(vrmEntity.entity.utx.localPosition.y - rootPosition.y) < 1e-6)
        #expect(abs(vrmEntity.entity.utx.localPosition.z - rootPosition.z) < 1e-6)
        #expect(abs(vrmEntity.entity.utx.localRotation.vector.x - rootRotation.vector.x) < 1e-6)
        #expect(abs(vrmEntity.entity.utx.localRotation.vector.y - rootRotation.vector.y) < 1e-6)
        #expect(abs(vrmEntity.entity.utx.localRotation.vector.z - rootRotation.vector.z) < 1e-6)
        #expect(abs(vrmEntity.entity.utx.localRotation.vector.w - rootRotation.vector.w) < 1e-6)
        #expect(abs(vrmEntity.entity.utx.lossyScale.x - rootScale.x) < 1e-6)
        #expect(abs(vrmEntity.entity.utx.lossyScale.y - rootScale.y) < 1e-6)
        #expect(abs(vrmEntity.entity.utx.lossyScale.z - rootScale.z) < 1e-6)
    }

    @Test
    func testApplySampleWithRetargetingPreservesTargetRestRotation() throws {
        guard #available(iOS 18.0, macOS 15.0, visionOS 2.0, *) else { return }
        let url = try #require(Bundle.module.url(forResource: "Seed-san", withExtension: "vrm"),
                               "Failed to load Seed-san.vrm resource from test bundle.")
        let loader = try VRMEntityLoader(withURL: url, isMToonEnabled: false)
        let vrmEntity = try loader.loadEntity()
        let head = try #require(vrmEntity.humanoid.node(forVRMABone: .head), "head bone not found")
        let targetRestRotation = simd_quatf(angle: 0.35, axis: SIMD3<Float>(0, 0, 1))
        head.utx.localRotation = targetRestRotation

        let clip = VRMAClip(
            name: nil,
            duration: 0,
            channels: [],
            sourceRestLocalRotations: [.head: .identity],
            sourceRestWorldRotations: [.head: .identity]
        )
        let context = vrmEntity.makeVRMARetargetingContext(for: clip)
        head.utx.localRotation = simd_quatf(angle: -0.5, axis: SIMD3<Float>(0, 1, 0))

        let sample = VRMASample(
            humanoidRotations: [.head: .identity],
            hipsTranslation: nil,
            expressionWeights: [:],
            lookAtRotation: nil
        )
        vrmEntity.apply(vrmaSample: sample, retargetingContext: context)

        #expect(Self.quaternionMatches(head.utx.localRotation, targetRestRotation))
    }

    @Test
    func testRetargetingContextIgnoresAvatarRootRotation() throws {
        guard #available(iOS 18.0, macOS 15.0, visionOS 2.0, *) else { return }
        let url = try #require(Bundle.module.url(forResource: "Seed-san", withExtension: "vrm"),
                               "Failed to load Seed-san.vrm resource from test bundle.")
        let loader = try VRMEntityLoader(withURL: url, isMToonEnabled: false)
        let vrmEntity = try loader.loadEntity()
        let head = try #require(vrmEntity.humanoid.node(forVRMABone: .head), "head bone not found")
        let clip = VRMAClip(
            name: nil,
            duration: 0,
            channels: [],
            sourceRestLocalRotations: [.head: .identity],
            sourceRestWorldRotations: [.head: .identity]
        )
        let sample = VRMASample(
            humanoidRotations: [.head: GLTF.Vector4(simd_quatf(angle: 0.35, axis: SIMD3<Float>(1, 0, 0)))],
            hipsTranslation: nil,
            expressionWeights: [:],
            lookAtRotation: nil
        )

        let identityRootContext = vrmEntity.makeVRMARetargetingContext(for: clip)
        vrmEntity.entity.utx.localRotation = simd_quatf(angle: 0.5, axis: SIMD3<Float>(0, 1, 0))
        let rotatedRootContext = vrmEntity.makeVRMARetargetingContext(for: clip)

        vrmEntity.apply(vrmaSample: sample, retargetingContext: identityRootContext)
        let identityRootRotation = head.utx.localRotation
        vrmEntity.apply(vrmaSample: sample, retargetingContext: rotatedRootContext)
        let rotatedRootRotation = head.utx.localRotation

        #expect(Self.quaternionMatches(rotatedRootRotation, identityRootRotation))
    }

    private static func quaternionMatches(_ lhs: simd_quatf,
                                          _ rhs: simd_quatf,
                                          accuracy: Float = 1e-5) -> Bool {
        let lhsVector = simd_normalize(lhs.vector)
        let rhsVector = simd_normalize(rhs.vector)
        return abs(simd_dot(lhsVector, rhsVector) - 1) < accuracy
            || abs(simd_dot(lhsVector, -rhsVector) - 1) < accuracy
    }
}
#endif

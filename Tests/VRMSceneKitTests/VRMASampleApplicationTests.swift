import SceneKit
import simd
@testable import VRMKit
import VRMKitRuntime
import XCTest
@testable import VRMSceneKit

class VRMASampleApplicationTests: XCTestCase {

    // MARK: - Mapping helpers

    func testVRMABoneNameResolvesToHumanoidBoneByRawValue() {
        let humanoid = Humanoid<SCNNode>()
        let hips = SCNNode()
        let head = SCNNode()
        humanoid.bones[.hips] = hips
        humanoid.bones[.head] = head

        XCTAssertTrue(humanoid.node(forVRMABone: .hips) === hips)
        XCTAssertTrue(humanoid.node(forVRMABone: .head) === head)
    }

    func testVRMABoneNameRawValueMatchesHumanoidBones() {
        XCTAssertEqual(Humanoid<Any>.Bones(rawValue: VRMA.BoneName.hips.rawValue), .hips)
        XCTAssertEqual(Humanoid<Any>.Bones(rawValue: VRMA.BoneName.head.rawValue), .head)
        XCTAssertEqual(Humanoid<Any>.Bones(rawValue: VRMA.BoneName.leftThumbMetacarpal.rawValue), .leftThumbMetacarpal)
        XCTAssertEqual(Humanoid<Any>.Bones(rawValue: VRMA.BoneName.leftUpperArm.rawValue), .leftUpperArm)
    }

    func testHumanoidNodeReturnsNilForUnmappedBone() {
        let humanoid = Humanoid<SCNNode>()
        XCTAssertNil(humanoid.node(forVRMABone: .leftUpperArm))
    }

    func testExpressionKeyPrefersPreset() {
        XCTAssertEqual(ExpressionPreset.expressionKey(for: "happy"), .preset(.happy))
        XCTAssertEqual(ExpressionPreset.expressionKey(for: "blinkLeft"), .preset(.blinkLeft))
        XCTAssertEqual(ExpressionPreset.expressionKey(for: "surprised"), .preset(.surprised))
    }

    func testExpressionKeyFallsBackToCustom() {
        XCTAssertEqual(ExpressionPreset.expressionKey(for: "smile"), .custom("smile"))
        XCTAssertEqual(ExpressionPreset.expressionKey(for: "mouthOpen"), .custom("mouthOpen"))
    }

    func testVector4ToSimdQuaternion() {
        let vector = GLTF.Vector4(x: 0, y: 0, z: 1, w: 0)
        let quaternion = vector.simdQuaternion
        XCTAssertEqual(quaternion.vector.x, 0, accuracy: 1e-6)
        XCTAssertEqual(quaternion.vector.y, 0, accuracy: 1e-6)
        XCTAssertEqual(quaternion.vector.z, 1, accuracy: 1e-6)
        XCTAssertEqual(quaternion.vector.w, 0, accuracy: 1e-6)
    }

    // MARK: - Renderer smoke test

    func testApplySampleSetsHumanoidLocalRotationAndHipsTranslation() throws {
        let node = try loadVRM()
        let sample = VRMASample(
            humanoidRotations: [
                .hips: GLTF.Vector4(x: 0, y: 1, z: 0, w: 0),
                .head: GLTF.Vector4(x: 0, y: 0, z: 0, w: 1)
            ],
            hipsTranslation: GLTF.Vector3(x: 0.1, y: 0.2, z: 0.3),
            expressionWeights: [:],
            lookAtRotation: nil
        )

        let hips = try XCTUnwrap(node.humanoid.node(forVRMABone: .hips))
        let head = try XCTUnwrap(node.humanoid.node(forVRMABone: .head))

        node.apply(vrmaSample: sample)

        let hipsRotation = hips.utx.localRotation
        XCTAssertEqual(hipsRotation.vector.x, 0, accuracy: 1e-6)
        XCTAssertEqual(hipsRotation.vector.y, 1, accuracy: 1e-6)
        XCTAssertEqual(hipsRotation.vector.z, 0, accuracy: 1e-6)
        XCTAssertEqual(hipsRotation.vector.w, 0, accuracy: 1e-6)

        let headRotation = head.utx.localRotation
        XCTAssertEqual(headRotation.vector.x, 0, accuracy: 1e-6)
        XCTAssertEqual(headRotation.vector.y, 0, accuracy: 1e-6)
        XCTAssertEqual(headRotation.vector.z, 0, accuracy: 1e-6)
        XCTAssertEqual(headRotation.vector.w, 1, accuracy: 1e-6)

        let hipsPosition = hips.utx.localPosition
        XCTAssertEqual(hipsPosition.x, 0.1, accuracy: 1e-6)
        XCTAssertEqual(hipsPosition.y, 0.2, accuracy: 1e-6)
        XCTAssertEqual(hipsPosition.z, 0.3, accuracy: 1e-6)
    }

    func testApplySampleLeavesRootTransformUnchanged() throws {
        let node = try loadVRM()
        let rootPosition = node.simdPosition
        let rootRotation = node.simdOrientation
        let rootScale = node.simdScale

        let sample = VRMASample(
            humanoidRotations: [.head: GLTF.Vector4(x: 0, y: 0, z: 1, w: 0)],
            hipsTranslation: nil,
            expressionWeights: [:],
            lookAtRotation: nil
        )
        node.apply(vrmaSample: sample)

        XCTAssertEqual(node.simdPosition.x, rootPosition.x, accuracy: 1e-6)
        XCTAssertEqual(node.simdPosition.y, rootPosition.y, accuracy: 1e-6)
        XCTAssertEqual(node.simdPosition.z, rootPosition.z, accuracy: 1e-6)
        XCTAssertEqual(node.simdOrientation.vector.x, rootRotation.vector.x, accuracy: 1e-6)
        XCTAssertEqual(node.simdOrientation.vector.y, rootRotation.vector.y, accuracy: 1e-6)
        XCTAssertEqual(node.simdOrientation.vector.z, rootRotation.vector.z, accuracy: 1e-6)
        XCTAssertEqual(node.simdOrientation.vector.w, rootRotation.vector.w, accuracy: 1e-6)
        XCTAssertEqual(node.simdScale.x, rootScale.x, accuracy: 1e-6)
        XCTAssertEqual(node.simdScale.y, rootScale.y, accuracy: 1e-6)
        XCTAssertEqual(node.simdScale.z, rootScale.z, accuracy: 1e-6)
    }

    func testApplySampleWithRetargetingPreservesTargetRestRotation() throws {
        let node = try loadVRM()
        let head = try XCTUnwrap(node.humanoid.node(forVRMABone: .head))
        let targetRestRotation = simd_quatf(angle: 0.35, axis: SIMD3<Float>(0, 0, 1))
        head.utx.localRotation = targetRestRotation

        let clip = VRMAClip(
            name: nil,
            duration: 0,
            channels: [],
            sourceRestLocalRotations: [.head: .identity],
            sourceRestWorldRotations: [.head: .identity]
        )
        let context = node.makeVRMARetargetingContext(for: clip)
        head.utx.localRotation = simd_quatf(angle: -0.5, axis: SIMD3<Float>(0, 1, 0))

        let sample = VRMASample(
            humanoidRotations: [.head: .identity],
            hipsTranslation: nil,
            expressionWeights: [:],
            lookAtRotation: nil
        )
        node.apply(vrmaSample: sample, retargetingContext: context)

        XCTAssertQuaternionEqual(head.utx.localRotation, targetRestRotation)
    }

    func testRetargetingContextIgnoresAvatarRootRotation() throws {
        let node = try loadVRM()
        let head = try XCTUnwrap(node.humanoid.node(forVRMABone: .head))
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

        let identityRootContext = node.makeVRMARetargetingContext(for: clip)
        node.simdOrientation = simd_quatf(angle: 0.5, axis: SIMD3<Float>(0, 1, 0))
        let rotatedRootContext = node.makeVRMARetargetingContext(for: clip)

        node.apply(vrmaSample: sample, retargetingContext: identityRootContext)
        let identityRootRotation = head.utx.localRotation
        node.apply(vrmaSample: sample, retargetingContext: rotatedRootContext)
        let rotatedRootRotation = head.utx.localRotation

        XCTAssertQuaternionEqual(rotatedRootRotation, identityRootRotation)
    }

    func loadVRM() throws -> VRMNode {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "AliciaSolid", withExtension: "vrm"))
        let data = try Data(contentsOf: url)
        let loader = try VRMSceneLoader(withData: data)
        return try loader.loadScene().vrmNode
    }

    private func XCTAssertQuaternionEqual(_ lhs: simd_quatf,
                                          _ rhs: simd_quatf,
                                          accuracy: Float = 1e-5,
                                          file: StaticString = #filePath,
                                          line: UInt = #line) {
        let lhsVector = simd_normalize(lhs.vector)
        let rhsVector = simd_normalize(rhs.vector)
        let dot = abs(simd_dot(lhsVector, rhsVector))
        XCTAssertEqual(dot, 1, accuracy: accuracy, file: file, line: line)
    }
}

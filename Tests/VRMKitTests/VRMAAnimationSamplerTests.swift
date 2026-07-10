import XCTest
@testable import VRMKit

class VRMAAnimationSamplerTests: XCTestCase {

    func testLinearScalarSampling() {
        let keyframes: [VRMAClip.Keyframe<Float>] = [
            VRMAClip.Keyframe(time: 0, value: 0),
            VRMAClip.Keyframe(time: 1, value: 10)
        ]
        let sampled = VRMAClip.Keyframes.scalar(keyframes).sampleScalar(at: 0.5, interpolation: .LINEAR)
        XCTAssertEqual(sampled, 5, accuracy: 1e-6)
    }

    func testLinearScalarSamplingFindsInteriorInterval() {
        let keyframes: [VRMAClip.Keyframe<Float>] = [
            VRMAClip.Keyframe(time: 0, value: 0),
            VRMAClip.Keyframe(time: 1, value: 10),
            VRMAClip.Keyframe(time: 3, value: 30)
        ]
        let sampled = VRMAClip.Keyframes.scalar(keyframes).sampleScalar(at: 2, interpolation: .LINEAR)
        XCTAssertEqual(sampled, 20, accuracy: 1e-6)
    }

    func testStepScalarSampling() {
        let keyframes: [VRMAClip.Keyframe<Float>] = [
            VRMAClip.Keyframe(time: 0, value: 0),
            VRMAClip.Keyframe(time: 1, value: 10)
        ]
        let sampled = VRMAClip.Keyframes.scalar(keyframes).sampleScalar(at: 0.99, interpolation: .STEP)
        XCTAssertEqual(sampled, 0, accuracy: 1e-6)
    }

    func testLinearVector3Sampling() {
        let keyframes: [VRMAClip.Keyframe<GLTF.Vector3>] = [
            VRMAClip.Keyframe(time: 0, value: GLTF.Vector3(x: 0, y: 0, z: 0)),
            VRMAClip.Keyframe(time: 1, value: GLTF.Vector3(x: 1, y: 2, z: 3))
        ]
        let sampled = VRMAClip.Keyframes.vector3(keyframes).sampleVector3(at: 0.5, interpolation: .LINEAR)
        XCTAssertEqual(sampled.x, 0.5, accuracy: 1e-6)
        XCTAssertEqual(sampled.y, 1.0, accuracy: 1e-6)
        XCTAssertEqual(sampled.z, 1.5, accuracy: 1e-6)
    }

    func testQuaternionSamplingNormalizesInterpolatedResult() {
        let q0 = GLTF.Vector4(x: 1, y: 0, z: 0, w: 0)
        let q1 = GLTF.Vector4(x: 0, y: 0, z: 0, w: 1)
        let keyframes: [VRMAClip.Keyframe<GLTF.Vector4>] = [
            VRMAClip.Keyframe(time: 0, value: q0),
            VRMAClip.Keyframe(time: 1, value: q1)
        ]
        let sampled = VRMAClip.Keyframes.quaternion(keyframes).sampleQuaternion(at: 0.5, interpolation: .LINEAR)
        XCTAssertEqual(Self.length(of: sampled), 1.0, accuracy: 1e-6)
        XCTAssertEqual(sampled.x, 1.0 / sqrt(2), accuracy: 1e-6)
        XCTAssertEqual(sampled.w, 1.0 / sqrt(2), accuracy: 1e-6)
    }

    func testClipBuildsFromFixtureAndSamplesWithinDuration() throws {
        let bundle = Bundle.module
        let url = bundle.url(forResource: "VRMA/001_motion_pose", withExtension: "vrma")!
        let vrma = try VRMA(data: Data(contentsOf: url))
        let clip = try VRMAClip(from: vrma)
        XCTAssertGreaterThan(clip.duration, 0)

        if let hipsTranslation = clip.channels.first(where: {
            if case .node(_, path: .translation) = $0.target { return true }
            return false
        }) {
            let value = hipsTranslation.keyframes.sampleVector3(at: 0, interpolation: hipsTranslation.interpolation)
            XCTAssertTrue(value.x.isFinite && value.y.isFinite && value.z.isFinite)
        } else {
            XCTFail(" hips translation channel missing")
        }

        if let firstRotation = clip.channels.first(where: {
            if case .node(_, path: .rotation) = $0.target { return true }
            return false
        }) {
            let value = firstRotation.keyframes.sampleQuaternion(at: 0, interpolation: firstRotation.interpolation)
            XCTAssertEqual(Self.length(of: value), 1.0, accuracy: 1e-4)
        } else {
            XCTFail(" rotation channel missing")
        }
    }

    func testSampleClampsBeforeFirstAndAfterLastKeyframe() {
        let keyframes: [VRMAClip.Keyframe<Float>] = [
            VRMAClip.Keyframe(time: 1, value: 5),
            VRMAClip.Keyframe(time: 2, value: 10)
        ]
        let samples = VRMAClip.Keyframes.scalar(keyframes)
        let before = samples.sampleScalar(at: 0, interpolation: .LINEAR)
        let after = samples.sampleScalar(at: 3, interpolation: .LINEAR)
        XCTAssertEqual(before, 5, accuracy: 1e-6)
        XCTAssertEqual(after, 10, accuracy: 1e-6)
    }

    private static func length(of vector: GLTF.Vector4) -> Float {
        return sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z + vector.w * vector.w)
    }
}

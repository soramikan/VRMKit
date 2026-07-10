import XCTest
@testable import VRMKit

class VRMAEvaluationTests: XCTestCase {

    // MARK: - Expression evaluation

    func testExpressionWeightSamplesTranslationXAndClamps() throws {
        let input = [Float](arrayLiteral: 0, 1)
        let output = [Float](arrayLiteral: 0, 0, 0, 1.5, 0, 0)
        let bin = Self.floatData(input + output)
        let data = try makeVRMAData(
            json: [
                "asset": ["version": "2.0"],
                "nodes": Self.emptyNodes(count: 16),
                "buffers": [["byteLength": bin.count]],
                "bufferViews": [
                    ["buffer": 0, "byteOffset": 0, "byteLength": input.count * 4],
                    ["buffer": 0, "byteOffset": input.count * 4, "byteLength": output.count * 4]
                ],
                "accessors": [
                    ["bufferView": 0, "componentType": 5126, "count": input.count, "type": "SCALAR"],
                    ["bufferView": 1, "componentType": 5126, "count": 2, "type": "VEC3"]
                ],
                "animations": [[
                    "samplers": [["input": 0, "output": 1, "interpolation": "LINEAR"]],
                    "channels": [["sampler": 0, "target": ["node": 15, "path": "translation"]]]
                ]],
                "extensions": [
                    "VRMC_vrm_animation": [
                        "specVersion": "1.0",
                        "humanoid": ["humanBones": Self.requiredHumanBones()],
                        "expressions": [
                            "preset": [
                                "happy": ["node": 15]
                            ]
                        ]
                    ]
                ]
            ],
            bin: bin
        )
        let vrma = try VRMA(data: data)
        let clip = try VRMAClip(from: vrma)
        let sample = clip.evaluate(at: 0.5)
        XCTAssertEqual(try XCTUnwrap(sample.expressionWeights["happy"]), 0.75, accuracy: 1e-6)

        let clamped = clip.evaluate(at: 1.0)
        XCTAssertEqual(try XCTUnwrap(clamped.expressionWeights["happy"]), 1.0, accuracy: 1e-6)
    }

    func testCustomExpressionNameIsSampled() throws {
        let input = [Float](arrayLiteral: 0, 1)
        let output = [Float](arrayLiteral: 0, 0, 0, 0.8, 0, 0)
        let bin = Self.floatData(input + output)
        let data = try makeVRMAData(
            json: [
                "asset": ["version": "2.0"],
                "nodes": Self.emptyNodes(count: 16),
                "buffers": [["byteLength": bin.count]],
                "bufferViews": [
                    ["buffer": 0, "byteOffset": 0, "byteLength": input.count * 4],
                    ["buffer": 0, "byteOffset": input.count * 4, "byteLength": output.count * 4]
                ],
                "accessors": [
                    ["bufferView": 0, "componentType": 5126, "count": input.count, "type": "SCALAR"],
                    ["bufferView": 1, "componentType": 5126, "count": 2, "type": "VEC3"]
                ],
                "animations": [[
                    "samplers": [["input": 0, "output": 1, "interpolation": "LINEAR"]],
                    "channels": [["sampler": 0, "target": ["node": 15, "path": "translation"]]]
                ]],
                "extensions": [
                    "VRMC_vrm_animation": [
                        "specVersion": "1.0",
                        "humanoid": ["humanBones": Self.requiredHumanBones()],
                        "expressions": [
                            "custom": [
                                "smile": ["node": 15]
                            ]
                        ]
                    ]
                ]
            ],
            bin: bin
        )
        let vrma = try VRMA(data: data)
        let clip = try VRMAClip(from: vrma)
        let sample = clip.evaluate(at: 0.5)
        XCTAssertEqual(try XCTUnwrap(sample.expressionWeights["smile"]), 0.4, accuracy: 1e-6)
    }

    // MARK: - LookAt evaluation

    func testLookAtRotationIsSampled() throws {
        let input = [Float](arrayLiteral: 0, 1)
        let q0 = [Float](arrayLiteral: 0, 0, 0, 1)
        let q1 = [Float](arrayLiteral: 0, 0, 1, 0)
        let output = q0 + q1
        let bin = Self.floatData(input + output)
        let data = try makeVRMAData(
            json: [
                "asset": ["version": "2.0"],
                "nodes": Self.emptyNodes(count: 16),
                "buffers": [["byteLength": bin.count]],
                "bufferViews": [
                    ["buffer": 0, "byteOffset": 0, "byteLength": input.count * 4],
                    ["buffer": 0, "byteOffset": input.count * 4, "byteLength": output.count * 4]
                ],
                "accessors": [
                    ["bufferView": 0, "componentType": 5126, "count": input.count, "type": "SCALAR"],
                    ["bufferView": 1, "componentType": 5126, "count": 2, "type": "VEC4"]
                ],
                "animations": [[
                    "samplers": [["input": 0, "output": 1, "interpolation": "LINEAR"]],
                    "channels": [["sampler": 0, "target": ["node": 15, "path": "rotation"]]]
                ]],
                "extensions": [
                    "VRMC_vrm_animation": [
                        "specVersion": "1.0",
                        "humanoid": ["humanBones": Self.requiredHumanBones()],
                        "lookAt": ["node": 15]
                    ]
                ]
            ],
            bin: bin
        )
        let vrma = try VRMA(data: data)
        let clip = try VRMAClip(from: vrma)
        let sample = clip.evaluate(at: 0.5)
        let rotation = try XCTUnwrap(sample.lookAtRotation)
        XCTAssertEqual(rotation.x, 0, accuracy: 1e-6)
        XCTAssertEqual(rotation.y, 0, accuracy: 1e-6)
        XCTAssertEqual(rotation.z, 1.0 / sqrt(2), accuracy: 1e-6)
        XCTAssertEqual(rotation.w, 1.0 / sqrt(2), accuracy: 1e-6)
        XCTAssertEqual(Self.length(of: rotation), 1.0, accuracy: 1e-6)
    }

    // MARK: - Humanoid evaluation

    func testHumanoidRotationsAreKeyedByBoneName() throws {
        let input = [Float](arrayLiteral: 0, 1)
        let qHips0 = [Float](arrayLiteral: 0, 0, 0, 1)
        let qHips1 = [Float](arrayLiteral: 0, 1, 0, 0)
        let qHead0 = [Float](arrayLiteral: 0, 0, 0, 1)
        let qHead1 = [Float](arrayLiteral: 0, 0, 0, 1)
        let hipsOutput = qHips0 + qHips1
        let headOutput = qHead0 + qHead1
        let output = hipsOutput + headOutput
        let bin = Self.floatData(input + output)
        let data = try makeVRMAData(
            json: [
                "asset": ["version": "2.0"],
                "nodes": Self.emptyNodes(count: 16),
                "buffers": [["byteLength": bin.count]],
                "bufferViews": [
                    ["buffer": 0, "byteOffset": 0, "byteLength": input.count * 4],
                    ["buffer": 0, "byteOffset": input.count * 4, "byteLength": output.count * 4]
                ],
                "accessors": [
                    ["bufferView": 0, "componentType": 5126, "count": input.count, "type": "SCALAR"],
                    ["bufferView": 1, "componentType": 5126, "count": 2, "type": "VEC4"],
                    ["bufferView": 1, "componentType": 5126, "byteOffset": hipsOutput.count * 4, "count": 2, "type": "VEC4"]
                ],
                "animations": [[
                    "samplers": [
                        ["input": 0, "output": 1, "interpolation": "LINEAR"],
                        ["input": 0, "output": 2, "interpolation": "LINEAR"]
                    ],
                    "channels": [
                        ["sampler": 0, "target": ["node": 0, "path": "rotation"]],
                        ["sampler": 1, "target": ["node": 2, "path": "rotation"]]
                    ]
                ]],
                "extensions": [
                    "VRMC_vrm_animation": [
                        "specVersion": "1.0",
                        "humanoid": ["humanBones": Self.requiredHumanBones()]
                    ]
                ]
            ],
            bin: bin
        )
        let vrma = try VRMA(data: data)
        let clip = try VRMAClip(from: vrma)
        let sample = clip.evaluate(at: 0.5)
        XCTAssertTrue(sample.humanoidRotations.keys.contains(.hips))
        XCTAssertTrue(sample.humanoidRotations.keys.contains(.head))
        let hipsRotation = try XCTUnwrap(sample.humanoidRotations[.hips])
        XCTAssertEqual(hipsRotation.y, 1.0 / sqrt(2), accuracy: 1e-6)
        XCTAssertEqual(hipsRotation.w, 1.0 / sqrt(2), accuracy: 1e-6)
    }

    func testHipsTranslationIsSampled() throws {
        let input = [Float](arrayLiteral: 0, 1)
        let output = [Float](arrayLiteral: 0, 0, 0, 1, 2, 3)
        let bin = Self.floatData(input + output)
        let data = try makeVRMAData(
            json: [
                "asset": ["version": "2.0"],
                "nodes": Self.emptyNodes(count: 16),
                "buffers": [["byteLength": bin.count]],
                "bufferViews": [
                    ["buffer": 0, "byteOffset": 0, "byteLength": input.count * 4],
                    ["buffer": 0, "byteOffset": input.count * 4, "byteLength": output.count * 4]
                ],
                "accessors": [
                    ["bufferView": 0, "componentType": 5126, "count": input.count, "type": "SCALAR"],
                    ["bufferView": 1, "componentType": 5126, "count": 2, "type": "VEC3"]
                ],
                "animations": [[
                    "samplers": [["input": 0, "output": 1, "interpolation": "LINEAR"]],
                    "channels": [["sampler": 0, "target": ["node": 0, "path": "translation"]]]
                ]],
                "extensions": [
                    "VRMC_vrm_animation": [
                        "specVersion": "1.0",
                        "humanoid": ["humanBones": Self.requiredHumanBones()]
                    ]
                ]
            ],
            bin: bin
        )
        let vrma = try VRMA(data: data)
        let clip = try VRMAClip(from: vrma)
        let sample = clip.evaluate(at: 0.5)
        let translation = try XCTUnwrap(sample.hipsTranslation)
        XCTAssertEqual(translation.x, 0.5, accuracy: 1e-6)
        XCTAssertEqual(translation.y, 1.0, accuracy: 1e-6)
        XCTAssertEqual(translation.z, 1.5, accuracy: 1e-6)
    }

    // MARK: - CUBICSPLINE sampling

    func testCubicSplineScalarSampling() {
        let keyframes: [VRMAClip.Keyframe<Float>] = [
            VRMAClip.Keyframe(time: 0, value: 0, inTangent: 0, outTangent: 0),
            VRMAClip.Keyframe(time: 1, value: 1, inTangent: 0, outTangent: 0)
        ]
        let sampled = VRMAClip.Keyframes.scalar(keyframes).sampleScalar(at: 0.5, interpolation: .CUBICSPLINE)
        XCTAssertEqual(sampled, 0.5, accuracy: 1e-6)
    }

    func testCubicSplineSamplingScalesTangentsByKeyframeDuration() {
        let keyframes: [VRMAClip.Keyframe<Float>] = [
            VRMAClip.Keyframe(time: 0, value: 0, inTangent: 0, outTangent: 1),
            VRMAClip.Keyframe(time: 2, value: 0, inTangent: 0, outTangent: 0)
        ]
        let sampled = VRMAClip.Keyframes.scalar(keyframes).sampleScalar(at: 1, interpolation: .CUBICSPLINE)
        XCTAssertEqual(sampled, 0.25, accuracy: 1e-6)
    }

    func testCubicSplineVector3Sampling() throws {
        let input = [Float](arrayLiteral: 0, 1)
        let v0 = [Float](arrayLiteral: 0, 0, 0)
        let v1 = [Float](arrayLiteral: 1, 2, 3)
        let zero = [Float](arrayLiteral: 0, 0, 0)
        let output = zero + v0 + zero + zero + v1 + zero
        let bin = Self.floatData(input + output)
        let data = try makeVRMAData(
            json: [
                "asset": ["version": "2.0"],
                "nodes": Self.emptyNodes(count: 16),
                "buffers": [["byteLength": bin.count]],
                "bufferViews": [
                    ["buffer": 0, "byteOffset": 0, "byteLength": input.count * 4],
                    ["buffer": 0, "byteOffset": input.count * 4, "byteLength": output.count * 4]
                ],
                "accessors": [
                    ["bufferView": 0, "componentType": 5126, "count": input.count, "type": "SCALAR"],
                    ["bufferView": 1, "componentType": 5126, "count": 6, "type": "VEC3"]
                ],
                "animations": [[
                    "samplers": [["input": 0, "output": 1, "interpolation": "CUBICSPLINE"]],
                    "channels": [["sampler": 0, "target": ["node": 0, "path": "translation"]]]
                ]],
                "extensions": [
                    "VRMC_vrm_animation": [
                        "specVersion": "1.0",
                        "humanoid": ["humanBones": Self.requiredHumanBones()]
                    ]
                ]
            ],
            bin: bin
        )
        let vrma = try VRMA(data: data)
        let clip = try VRMAClip(from: vrma)
        let sample = clip.evaluate(at: 0.5)
        let translation = try XCTUnwrap(sample.hipsTranslation)
        XCTAssertEqual(translation.x, 0.5, accuracy: 1e-6)
        XCTAssertEqual(translation.y, 1.0, accuracy: 1e-6)
        XCTAssertEqual(translation.z, 1.5, accuracy: 1e-6)
    }

    func testCubicSplineQuaternionSamplingNormalizes() throws {
        let input = [Float](arrayLiteral: 0, 1)
        let q0 = [Float](arrayLiteral: 1, 0, 0, 0)
        let q1 = [Float](arrayLiteral: 0, 0, 0, 1)
        let zero = [Float](arrayLiteral: 0, 0, 0, 0)
        let output = zero + q0 + zero + zero + q1 + zero
        let bin = Self.floatData(input + output)
        let data = try makeVRMAData(
            json: [
                "asset": ["version": "2.0"],
                "nodes": Self.emptyNodes(count: 16),
                "buffers": [["byteLength": bin.count]],
                "bufferViews": [
                    ["buffer": 0, "byteOffset": 0, "byteLength": input.count * 4],
                    ["buffer": 0, "byteOffset": input.count * 4, "byteLength": output.count * 4]
                ],
                "accessors": [
                    ["bufferView": 0, "componentType": 5126, "count": input.count, "type": "SCALAR"],
                    ["bufferView": 1, "componentType": 5126, "count": 6, "type": "VEC4"]
                ],
                "animations": [[
                    "samplers": [["input": 0, "output": 1, "interpolation": "CUBICSPLINE"]],
                    "channels": [["sampler": 0, "target": ["node": 15, "path": "rotation"]]]
                ]],
                "extensions": [
                    "VRMC_vrm_animation": [
                        "specVersion": "1.0",
                        "humanoid": ["humanBones": Self.requiredHumanBones()],
                        "lookAt": ["node": 15]
                    ]
                ]
            ],
            bin: bin
        )
        let vrma = try VRMA(data: data)
        let clip = try VRMAClip(from: vrma)
        let sample = clip.evaluate(at: 0.5)
        let rotation = try XCTUnwrap(sample.lookAtRotation)
        XCTAssertEqual(rotation.x, 1.0 / sqrt(2), accuracy: 1e-6)
        XCTAssertEqual(rotation.y, 0, accuracy: 1e-6)
        XCTAssertEqual(rotation.z, 0, accuracy: 1e-6)
        XCTAssertEqual(rotation.w, 1.0 / sqrt(2), accuracy: 1e-6)
        XCTAssertEqual(Self.length(of: rotation), 1.0, accuracy: 1e-6)
    }

    // MARK: - Time clamping

    func testEvaluateClampsTimeToDuration() throws {
        let input = [Float](arrayLiteral: 0, 1)
        let output = [Float](arrayLiteral: 0, 0, 0, 1, 0, 0)
        let bin = Self.floatData(input + output)
        let data = try makeVRMAData(
            json: [
                "asset": ["version": "2.0"],
                "nodes": Self.emptyNodes(count: 16),
                "buffers": [["byteLength": bin.count]],
                "bufferViews": [
                    ["buffer": 0, "byteOffset": 0, "byteLength": input.count * 4],
                    ["buffer": 0, "byteOffset": input.count * 4, "byteLength": output.count * 4]
                ],
                "accessors": [
                    ["bufferView": 0, "componentType": 5126, "count": input.count, "type": "SCALAR"],
                    ["bufferView": 1, "componentType": 5126, "count": 2, "type": "VEC3"]
                ],
                "animations": [[
                    "samplers": [["input": 0, "output": 1, "interpolation": "LINEAR"]],
                    "channels": [["sampler": 0, "target": ["node": 15, "path": "translation"]]]
                ]],
                "extensions": [
                    "VRMC_vrm_animation": [
                        "specVersion": "1.0",
                        "humanoid": ["humanBones": Self.requiredHumanBones()],
                        "expressions": [
                            "preset": ["happy": ["node": 15]]
                        ]
                    ]
                ]
            ],
            bin: bin
        )
        let vrma = try VRMA(data: data)
        let clip = try VRMAClip(from: vrma)
        XCTAssertEqual(try XCTUnwrap(clip.evaluate(at: -1).expressionWeights["happy"]), 0, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(clip.evaluate(at: 2).expressionWeights["happy"]), 1, accuracy: 1e-6)
    }
}

private extension VRMAEvaluationTests {
    static func emptyNodes(count: Int) -> [[String: Any]] {
        return (0..<count).map { _ in [String: Any]() }
    }

    static func requiredHumanBones(overrides: [String: Int] = [:]) -> [String: [String: Int]] {
        let names = [
            "hips", "spine", "head",
            "leftUpperLeg", "leftLowerLeg", "leftFoot",
            "rightUpperLeg", "rightLowerLeg", "rightFoot",
            "leftUpperArm", "leftLowerArm", "leftHand",
            "rightUpperArm", "rightLowerArm", "rightHand"
        ]
        return names.enumerated().reduce(into: overrides.reduce(into: [String: [String: Int]]()) { result, pair in
            result[pair.key] = ["node": pair.value]
        }) { result, pair in
            let (index, name) = pair
            result[name] = result[name] ?? ["node": index]
        }
    }

    static func floatData(_ values: [Float]) -> Data {
        return values.reduce(into: Data()) { data, value in
            var value = value
            Swift.withUnsafeBytes(of: &value) {
                data.append(contentsOf: $0)
            }
        }
    }

    static func length(of vector: GLTF.Vector4) -> Float {
        return sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z + vector.w * vector.w)
    }

    func makeVRMAData(json: [String: Any], bin: Data = Data()) throws -> Data {
        let jsonData = try JSONSerialization.data(withJSONObject: json)
        let padding = (4 - jsonData.count % 4) % 4
        let paddedJSON = jsonData + Data(repeating: 0x20, count: padding)
        let binPadding = (4 - bin.count % 4) % 4
        let binChunk = bin + Data(repeating: 0, count: binPadding)
        let totalLength = 12 + 8 + paddedJSON.count + 8 + binChunk.count

        var data = Data()
        data.append(uInt32: 0x46546C67)
        data.append(uInt32: 2)
        data.append(uInt32: UInt32(totalLength))
        data.append(uInt32: UInt32(paddedJSON.count))
        data.append(uInt32: 0x4E4F534A)
        data.append(paddedJSON)
        data.append(uInt32: UInt32(binChunk.count))
        data.append(uInt32: 0x004E4942)
        data.append(binChunk)
        return data
    }
}

private extension Data {
    mutating func append(uInt32 value: UInt32) {
        var value = value.littleEndian
        Swift.withUnsafeBytes(of: &value) {
            append(contentsOf: $0)
        }
    }
}

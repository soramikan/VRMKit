import XCTest
@testable import VRMKit

class VRMAParserTests: XCTestCase {

    private func fixtureURLs() throws -> [URL] {
        let bundle = Bundle.module
        let directory = try XCTUnwrap(bundle.url(forResource: "VRMA", withExtension: nil))
        return try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "vrma" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func testAllFixturesLoadAsGLB() throws {
        let fixtureURLs = try fixtureURLs()
        XCTAssertEqual(fixtureURLs.count, 8)
        for url in fixtureURLs {
            XCTAssertNoThrow(try BinaryGLTF(data: Data(contentsOf: url)), "Failed to load \(url.lastPathComponent)")
        }
    }

    func testExtensionKeyAndSpecVersion() throws {
        for url in try fixtureURLs() {
            let vrma = try VRMA(data: Data(contentsOf: url))
            XCTAssertEqual(vrma.specVersion, "1.0", url.lastPathComponent)
        }
    }

    func testHumanoidMappingCount() throws {
        for url in try fixtureURLs() {
            let vrma = try VRMA(data: Data(contentsOf: url))
            let humanoid = try XCTUnwrap(vrma.humanoid, url.lastPathComponent)
            XCTAssertEqual(humanoid.humanBones.count, 51, url.lastPathComponent)
        }
    }

    func testFirstAnimationExistsAndChannelsClassify() throws {
        for url in try fixtureURLs() {
            let vrma = try VRMA(data: Data(contentsOf: url))
            let clip = try VRMAClip(from: vrma)
            XCTAssertFalse(clip.channels.isEmpty, url.lastPathComponent)

            let translationChannels = clip.channels.filter {
                if case .node(_, path: .translation) = $0.target { return true }
                return false
            }
            let rotationChannels = clip.channels.filter {
                if case .node(_, path: .rotation) = $0.target { return true }
                return false
            }
            XCTAssertEqual(translationChannels.count, 1, url.lastPathComponent)
            XCTAssertEqual(rotationChannels.count, 51, url.lastPathComponent)

            let hipsTranslation = translationChannels.first
            if case .node(let node, path: .translation) = hipsTranslation?.target {
                XCTAssertEqual(node, 0, url.lastPathComponent)
            } else {
                XCTFail("Expected single hips translation channel in \(url.lastPathComponent)")
            }
        }
    }

    func testLoaderAPI() throws {
        let loader = VRMAAnimationLoader()
        for url in try fixtureURLs() {
            let vrma = try loader.load(withURL: url)
            let clip = try loader.loadClip(from: vrma)
            XCTAssertGreaterThan(clip.duration, 0, url.lastPathComponent)
        }
    }

    func testGLTFNodeRotationDefaultsToIdentity() throws {
        let node = try JSONDecoder().decode(GLTF.Node.self, from: Data("{}".utf8))
        XCTAssertEqual(node.rotation.x, 0)
        XCTAssertEqual(node.rotation.y, 0)
        XCTAssertEqual(node.rotation.z, 0)
        XCTAssertEqual(node.rotation.w, 1)
    }

    func testMissingSpecVersionFails() throws {
        let data = try makeVRMAData(json: [
            "asset": ["version": "2.0"],
            "nodes": [[:]],
            "extensions": [
                "VRMC_vrm_animation": [
                    "humanoid": ["humanBones": Self.requiredHumanBones()]
                ]
            ]
        ])
        XCTAssertThrowsError(try VRMA(data: data)) { error in
            guard case VRMError.keyNotFound(let key) = error else {
                XCTFail("Expected keyNotFound error, got \(error)")
                return
            }
            XCTAssertEqual(key, "specVersion")
        }
    }

    func testInvalidSpecVersionFails() throws {
        let data = try makeVRMAData(json: [
            "asset": ["version": "2.0"],
            "nodes": [[:]],
            "extensions": [
                "VRMC_vrm_animation": [
                    "specVersion": "2.0",
                    "humanoid": ["humanBones": Self.requiredHumanBones()]
                ]
            ]
        ])
        XCTAssertThrowsError(try VRMA(data: data)) { error in
            guard case VRMError.notSupported = error else {
                XCTFail("Expected notSupported error, got \(error)")
                return
            }
        }
    }

    func testInvalidHumanoidNodeIndexFails() throws {
        let data = try makeVRMAData(json: [
            "asset": ["version": "2.0"],
            "nodes": [[:], [:]],
            "extensions": [
                "VRMC_vrm_animation": [
                    "specVersion": "1.0",
                    "humanoid": ["humanBones": Self.requiredHumanBones(overrides: ["hips": 5])]
                ]
            ]
        ])
        XCTAssertThrowsError(try VRMA(data: data)) { error in
            guard case VRMError.dataInconsistent = error else {
                XCTFail("Expected dataInconsistent error, got \(error)")
                return
            }
        }
    }

    func testForbiddenLeftEyeHumanoidBoneFails() throws {
        let data = try makeVRMAData(json: [
            "asset": ["version": "2.0"],
            "nodes": [[:], [:]],
            "extensions": [
                "VRMC_vrm_animation": [
                    "specVersion": "1.0",
                    "humanoid": ["humanBones": Self.requiredHumanBones(overrides: ["leftEye": 1])]
                ]
            ]
        ])
        XCTAssertThrowsError(try VRMA(data: data)) { error in
            guard case VRMError.notSupported = error else {
                XCTFail("Expected notSupported error, got \(error)")
                return
            }
        }
    }

    func testForbiddenRightEyeHumanoidBoneFails() throws {
        let data = try makeVRMAData(json: [
            "asset": ["version": "2.0"],
            "nodes": [[:], [:]],
            "extensions": [
                "VRMC_vrm_animation": [
                    "specVersion": "1.0",
                    "humanoid": ["humanBones": Self.requiredHumanBones(overrides: ["rightEye": 1])]
                ]
            ]
        ])
        XCTAssertThrowsError(try VRMA(data: data)) { error in
            guard case VRMError.notSupported = error else {
                XCTFail("Expected notSupported error, got \(error)")
                return
            }
        }
    }

    func testForbiddenLookAtExpressionPresetFails() throws {
        let data = try makeVRMAData(json: [
            "asset": ["version": "2.0"],
            "nodes": [[:], [:]],
            "extensions": [
                "VRMC_vrm_animation": [
                    "specVersion": "1.0",
                    "expressions": [
                        "preset": [
                            "lookUp": ["node": 1]
                        ]
                    ]
                ]
            ]
        ])
        XCTAssertThrowsError(try VRMA(data: data)) { error in
            guard case VRMError.notSupported = error else {
                XCTFail("Expected notSupported error, got \(error)")
                return
            }
        }
    }

    func testLookAtRequiresNode() throws {
        let data = try makeVRMAData(json: [
            "asset": ["version": "2.0"],
            "nodes": [[:]],
            "extensions": [
                "VRMC_vrm_animation": [
                    "specVersion": "1.0",
                    "lookAt": [
                        "offsetFromHeadBone": [0.0, 0.0, 0.0]
                    ]
                ]
            ]
        ])
        XCTAssertThrowsError(try VRMA(data: data)) { error in
            guard case VRMError.keyNotFound(let key) = error else {
                XCTFail("Expected keyNotFound error, got \(error)")
                return
            }
            XCTAssertEqual(key, "lookAt.node")
        }
    }

    func testCustomExpressionCannotCollideWithPresetName() throws {
        let data = try makeVRMAData(json: [
            "asset": ["version": "2.0"],
            "nodes": [[:], [:]],
            "extensions": [
                "VRMC_vrm_animation": [
                    "specVersion": "1.0",
                    "expressions": [
                        "custom": [
                            "happy": ["node": 1]
                        ]
                    ]
                ]
            ]
        ])
        XCTAssertThrowsError(try VRMA(data: data)) { error in
            guard case VRMError.dataInconsistent = error else {
                XCTFail("Expected dataInconsistent error, got \(error)")
                return
            }
        }
    }

    func testHumanoidTranslationIsOnlyAllowedForHips() throws {
        let input = [Float](arrayLiteral: 0, 1)
        let output = [Float](arrayLiteral: 0, 0, 0, 0, 1, 0)
        let bin = Self.floatData(input + output)
        let data = try makeVRMAData(
            json: [
                "asset": ["version": "2.0"],
                "nodes": [[:], [:]],
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
                    "channels": [["sampler": 0, "target": ["node": 1, "path": "translation"]]]
                ]],
                "extensions": [
                    "VRMC_vrm_animation": [
                        "specVersion": "1.0",
                        "humanoid": ["humanBones": Self.requiredHumanBones(overrides: ["spine": 1])]
                    ]
                ]
            ],
            bin: bin
        )
        let vrma = try VRMA(data: data)
        XCTAssertThrowsError(try VRMAClip(from: vrma)) { error in
            guard case VRMError.notSupported = error else {
                XCTFail("Expected notSupported error, got \(error)")
                return
            }
        }
    }
}

private extension VRMAParserTests {
    static func requiredHumanBones(overrides: [String: Int] = [:]) -> [String: [String: Int]] {
        let names = [
            "hips", "spine", "head",
            "leftUpperLeg", "leftLowerLeg", "leftFoot",
            "rightUpperLeg", "rightLowerLeg", "rightFoot",
            "leftUpperArm", "leftLowerArm", "leftHand",
            "rightUpperArm", "rightLowerArm", "rightHand"
        ]
        return names.reduce(into: overrides.reduce(into: [String: [String: Int]]()) { result, pair in
            result[pair.key] = ["node": pair.value]
        }) { result, name in
            result[name] = result[name] ?? ["node": 0]
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

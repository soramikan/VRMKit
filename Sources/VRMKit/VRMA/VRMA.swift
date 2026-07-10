import Foundation

/// VRMC_vrm_animation 1.0 data.
///
/// VRMA files are glTF 2.0 assets that carry a root `VRMC_vrm_animation`
/// extension describing how the glTF nodes map to VRM humanoid bones,
/// expressions, and LookAt targets. The actual animation curves live in the
/// glTF `animations` array.
public struct VRMA {
    let gltf: BinaryGLTF
    public let specVersion: String
    public let humanoid: Humanoid?
    public let expressions: Expressions?
    public let lookAt: LookAt?
    public let extensions: CodableAny?
    public let extras: CodableAny?

    public init(data: Data) throws {
        let gltf = try BinaryGLTF(data: data)
        self.gltf = gltf
        let parsed = try Self.parseExtension(from: gltf)
        self.specVersion = parsed.specVersion
        self.humanoid = parsed.humanoid
        self.expressions = parsed.expressions
        self.lookAt = parsed.lookAt
        self.extensions = parsed.extensions
        self.extras = parsed.extras
    }
}

extension VRMA {
    public struct Humanoid: Codable {
        public let humanBones: [String: HumanBone]
        public let extensions: CodableAny?
        public let extras: CodableAny?

        /// Humanoid bones keyed by the strongly typed bone name.
        public var boneMappings: [BoneName: HumanBone] {
            return humanBones.reduce(into: [:]) { result, pair in
                guard let bone = BoneName(rawValue: pair.key) else { return }
                result[bone] = pair.value
            }
        }

        public struct HumanBone: Codable {
            public let node: Int
            public let extensions: CodableAny?
            public let extras: CodableAny?
        }
    }

    public enum BoneName: String, Codable, CaseIterable {
        case hips, spine, chest, upperChest, neck, head
        case leftEye, rightEye, jaw
        case leftUpperLeg, leftLowerLeg, leftFoot, leftToes
        case rightUpperLeg, rightLowerLeg, rightFoot, rightToes
        case leftShoulder, leftUpperArm, leftLowerArm, leftHand
        case rightShoulder, rightUpperArm, rightLowerArm, rightHand
        case leftThumbMetacarpal, leftThumbProximal, leftThumbDistal
        case leftIndexProximal, leftIndexIntermediate, leftIndexDistal
        case leftMiddleProximal, leftMiddleIntermediate, leftMiddleDistal
        case leftRingProximal, leftRingIntermediate, leftRingDistal
        case leftLittleProximal, leftLittleIntermediate, leftLittleDistal
        case rightThumbMetacarpal, rightThumbProximal, rightThumbDistal
        case rightIndexProximal, rightIndexIntermediate, rightIndexDistal
        case rightMiddleProximal, rightMiddleIntermediate, rightMiddleDistal
        case rightRingProximal, rightRingIntermediate, rightRingDistal
        case rightLittleProximal, rightLittleIntermediate, rightLittleDistal
    }
}

extension VRMA {
    public struct Expressions: Codable {
        public let preset: Preset?
        public let custom: [String: ExpressionNode]?
        public let extensions: CodableAny?
        public let extras: CodableAny?

        public struct Preset: Codable {
            public let happy: ExpressionNode?
            public let angry: ExpressionNode?
            public let sad: ExpressionNode?
            public let relaxed: ExpressionNode?
            public let surprised: ExpressionNode?
            public let aa: ExpressionNode?
            public let ih: ExpressionNode?
            public let ou: ExpressionNode?
            public let ee: ExpressionNode?
            public let oh: ExpressionNode?
            public let blink: ExpressionNode?
            public let blinkLeft: ExpressionNode?
            public let blinkRight: ExpressionNode?
            public let neutral: ExpressionNode?
        }

        public struct ExpressionNode: Codable {
            public let node: Int
            public let extensions: CodableAny?
            public let extras: CodableAny?
        }
    }
}

extension VRMA {
    public struct LookAt: Codable {
        public let node: Int?
        public let offsetFromHeadBone: [Double]?
        public let extensions: CodableAny?
        public let extras: CodableAny?
    }
}

private extension VRMA {
    struct ParsedExtension {
        let specVersion: String
        let humanoid: Humanoid?
        let expressions: Expressions?
        let lookAt: LookAt?
        let extensions: CodableAny?
        let extras: CodableAny?
    }

    static func parseExtension(from gltf: BinaryGLTF) throws -> ParsedExtension {
        let rawExtensions = try gltf.jsonData.extensions ??? .keyNotFound("extensions")
        let extensions = try rawExtensions.value as? [String: [String: Any]] ??? .dataInconsistent("extension type mismatch")
        let vrma = try extensions["VRMC_vrm_animation"] ??? .keyNotFound("VRMC_vrm_animation")

        let specVersion = try decodeSpecVersion(from: vrma)
        try validateExpressionPresetKeys(from: vrma)

        let decoder = DictionaryDecoder()
        let humanoid: Humanoid? = try {
            guard let value = vrma["humanoid"] else { return nil }
            return try decoder.decode(Humanoid.self, from: value)
        }()
        let expressions: Expressions? = try {
            guard let value = vrma["expressions"] else { return nil }
            return try decoder.decode(Expressions.self, from: value)
        }()
        let lookAt: LookAt? = try {
            guard let value = vrma["lookAt"] else { return nil }
            return try decoder.decode(LookAt.self, from: value)
        }()
        let ext: CodableAny? = try {
            guard let value = vrma["extensions"] else { return nil }
            return try decoder.decode(CodableAny.self, from: value)
        }()
        let extras: CodableAny? = try {
            guard let value = vrma["extras"] else { return nil }
            return try decoder.decode(CodableAny.self, from: value)
        }()

        let nodeCount = gltf.jsonData.nodes?.count ?? 0
        try validate(humanoid: humanoid, nodeCount: nodeCount)
        try validate(expressions: expressions, nodeCount: nodeCount)
        try validate(lookAt: lookAt, nodeCount: nodeCount)

        return ParsedExtension(
            specVersion: specVersion,
            humanoid: humanoid,
            expressions: expressions,
            lookAt: lookAt,
            extensions: ext,
            extras: extras
        )
    }

    static func decodeSpecVersion(from vrma: [String: Any]) throws -> String {
        let version = try vrma["specVersion"] as? String ??? .keyNotFound("specVersion")
        guard version == "1.0" else {
            throw VRMError.notSupported("Unsupported VRMC_vrm_animation specVersion: \(version)")
        }
        return version
    }

    static func validate(humanoid: Humanoid?, nodeCount: Int) throws {
        guard let humanoid = humanoid else { return }
        let forbiddenBones: Set<BoneName> = [.leftEye, .rightEye]
        let requiredBones: Set<BoneName> = [
            .hips, .spine, .head,
            .leftUpperLeg, .leftLowerLeg, .leftFoot,
            .rightUpperLeg, .rightLowerLeg, .rightFoot,
            .leftUpperArm, .leftLowerArm, .leftHand,
            .rightUpperArm, .rightLowerArm, .rightHand
        ]
        let mappedBones = Set(humanoid.humanBones.compactMap { BoneName(rawValue: $0.key) })
        let missingBones = requiredBones.subtracting(mappedBones)
        guard missingBones.isEmpty else {
            let names = missingBones.map(\.rawValue).sorted().joined(separator: ", ")
            throw VRMError.dataInconsistent("Missing required humanoid bones in VRMC_vrm_animation: \(names)")
        }

        for (name, bone) in humanoid.humanBones {
            if let boneName = BoneName(rawValue: name), forbiddenBones.contains(boneName) {
                throw VRMError.notSupported("Forbidden humanoid bone in VRMC_vrm_animation: \(name)")
            }
            if bone.node < 0 || bone.node >= nodeCount {
                throw VRMError.dataInconsistent("Invalid humanoid node index \(bone.node) (node count \(nodeCount))")
            }
        }
    }

    static func validate(expressions: Expressions?, nodeCount: Int) throws {
        guard let expressions = expressions else { return }
        let validPresetNames = Expressions.Preset.validPresetNames
        let allVRMExpressionPresetNames = validPresetNames.union(Expressions.Preset.lookAtPresetNames)

        if let preset = expressions.preset {
            for (_, node) in preset.expressionNodes {
                if node.node < 0 || node.node >= nodeCount {
                    throw VRMError.dataInconsistent("Invalid expression node index \(node.node) (node count \(nodeCount))")
                }
            }
        }

        if let custom = expressions.custom {
            for (name, node) in custom {
                if allVRMExpressionPresetNames.contains(name) {
                    throw VRMError.dataInconsistent("Custom expression name collides with preset: \(name)")
                }
                if node.node < 0 || node.node >= nodeCount {
                    throw VRMError.dataInconsistent("Invalid custom expression node index \(node.node) (node count \(nodeCount))")
                }
            }
        }
    }

    static func validate(lookAt: LookAt?, nodeCount: Int) throws {
        guard let lookAt = lookAt else { return }
        let node = try lookAt.node ??? .keyNotFound("lookAt.node")
        if node < 0 || node >= nodeCount {
            throw VRMError.dataInconsistent("Invalid lookAt node index \(node) (node count \(nodeCount))")
        }
        if let offset = lookAt.offsetFromHeadBone, offset.count != 3 {
            throw VRMError.dataInconsistent("Invalid lookAt offsetFromHeadBone component count \(offset.count)")
        }
    }

    static func validateExpressionPresetKeys(from vrma: [String: Any]) throws {
        guard let expressions = vrma["expressions"] as? [String: Any],
              let preset = expressions["preset"] as? [String: Any] else { return }

        for key in preset.keys {
            if Expressions.Preset.lookAtPresetNames.contains(key) {
                throw VRMError.notSupported("Forbidden expression preset in VRMC_vrm_animation: \(key)")
            }
            if !Expressions.Preset.validPresetNames.contains(key) {
                throw VRMError.dataInconsistent("Invalid expression preset name: \(key)")
            }
        }
    }
}

extension VRMA.Expressions {
    /// All expression nodes keyed by glTF node index, with preset names first so
    /// custom names can only override if a node is mapped twice (which is invalid
    /// but harmless here because the last write wins).
    var expressionNodeNames: [Int: String] {
        var result: [Int: String] = [:]
        if let preset = preset {
            for (name, node) in preset.expressionNodes {
                result[node.node] = name
            }
        }
        if let custom = custom {
            for (name, node) in custom {
                result[node.node] = name
            }
        }
        return result
    }
}

extension VRMA.Expressions.Preset {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case happy, angry, sad, relaxed, surprised
        case aa, ih, ou, ee, oh
        case blink, blinkLeft, blinkRight
        case neutral
    }

    static let validPresetNames = Set(CodingKeys.allCases.map(\.stringValue))
    static let lookAtPresetNames: Set<String> = ["lookUp", "lookDown", "lookLeft", "lookRight"]

    var expressionNodes: [(String, VRMA.Expressions.ExpressionNode)] {
        return [
            ("happy", happy),
            ("angry", angry),
            ("sad", sad),
            ("relaxed", relaxed),
            ("surprised", surprised),
            ("aa", aa),
            ("ih", ih),
            ("ou", ou),
            ("ee", ee),
            ("oh", oh),
            ("blink", blink),
            ("blinkLeft", blinkLeft),
            ("blinkRight", blinkRight),
            ("neutral", neutral)
        ].compactMap { name, node in
            guard let node = node else { return nil }
            return (name, node)
        }
    }
}

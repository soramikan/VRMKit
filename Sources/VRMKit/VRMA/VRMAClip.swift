import Foundation
import simd

/// A sampled representation of a single glTF animation, suitable for VRMA
/// inspection and playback. Defaults to the first animation in the file.
public struct VRMAClip {
    public let name: String?
    public let duration: Float
    public let channels: [Channel]

    let humanoidNodeBones: [Int: VRMA.BoneName]
    let expressionNodeNames: [Int: String]
    let lookAtNode: Int?
    package let sourceRestLocalRotations: [VRMA.BoneName: GLTF.Vector4]
    package let sourceRestWorldRotations: [VRMA.BoneName: GLTF.Vector4]

    public struct Channel {
        public let target: Target
        public let interpolation: GLTF.Animation.Sampler.Interpolation
        public let keyframes: Keyframes
    }

    public enum Target: Equatable {
        case node(Int, path: Path)
    }

    public enum Path: String, Equatable {
        case translation, rotation, scale
    }

    public enum Keyframes {
        case scalar([Keyframe<Float>])
        case vector3([Keyframe<GLTF.Vector3>])
        case quaternion([Keyframe<GLTF.Vector4>])
    }

    public struct Keyframe<T> {
        public let time: Float
        public let value: T
        public let inTangent: T?
        public let outTangent: T?

        init(time: Float, value: T, inTangent: T? = nil, outTangent: T? = nil) {
            self.time = time
            self.value = value
            self.inTangent = inTangent
            self.outTangent = outTangent
        }
    }

    init(name: String?, duration: Float, channels: [Channel], humanoidNodeBones: [Int: VRMA.BoneName] = [:], expressionNodeNames: [Int: String] = [:], lookAtNode: Int? = nil, sourceRestLocalRotations: [VRMA.BoneName: GLTF.Vector4] = [:], sourceRestWorldRotations: [VRMA.BoneName: GLTF.Vector4] = [:]) {
        self.name = name
        self.duration = duration
        self.channels = channels
        self.humanoidNodeBones = humanoidNodeBones
        self.expressionNodeNames = expressionNodeNames
        self.lookAtNode = lookAtNode
        self.sourceRestLocalRotations = sourceRestLocalRotations
        self.sourceRestWorldRotations = sourceRestWorldRotations
    }
}

public extension VRMAClip {
    init(from vrma: VRMA, animationIndex: Int = 0) throws {
        let humanoidNodeBones = vrma.humanoid?.boneMappings.reduce(into: [Int: VRMA.BoneName]()) { result, pair in
            result[pair.value.node] = pair.key
        } ?? [:]
        try self.init(
            from: vrma.gltf,
            animationIndex: animationIndex,
            humanoidNodeBones: humanoidNodeBones,
            expressionNodeNames: vrma.expressions?.expressionNodeNames ?? [:],
            lookAtNode: vrma.lookAt?.node
        )
    }
}

extension VRMAClip {
    init(from gltf: BinaryGLTF, animationIndex: Int = 0) throws {
        try self.init(from: gltf, animationIndex: animationIndex, humanoidNodeBones: [:], expressionNodeNames: [:], lookAtNode: nil)
    }
}

private extension VRMAClip {
    init(from gltf: BinaryGLTF, animationIndex: Int, humanoidNodeBones: [Int: VRMA.BoneName], expressionNodeNames: [Int: String], lookAtNode: Int?) throws {
        let animations = try gltf.jsonData.load(\.animations)
        guard animations.indices.contains(animationIndex) else {
            throw VRMError.dataInconsistent("animation index \(animationIndex) out of range")
        }
        let animation = animations[animationIndex]
        self.name = animation.name
        let nodeCount = gltf.jsonData.nodes?.count ?? 0

        var channels: [Channel] = []
        var maxTime: Float = 0

        for channel in animation.channels {
            guard animation.samplers.indices.contains(channel.sampler) else {
                throw VRMError.dataInconsistent("channel sampler index \(channel.sampler) out of range")
            }
            let sampler = animation.samplers[channel.sampler]
            let targetNode = try channel.target.node ??? .dataInconsistent("animation channel target node missing")
            let path = try Path(rawValue: channel.target.path) ??? .dataInconsistent("unknown animation path: \(channel.target.path)")
            guard targetNode >= 0 && targetNode < nodeCount else {
                throw VRMError.dataInconsistent("animation channel target node \(targetNode) out of range")
            }
            if let boneName = humanoidNodeBones[targetNode] {
                switch path {
                case .translation where boneName != .hips:
                    throw VRMError.notSupported("Humanoid bone translation is only allowed for hips in VRMC_vrm_animation: \(boneName.rawValue)")
                case .scale:
                    throw VRMError.notSupported("Humanoid bone scale animation is not supported in VRMC_vrm_animation: \(boneName.rawValue)")
                default:
                    break
                }
            }

            let times = try gltf.readScalarFloatAccessor(sampler.input)
            guard !times.isEmpty else {
                throw VRMError.dataInconsistent("animation sampler input is empty")
            }
            if let last = times.last {
                maxTime = max(maxTime, last)
            }

            let keyframes: Keyframes
            switch path {
            case .translation:
                if sampler.interpolation == .CUBICSPLINE {
                    let triplets = try gltf.readCubicVector3Accessor(sampler.output)
                    guard triplets.count == times.count else {
                        throw VRMError.dataInconsistent("CUBICSPLINE output count \(triplets.count) does not match input count \(times.count)")
                    }
                    keyframes = .vector3(zip(times, triplets).map { Keyframe(time: $0, value: $1.value, inTangent: $1.inTangent, outTangent: $1.outTangent) })
                } else {
                    let values = try gltf.readVector3FloatAccessor(sampler.output)
                    guard values.count == times.count else {
                        throw VRMError.dataInconsistent("translation output count \(values.count) does not match input count \(times.count)")
                    }
                    keyframes = .vector3(zip(times, values).map { Keyframe(time: $0, value: $1) })
                }
            case .rotation:
                if sampler.interpolation == .CUBICSPLINE {
                    let triplets = try gltf.readCubicVector4Accessor(sampler.output)
                    guard triplets.count == times.count else {
                        throw VRMError.dataInconsistent("CUBICSPLINE output count \(triplets.count) does not match input count \(times.count)")
                    }
                    keyframes = .quaternion(zip(times, triplets).map { Keyframe(time: $0, value: $1.value, inTangent: $1.inTangent, outTangent: $1.outTangent) })
                } else {
                    let values = try gltf.readVector4FloatAccessor(sampler.output)
                    guard values.count == times.count else {
                        throw VRMError.dataInconsistent("rotation output count \(values.count) does not match input count \(times.count)")
                    }
                    keyframes = .quaternion(zip(times, values).map { Keyframe(time: $0, value: $1) })
                }
            case .scale:
                throw VRMError.notSupported("scale animation is not supported for VRMC_vrm_animation")
            }

            channels.append(Channel(target: .node(targetNode, path: path), interpolation: sampler.interpolation, keyframes: keyframes))
        }

        let sourceRestRotations = Self.sourceRestRotations(from: gltf, humanoidNodeBones: humanoidNodeBones)
        self.duration = maxTime
        self.channels = channels
        self.humanoidNodeBones = humanoidNodeBones
        self.expressionNodeNames = expressionNodeNames
        self.lookAtNode = lookAtNode
        self.sourceRestLocalRotations = sourceRestRotations.local
        self.sourceRestWorldRotations = sourceRestRotations.world
    }
}

private extension VRMAClip {
    static func sourceRestRotations(from gltf: BinaryGLTF, humanoidNodeBones: [Int: VRMA.BoneName]) -> (local: [VRMA.BoneName: GLTF.Vector4], world: [VRMA.BoneName: GLTF.Vector4]) {
        guard let nodes = gltf.jsonData.nodes else {
            return ([:], [:])
        }

        var parentNodes: [Int: Int] = [:]
        for (parentIndex, node) in nodes.enumerated() {
            for childIndex in node.children ?? [] where nodes.indices.contains(childIndex) {
                parentNodes[childIndex] = parentIndex
            }
        }

        var worldCache: [Int: simd_quatf] = [:]
        func localRotation(for node: GLTF.Node) -> simd_quatf {
            if let matrix = node._matrix {
                return matrix.rotation
            }
            return node.rotation.simdQuaternion
        }

        func worldRotation(for nodeIndex: Int) -> simd_quatf {
            if let cached = worldCache[nodeIndex] {
                return cached
            }
            guard nodes.indices.contains(nodeIndex) else {
                return .vrmaIdentity
            }
            let local = localRotation(for: nodes[nodeIndex])
            let world: simd_quatf
            if let parentIndex = parentNodes[nodeIndex] {
                world = worldRotation(for: parentIndex) * local
            } else {
                world = local
            }
            worldCache[nodeIndex] = world.vrmaNormalized
            return world.vrmaNormalized
        }

        var localRotations: [VRMA.BoneName: GLTF.Vector4] = [:]
        var worldRotations: [VRMA.BoneName: GLTF.Vector4] = [:]
        for (nodeIndex, boneName) in humanoidNodeBones where nodes.indices.contains(nodeIndex) {
            localRotations[boneName] = GLTF.Vector4(localRotation(for: nodes[nodeIndex]).vrmaNormalized)
            worldRotations[boneName] = GLTF.Vector4(worldRotation(for: nodeIndex).vrmaNormalized)
        }
        return (localRotations, worldRotations)
    }
}

// MARK: - Evaluation

/// A renderer-neutral sample of a VRMC_vrm_animation clip at a specific time.
public struct VRMASample {
    /// Humanoid bone rotations keyed by strongly typed bone name.
    public let humanoidRotations: [VRMA.BoneName: GLTF.Vector4]
    /// Hips translation if the animation contains a hips translation channel.
    public let hipsTranslation: GLTF.Vector3?
    /// Expression weights for preset and custom expressions, clamped to [0, 1].
    public let expressionWeights: [String: Float]
    /// LookAt rotation quaternion sampled from the lookAt node, if present.
    public let lookAtRotation: GLTF.Vector4?
    package let sourceRestLocalRotations: [VRMA.BoneName: GLTF.Vector4]
    package let sourceRestWorldRotations: [VRMA.BoneName: GLTF.Vector4]

    public init(humanoidRotations: [VRMA.BoneName: GLTF.Vector4],
                hipsTranslation: GLTF.Vector3?,
                expressionWeights: [String: Float],
                lookAtRotation: GLTF.Vector4?) {
        self.humanoidRotations = humanoidRotations
        self.hipsTranslation = hipsTranslation
        self.expressionWeights = expressionWeights
        self.lookAtRotation = lookAtRotation
        self.sourceRestLocalRotations = [:]
        self.sourceRestWorldRotations = [:]
    }

    package init(humanoidRotations: [VRMA.BoneName: GLTF.Vector4],
                 hipsTranslation: GLTF.Vector3?,
                 expressionWeights: [String: Float],
                 lookAtRotation: GLTF.Vector4?,
                 sourceRestLocalRotations: [VRMA.BoneName: GLTF.Vector4],
                 sourceRestWorldRotations: [VRMA.BoneName: GLTF.Vector4]) {
        self.humanoidRotations = humanoidRotations
        self.hipsTranslation = hipsTranslation
        self.expressionWeights = expressionWeights
        self.lookAtRotation = lookAtRotation
        self.sourceRestLocalRotations = sourceRestLocalRotations
        self.sourceRestWorldRotations = sourceRestWorldRotations
    }
}

public extension VRMAClip {
    /// Evaluates the clip at the given time and returns a renderer-neutral pose sample.
    ///
    /// Time is clamped to the clip's duration. Values are sampled according to each
    /// channel's interpolation mode.
    func evaluate(at time: Float) -> VRMASample {
        let clippedTime = max(0, min(time, duration))
        var rotations: [VRMA.BoneName: GLTF.Vector4] = [:]
        var hipsTranslation: GLTF.Vector3?
        var expressionWeights: [String: Float] = [:]
        var lookAtRotation: GLTF.Vector4?

        let hipsNode = humanoidNodeBones.first { $0.value == .hips }?.key

        for channel in channels {
            guard case .node(let node, path: let path) = channel.target else { continue }
            switch path {
            case .rotation:
                if let bone = humanoidNodeBones[node] {
                    rotations[bone] = channel.keyframes.sampleQuaternion(at: clippedTime, interpolation: channel.interpolation)
                } else if node == lookAtNode {
                    lookAtRotation = channel.keyframes.sampleQuaternion(at: clippedTime, interpolation: channel.interpolation)
                }
            case .translation:
                if node == hipsNode {
                    hipsTranslation = channel.keyframes.sampleVector3(at: clippedTime, interpolation: channel.interpolation)
                } else if let expressionName = expressionNodeNames[node] {
                    let value = channel.keyframes.sampleVector3(at: clippedTime, interpolation: channel.interpolation)
                    expressionWeights[expressionName] = max(0, min(1, value.x))
                }
            case .scale:
                break
            }
        }

        return VRMASample(
            humanoidRotations: rotations,
            hipsTranslation: hipsTranslation,
            expressionWeights: expressionWeights,
            lookAtRotation: lookAtRotation,
            sourceRestLocalRotations: sourceRestLocalRotations,
            sourceRestWorldRotations: sourceRestWorldRotations
        )
    }
}

// MARK: - Sampling

extension VRMAClip.Keyframes {
    func sampleScalar(at time: Float, interpolation: GLTF.Animation.Sampler.Interpolation) -> Float {
        guard case .scalar(let keyframes) = self else {
            fatalError("sampleScalar called on non-scalar keyframes")
        }
        return VRMAClip.sample(keyframes: keyframes, at: time, interpolation: interpolation, lerp: { a, b, t in
            a + (b - a) * t
        }, cubic: { p0, outTangent, p1, inTangent, u, duration in
            let u2 = u * u
            let u3 = u2 * u
            return (2 * u3 - 3 * u2 + 1) * p0
                + (u3 - 2 * u2 + u) * duration * outTangent
                + (-2 * u3 + 3 * u2) * p1
                + (u3 - u2) * duration * inTangent
        })
    }

    func sampleVector3(at time: Float, interpolation: GLTF.Animation.Sampler.Interpolation) -> GLTF.Vector3 {
        guard case .vector3(let keyframes) = self else {
            fatalError("sampleVector3 called on non-vector3 keyframes")
        }
        return VRMAClip.sample(keyframes: keyframes, at: time, interpolation: interpolation, lerp: { a, b, t in
            a.lerp(to: b, t: t)
        }, cubic: { p0, outTangent, p1, inTangent, u, duration in
            GLTF.Vector3.cubicHermite(p0: p0, outTangent: outTangent, p1: p1, inTangent: inTangent, u: u, duration: duration)
        })
    }

    func sampleQuaternion(at time: Float, interpolation: GLTF.Animation.Sampler.Interpolation) -> GLTF.Vector4 {
        guard case .quaternion(let keyframes) = self else {
            fatalError("sampleQuaternion called on non-quaternion keyframes")
        }
        return VRMAClip.sample(keyframes: keyframes, at: time, interpolation: interpolation, lerp: { a, b, t in
            a.lerp(to: b, t: t).normalized()
        }, cubic: { p0, outTangent, p1, inTangent, u, duration in
            GLTF.Vector4.cubicHermite(p0: p0, outTangent: outTangent, p1: p1, inTangent: inTangent, u: u, duration: duration).normalized()
        })
    }
}

extension VRMAClip {
    static func sample<T>(keyframes: [Keyframe<T>], at time: Float, interpolation: GLTF.Animation.Sampler.Interpolation, lerp: (T, T, Float) -> T, cubic: (T, T, T, T, Float, Float) -> T) -> T {
        guard let first = keyframes.first else {
            fatalError("Cannot sample empty keyframes")
        }
        guard keyframes.count > 1 else { return first.value }

        if time <= first.time { return first.value }
        let last = keyframes[keyframes.count - 1]
        if time >= last.time { return last.value }

        var lowerBound = 0
        var upperBound = keyframes.count - 1
        while lowerBound + 1 < upperBound {
            let midpoint = (lowerBound + upperBound) / 2
            if time < keyframes[midpoint].time {
                upperBound = midpoint
            } else {
                lowerBound = midpoint
            }
        }

        let current = keyframes[lowerBound]
        let next = keyframes[lowerBound + 1]
        let duration = next.time - current.time
        guard duration > 0 else { return current.value }

        let u = (time - current.time) / duration

        switch interpolation {
        case .STEP:
            return current.value
        case .LINEAR:
            return lerp(current.value, next.value, u)
        case .CUBICSPLINE:
            guard let outTangent = current.outTangent, let inTangent = next.inTangent else {
                return lerp(current.value, next.value, u)
            }
            return cubic(current.value, outTangent, next.value, inTangent, u, duration)
        }
    }
}

// MARK: - Math helpers

private extension GLTF.Vector3 {
    func lerp(to other: GLTF.Vector3, t: Float) -> GLTF.Vector3 {
        return GLTF.Vector3(
            x: x + (other.x - x) * t,
            y: y + (other.y - y) * t,
            z: z + (other.z - z) * t
        )
    }

    static func cubicHermite(p0: GLTF.Vector3, outTangent: GLTF.Vector3, p1: GLTF.Vector3, inTangent: GLTF.Vector3, u: Float, duration: Float) -> GLTF.Vector3 {
        let u2 = u * u
        let u3 = u2 * u
        return p0 * (2 * u3 - 3 * u2 + 1)
            + outTangent * ((u3 - 2 * u2 + u) * duration)
            + p1 * (-2 * u3 + 3 * u2)
            + inTangent * ((u3 - u2) * duration)
    }

    static func * (vector: GLTF.Vector3, scalar: Float) -> GLTF.Vector3 {
        return GLTF.Vector3(x: vector.x * scalar, y: vector.y * scalar, z: vector.z * scalar)
    }

    static func + (lhs: GLTF.Vector3, rhs: GLTF.Vector3) -> GLTF.Vector3 {
        return GLTF.Vector3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }
}

private extension GLTF.Vector4 {
    var length: Float {
        return sqrt(x * x + y * y + z * z + w * w)
    }

    func normalized() -> GLTF.Vector4 {
        let len = length
        guard len > 0 else { return self }
        return GLTF.Vector4(x: x / len, y: y / len, z: z / len, w: w / len)
    }

    func lerp(to other: GLTF.Vector4, t: Float) -> GLTF.Vector4 {
        return GLTF.Vector4(
            x: x + (other.x - x) * t,
            y: y + (other.y - y) * t,
            z: z + (other.z - z) * t,
            w: w + (other.w - w) * t
        )
    }

    static func cubicHermite(p0: GLTF.Vector4, outTangent: GLTF.Vector4, p1: GLTF.Vector4, inTangent: GLTF.Vector4, u: Float, duration: Float) -> GLTF.Vector4 {
        let u2 = u * u
        let u3 = u2 * u
        return p0 * (2 * u3 - 3 * u2 + 1)
            + outTangent * ((u3 - 2 * u2 + u) * duration)
            + p1 * (-2 * u3 + 3 * u2)
            + inTangent * ((u3 - u2) * duration)
    }

    static func * (vector: GLTF.Vector4, scalar: Float) -> GLTF.Vector4 {
        return GLTF.Vector4(x: vector.x * scalar, y: vector.y * scalar, z: vector.z * scalar, w: vector.w * scalar)
    }

    static func + (lhs: GLTF.Vector4, rhs: GLTF.Vector4) -> GLTF.Vector4 {
        return GLTF.Vector4(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z, w: lhs.w + rhs.w)
    }
}

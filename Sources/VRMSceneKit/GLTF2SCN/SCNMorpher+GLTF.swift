import VRMKit
import SceneKit

@available(*, deprecated, message: "Deprecated. Use VRMRealityKit instead.")
extension SCNMorpher {
    convenience init(primitiveTargets: [[GLTF.Mesh.Primitive.AttributeKey: Int]],
                     baseSources: [SCNGeometrySource],
                     loader: VRMSceneLoader) throws {
        self.init()
        for target in primitiveTargets {
            let sources = try loader.attributes(target).map { targetSource in
                try targetSource.absoluteMorphTargetSource(baseSources: baseSources)
            }
            let geometry = SCNGeometry(sources: sources, elements: nil)
            targets.append(geometry)
        }
        calculationMode = .normalized
        for index in targets.indices {
            setWeight(0, forTargetAt: index)
        }
    }
}

private extension SCNGeometrySource {
    func absoluteMorphTargetSource(baseSources: [SCNGeometrySource]) throws -> SCNGeometrySource {
        guard let baseSource = baseSources.first(where: { $0.semantic == semantic }),
              usesFloatComponents,
              baseSource.usesFloatComponents,
              bytesPerComponent == MemoryLayout<Float>.size,
              baseSource.bytesPerComponent == MemoryLayout<Float>.size,
              vectorCount == baseSource.vectorCount,
              baseSource.componentsPerVector >= componentsPerVector else {
            return self
        }

        let vectorSize = componentsPerVector * bytesPerComponent
        var result = Data(count: vectorCount * vectorSize)
        try result.withUnsafeMutableBytes { rawResult in
            try data.withUnsafeBytes { rawDelta in
                try baseSource.data.withUnsafeBytes { rawBase in
                    for vectorIndex in 0..<vectorCount {
                        let resultOffset = vectorIndex * vectorSize
                        let deltaOffset = dataOffset + vectorIndex * dataStride
                        let baseOffset = baseSource.dataOffset + vectorIndex * baseSource.dataStride
                        let byteCount = componentsPerVector * MemoryLayout<Float>.size
                        guard resultOffset >= 0,
                              resultOffset + byteCount <= rawResult.count,
                              deltaOffset >= 0,
                              deltaOffset + byteCount <= rawDelta.count,
                              baseOffset >= 0,
                              baseOffset + byteCount <= rawBase.count else {
                            throw VRMError._dataInconsistent("morph target source is out of range")
                        }

                        var values = [Float](repeating: 0, count: componentsPerVector)
                        for componentIndex in 0..<componentsPerVector {
                            let componentOffset = componentIndex * MemoryLayout<Float>.size
                            let baseValue = rawBase.loadUnaligned(fromByteOffset: baseOffset + componentOffset, as: Float.self)
                            let deltaValue = rawDelta.loadUnaligned(fromByteOffset: deltaOffset + componentOffset, as: Float.self)
                            values[componentIndex] = baseValue + deltaValue
                        }

                        if semantic == .normal || semantic == .tangent {
                            values.normalizeVector3()
                        }

                        for componentIndex in 0..<componentsPerVector {
                            let value = values[componentIndex]
                            rawResult.storeBytes(of: value,
                                                 toByteOffset: resultOffset + componentIndex * MemoryLayout<Float>.size,
                                                 as: Float.self)
                        }
                    }
                }
            }
        }

        return SCNGeometrySource(data: result,
                                 semantic: semantic,
                                 vectorCount: vectorCount,
                                 usesFloatComponents: true,
                                 componentsPerVector: componentsPerVector,
                                 bytesPerComponent: MemoryLayout<Float>.size,
                                 dataOffset: 0,
                                 dataStride: vectorSize)
    }
}

private extension Array where Element == Float {
    mutating func normalizeVector3() {
        guard count >= 3 else { return }
        let length = sqrt(self[0] * self[0] + self[1] * self[1] + self[2] * self[2])
        guard length > 0.000001 else { return }
        self[0] /= length
        self[1] /= length
        self[2] /= length
    }
}

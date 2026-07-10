import Foundation

// MARK: - Animation accessor reading

extension BinaryGLTF {
    func readScalarFloatAccessor(_ index: Int) throws -> [Float] {
        let accessor = try floatAccessor(at: index, type: .SCALAR)
        return try readFloatComponents(accessor: accessor, components: 1).map { $0[0] }
    }

    func readVector3FloatAccessor(_ index: Int) throws -> [GLTF.Vector3] {
        let accessor = try floatAccessor(at: index, type: .VEC3)
        return try readFloatComponents(accessor: accessor, components: 3).map {
            GLTF.Vector3(x: $0[0], y: $0[1], z: $0[2])
        }
    }

    func readVector4FloatAccessor(_ index: Int) throws -> [GLTF.Vector4] {
        let accessor = try floatAccessor(at: index, type: .VEC4)
        return try readFloatComponents(accessor: accessor, components: 4).map {
            GLTF.Vector4(x: $0[0], y: $0[1], z: $0[2], w: $0[3])
        }
    }
}

// MARK: - CUBICSPLINE output reading

extension BinaryGLTF {
    struct CubicScalarTriplet {
        let inTangent: Float
        let value: Float
        let outTangent: Float
    }

    struct CubicVector3Triplet {
        let inTangent: GLTF.Vector3
        let value: GLTF.Vector3
        let outTangent: GLTF.Vector3
    }

    struct CubicVector4Triplet {
        let inTangent: GLTF.Vector4
        let value: GLTF.Vector4
        let outTangent: GLTF.Vector4
    }

    func readCubicScalarAccessor(_ index: Int) throws -> [CubicScalarTriplet] {
        let accessor = try floatAccessor(at: index, type: .SCALAR)
        let components = try readFloatComponents(accessor: accessor, components: 1)
        guard components.count % 3 == 0 else {
            throw VRMError._dataInconsistent("CUBICSPLINE scalar accessor \(index) count is not a multiple of 3")
        }
        return stride(from: 0, to: components.count, by: 3).map { i in
            CubicScalarTriplet(
                inTangent: components[i][0],
                value: components[i + 1][0],
                outTangent: components[i + 2][0]
            )
        }
    }

    func readCubicVector3Accessor(_ index: Int) throws -> [CubicVector3Triplet] {
        let accessor = try floatAccessor(at: index, type: .VEC3)
        let components = try readFloatComponents(accessor: accessor, components: 3)
        guard components.count % 3 == 0 else {
            throw VRMError._dataInconsistent("CUBICSPLINE VEC3 accessor \(index) count is not a multiple of 3")
        }
        return stride(from: 0, to: components.count, by: 3).map { i in
            CubicVector3Triplet(
                inTangent: GLTF.Vector3(x: components[i][0], y: components[i][1], z: components[i][2]),
                value: GLTF.Vector3(x: components[i + 1][0], y: components[i + 1][1], z: components[i + 1][2]),
                outTangent: GLTF.Vector3(x: components[i + 2][0], y: components[i + 2][1], z: components[i + 2][2])
            )
        }
    }

    func readCubicVector4Accessor(_ index: Int) throws -> [CubicVector4Triplet] {
        let accessor = try floatAccessor(at: index, type: .VEC4)
        let components = try readFloatComponents(accessor: accessor, components: 4)
        guard components.count % 3 == 0 else {
            throw VRMError._dataInconsistent("CUBICSPLINE VEC4 accessor \(index) count is not a multiple of 3")
        }
        return stride(from: 0, to: components.count, by: 3).map { i in
            CubicVector4Triplet(
                inTangent: GLTF.Vector4(x: components[i][0], y: components[i][1], z: components[i][2], w: components[i][3]),
                value: GLTF.Vector4(x: components[i + 1][0], y: components[i + 1][1], z: components[i + 1][2], w: components[i + 1][3]),
                outTangent: GLTF.Vector4(x: components[i + 2][0], y: components[i + 2][1], z: components[i + 2][2], w: components[i + 2][3])
            )
        }
    }
}

// MARK: - Private helpers

private extension BinaryGLTF {
    func floatAccessor(at index: Int, type: GLTF.Accessor.`Type`) throws -> GLTF.Accessor {
        let accessors = try jsonData.load(\.accessors)
        guard accessors.indices.contains(index) else {
            throw VRMError._dataInconsistent("Accessor \(index) out of range")
        }
        let accessor = accessors[index]
        guard accessor.componentType == .float, accessor.type == type else {
            throw VRMError._dataInconsistent("Accessor \(index) is not \(type.rawValue) FLOAT")
        }
        return accessor
    }

    func readFloatComponents(accessor: GLTF.Accessor, components: Int) throws -> [[Float]] {
        let count = accessor.count
        guard count >= 0 else {
            throw VRMError._dataInconsistent("invalid accessor count")
        }
        guard count > 0 else {
            return []
        }
        let bufferViewIndex = try accessor.bufferView ??? .dataInconsistent("accessor missing bufferView")
        let (data, byteStride) = try bufferViewData(at: bufferViewIndex)
        let componentSize = MemoryLayout<Float>.size
        let elementSize = componentSize * components
        let stride = byteStride ?? elementSize
        let offset = accessor.byteOffset

        guard stride >= elementSize else {
            throw VRMError._dataInconsistent("bufferView byteStride \(stride) is smaller than element size \(elementSize)")
        }
        guard offset >= 0 else {
            throw VRMError._dataInconsistent("invalid accessor offset")
        }
        let requiredBytes = offset + stride * (count - 1) + elementSize
        guard data.count >= requiredBytes else {
            throw VRMError._dataInconsistent("accessor data out of bounds: \(data.count) < \(requiredBytes)")
        }

        var result: [[Float]] = []
        result.reserveCapacity(count)
        for i in 0..<count {
            let start = offset + stride * i
            let floats = data.withUnsafeBytes { raw -> [Float] in
                (0..<components).map { component in
                    raw.loadUnaligned(fromByteOffset: start + componentSize * component, as: Float.self)
                }
            }
            result.append(floats)
        }
        return result
    }
}

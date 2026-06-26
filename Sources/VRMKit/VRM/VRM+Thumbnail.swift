package extension VRM {
    var thumbnailImageIndex: Int {
        get throws {
            switch self {
            case .v0(let vrm0):
                return try vrm0.thumbnailImageIndex
            case .v1(let vrm1):
                return try vrm1.thumbnailImageIndex
            }
        }
    }
}

package extension VRM0 {
    var thumbnailImageIndex: Int {
        get throws {
            guard let textureIndex = meta.texture, textureIndex >= 0 else {
                throw VRMError.thumbnailNotFound
            }
            let textures = try gltf.jsonData.load(\.textures)
            guard textures.indices.contains(textureIndex) else {
                throw VRMError.thumbnailNotFound
            }
            let imageIndex = textures[textureIndex].source
            let images = try gltf.jsonData.load(\.images)
            guard images.indices.contains(imageIndex) else {
                throw VRMError.thumbnailNotFound
            }
            return imageIndex
        }
    }
}

package extension VRM1 {
    var thumbnailImageIndex: Int {
        get throws {
            guard let imageIndex = meta.thumbnailImage, imageIndex >= 0 else {
                throw VRMError.thumbnailNotFound
            }
            let images = try gltf.jsonData.load(\.images)
            guard images.indices.contains(imageIndex) else {
                throw VRMError.thumbnailNotFound
            }
            return imageIndex
        }
    }
}

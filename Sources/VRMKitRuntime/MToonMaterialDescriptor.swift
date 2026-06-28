import Foundation
import simd
import VRMKit

package struct MToonMaterialDescriptor {
    package enum OutlineWidthMode {
        case none
        case worldCoordinates
        case screenCoordinates
    }

    package struct Texture {
        package let index: Int
        package let texCoord: Int

        package init(_ index: Int) {
            self.init(index: index)
        }

        package init(index: Int, texCoord: Int = 0) {
            self.index = index
            self.texCoord = texCoord
        }
    }

    package let baseColorFactor: SIMD4<Float>
    package let shadeColorFactor: SIMD4<Float>
    package let shadingShiftFactor: Float
    package let shadingShiftTextureScale: Float
    package let shadingToonyFactor: Float
    package let giEqualizationFactor: Float
    package let matcapFactor: SIMD3<Float>
    package let parametricRimColorFactor: SIMD4<Float>
    package let rimLightingMixFactor: Float
    package let parametricRimFresnelPowerFactor: Float
    package let parametricRimLiftFactor: Float
    package let outlineWidthMode: OutlineWidthMode
    package let outlineWidthFactor: Float
    package let outlineColorFactor: SIMD4<Float>
    package let outlineLightingMixFactor: Float
    package let uvAnimationScrollXSpeedFactor: Float
    package let uvAnimationScrollYSpeedFactor: Float
    package let uvAnimationRotationSpeedFactor: Float
    package let transparentWithZWrite: Bool
    package let renderQueueOffsetNumber: Int
    package let alphaMode: GLTF.Material.AlphaMode
    package let alphaCutoff: Float
    package let doubleSided: Bool
    package let baseColorTexture: Texture?
    package let shadeMultiplyTexture: Texture?
    package let shadingShiftTexture: Texture?
    package let normalTexture: Texture?
    package let matcapTexture: Texture?
    package let rimMultiplyTexture: Texture?
    package let outlineWidthMultiplyTexture: Texture?
    package let uvAnimationMaskTexture: Texture?

    package init?(material: GLTF.Material, materialProperty: VRM0.MaterialProperty?) {
        if let mtoon = material.extensions?.materialsMToon {
            self.init(vrm1: mtoon, material: material)
            return
        }

        guard let materialProperty,
              materialProperty.vrmShader == .mToon || materialProperty.shader.lowercased().contains("mtoon") else {
            return nil
        }
        self.init(vrm0: materialProperty, material: material)
    }
}

package extension MToonMaterialDescriptor {
    var hasOutline: Bool {
        switch outlineWidthMode {
        case .none:
            return false
        case .worldCoordinates, .screenCoordinates:
            return outlineWidthFactor > 0
        }
    }
}

package extension MToonMaterialDescriptor.OutlineWidthMode {
    var rawValue: Float {
        switch self {
        case .none:
            return 0
        case .worldCoordinates:
            return 1
        case .screenCoordinates:
            return 2
        }
    }
}

private extension MToonMaterialDescriptor {
    init(vrm1 mtoon: GLTF.Material.MaterialExtensions.MaterialsMToon, material: GLTF.Material) {
        let pbr = material.pbrMetallicRoughness
        let baseColor = (pbr?.baseColorFactor).map(SIMD4<Float>.init) ?? SIMD4<Float>(1, 1, 1, 1)
        let shadeColor = SIMD4<Float>(mtoon.shadeColorFactor, default: SIMD4<Float>(1, 1, 1, 1))
        let matcapFactor = SIMD3<Float>(mtoon.matcapFactor, default: SIMD3<Float>(0, 0, 0))
        let rimColor = SIMD4<Float>(mtoon.parametricRimColorFactor, default: SIMD4<Float>(0, 0, 0, 1))
        let outlineColor = SIMD4<Float>(mtoon.outlineColorFactor, default: SIMD4<Float>(0, 0, 0, 1))

        self.baseColorFactor = baseColor
        self.shadeColorFactor = shadeColor
        self.shadingShiftFactor = Float(mtoon.shadingShiftFactor ?? 0)
        self.shadingShiftTextureScale = Float(mtoon.shadingShiftTexture?.scale ?? 1)
        self.shadingToonyFactor = Float(mtoon.shadingToonyFactor ?? 0.9)
        self.giEqualizationFactor = Float(mtoon.giEqualizationFactor ?? 0.9)
        self.matcapFactor = matcapFactor
        self.parametricRimColorFactor = rimColor
        self.rimLightingMixFactor = Float(mtoon.rimLightingMixFactor ?? 1)
        self.parametricRimFresnelPowerFactor = Float(mtoon.parametricRimFresnelPowerFactor ?? 1)
        self.parametricRimLiftFactor = Float(mtoon.parametricRimLiftFactor ?? 0)
        self.outlineWidthMode = .init(vrm1: mtoon.outlineWidthMode)
        self.outlineWidthFactor = Float(mtoon.outlineWidthFactor ?? 0)
        self.outlineColorFactor = outlineColor
        self.outlineLightingMixFactor = Float(mtoon.outlineLightingMixFactor ?? 1)
        self.uvAnimationScrollXSpeedFactor = Float(mtoon.uvAnimationScrollXSpeedFactor ?? 0)
        self.uvAnimationScrollYSpeedFactor = Float(mtoon.uvAnimationScrollYSpeedFactor ?? 0)
        self.uvAnimationRotationSpeedFactor = Float(mtoon.uvAnimationRotationSpeedFactor ?? 0)
        self.transparentWithZWrite = mtoon.transparentWithZWrite ?? false
        self.renderQueueOffsetNumber = mtoon.renderQueueOffsetNumber ?? 0
        self.alphaMode = material.alphaMode
        self.alphaCutoff = material.alphaCutoff
        self.doubleSided = material.doubleSided
        self.baseColorTexture = pbr?.baseColorTexture.map(MToonMaterialDescriptor.Texture.init)
        self.shadeMultiplyTexture = mtoon.shadeMultiplyTexture.map(MToonMaterialDescriptor.Texture.init)
        self.shadingShiftTexture = mtoon.shadingShiftTexture.map(MToonMaterialDescriptor.Texture.init)
        self.normalTexture = material.normalTexture.map(MToonMaterialDescriptor.Texture.init)
        self.matcapTexture = mtoon.matcapTexture.map(MToonMaterialDescriptor.Texture.init)
        self.rimMultiplyTexture = mtoon.rimMultiplyTexture.map(MToonMaterialDescriptor.Texture.init)
        self.outlineWidthMultiplyTexture = mtoon.outlineWidthMultiplyTexture.map(MToonMaterialDescriptor.Texture.init)
        self.uvAnimationMaskTexture = mtoon.uvAnimationMaskTexture.map(MToonMaterialDescriptor.Texture.init)
    }

    init(vrm0 property: VRM0.MaterialProperty, material: GLTF.Material) {
        let floats = property.floatProperties.dictionaryValue
        let textures = property.textureProperties
        let vectors = property.vectorProperties.dictionaryValue
        let pbr = material.pbrMetallicRoughness
        let baseColor = vectors.simd4("_Color") ?? (pbr?.baseColorFactor).map(SIMD4<Float>.init) ?? SIMD4<Float>(1, 1, 1, 1)
        let shadeColor = vectors.simd4("_ShadeColor") ?? SIMD4<Float>(0.97, 0.81, 0.86, 1)
        let rimColor = vectors.simd4("_RimColor") ?? SIMD4<Float>(0, 0, 0, 1)
        let outlineColor = vectors.simd4("_OutlineColor") ?? SIMD4<Float>(0, 0, 0, 1)
        let alphaMode = GLTF.Material.AlphaMode(vrm0: property, fallback: material.alphaMode)
        let doubleSided = material.doubleSided || floats.float("_CullMode") == 0

        self.baseColorFactor = baseColor
        self.shadeColorFactor = shadeColor
        self.shadingShiftFactor = floats.float("_ShadeShift") ?? floats.float("_ShadingShift") ?? 0
        self.shadingShiftTextureScale = 1
        self.shadingToonyFactor = floats.float("_ShadeToony") ?? floats.float("_ShadingToony") ?? 0.9
        self.giEqualizationFactor = floats.float("_GiEqualization") ?? floats.float("_IndirectLightIntensity") ?? 0.9
        self.matcapFactor = SIMD3<Float>(1, 1, 1)
        self.parametricRimColorFactor = rimColor
        self.rimLightingMixFactor = floats.float("_RimLightingMix") ?? 1
        self.parametricRimFresnelPowerFactor = floats.float("_RimFresnelPower") ?? 1
        self.parametricRimLiftFactor = floats.float("_RimLift") ?? 0
        self.outlineWidthMode = .init(vrm0: floats.float("_OutlineWidthMode") ?? 0)
        self.outlineWidthFactor = floats.float("_OutlineWidth") ?? 0
        self.outlineColorFactor = outlineColor
        self.outlineLightingMixFactor = floats.float("_OutlineLightingMix") ?? 1
        self.uvAnimationScrollXSpeedFactor = floats.float("_UvAnimScrollX") ?? 0
        self.uvAnimationScrollYSpeedFactor = floats.float("_UvAnimScrollY") ?? 0
        self.uvAnimationRotationSpeedFactor = floats.float("_UvAnimRotation") ?? 0
        self.transparentWithZWrite = property.keywordMap["_ZWRITE_ON"] ?? false
        self.renderQueueOffsetNumber = property.renderQueue
        self.alphaMode = alphaMode
        self.alphaCutoff = floats.float("_Cutoff") ?? material.alphaCutoff
        self.doubleSided = doubleSided
        self.baseColorTexture = textures["_MainTex"].map(MToonMaterialDescriptor.Texture.init)
        self.shadeMultiplyTexture = textures["_ShadeTexture"].map(MToonMaterialDescriptor.Texture.init)
        self.shadingShiftTexture = nil
        self.normalTexture = textures["_BumpMap"].map(MToonMaterialDescriptor.Texture.init) ?? material.normalTexture.map(MToonMaterialDescriptor.Texture.init)
        self.matcapTexture = textures["_SphereAdd"].map(MToonMaterialDescriptor.Texture.init)
        self.rimMultiplyTexture = textures["_RimTexture"].map(MToonMaterialDescriptor.Texture.init)
        self.outlineWidthMultiplyTexture = textures["_OutlineWidthTexture"].map(MToonMaterialDescriptor.Texture.init)
        self.uvAnimationMaskTexture = textures["_UvAnimMaskTexture"].map(MToonMaterialDescriptor.Texture.init)
    }
}

private extension MToonMaterialDescriptor.OutlineWidthMode {
    init(vrm1 mode: GLTF.Material.MaterialExtensions.MaterialsMToon.MaterialsMToonOutlineWidthMode?) {
        switch mode {
        case .some(.worldCoordinates):
            self = .worldCoordinates
        case .some(.screenCoordinates):
            self = .screenCoordinates
        case .some(.none), nil:
            self = .none
        }
    }

    init(vrm0 mode: Float) {
        switch Int(mode) {
        case 1:
            self = .worldCoordinates
        case 2:
            self = .screenCoordinates
        default:
            self = .none
        }
    }
}

private extension MToonMaterialDescriptor.Texture {
    init(_ textureInfo: GLTF.TextureInfo) {
        self.init(index: textureInfo.index, texCoord: textureInfo.texCoord)
    }

    init(_ textureInfo: GLTF.Material.NormalTextureInfo) {
        self.init(index: textureInfo.index, texCoord: textureInfo.texCoord)
    }

    init(_ textureInfo: GLTF.Material.MaterialExtensions.MaterialsMToon.MaterialsMToonTextureInfo) {
        self.init(index: textureInfo.index, texCoord: textureInfo.texCoord ?? 0)
    }

    init(_ textureInfo: GLTF.Material.MaterialExtensions.MaterialsMToon.MaterialsMToonShadingShiftTexture) {
        self.init(index: textureInfo.index, texCoord: textureInfo.texCoord ?? 0)
    }
}

private extension GLTF.Material.AlphaMode {
    init(vrm0 property: VRM0.MaterialProperty, fallback: GLTF.Material.AlphaMode) {
        if let renderType = property.tagMap["RenderType"]?.lowercased() {
            switch renderType {
            case "opaque":
                self = .OPAQUE
                return
            case "transparentcutout", "cutout":
                self = .MASK
                return
            case "transparent":
                self = .BLEND
                return
            default:
                break
            }
        }

        if property.keywordMap["_ALPHAPREMULTIPLY_ON"] == true || property.keywordMap["_ALPHABLEND_ON"] == true {
            self = .BLEND
        } else if property.keywordMap["_ALPHATEST_ON"] == true {
            self = .MASK
        } else {
            self = fallback
        }
    }
}

private extension CodableAny {
    var dictionaryValue: [String: Any] {
        return value as? [String: Any] ?? [:]
    }
}

private extension Dictionary where Key == String, Value == Any {
    func float(_ key: String) -> Float? {
        switch self[key] {
        case let value as Float:
            return value
        case let value as Double:
            return Float(value)
        case let value as Int:
            return Float(value)
        case let value as NSNumber:
            return value.floatValue
        default:
            return nil
        }
    }

    func simd4(_ key: String) -> SIMD4<Float>? {
        return (self[key] as? [Any]).map(SIMD4<Float>.init)
    }
}

private extension SIMD4 where Scalar == Float {
    init(_ values: [Double]?, default defaultValue: SIMD4<Float>) {
        guard let values else {
            self = defaultValue
            return
        }
        self.init(Float(values[safe: 0] ?? Double(defaultValue.x)),
                  Float(values[safe: 1] ?? Double(defaultValue.y)),
                  Float(values[safe: 2] ?? Double(defaultValue.z)),
                  Float(values[safe: 3] ?? Double(defaultValue.w)))
    }

    init(_ color: GLTF.Color4) {
        self.init(color.r, color.g, color.b, color.a)
    }

    init(_ values: [Any]) {
        self.init(values.float(at: 0, default: 1),
                  values.float(at: 1, default: 1),
                  values.float(at: 2, default: 1),
                  values.float(at: 3, default: 1))
    }
}

private extension Array where Element == Any {
    func float(at index: Int, default defaultValue: Float) -> Float {
        guard indices.contains(index) else { return defaultValue }
        switch self[index] {
        case let value as Float:
            return value
        case let value as Double:
            return Float(value)
        case let value as Int:
            return Float(value)
        case let value as NSNumber:
            return value.floatValue
        default:
            return defaultValue
        }
    }
}

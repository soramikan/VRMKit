import simd

/// Morph target binding shared by VRM 0.x BlendShape and VRM 1.0 Expression runtime clips.
package struct BlendShapeBinding<Mesh> {
    package let mesh: Mesh
    package let index: Int
    package let weight: Double

    package init(mesh: Mesh, index: Int, weight: Double) {
        self.mesh = mesh
        self.index = index
        self.weight = weight
    }
}

/// Runtime clip for VRM 0.x BlendShape groups.
package struct BlendShapeClip<Mesh> {
    package let name: String
    package let preset: BlendShapePreset
    package let values: [BlendShapeBinding<Mesh>]
    package let isBinary: Bool

    package var key: BlendShapeKey {
        return preset == .unknown ? .custom(name) : .preset(preset)
    }

    package init(name: String,
                 preset: BlendShapePreset,
                 values: [BlendShapeBinding<Mesh>],
                 isBinary: Bool) {
        self.name = name
        self.preset = preset
        self.values = values
        self.isBinary = isBinary
    }
}

/// Runtime clip for VRM 1.0 Expressions.
package struct ExpressionClip<Mesh> {
    package let name: String
    package let preset: ExpressionPreset?
    package let values: [BlendShapeBinding<Mesh>]
    package let isBinary: Bool

    package var key: ExpressionKey {
        return preset.map(ExpressionKey.preset) ?? .custom(name)
    }

    package init(name: String,
                 preset: ExpressionPreset?,
                 values: [BlendShapeBinding<Mesh>],
                 isBinary: Bool) {
        self.name = name
        self.preset = preset
        self.values = values
        self.isBinary = isBinary
    }
}

/// Material value binding used by VRM 0.x BlendShape material values.
package struct MaterialValueBinding {
    package let materialName: String
    package let valueName: String
    package let targetValue: SIMD4<Float>
    package let baseValue: SIMD4<Float>

    package init(materialName: String,
                 valueName: String,
                 targetValue: SIMD4<Float>,
                 baseValue: SIMD4<Float>) {
        self.materialName = materialName
        self.valueName = valueName
        self.targetValue = targetValue
        self.baseValue = baseValue
    }
}

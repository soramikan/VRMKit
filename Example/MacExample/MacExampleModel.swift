import CoreGraphics
import Foundation
internal import VRMKit
internal import VRMSceneKit
internal import VRMRealityKit

enum MacExampleRenderer: String, CaseIterable, Identifiable {
    case sceneKit
    case realityKit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sceneKit: return "SceneKit"
        case .realityKit: return "RealityKit"
        }
    }
}

enum MacExampleModel: String, CaseIterable, Identifiable {
    case alicia = "AliciaSolid.vrm"
    case vrm1 = "VRM1_Constraint_Twist_Sample.vrm"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .alicia: return "Alicia"
        case .vrm1: return "VRM 1.0"
        }
    }

    var initialRotation: Float {
        switch self {
        case .alicia: return 0
        case .vrm1: return .pi
        }
    }
}

enum MacExampleExpression: String, CaseIterable, Identifiable {
    case neutral
    case joy
    case angry
    case sorrow
    case fun

    var id: String { rawValue }

    var blendShapePreset: BlendShapePreset {
        switch self {
        case .neutral: return .neutral
        case .joy: return .joy
        case .angry: return .angry
        case .sorrow: return .sorrow
        case .fun: return .fun
        }
    }

    var expressionPreset: ExpressionPreset {
        switch self {
        case .neutral: return .neutral
        case .joy: return .happy
        case .angry: return .angry
        case .sorrow: return .sad
        case .fun: return .relaxed
        }
    }

    func displayName(for model: MacExampleModel) -> String {
        switch model {
        case .alicia:
            return rawValue.capitalized
        case .vrm1:
            switch self {
            case .neutral: return "Neutral"
            case .joy: return "Happy"
            case .angry: return "Angry"
            case .sorrow: return "Sad"
            case .fun: return "Relaxed"
            }
        }
    }
}

enum MacExampleMotion: String, CaseIterable, Identifiable {
    case none
    case motionPose = "001_motion_pose"
    case dogeza = "002_dogeza"
    case humidai = "003_humidai"
    case hello1 = "004_hello_1"
    case smartphone = "005_smartphone"
    case drinkWater = "006_drinkwater"
    case gekirei = "007_gekirei"
    case gatan = "008_gatan"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None"
        case .motionPose: return "Pose"
        case .dogeza: return "Dogeza"
        case .humidai: return "Humidai"
        case .hello1: return "Hello"
        case .smartphone: return "Phone"
        case .drinkWater: return "Drink"
        case .gekirei: return "Gekirei"
        case .gatan: return "Gatan"
        }
    }
}

extension VRMEntity {
    func setExampleExpression(_ expression: MacExampleExpression, value: CGFloat) {
        switch vrm {
        case .v0:
            setBlendShape(value: value, for: .preset(expression.blendShapePreset))
        case .v1:
            setExpression(value: value, for: .preset(expression.expressionPreset))
        }
    }
}

extension VRMNode {
    func setExampleExpression(_ expression: MacExampleExpression, value: CGFloat) {
        switch vrm {
        case .v0:
            setBlendShape(value: value, for: .preset(expression.blendShapePreset))
        case .v1:
            setExpression(value: value, for: .preset(expression.expressionPreset))
        }
    }
}

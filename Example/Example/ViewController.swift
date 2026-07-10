import UIKit
import SceneKit
import simd
internal import VRMKit
internal import VRMSceneKit

class ViewController: UIViewController {

    @IBOutlet private weak var scnView: SCNView! {
        didSet {
            scnView.autoenablesDefaultLighting = true
            scnView.allowsCameraControl = true
            scnView.showsStatistics = true
            scnView.backgroundColor = UIColor.black
        }
    }

    private var vrmNode: VRMNode?
    private var expressionSegmentedControl: UISegmentedControl?
    private var currentModel: VRMExampleModel = .alicia
    private var currentExpression: ExampleExpression = .neutral
    private var currentMotion: VRMAExampleMotion = .none
    private var vrmaPlayer: VRMAPlayer?
    private var vrmaRetargetingContext: VRMARetargetingContext?
    private var lastVRMAUpdateTime: TimeInterval?
    private var motionButton: UIButton?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadVRM(model: .alicia)
    }

    private func setupUI() {
        let items = VRMExampleModel.allCases.map { $0.displayName }
        let segmentedControl = UISegmentedControl(items: items)
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentedControl)

        let expressionItems = ExampleExpression.allCases.map { $0.displayName(for: currentModel) }
        let expressionSegmentedControl = UISegmentedControl(items: expressionItems)
        expressionSegmentedControl.selectedSegmentIndex = 0
        expressionSegmentedControl.addTarget(self, action: #selector(expressionSegmentChanged(_:)), for: .valueChanged)
        expressionSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(expressionSegmentedControl)
        self.expressionSegmentedControl = expressionSegmentedControl

        let motionButton = makeMotionButton()
        motionButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(motionButton)
        self.motionButton = motionButton

        NSLayoutConstraint.activate([
            segmentedControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            segmentedControl.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -50),

            expressionSegmentedControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            expressionSegmentedControl.bottomAnchor.constraint(equalTo: segmentedControl.topAnchor, constant: -20),

            motionButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            motionButton.bottomAnchor.constraint(equalTo: expressionSegmentedControl.topAnchor, constant: -20)
        ])
    }

    private func makeMotionButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("Motion: \(currentMotion.displayName)", for: .normal)
        button.showsMenuAsPrimaryAction = true
        button.menu = makeMotionMenu()
        return button
    }

    private func makeMotionMenu() -> UIMenu {
        let actions = VRMAExampleMotion.allCases.map { motion in
            UIAction(title: motion.displayName, state: currentMotion == motion ? .on : .off) { [weak self] _ in
                self?.selectMotion(motion)
            }
        }
        return UIMenu(title: "Motion", children: actions)
    }

    private func selectMotion(_ motion: VRMAExampleMotion) {
        currentMotion = motion
        motionButton?.setTitle("Motion: \(motion.displayName)", for: .normal)
        motionButton?.menu = makeMotionMenu()
        loadVRM(model: currentModel)
    }

    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        let model = VRMExampleModel.allCases[sender.selectedSegmentIndex]
        loadVRM(model: model)
    }

    @objc private func expressionSegmentChanged(_ sender: UISegmentedControl) {
        let expression = ExampleExpression.allCases[sender.selectedSegmentIndex]
        vrmNode?.setExampleExpression(currentExpression, value: 0.0)
        currentExpression = expression
        vrmNode?.setExampleExpression(currentExpression, value: 1.0)
    }

    private func loadVRM(model: VRMExampleModel) {
        do {
            currentModel = model
            updateExpressionLabels()
            let loader = try VRMSceneLoader(named: model.rawValue)
            let scene = try loader.loadScene()
            setupScene(scene)
            scnView.scene = scene
            scnView.delegate = self
            let node = scene.vrmNode
            self.vrmNode = node

            let rotationOffset = CGFloat(model.initialRotation)
            node.eulerAngles = SCNVector3(0, rotationOffset, 0)
            node.setMToonLightDirection(SceneKitExampleLighting.direction)
            node.setExampleExpression(currentExpression, value: 1.0)

            if currentMotion == .none {
                node.humanoid.node(for: .neck)?.eulerAngles = SCNVector3(0, 0, 20 * CGFloat.pi / 180)
                let leftArm: SCNNode?
                let rightArm: SCNNode?
                switch node.vrm {
                case .v1:
                    leftArm = node.humanoid.node(for: .leftShoulder)
                    rightArm = node.humanoid.node(for: .rightShoulder)
                case .v0:
                    leftArm = node.humanoid.node(for: .leftUpperArm)
                    rightArm = node.humanoid.node(for: .rightUpperArm)
                }
                leftArm?.eulerAngles = SCNVector3(0, 0, 40 * CGFloat.pi / 180)
                rightArm?.eulerAngles = SCNVector3(0, 0, 40 * CGFloat.pi / 180)

                node.runAction(SCNAction.repeatForever(SCNAction.sequence([
                    SCNAction.rotateBy(x: 0, y: -0.5, z: 0, duration: 0.5),
                    SCNAction.rotateBy(x: 0, y: 0.5, z: 0, duration: 0.5),
                ])))
            } else {
                loadCurrentMotion()
            }
        } catch {
            print(error)
        }
    }

    private func loadCurrentMotion() {
        guard currentMotion != .none, let vrmNode else {
            vrmaPlayer = nil
            vrmaRetargetingContext = nil
            lastVRMAUpdateTime = nil
            return
        }
        do {
            guard let url = Bundle.main.url(forResource: currentMotion.rawValue,
                                            withExtension: "vrma",
                                            subdirectory: "VRMA") else {
                throw URLError(.fileDoesNotExist)
            }
            let loader = VRMAAnimationLoader()
            let vrma = try loader.load(withURL: url)
            let clip = try loader.loadClip(from: vrma)
            vrmaRetargetingContext = vrmNode.makeVRMARetargetingContext(for: clip)
            vrmaPlayer = VRMAPlayer(clip: clip, isPlaying: true, isLooping: true, playbackSpeed: 1.0)
            lastVRMAUpdateTime = nil

            // Apply the first sample immediately so the pose updates this frame.
            let sample = vrmaPlayer?.sample
            if let sample { vrmNode.apply(vrmaSample: sample, retargetingContext: vrmaRetargetingContext) }
        } catch {
            print("VRMA load error: \(error)")
            vrmaPlayer = nil
            vrmaRetargetingContext = nil
            lastVRMAUpdateTime = nil
        }
    }

    private func updateExpressionLabels() {
        guard let expressionSegmentedControl else { return }
        let selectedIndex = expressionSegmentedControl.selectedSegmentIndex
        expressionSegmentedControl.removeAllSegments()
        for (index, expression) in ExampleExpression.allCases.enumerated() {
            expressionSegmentedControl.insertSegment(withTitle: expression.displayName(for: currentModel),
                                                     at: index,
                                                     animated: false)
        }
        expressionSegmentedControl.selectedSegmentIndex = selectedIndex >= 0 ? selectedIndex : 0
    }

    private func setupScene(_ scene: SCNScene) {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        scene.rootNode.addChildNode(cameraNode)

        cameraNode.position = SCNVector3(0, 0.8, -1.6)
        cameraNode.rotation = SCNVector4(0, 1, 0, Float.pi)

        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .directional
        lightNode.light?.intensity = 1200
        lightNode.simdPosition = -SceneKitExampleLighting.direction
        lightNode.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(lightNode)
    }
}

private enum SceneKitExampleLighting {
    static let direction = simd_normalize(SIMD3<Float>(0.35, 0.55, 0.75))
}

@available(*, deprecated, message: "Deprecated. Use VRMRealityKit instead.")
extension ViewController: SCNSceneRendererDelegate {
    nonisolated func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let scene = renderer.scene as? VRMScene else { return }
        let node = scene.vrmNode

        if let player = vrmaPlayer {
            let delta: Float
            if let last = lastVRMAUpdateTime {
                delta = Float(time - last)
            } else {
                delta = 1.0 / 60.0
            }
            lastVRMAUpdateTime = time
            var nextPlayer = player
            let sample = nextPlayer.update(deltaTime: delta)
            vrmaPlayer = nextPlayer
            node.apply(vrmaSample: sample, retargetingContext: vrmaRetargetingContext)
        } else {
            lastVRMAUpdateTime = nil
        }

        node.update(at: time)
    }
}

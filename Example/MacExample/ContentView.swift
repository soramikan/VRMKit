//
//  ContentView.swift
//  MacExample
//
//  Created by tattn on 2026/01/26.
//  Copyright © 2026 tattn. All rights reserved.
//

import SwiftUI
import SceneKit
import RealityKit
internal import VRMSceneKit
internal import VRMRealityKit
internal import Combine
internal import VRMKit

struct ContentView: View {
    @State private var realityKitViewModel = RealityKitContentViewModel()
    @State private var sceneKitViewModel = SceneKitContentViewModel()
    @State private var selectedRenderer: MacExampleRenderer = .realityKit
    @State private var selectedModel: MacExampleModel = .alicia
    @State private var selectedExpression: MacExampleExpression = .neutral
    @State private var selectedMotion: MacExampleMotion = .none
    @State private var hasShownSceneKit = false
    @State private var hasShownRealityKit = true

    var body: some View {
        VStack {
            HStack {
                Picker("Renderer", selection: $selectedRenderer) {
                    ForEach(MacExampleRenderer.allCases) { renderer in
                        Text(renderer.displayName).tag(renderer)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Model", selection: $selectedModel) {
                    ForEach(MacExampleModel.allCases) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Expression", selection: $selectedExpression) {
                    ForEach(MacExampleExpression.allCases) { expression in
                        Text(expression.displayName(for: selectedModel)).tag(expression)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Motion", selection: $selectedMotion) {
                    ForEach(MacExampleMotion.allCases) { motion in
                        Text(motion.displayName).tag(motion)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding([.top, .horizontal])

            ZStack {
                if hasShownSceneKit {
                    SceneKitRendererView(viewModel: sceneKitViewModel,
                                         selectedModel: selectedModel,
                                         selectedExpression: selectedExpression,
                                         selectedMotion: selectedMotion,
                                         isActive: selectedRenderer == .sceneKit)
                        .opacity(selectedRenderer == .sceneKit ? 1 : 0)
                        .allowsHitTesting(selectedRenderer == .sceneKit)
                        .zIndex(selectedRenderer == .sceneKit ? 1 : 0)
                }

                if hasShownRealityKit {
                    RealityKitRendererView(viewModel: realityKitViewModel,
                                           selectedModel: selectedModel,
                                           selectedExpression: selectedExpression,
                                           selectedMotion: selectedMotion,
                                           isActive: selectedRenderer == .realityKit)
                        .opacity(selectedRenderer == .realityKit ? 1 : 0)
                        .allowsHitTesting(selectedRenderer == .realityKit)
                        .zIndex(selectedRenderer == .realityKit ? 1 : 0)
                }
            }
            .onChange(of: selectedRenderer) { _, renderer in
                switch renderer {
                case .sceneKit:
                    hasShownSceneKit = true
                case .realityKit:
                    hasShownRealityKit = true
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

private struct RealityKitRendererView: View {
    let viewModel: RealityKitContentViewModel
    let selectedModel: MacExampleModel
    let selectedExpression: MacExampleExpression
    let selectedMotion: MacExampleMotion
    let isActive: Bool

    var body: some View {
        RealityView { content in
            content.add(viewModel.makeRenderRootEntity())
        }
        .background(Color.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: selectedModel) {
            await viewModel.loadEntity(model: selectedModel,
                                       expression: selectedExpression,
                                       motion: selectedMotion,
                                       forceReload: true)
        }
        .task(id: selectedMotion) {
            await viewModel.setMotion(selectedMotion)
        }
        .onAppear {
            viewModel.resumeUpdates()
        }
        .onChange(of: isActive) { _, isActive in
            if isActive {
                viewModel.resumeUpdates()
            }
        }
        .onChange(of: selectedExpression) { _, expression in
            viewModel.setExpression(expression)
        }
        .onReceive(viewModel.updateTimer) { _ in
            if isActive {
                viewModel.update()
            }
        }
        .overlay(alignment: .bottomLeading) {
            if let errorMessage = viewModel.errorMessage {
                ErrorMessageView(message: errorMessage)
            }
        }
    }
}

private struct SceneKitRendererView: View {
    let viewModel: SceneKitContentViewModel
    let selectedModel: MacExampleModel
    let selectedExpression: MacExampleExpression
    let selectedMotion: MacExampleMotion
    let isActive: Bool

    var body: some View {
        SceneKitView(scene: viewModel.scene)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task(id: selectedModel) {
                await viewModel.loadScene(model: selectedModel,
                                          expression: selectedExpression,
                                          motion: selectedMotion)
            }
            .task(id: selectedMotion) {
                await viewModel.setMotion(selectedMotion)
            }
            .onAppear {
                viewModel.resumeUpdates()
            }
            .onChange(of: isActive) { _, isActive in
                if isActive {
                    viewModel.resumeUpdates()
                }
            }
            .onChange(of: selectedExpression) { _, expression in
                viewModel.setExpression(expression)
            }
            .onReceive(viewModel.updateTimer) { _ in
                if isActive {
                    viewModel.update()
                }
            }
            .overlay(alignment: .bottomLeading) {
                if let errorMessage = viewModel.errorMessage {
                    ErrorMessageView(message: errorMessage)
                }
            }
    }
}

private struct ErrorMessageView: View {
    let message: String

    var body: some View {
        Text("Error: \(message)")
            .foregroundStyle(.red)
            .padding()
    }
}

@MainActor
@Observable
final class RealityKitContentViewModel {
    private var rootEntity = Entity()
    private(set) var errorMessage: String?
    private var vrmEntity: VRMEntity?
    private var cameraEntity: PerspectiveCamera?
    private var lightEntity: DirectionalLight?
    private var time: TimeInterval = 0
    private var lastUpdateTime: Date?
    private var currentModel: MacExampleModel = .alicia
    private var currentExpression: MacExampleExpression = .neutral
    private var currentMotion: MacExampleMotion = .none
    private var vrmaPlayer: VRMAPlayer?
    private var vrmaRetargetingContext: VRMARetargetingContext?
    private var orbitDistance: Float = 2
    private var orbitTarget = SIMD3<Float>(0, 0.8, 0)

    let updateTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    func makeRenderRootEntity() -> Entity {
        let nextRootEntity = Entity()
        if let cameraEntity {
            nextRootEntity.addChild(cameraEntity)
        }
        if let lightEntity {
            nextRootEntity.addChild(lightEntity)
        }
        if let vrmEntity {
            nextRootEntity.addChild(vrmEntity.entity)
        }
        rootEntity = nextRootEntity
        return nextRootEntity
    }

    func loadEntity(
        model: MacExampleModel,
        expression: MacExampleExpression,
        motion: MacExampleMotion,
        forceReload: Bool = false
    ) async {
        if !forceReload, currentModel == model, currentMotion == motion, let vrmEntity {
            apply(expression, to: vrmEntity)
            currentExpression = expression
            resumeUpdates()
            return
        }

        await Task.yield()
        guard !Task.isCancelled else { return }

        do {
            errorMessage = nil

            let loader = try VRMEntityLoader(named: model.rawValue)
            let nextVRMEntity = try loader.loadEntity()

            nextVRMEntity.entity.transform.translation = SIMD3<Float>(0, -1, 0)
            nextVRMEntity.entity.transform.rotation = simd_quatf(angle: model.initialRotation, axis: SIMD3<Float>(0, 1, 0))
            nextVRMEntity.setMToonLightDirection(MacExampleLighting.realityKitDirection)
            setUpCamera()
            setUpLight()
            rootEntity.addChild(nextVRMEntity.entity)
            normalizeScale(for: nextVRMEntity.entity)
            updateCameraTransform()

            apply(expression, to: nextVRMEntity)
            if motion == .none {
                applyPose(to: nextVRMEntity)
                vrmaPlayer = nil
                vrmaRetargetingContext = nil
            } else {
                loadMotion(motion, for: nextVRMEntity)
            }

            let previousVRMEntity = self.vrmEntity
            self.vrmEntity = nextVRMEntity
            previousVRMEntity?.entity.removeFromParent()
            self.currentModel = model
            self.currentExpression = expression
            self.currentMotion = motion
            self.time = 0
            resumeUpdates()
        } catch {
            errorMessage = error.localizedDescription
            print("VRM Load Error: \(error)")
        }
    }

    func setMotion(_ motion: MacExampleMotion) async {
        guard motion != currentMotion else { return }
        await loadEntity(model: currentModel,
                         expression: currentExpression,
                         motion: motion,
                         forceReload: true)
    }

    private func loadMotion(_ motion: MacExampleMotion, for vrmEntity: VRMEntity) {
        guard motion != .none else {
            vrmaPlayer = nil
            vrmaRetargetingContext = nil
            return
        }
        do {
            guard let url = Bundle.main.url(forResource: motion.rawValue,
                                            withExtension: "vrma",
                                            subdirectory: "VRMA") else {
                throw URLError(.fileDoesNotExist)
            }
            let loader = VRMAAnimationLoader()
            let vrma = try loader.load(withURL: url)
            let clip = try loader.loadClip(from: vrma)
            vrmaRetargetingContext = vrmEntity.makeVRMARetargetingContext(for: clip)
            vrmaPlayer = VRMAPlayer(clip: clip, isPlaying: true, isLooping: true, playbackSpeed: 1.0)
            if let sample = vrmaPlayer?.sample {
                vrmEntity.apply(vrmaSample: sample, retargetingContext: vrmaRetargetingContext)
            }
        } catch {
            print("VRMA load error: \(error)")
            vrmaPlayer = nil
            vrmaRetargetingContext = nil
        }
    }

    func setExpression(_ expression: MacExampleExpression) {
        guard expression != currentExpression else { return }
        currentExpression = expression
        guard let vrmEntity else { return }
        apply(expression, to: vrmEntity)
    }

    func resumeUpdates() {
        lastUpdateTime = Date()
    }

    func update() {
        guard let vrmEntity else { return }

        let now = Date()
        let deltaTime = lastUpdateTime.map { now.timeIntervalSince($0) } ?? (1.0 / 60.0)
        lastUpdateTime = now

        time += deltaTime

        let cycle = time.truncatingRemainder(dividingBy: 1.0)
        let angle: Float
        if cycle < 0.5 {
            let progress = Float(cycle) / 0.5
            angle = -0.5 * progress
        } else {
            let progress = Float(cycle - 0.5) / 0.5
            angle = -0.5 + 0.5 * progress
        }

        if var player = vrmaPlayer {
            let sample = player.update(deltaTime: Float(deltaTime))
            vrmaPlayer = player
            vrmEntity.apply(vrmaSample: sample, retargetingContext: vrmaRetargetingContext)
        }

        let rootAngle = currentMotion == .none ? currentModel.initialRotation + angle : currentModel.initialRotation
        vrmEntity.entity.transform.rotation = simd_quatf(angle: rootAngle,
                                                         axis: SIMD3<Float>(0, 1, 0))
        vrmEntity.update(at: time)
    }

    private func applyPose(to vrmEntity: VRMEntity) {
        let neck = vrmEntity.humanoid.node(for: .neck)
        let leftArm: Entity?
        let rightArm: Entity?
        switch vrmEntity.vrm {
        case .v1:
            leftArm = vrmEntity.humanoid.node(for: .leftShoulder)
            rightArm = vrmEntity.humanoid.node(for: .rightShoulder)
        case .v0:
            leftArm = vrmEntity.humanoid.node(for: .leftUpperArm)
            rightArm = vrmEntity.humanoid.node(for: .rightUpperArm)
        }

        let neckRotation = simd_quatf(angle: 20 * .pi / 180, axis: SIMD3<Float>(0, 0, 1))
        let armRotation = simd_quatf(angle: 40 * .pi / 180, axis: SIMD3<Float>(0, 0, 1))
        if let neck {
            neck.transform.rotation = neck.transform.rotation * neckRotation
        }
        if let leftArm {
            leftArm.transform.rotation = leftArm.transform.rotation * armRotation
        }
        if let rightArm {
            rightArm.transform.rotation = rightArm.transform.rotation * armRotation
        }
    }

    private func setUpLight() {
        if lightEntity == nil {
            let light = DirectionalLight()
            light.light.intensity = 1200
            rootEntity.addChild(light)
            lightEntity = light
        }
        lightEntity?.look(at: .zero,
                          from: -MacExampleLighting.realityKitDirection,
                          relativeTo: nil)
    }

    private func setUpCamera() {
        if cameraEntity == nil {
            let camera = PerspectiveCamera()
            rootEntity.addChild(camera)
            cameraEntity = camera
        }
        updateCameraTransform()
    }

    private func normalizeScale(for entity: Entity) {
        let bounds = entity.visualBounds(relativeTo: nil)
        let height = bounds.max.y - bounds.min.y
        guard height > 0.001 else { return }
        let targetHeight: Float = 2
        entity.transform.scale = SIMD3<Float>(repeating: targetHeight / height)
        updateOrbitTarget(for: entity)
    }

    private func updateOrbitTarget(for entity: Entity) {
        let bounds = entity.visualBounds(relativeTo: nil)
        orbitTarget = (bounds.min + bounds.max) * 0.5
        let extents = bounds.max - bounds.min
        let maxExtent = max(extents.x, max(extents.y, extents.z))
        orbitDistance = max(0.2, maxExtent * 1.5)
    }

    private func updateCameraTransform() {
        guard let cameraEntity else { return }
        let position = orbitTarget + SIMD3<Float>(0, 0, -orbitDistance)
        cameraEntity.look(at: orbitTarget, from: position, relativeTo: nil)
    }

    private func apply(_ expression: MacExampleExpression, to vrmEntity: VRMEntity) {
        resetExpressions(on: vrmEntity)
        vrmEntity.setExampleExpression(expression, value: 1.0)
    }

    private func resetExpressions(on vrmEntity: VRMEntity) {
        for expression in MacExampleExpression.allCases {
            vrmEntity.setExampleExpression(expression, value: 0.0)
        }
    }
}

private struct SceneKitView: NSViewRepresentable {
    let scene: SCNScene?

    func makeNSView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.autoenablesDefaultLighting = true
        sceneView.allowsCameraControl = true
        sceneView.showsStatistics = true
        sceneView.backgroundColor = .black
        return sceneView
    }

    func updateNSView(_ sceneView: SCNView, context: Context) {
        sceneView.scene = scene
    }
}

@MainActor
@Observable
final class SceneKitContentViewModel {
    private(set) var scene: VRMScene?
    private(set) var errorMessage: String?
    private var vrmNode: VRMNode?
    private var time: TimeInterval = 0
    private var lastUpdateTime: Date?
    private var currentModel: MacExampleModel = .alicia
    private var currentExpression: MacExampleExpression = .neutral
    private var currentMotion: MacExampleMotion = .none
    private var vrmaPlayer: VRMAPlayer?
    private var vrmaRetargetingContext: VRMARetargetingContext?

    let updateTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    func loadScene(model: MacExampleModel, expression: MacExampleExpression, motion: MacExampleMotion) async {
        if currentModel == model, currentMotion == motion, let vrmNode {
            apply(expression, to: vrmNode)
            currentExpression = expression
            resumeUpdates()
            return
        }

        await Task.yield()
        guard !Task.isCancelled else { return }

        do {
            errorMessage = nil

            let loader = try VRMSceneLoader(named: model.rawValue)
            let scene = try loader.loadScene()
            setUpCamera(in: scene)

            let node = scene.vrmNode
            node.eulerAngles = SCNVector3(0, CGFloat(model.initialRotation), 0)
            node.setMToonLightDirection(MacExampleLighting.direction)
            apply(expression, to: node)
            if motion == .none {
                applyPose(to: node)
                vrmaPlayer = nil
                vrmaRetargetingContext = nil
            } else {
                loadMotion(motion, for: node)
            }

            self.scene = scene
            self.vrmNode = node
            self.currentModel = model
            self.currentExpression = expression
            self.currentMotion = motion
            self.time = 0
            resumeUpdates()
        } catch {
            errorMessage = error.localizedDescription
            print("VRM Load Error: \(error)")
        }
    }

    func setMotion(_ motion: MacExampleMotion) async {
        guard motion != currentMotion else { return }
        await loadScene(model: currentModel,
                        expression: currentExpression,
                        motion: motion)
    }

    private func loadMotion(_ motion: MacExampleMotion, for vrmNode: VRMNode) {
        guard motion != .none else {
            vrmaPlayer = nil
            vrmaRetargetingContext = nil
            return
        }
        do {
            guard let url = Bundle.main.url(forResource: motion.rawValue,
                                            withExtension: "vrma",
                                            subdirectory: "VRMA") else {
                throw URLError(.fileDoesNotExist)
            }
            let loader = VRMAAnimationLoader()
            let vrma = try loader.load(withURL: url)
            let clip = try loader.loadClip(from: vrma)
            vrmaRetargetingContext = vrmNode.makeVRMARetargetingContext(for: clip)
            vrmaPlayer = VRMAPlayer(clip: clip, isPlaying: true, isLooping: true, playbackSpeed: 1.0)
            if let sample = vrmaPlayer?.sample {
                vrmNode.apply(vrmaSample: sample, retargetingContext: vrmaRetargetingContext)
            }
        } catch {
            print("VRMA load error: \(error)")
            vrmaPlayer = nil
            vrmaRetargetingContext = nil
        }
    }

    func setExpression(_ expression: MacExampleExpression) {
        guard expression != currentExpression else { return }
        currentExpression = expression
        guard let vrmNode else { return }
        apply(expression, to: vrmNode)
    }

    func resumeUpdates() {
        lastUpdateTime = Date()
    }

    func update() {
        guard let vrmNode else { return }

        let now = Date()
        let deltaTime = lastUpdateTime.map { now.timeIntervalSince($0) } ?? (1.0 / 60.0)
        lastUpdateTime = now

        time += deltaTime

        let cycle = time.truncatingRemainder(dividingBy: 1.0)
        let angle: Float
        if cycle < 0.5 {
            let progress = Float(cycle) / 0.5
            angle = -0.5 * progress
        } else {
            let progress = Float(cycle - 0.5) / 0.5
            angle = -0.5 + 0.5 * progress
        }

        if var player = vrmaPlayer {
            let sample = player.update(deltaTime: Float(deltaTime))
            vrmaPlayer = player
            vrmNode.apply(vrmaSample: sample, retargetingContext: vrmaRetargetingContext)
        }

        let rootAngle = currentMotion == .none ? currentModel.initialRotation + angle : currentModel.initialRotation
        vrmNode.eulerAngles = SCNVector3(0, CGFloat(rootAngle), 0)
        vrmNode.update(at: time)
    }

    private func applyPose(to node: VRMNode) {
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
    }

    private func setUpCamera(in scene: SCNScene) {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0.8, -1.6)
        cameraNode.rotation = SCNVector4(0, 1, 0, Float.pi)
        scene.rootNode.addChildNode(cameraNode)

        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .directional
        lightNode.light?.intensity = 1200
        lightNode.simdPosition = -MacExampleLighting.direction
        lightNode.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(lightNode)
    }

    private func apply(_ expression: MacExampleExpression, to vrmNode: VRMNode) {
        resetExpressions(on: vrmNode)
        vrmNode.setExampleExpression(expression, value: 1.0)
    }

    private func resetExpressions(on vrmNode: VRMNode) {
        for expression in MacExampleExpression.allCases {
            vrmNode.setExampleExpression(expression, value: 0.0)
        }
    }
}

private enum MacExampleLighting {
    static let direction = simd_normalize(SIMD3<Float>(0.35, 0.55, 0.75))
    static let realityKitDirection = simd_normalize(SIMD3<Float>(0, 0, -1))
}

#Preview {
    ContentView()
}

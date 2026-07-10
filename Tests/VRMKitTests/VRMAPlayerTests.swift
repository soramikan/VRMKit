import XCTest
@testable import VRMKit

class VRMAPlayerTests: XCTestCase {

    func testUpdateDoesNotAdvanceWhilePaused() {
        var player = VRMAPlayer(clip: Self.clip(), isPlaying: false)
        let sample = player.update(deltaTime: 0.5)

        XCTAssertEqual(player.currentTime, 0, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(sample.hipsTranslation).x, 0, accuracy: 1e-6)
    }

    func testUpdateAdvancesWithPlaybackSpeed() {
        var player = VRMAPlayer(clip: Self.clip(), isPlaying: true, playbackSpeed: 2)
        let sample = player.update(deltaTime: 0.25)

        XCTAssertEqual(player.currentTime, 0.5, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(sample.hipsTranslation).x, 0.5, accuracy: 1e-6)
    }

    func testLoopingUpdateWrapsAtDuration() {
        var player = VRMAPlayer(clip: Self.clip(), currentTime: 0.75, isPlaying: true, isLooping: true)
        let sample = player.update(deltaTime: 0.5)

        XCTAssertEqual(player.currentTime, 0.25, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(sample.hipsTranslation).x, 0.25, accuracy: 1e-6)
        XCTAssertTrue(player.isPlaying)
    }

    func testNonLoopingUpdateStopsAtDuration() {
        var player = VRMAPlayer(clip: Self.clip(), currentTime: 0.75, isPlaying: true, isLooping: false)
        let sample = player.update(deltaTime: 0.5)

        XCTAssertEqual(player.currentTime, 1, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(sample.hipsTranslation).x, 1, accuracy: 1e-6)
        XCTAssertFalse(player.isPlaying)
    }

    func testSeekClampsOutsideDuration() {
        var player = VRMAPlayer(clip: Self.clip())

        player.seek(to: -1)
        XCTAssertEqual(player.currentTime, 0, accuracy: 1e-6)

        player.seek(to: 2)
        XCTAssertEqual(player.currentTime, 1, accuracy: 1e-6)
    }

    func testStopPausesAndResetsTime() {
        var player = VRMAPlayer(clip: Self.clip(), currentTime: 0.5, isPlaying: true)

        player.stop()

        XCTAssertEqual(player.currentTime, 0, accuracy: 1e-6)
        XCTAssertFalse(player.isPlaying)
    }
}

private extension VRMAPlayerTests {
    static func clip() -> VRMAClip {
        return VRMAClip(
            name: "test",
            duration: 1,
            channels: [
                VRMAClip.Channel(
                    target: .node(0, path: .translation),
                    interpolation: .LINEAR,
                    keyframes: .vector3([
                        VRMAClip.Keyframe(time: 0, value: GLTF.Vector3(x: 0, y: 0, z: 0)),
                        VRMAClip.Keyframe(time: 1, value: GLTF.Vector3(x: 1, y: 0, z: 0))
                    ])
                )
            ],
            humanoidNodeBones: [0: .hips]
        )
    }
}

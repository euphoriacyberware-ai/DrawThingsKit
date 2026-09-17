//
//  CheckpointModelRateTests.swift
//  DrawThingsKit
//

import XCTest
@testable import DrawThingsKit

final class CheckpointModelRateTests: XCTestCase {

    private func checkpoint(version: String?, file: String = "model.ckpt") -> CheckpointModel {
        CheckpointModel(name: "Test", file: file, version: version)
    }

    // MARK: - framesPerSecond

    func testFramesPerSecond() {
        XCTAssertEqual(checkpoint(version: "minimax_h3").framesPerSecond, 24)
        XCTAssertEqual(checkpoint(version: "minimaxH3").framesPerSecond, 24)
        XCTAssertEqual(checkpoint(version: "longcat_video_avatar_v1.5").framesPerSecond, 25)
        XCTAssertEqual(checkpoint(version: "ltx2").framesPerSecond, 25)
        XCTAssertEqual(checkpoint(version: "ltx2.3").framesPerSecond, 25)
        XCTAssertEqual(checkpoint(version: "wan_v2.1_14b").framesPerSecond, 16)
        XCTAssertEqual(checkpoint(version: "hunyuan_video").framesPerSecond, 24)
        XCTAssertNil(checkpoint(version: "flux1").framesPerSecond)
        XCTAssertNil(checkpoint(version: nil).framesPerSecond)
    }

    // MARK: - audioSampleRate

    func testAudioSampleRate() {
        XCTAssertEqual(checkpoint(version: "minimax_h3").audioSampleRate, 32_000)
        XCTAssertEqual(checkpoint(version: "minimaxH3").audioSampleRate, 32_000)
        XCTAssertEqual(checkpoint(version: "longcat_video_avatar_v1.5").audioSampleRate, 16_000)
        XCTAssertEqual(checkpoint(version: "ltx2").audioSampleRate, 24_000)
        XCTAssertEqual(checkpoint(version: "ltx2.3").audioSampleRate, 48_000)
        XCTAssertEqual(checkpoint(version: "ltx2_3").audioSampleRate, 48_000)
        XCTAssertNil(checkpoint(version: "wan_v2.1_14b").audioSampleRate)
        XCTAssertNil(checkpoint(version: "flux1").audioSampleRate)
        XCTAssertNil(checkpoint(version: nil).audioSampleRate)
    }
}

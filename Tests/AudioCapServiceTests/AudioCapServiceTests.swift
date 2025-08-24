import XCTest
@testable import AudioCapService

final class AudioCapServiceTests: XCTestCase {
    
    @MainActor
    func testAudioCapServiceInit() {
        // Test that we can create an instance
        let service = AudioCapService()
        XCTAssertFalse(service.isRecording)
        XCTAssertNil(service.activeProcess)
        XCTAssertNil(service.errorMessage)
    }
    
    @MainActor
    func testAudioProcessControllerInit() {
        // Test that the audio process controller can be created
        let controller = AudioProcessController()
        XCTAssertFalse(controller.isRecording)
        XCTAssertFalse(controller.isAnyAudioPlaying)
    }
    
    func testAudioRecordingPermissionInit() {
        // Test that permission handler can be created
        let permission = AudioRecordingPermission()
        // Status should be either unknown, authorized, or denied
        XCTAssertTrue([.unknown, .authorized, .denied].contains(permission.status))
    }
    
    func testConstants() {
        // Test that constants are defined
        XCTAssertEqual(kAppSubsystem, "codes.ankit.AudioCapService")
    }
}
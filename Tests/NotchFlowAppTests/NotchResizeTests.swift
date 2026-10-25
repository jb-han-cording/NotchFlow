import XCTest
import NotchFlowCore
@testable import NotchFlow

final class NotchResizeTests: XCTestCase {
    func testModuleRefreshCannotStealHoverAnimation() {
        var policy = NotchResizePolicy()
        XCTAssertFalse(policy.shouldAnimate(state: .collapsed, requested: false, inFlight: false))
        // The module refresh was enqueued before the hover subscriber, but
        // both callbacks now see the new hover state. This used to snap open.
        XCTAssertTrue(policy.shouldAnimate(state: .hover, requested: false, inFlight: false))
        XCTAssertTrue(policy.shouldAnimate(state: .hover, requested: true, inFlight: true))
        XCTAssertFalse(policy.shouldAnimate(state: .hover, requested: false, inFlight: false))
    }

    func testRetargetDuringExpansionKeepsAnimation() {
        var policy = NotchResizePolicy()
        _ = policy.shouldAnimate(state: .collapsed, requested: false, inFlight: false)
        XCTAssertTrue(policy.shouldAnimate(state: .hover, requested: true, inFlight: false))
        // Content measurements/settings can change the target mid-animation.
        XCTAssertTrue(policy.shouldAnimate(state: .hover, requested: false, inFlight: true))
        XCTAssertTrue(policy.shouldAnimate(state: .collapsed, requested: false, inFlight: true))
    }

    func testInitialLayoutAndIdleRefreshStayImmediate() {
        var policy = NotchResizePolicy()
        XCTAssertFalse(policy.shouldAnimate(state: .expanded, requested: false, inFlight: false))
        XCTAssertFalse(policy.shouldAnimate(state: .expanded, requested: false, inFlight: false))
        XCTAssertTrue(policy.shouldAnimate(state: .expanded, requested: true, inFlight: false))
    }
}

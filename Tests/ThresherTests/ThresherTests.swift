import XCTest
import Foundation
import Combine
@testable import Thresher

final class ThresherTests: XCTestCase {

    func test_schedule() {
        let scheduler = TestScheduler()

        var didRun = false
        scheduler.schedule {
            didRun = true
        }

        scheduler.advance()

        XCTAssert(didRun)
    }

    func test_schedule_after_advance_by() {
        let scheduler = TestScheduler()

        var didRun = false
        let now = DispatchTime.now()
        scheduler.schedule(after: TestScheduler.SchedulerTimeType(now + 100), tolerance: 1, options: nil) { didRun = true }

        scheduler.advance(by: 101)

        XCTAssert(didRun)
    }

    func test_schedule_after_advance_to() {
        let scheduler = TestScheduler()

        var didRun = false
        let now = DispatchTime.now()
        scheduler.schedule(after: TestScheduler.SchedulerTimeType(now + 100), tolerance: 1, options: nil) { didRun = true }

        scheduler.advance(to: TestScheduler.SchedulerTimeType(now + 101))

        XCTAssert(didRun)
    }

    func test_schedule_in_order() {
        let scheduler = TestScheduler()

        var ints: [Int] = []
        let now = DispatchTime.now()
        scheduler.schedule(after: TestScheduler.SchedulerTimeType(now + 200), tolerance: 1, options: nil) { ints.append(200) }
        scheduler.schedule(after: TestScheduler.SchedulerTimeType(now + 100), tolerance: 1, options: nil) { ints.append(100) }
        scheduler.schedule(after: TestScheduler.SchedulerTimeType(now + 300), tolerance: 1, options: nil) { ints.append(300) }

        scheduler.run()

        XCTAssert(ints == [100, 200, 300])
    }

    // this test currently failing - needs investigation
    func _test_passthrough_subject() {
        let scheduler = TestScheduler()
        let subject = PassthroughSubject<Int, Never>()

        var ints: [Int] = []

        let cancel = subject
            .receive(on: scheduler)
            .sink { value in
                print(value)
                ints.append(value)
            }

        subject.send(1)
        subject.send(2)
        XCTAssert(ints.isEmpty)

        scheduler.run()
        XCTAssert(ints == [1, 2])

        cancel.cancel()
    }

    static var allTests = [
        ("test_schedule", test_schedule),
        ("test_schedule_after_advance_by", test_schedule_after_advance_by),
        ("test_schedule_after_advance_to", test_schedule_after_advance_to),
        ("test_schedule_in_order", test_schedule_in_order),
    ]
}

import XCTest
import Foundation
import Combine
@testable import Thresher

final class ThresherTests: XCTestCase {
    var directory: URL {
        return URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
    }

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

        XCTAssertEqual(ints, [100, 200, 300])
    }

    func test_schedule_nested() {
        let scheduler = TestScheduler()

        var ints: [Int] = []
        var cancellables: [AnyCancellable] = []

        scheduler.schedule {
            ints.append(1)
        }
        scheduler.schedule(after: scheduler.now.advanced(by: .seconds(10))) {
            ints.append(2)
            scheduler.schedule(after: scheduler.now.advanced(by: .seconds(20))) {
                ints.append(3)
            }
        }
        scheduler.schedule {
            ints.append(4)
        }
        scheduler.schedule(after: scheduler.now.advanced(by: .seconds(5)), interval: .seconds(10)) {
            ints.append(5) // 10 sec interval
        }
        .store(in: &cancellables)

        scheduler.advance(by: 30)

        XCTAssertEqual(ints, [1, 4, 5, 2, 5, 5, 3])
    }

    func test_passthrough_subject() {
        let scheduler = TestScheduler()
        let subject = PassthroughSubject<Int, Never>()

        var ints: [Int] = []
        var cancellables: [AnyCancellable] = []

        subject
            .receive(on: scheduler)
            .sink { value in
                print(value)
                ints.append(value)
            }
            .store(in: &cancellables)

        // the act of subscription is also scheduled on the scheduler
        // so we need to advance the scheduler to make sure the subription
        // has occured
        scheduler.advance()

        subject.send(1)
        subject.send(2)
        // the subscriber hasn't received any values yet
        // as it hasn't been scheduled
        XCTAssert(ints.isEmpty)

        scheduler.run()
        XCTAssertEqual(ints, [1, 2])
    }

    func test_passthrough_subject_single_values() {
        let scheduler = TestScheduler()
        let subject = PassthroughSubject<Int, Never>()

        var ints: [Int] = []
        var cancellables: [AnyCancellable] = []

        subject
            .receive(on: scheduler)
            .sink { value in
                ints.append(value)
            }
            .store(in: &cancellables)

        // the act of subscription is also scheduled on the scheduler
        // so we need to advance the scheduler to make sure the subription
        // has occured
        scheduler.advance()

        subject.send(1)
        scheduler.advance()
        XCTAssertEqual(ints, [1])

        subject.send(2)
        scheduler.advance()
        XCTAssertEqual(ints, [1, 2])
    }

    func test_image_loading() {
        let url = directory.appendingPathComponent("thresher.jpg")
        let scheduler = TestScheduler()
        var image: UIImage? = nil
        var cancellables: [AnyCancellable] = []

        loadImage(from: url)
            .receive(on: scheduler)
            .sink { image = $0 }
            .store(in: &cancellables)

        // schedule the subscription
        scheduler.advance()

        // wait for URLSession dataTaskPublisher to do its thing
        wait(seconds: 2)

        // process subscription results
        scheduler.advance()
        XCTAssertNotNil(image)
    }

    private func loadImage(from url: URL) -> AnyPublisher<UIImage?, Never> {
        return URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .map(UIImage.init(data:))
            .catch { _ in Empty<UIImage?, Never>() }
            .eraseToAnyPublisher()
    }

    private func wait(seconds: TimeInterval) {
        let expectation = XCTestExpectation(description: "waiting")
        DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: seconds + 1)
    }

    static var allTests = [
        ("test_schedule", test_schedule),
        ("test_schedule_after_advance_by", test_schedule_after_advance_by),
        ("test_schedule_after_advance_to", test_schedule_after_advance_to),
        ("test_schedule_in_order", test_schedule_in_order),
        ("test_passthrough_subject", test_passthrough_subject),
        ("test_passthrough_subject_single_values", test_passthrough_subject_single_values),
        ("test_image_loading", test_image_loading),
    ]
}

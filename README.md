# Thresher

Thresher is a Swift µFramework for synchronously  testing asynchronous code using Apple's [Combine](https://developer.apple.com/documentation/combine) framework.

## Installation

### Swift Package Manager (requires Xcode 11 or higher)

`File -> Swift Packages -> Add Package Dependency` and use the repository URL (`https://github.com/mluisbrown/Thresher`).

### Manual Installation
Copy the `TestScheduler.swift` file into your project.

## Usage

Normally, `Publisher` values are delivered to a `Subscriber` on the thread on which they are sent. However, you can specify an alternate `Scheduler` on which a `Publisher`'s values should be sent to the `Subscriber` using [`receive(on:)`](https://developer.apple.com/documentation/combine/publisher/3204743-receive).  For example, if you want the results of a network request to be delivered to subscribers on the main thread:

```swift
func loadImage(from url: URL) -> AnyPublisher<UIImage?, Never> {
    return URLSession.shared.dataTaskPublisher(for: url)
        .map(\.data)
        .map(UIImage.init(data:))
        .catch { _ in Empty<UIImage?, Never>() }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
}
```

`DispatchQueue` conforms to the Combine `Scheduler` protocol. 

Asynchronous code like the above snippet is fiddly to test. You have to use `XCTestExpectation`, dispatch your test code asynchronously and then wait for your expectation to be fulfilled:

```swift
func test_image_loading() {
    let url = URL(fileURLWithPath: "test-image.png")
    let expectation = XCTestExpectation()

    DispatchQueue.main.async {
        _ = loadImage(from: url)
            .sink { image in
                XCTAssertNotNil(image)
                expectation.fulfill()
            }
    }

    waitForExpectations(timeout: 2)
}
```

`TestScheduler` allows you to test asynchronous code in a synchronous way, which makes it much easier to write tests. 

You need to add a `receive(on:)` call in your test code, so your testing function becomes:

```swift
func test_image_loading() {
    let url = URL(fileURLWithPath: "test-image.png")
    let scheduler = TestScheduler()
    var image: UIImage? = nil

    let _ = loadImage(from: url)
        .receive(on: scheduler)
        .sink { image = $0 }

    // schedule the subscription
    scheduler.advance()

    // wait for URLSession dataTaskPublisher to do its thing
    wait(seconds: 2)

    // process subscription results
    scheduler.advance()
    XCTAssertNotNil(image)
}

func wait(seconds: TimeInterval) {
    let expectation = XCTestExpectation(description: "waiting")
    DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
        expectation.fulfill()
    }
    wait(for: [expectation], timeout: seconds + 1)
}
```
Whilst this code is actually more verbose than the async code it is written in an synchronous manner: 
* create the publisher and setup the subcription
* advance the scheduler so the subscription closure runs
* check the results

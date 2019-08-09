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

    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        loadImage(from: url)
            .sink { image in
                XCTAssertNotNil(image)
                expectation.fulfill()
            }
    }

    waitForExpectations(timeout: 2)
}
```

`TestScheduler` allows you to test asynchronous code in a synchronous way, which makes it much easier to write tests. It *does* require that you write your code that returns `Publisher`s to require a `Scheduler` to be specified:

```swift
func loadImage(
    from url: URL,
    on scheduler: Scheduler
) -> AnyPublisher<UIImage?, Never> {
    return URLSession.shared.dataTaskPublisher(for: url)
        .map(\.data)
        .map(UIImage.init(data:))
        .catch { _ in Empty<UIImage?, Never>() }
        .receive(on: scheduler)
        .eraseToAnyPublisher()
}
```

Then your testing function becomes:

```swift
func test_image_loading() {
    let url = URL(fileURLWithPath: "test-image.png")
    let scheduler = TestScheduler()
    var image: UIImage? = nil

    _ = loadImage(from: url, on: scheduler)
        .sink {  image = $0 }

    // this will cause all actions currently queued to
    // run, and advance the scheduler clock by 1 nanosecond
    scheduler.advance()

    XCTAssertNotNil(image)
}
```
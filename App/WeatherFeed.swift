import AppCore
import CoreLocation
import os

@MainActor
final class WeatherFeed: NSObject, CLLocationManagerDelegate {
    enum State: Equatable {
        case loading
        case needsPermission
        case denied
        case notFound(String)
        case failed
        case ready(Weather)
    }

    private struct Reading {
        let city: String
        let time: Date
        let weather: Weather
    }

    private static let stale: TimeInterval = 900

    var onChange: (() -> Void)?
    private(set) var state = State.loading {
        didSet {
            if state != oldValue { onChange?() }
        }
    }

    private let logger = Log.logger("Weather")
    private let locations = CLLocationManager()
    private var located: CheckedContinuation<CLLocation, any Error>?
    private var fetching: (city: String, task: Task<Void, Never>)?
    private var fetched: Reading?
    private var described: String?

    private var blocked: State? {
        switch locations.authorizationStatus {
        case .notDetermined: .needsPermission
        case .denied, .restricted: .denied
        default: nil
        }
    }

    override init() {
        super.init()
        locations.delegate = self
    }

    func refresh(for place: String) {
        let city = place.trimmingCharacters(in: .whitespacesAndNewlines)
        if city.isEmpty, let reason = blocked {
            fetching?.task.cancel()
            fetching = nil
            fetched = nil
            described = nil
            state = reason
            return
        }
        if let fetched, fetched.city == city, -fetched.time.timeIntervalSinceNow < Self.stale {
            fetching?.task.cancel()
            fetching = nil
            described = city
            state = .ready(fetched.weather)
            return
        }
        if let fetching {
            guard fetching.city != city else { return }
            fetching.task.cancel()
        }
        fetching = (city, Task { await fetch(city) })
        if described != city {
            described = city
            state = .loading
        }
    }

    func requestPermission() {
        locations.requestWhenInUseAuthorization()
    }

    func locationManager(_: CLLocationManager, didUpdateLocations found: [CLLocation]) {
        guard let location = found.last else { return }
        located?.resume(returning: location)
        located = nil
    }

    func locationManager(_: CLLocationManager, didFailWithError error: any Error) {
        located?.resume(throwing: error)
        located = nil
    }

    private func fetch(_ city: String) async {
        do {
            guard let place = try await city.isEmpty ? here() : Weather.place(named: city) else {
                finish(city, .notFound(city))
                return
            }
            let weather = try await Weather.forecast(at: place)
            fetched = Reading(city: city, time: .now, weather: weather)
            finish(city, .ready(weather))
        } catch {
            guard !Task.isCancelled else { return }
            logger.error("Weather failed: \(error, privacy: .public)")
            finish(city, fetched?.city == city ? state : .failed)
        }
    }

    private func finish(_ city: String, _ result: State) {
        guard !Task.isCancelled, fetching?.city == city else { return }
        fetching = nil
        state = result
    }

    private func here() async throws -> Weather.Place {
        let location = try await withCheckedThrowingContinuation { continuation in
            located?.resume(throwing: CancellationError())
            located = continuation
            locations.requestLocation()
        }
        return Weather.Place(
            latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }
}

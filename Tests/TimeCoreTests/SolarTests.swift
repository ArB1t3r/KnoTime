import XCTest
@testable import TimeCore

final class SolarTests: XCTestCase {
    func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    func testAustinAtFiveAMIsNight() {
        let austin = CityLocations.named["Austin, US"]!
        XCTAssertFalse(Solar.isDaylight(at: date("2026-10-30T10:30:00Z"), location: austin))
        XCTAssertTrue(Solar.isDaylight(at: date("2026-10-30T17:00:00Z"), location: austin))
    }
    func testWuhanDayAndNight() {
        let location = CityLocations.named["Wuhan, CN"]!
        XCTAssertFalse(Solar.isDaylight(at: date("2026-10-29T22:00:00Z"), location: location))
        XCTAssertTrue(Solar.isDaylight(at: date("2026-10-29T23:00:00Z"), location: location))
        XCTAssertTrue(Solar.isDaylight(at: date("2026-10-30T04:00:00Z"), location: location))
        XCTAssertFalse(Solar.isDaylight(at: date("2026-10-30T10:00:00Z"), location: location))
    }
    func testSameTimeDifferentSeason() {
        let london = CityLocations.named["London, UK"]!
        XCTAssertTrue(Solar.isDaylight(at: date("2026-06-21T04:00:00Z"), location: london))
        XCTAssertFalse(Solar.isDaylight(at: date("2026-12-21T04:00:00Z"), location: london))
        XCTAssertTrue(Solar.isDaylight(at: date("2026-06-21T20:00:00Z"), location: london))
        XCTAssertFalse(Solar.isDaylight(at: date("2026-12-21T20:00:00Z"), location: london))
    }
    func testPolarDayAndNightWithoutInventingSunrise() {
        let tromso = Coordinates(69.6492, 18.9553)
        for hour in [0, 6, 12, 18] {
            XCTAssertTrue(Solar.isDaylight(at: date(String(format: "2026-06-21T%02d:00:00Z", hour)), location: tromso))
            XCTAssertFalse(Solar.isDaylight(at: date(String(format: "2026-12-21T%02d:00:00Z", hour)), location: tromso))
        }
    }
    func testDateLineAndFiniteAtPoles() {
        let d = date("2026-03-20T12:00:00Z")
        XCTAssertEqual(Solar.elevation(at: d, location: Coordinates(0, -180)), Solar.elevation(at: d, location: Coordinates(0, 180)), accuracy: 0.000001)
        for lat in [-90.0, 90.0] { XCTAssertTrue(Solar.elevation(at: d, location: Coordinates(lat, 0)).isFinite) }
    }
    func testCityCoordinatesAreNotMerelyTimeZoneCoordinates() {
        XCTAssertNotEqual(CityLocations.named["Wuhan, CN"], CityLocations.named["Shanghai, CN"])
        XCTAssertNotEqual(CityLocations.named["Austin, US"], CityLocations.named["Chicago, US"])
        for option in CityCatalog.all {
            let coordinate = CityLocations.resolve(name: option.name, zone: option.zone)
            XCTAssertNotNil(coordinate, option.name)
            if let coordinate { XCTAssertTrue((-90...90).contains(coordinate.latitude)); XCTAssertTrue((-180...180).contains(coordinate.longitude)) }
        }
    }
    func testLegacyCityDecodingAndLocationPersistence() throws {
        let data = "{\"id\":\"0C4A665D-9E3F-4FA8-87E1-D684C93D5764\",\"name\":\"Wuhan, CN\",\"zone\":\"Asia/Shanghai\",\"pinned\":true,\"workEnabled\":true,\"workStart\":540,\"workEnd\":1080}".data(using: .utf8)!
        let old = try JSONDecoder().decode(City.self, from: data)
        XCTAssertNil(old.location)
        var city = City(name: "Wuhan, CN", zone: "Asia/Shanghai")
        city.name = "Home"
        let restored = try JSONDecoder().decode(City.self, from: JSONEncoder().encode(city))
        XCTAssertEqual(restored.location, CityLocations.named["Wuhan, CN"])
    }
}

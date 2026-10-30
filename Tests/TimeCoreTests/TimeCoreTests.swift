import XCTest
@testable import TimeCore

final class TimeCoreTests: XCTestCase {
    func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    func city(_ zone: String, _ start: Int = 540, _ end: Int = 1080) -> City { City(name: zone, zone: zone, workEnabled: true, workStart: start, workEnd: end) }
    func duration(_ ranges: [ClosedRange<Double>], day: DateInterval) -> Double { ranges.reduce(0) { $0 + ($1.upperBound - $1.lowerBound) * day.duration } }
    func testWallClockInputNeverUsesSystemTimeZone() {
        XCTAssertEqual(TimeMath.parseClock("09:00"), 540)
        XCTAssertEqual(TimeMath.parseClock(" 9:30 "), 570)
        XCTAssertEqual(TimeMath.parseClock("23:59"), 1439)
        for invalid in ["24:00", "09:60", "9:5", "-1:00", "9", "", "09:00:00", "+9:00"] { XCTAssertNil(TimeMath.parseClock(invalid)) }
        for minute in 0..<1440 { XCTAssertEqual(TimeMath.parseClock(TimeMath.clockString(minute)), minute) }
    }
    func testOfficeHoursAreHalfOpen() {
        XCTAssertFalse(TimeMath.contains(539, start: 540, end: 1080))
        XCTAssertTrue(TimeMath.contains(540, start: 540, end: 1080))
        XCTAssertTrue(TimeMath.contains(1079, start: 540, end: 1080))
        XCTAssertFalse(TimeMath.contains(1080, start: 540, end: 1080))
    }
    func testOvernight() {
        for minute in [1320, 1439, 0, 359] { XCTAssertTrue(TimeMath.contains(minute, start: 1320, end: 360)) }
        for minute in [360, 900, 1319] { XCTAssertFalse(TimeMath.contains(minute, start: 1320, end: 360)) }
        XCTAssertFalse(TimeMath.contains(540, start: 540, end: 540))
    }
    func testNoSelectionHasNoHighlight() {
        let day = TimeMath.day(date("2026-01-15T12:00:00Z"), zone: .gmt)
        XCTAssertTrue(TimeMath.overlap(cities: City.defaults, day: day).isEmpty)
    }
    func testTwoCitiesIntersectRatherThanUnion() {
        let day = TimeMath.day(date("2026-01-15T12:00:00Z"), zone: .gmt)
        let ranges = TimeMath.overlap(cities: [city("Europe/London"), city("Asia/Shanghai")], day: day)
        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].lowerBound, 9.0 / 24, accuracy: 0.00001)
        XCTAssertEqual(ranges[0].upperBound, 10.0 / 24, accuracy: 0.00001)
        XCTAssertTrue(TimeMath.overlap(cities: [city("America/New_York"), city("Asia/Shanghai")], day: day).isEmpty)
    }
    func testMidnightSplitsBand() {
        let day = TimeMath.day(date("2026-01-15T12:00:00Z"), zone: .gmt)
        let ranges = TimeMath.overlap(cities: [city("Etc/UTC", 1320, 360)], day: day)
        XCTAssertEqual(ranges.count, 2)
        XCTAssertEqual(duration(ranges, day: day), 8 * 3600, accuracy: 0.001)
    }
    func testQuarterHourZone() {
        let day = TimeMath.day(date("2026-01-15T12:00:00Z"), zone: .gmt)
        let ranges = TimeMath.overlap(cities: [city("Asia/Kathmandu")], day: day)
        XCTAssertEqual(ranges[0].lowerBound * 1440, 195, accuracy: 0.001)
        XCTAssertEqual(duration(ranges, day: day), 9 * 3600, accuracy: 0.001)
    }
    func testSpringDSTDayAndMissingHour() {
        let zone = TimeZone(identifier: "America/New_York")!
        let day = TimeMath.day(date("2026-03-08T16:00:00Z"), zone: zone)
        XCTAssertEqual(day.duration, 23 * 3600)
        let ranges = TimeMath.overlap(cities: [city(zone.identifier, 60, 180)], day: day)
        XCTAssertEqual(duration(ranges, day: day), 3600, accuracy: 0.001)
        XCTAssertEqual(TimeMath.minute(TimeMath.date(at: 1, in: day), zone: zone), 1439)
    }
    func testFallDSTIncludesBothRepeatedHours() {
        let zone = TimeZone(identifier: "America/New_York")!
        let day = TimeMath.day(date("2026-11-01T16:00:00Z"), zone: zone)
        XCTAssertEqual(day.duration, 25 * 3600)
        let ranges = TimeMath.overlap(cities: [city(zone.identifier, 60, 180)], day: day)
        XCTAssertEqual(duration(ranges, day: day), 3 * 3600, accuracy: 0.001)
    }
    func testPreviousNextDaysAcrossYear() {
        let d = date("2026-12-31T20:00:00Z")
        XCTAssertEqual(TimeMath.dayDifference(d, cityZone: TimeZone(identifier: "Asia/Tokyo")!, referenceZone: .gmt), 1)
        XCTAssertEqual(TimeMath.dayDifference(d, cityZone: .gmt, referenceZone: TimeZone(identifier: "Asia/Tokyo")!), -1)
    }
    func testSliderEndpointsAndClamping() {
        let day = TimeMath.day(date("2026-01-15T12:00:00Z"), zone: .gmt)
        XCTAssertEqual(TimeMath.date(at: -1, in: day), day.start)
        XCTAssertEqual(TimeMath.date(at: 2, in: day), day.end.addingTimeInterval(-60))
        XCTAssertEqual(TimeMath.position(day.start.addingTimeInterval(3600), in: day), 1.0 / 24, accuracy: 0.00001)
    }
    func testStableIDsSurviveRenameAndCodable() throws {
        var a = city("Europe/London"), b = city("Europe/London")
        a.name = "Team"; b.name = "Team"
        XCTAssertNotEqual(a.id, b.id)
        let roundTrip = try JSONDecoder().decode([City].self, from: JSONEncoder().encode([a, b]))
        XCTAssertEqual(roundTrip, [a, b])
    }
    func testOfflineSearchAliasesAndTimeZones() {
        XCTAssertEqual(CityCatalog.search("武汉").first?.name, "Wuhan, CN")
        XCTAssertEqual(CityCatalog.search("London").first?.zone, "Europe/London")
        XCTAssertFalse(CityCatalog.search("Kathmandu").isEmpty)
        XCTAssertTrue(CityCatalog.search("  ").isEmpty)
    }
    func testInvalidWorkingHoursAndZonesRejected() {
        XCTAssertFalse(city("No/Such_Zone").valid)
        XCTAssertFalse(city("Europe/London", 540, 540).valid)
        XCTAssertFalse(city("Europe/London", -1, 540).valid)
    }
    func testIntersectionCommutativeAndDisabledCitiesIgnored() {
        let day = TimeMath.day(date("2026-07-15T12:00:00Z"), zone: .gmt)
        let a = city("Europe/London"), b = city("Asia/Shanghai")
        let ignored = City(name: "New York", zone: "America/New_York")
        XCTAssertEqual(TimeMath.overlap(cities: [a, b], day: day), TimeMath.overlap(cities: [b, a, ignored], day: day))
    }
}

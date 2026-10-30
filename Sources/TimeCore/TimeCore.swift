import Foundation

public struct City: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var zone: String
    public var location: Coordinates?
    public var pinned: Bool
    public var workEnabled: Bool
    public var workStart: Int
    public var workEnd: Int
    public init(id: UUID = UUID(), name: String, zone: String, pinned: Bool = false, workEnabled: Bool = false, workStart: Int = 540, workEnd: Int = 1080) {
        self.id = id; self.name = name; self.zone = zone; self.pinned = pinned
        self.location = CityLocations.resolve(name: name, zone: zone)
        self.workEnabled = workEnabled; self.workStart = workStart; self.workEnd = workEnd
    }
    public var timeZone: TimeZone { TimeZone(identifier: zone) ?? .gmt }
    public var valid: Bool { TimeZone(identifier: zone) != nil && (0..<1440).contains(workStart) && (0..<1440).contains(workEnd) && workStart != workEnd && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    public static let defaults = [City(name: "Austin, US", zone: "America/Chicago"), City(name: "Menlo Park, US", zone: "America/Los_Angeles"), City(name: "Wuhan, CN", zone: "Asia/Shanghai", pinned: true), City(name: "New York, US", zone: "America/New_York")]
}

public enum TimeMath {
    public static func parseClock(_ value: String) -> Int? {
        let parts = value.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, (1...2).contains(parts[0].count), parts[1].count == 2,
              parts.allSatisfy({ $0.allSatisfy({ $0.isASCII && $0.isNumber }) }),
              let hour = Int(parts[0]), let minute = Int(parts[1]), (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        return hour * 60 + minute
    }
    public static func clockString(_ minute: Int) -> String { String(format: "%02d:%02d", minute / 60, minute % 60) }

    public static func calendar(_ zone: TimeZone) -> Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = zone; return c
    }
    public static func minute(_ date: Date, zone: TimeZone) -> Int {
        let c = calendar(zone); return c.component(.hour, from: date) * 60 + c.component(.minute, from: date)
    }
    /// The slider is the actual local calendar day: 23, 24, or 25 hours at DST boundaries.
    public static func day(_ date: Date, zone: TimeZone) -> DateInterval {
        calendar(zone).dateInterval(of: .day, for: date)!
    }
    public static func position(_ date: Date, in day: DateInterval) -> Double {
        min(1, max(0, date.timeIntervalSince(day.start) / day.duration))
    }
    public static func date(at position: Double, in day: DateInterval) -> Date {
        let seconds = min(day.duration - 60, max(0, floor(position * day.duration / 60) * 60))
        return day.start.addingTimeInterval(seconds)
    }
    public static func isWorking(_ date: Date, city: City) -> Bool {
        contains(minute(date, zone: city.timeZone), start: city.workStart, end: city.workEnd)
    }
    public static func contains(_ minute: Int, start: Int, end: Int) -> Bool {
        guard start != end else { return false }
        return start < end ? minute >= start && minute < end : minute >= start || minute < end
    }
    /// Half-open, minute-accurate intervals on the reference day; never add a fixed UTC offset.
    public static func overlap(cities: [City], day: DateInterval) -> [ClosedRange<Double>] {
        let selected = cities.filter(\.workEnabled)
        guard !selected.isEmpty else { return [] }
        let count = Int(day.duration / 60)
        var result: [ClosedRange<Double>] = []; var beginning: Int?
        let calendars = selected.map { calendar($0.timeZone) }
        for i in 0...count {
            let time = day.start.addingTimeInterval(Double(i * 60))
            let matches = i < count && selected.indices.allSatisfy { index in
                let c = calendars[index], city = selected[index]
                let m = c.component(.hour, from: time) * 60 + c.component(.minute, from: time)
                return contains(m, start: city.workStart, end: city.workEnd)
            }
            if matches && beginning == nil { beginning = i }
            if !matches, let start = beginning {
                result.append(Double(start) / Double(count)...Double(i) / Double(count)); beginning = nil
            }
        }
        return result
    }
    public static func dayDifference(_ date: Date, cityZone: TimeZone, referenceZone: TimeZone) -> Int {
        let local = calendar(referenceZone).dateComponents([.year, .month, .day], from: date)
        let remote = calendar(cityZone).dateComponents([.year, .month, .day], from: date)
        let utc = calendar(.gmt)
        return utc.dateComponents([.day], from: utc.date(from: local)!, to: utc.date(from: remote)!).day ?? 0
    }
}

public struct CityOption: Identifiable, Sendable {
    public var id: String { name + zone }
    public let name: String
    public let zone: String
    public let keywords: String
    public init(_ name: String, _ zone: String, _ keywords: String = "") { self.name = name; self.zone = zone; self.keywords = keywords }
}
public enum CityCatalog {
    public static let featured: [CityOption] = [
        .init("Austin, US", "America/Chicago", "奥斯汀 Texas"), .init("Menlo Park, US", "America/Los_Angeles", "门洛帕克 Silicon Valley"),
        .init("Wuhan, CN", "Asia/Shanghai", "武汉"), .init("Beijing, CN", "Asia/Shanghai", "北京 Peking"), .init("Shanghai, CN", "Asia/Shanghai", "上海"), .init("Shenzhen, CN", "Asia/Shanghai", "深圳"),
        .init("New York, US", "America/New_York", "纽约 NYC"), .init("San Francisco, US", "America/Los_Angeles", "旧金山 SF"), .init("Los Angeles, US", "America/Los_Angeles", "洛杉矶 LA"),
        .init("Seattle, US", "America/Los_Angeles", "西雅图"), .init("Chicago, US", "America/Chicago", "芝加哥"), .init("London, UK", "Europe/London", "伦敦"),
        .init("Berlin, DE", "Europe/Berlin", "柏林"), .init("Paris, FR", "Europe/Paris", "巴黎"), .init("Tokyo, JP", "Asia/Tokyo", "东京"),
        .init("Singapore, SG", "Asia/Singapore", "新加坡"), .init("Hong Kong, HK", "Asia/Hong_Kong", "香港"), .init("Taipei, TW", "Asia/Taipei", "台北"),
        .init("Seoul, KR", "Asia/Seoul", "首尔"), .init("Sydney, AU", "Australia/Sydney", "悉尼"), .init("Melbourne, AU", "Australia/Melbourne", "墨尔本"),
        .init("Dubai, AE", "Asia/Dubai", "迪拜"), .init("Mumbai, IN", "Asia/Kolkata", "孟买 Bombay"), .init("New Delhi, IN", "Asia/Kolkata", "新德里"),
        .init("Bengaluru, IN", "Asia/Kolkata", "Bangalore 班加罗尔"), .init("Toronto, CA", "America/Toronto", "多伦多"), .init("Vancouver, CA", "America/Vancouver", "温哥华")
    ]
    public static let all: [CityOption] = {
        let extras = TimeZone.knownTimeZoneIdentifiers.filter { $0.contains("/") && !$0.hasPrefix("Etc/") }.compactMap { zone -> CityOption? in
            guard CityLocations.zones[zone] != nil else { return nil }
            let name = String(zone.split(separator: "/").last!).replacingOccurrences(of: "_", with: " ")
            if featured.contains(where: { $0.zone == zone && $0.name.hasPrefix(name + ",") }) { return nil }
            return CityOption(name, zone, zone)
        }
        return featured + extras
    }()
    public static func search(_ query: String) -> [CityOption] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        return Array(all.filter { ($0.name + " " + $0.keywords + " " + $0.zone).localizedStandardContains(q) }.prefix(8))
    }
}

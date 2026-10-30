import AppKit
import SwiftUI
import ServiceManagement
import TimeCore

struct Preferences: Codable {
    var cities = City.defaults
    var twentyFour = true
    var compact = true
    var showDate = false
    var collapsed = true
}

@MainActor final class ClockStore: ObservableObject {
    @Published var preferences: Preferences
    @Published var now = Date()
    @Published var preview: Date?
    @Published var visible = false
    @Published var query = ""
    @Published var ranges: [ClosedRange<Double>] = []
    @Published var notice: String?
    @Published var loginEnabled = SMAppService.mainApp.status == .enabled
    var statusChanged: (() -> Void)?
    var showWorkingHours: ((City, NSRect) -> Void)?
    var sizeChanged: (() -> Void)?
    private var timer: Timer?
    private var noticeTask: Task<Void, Never>?
    private var undoCity: (City, Int)?
    private var formatters: [String: DateFormatter] = [:]
    private var overlapKey = ""
    private let defaults: UserDefaults
    var referenceZone = TimeZone.current
    var displayDate: Date { preview ?? now }
    var selected: [City] { preferences.cities.filter(\.workEnabled) }
    var day: DateInterval { TimeMath.day(now, zone: referenceZone) }
    var position: Double { TimeMath.position(displayDate, in: day) }
    var inOverlap: Bool { !selected.isEmpty && selected.allSatisfy { TimeMath.isWorking(displayDate, city: $0) } }
    var results: [CityOption] { CityCatalog.search(query) }
    @Published var availableHeight: CGFloat = 800
    var searchHeight: CGFloat { query.isEmpty ? 0 : CGFloat(max(1, min(3, results.count))) * 43 + 12 }
    private var fixedHeight: CGFloat { 52 + searchHeight + 61 + 28 + (preferences.collapsed ? 0 : 316) + (notice == nil ? 0 : 34) }
    var listHeight: CGFloat { min(CGFloat(max(1, min(8, preferences.cities.count))) * 42 + 20, max(62, availableHeight - fixedHeight)) }
    var height: CGFloat { fixedHeight + listHeight }
    init() {
        defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "preferences.v1"), let loaded = try? JSONDecoder().decode(Preferences.self, from: data) {
            var safe = loaded
            var seen = Set<UUID>()
            safe.cities = loaded.cities.filter { $0.valid && seen.insert($0.id).inserted }
            for i in safe.cities.indices where safe.cities[i].location == nil {
                safe.cities[i].location = CityLocations.resolve(name: safe.cities[i].name, zone: safe.cities[i].zone)
            }
            preferences = safe
        } else { preferences = Preferences() }
        scheduleMinute()
        NotificationCenter.default.addObserver(forName: .NSSystemTimeZoneDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshEnvironment() }
        }
        NotificationCenter.default.addObserver(forName: NSLocale.currentLocaleDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshEnvironment() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshEnvironment() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.timer?.invalidate() }
        }
    }
    func refreshEnvironment() {
        referenceZone = .current; formatters.removeAll(); overlapKey = ""; preview = nil; now = Date()
        updateRanges(); statusChanged?(); scheduleMinute()
    }
    private func scheduleMinute() {
        timer?.invalidate()
        let delay = 60 - Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 60)
        let next = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.visible { self.now = Date(); self.updateRanges() }; self.statusChanged?(); self.scheduleMinute()
            }
        }
        next.tolerance = 0.5
        RunLoop.main.add(next, forMode: .common); timer = next
    }
    func open() { now = Date(); preview = nil; visible = true; updateRanges(); loginEnabled = SMAppService.mainApp.status == .enabled }
    func close() { preview = nil; visible = false; query = ""; sizeChanged?() }
    func scrub(_ value: Double) {
        let date = TimeMath.date(at: value, in: day)
        if preview != date { preview = date }
    }
    func snap() { preview = nil; now = Date() }
    func save() {
        if let data = try? JSONEncoder().encode(preferences) { defaults.set(data, forKey: "preferences.v1") }
        updateRanges(); statusChanged?(); sizeChanged?()
    }
    func updateRanges() {
        guard visible else { return }
        let key = "\(day.start.timeIntervalSince1970)|\(referenceZone.identifier)|" + selected.map { "\($0.zone):\($0.workStart)-\($0.workEnd)" }.joined(separator: ";")
        guard key != overlapKey else { return }
        overlapKey = key; ranges = TimeMath.overlap(cities: preferences.cities, day: day)
    }
    func time(_ date: Date, zone: TimeZone) -> String {
        let key = zone.identifier + (preferences.twentyFour ? "24" : "12")
        if formatters[key] == nil {
            let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = zone
            f.dateFormat = preferences.twentyFour ? "HH:mm" : "h:mm a"; formatters[key] = f
        }
        return formatters[key]!.string(from: date)
    }
    func statusTitle() -> String {
        let now = Date()
        var parts: [String] = []
        if preferences.showDate { parts.append(now.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))) }
        for city in preferences.cities where city.pinned {
            let name = city.name.components(separatedBy: ",")[0]
            let short: String
            if preferences.compact {
                let words = name.split(separator: " ")
                short = words.count > 1 ? words.compactMap(\.first).map(String.init).joined().uppercased() : String(name.prefix(3)).uppercased()
            } else { short = name }
            parts.append(short + " " + time(now, zone: city.timeZone))
        }
        return parts.joined(separator: "   ")
    }
    func edit(_ id: UUID, change: (inout City) -> Void) {
        guard let i = preferences.cities.firstIndex(where: { $0.id == id }) else { return }
        change(&preferences.cities[i]); save()
    }
    func rename(_ id: UUID, name: String) {
        let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(50))
        guard !clean.isEmpty else { return }; edit(id) { $0.name = clean }
    }
    func add(_ option: CityOption) {
        if preferences.cities.contains(where: { $0.name == option.name && $0.zone == option.zone }) { flash("City already added"); return }
        preferences.cities.append(City(name: option.name, zone: option.zone)); query = ""; save()
    }
    func remove(_ city: City) {
        guard let index = preferences.cities.firstIndex(where: { $0.id == city.id }) else { return }
        undoCity = (city, index); preferences.cities.remove(at: index); save(); flash("Removed \(city.name)")
    }
    var canUndo: Bool { undoCity != nil }
    func undo() {
        guard let (city, i) = undoCity else { return }
        preferences.cities.insert(city, at: min(i, preferences.cities.count)); undoCity = nil; notice = nil; noticeTask?.cancel(); save()
    }
    func move(_ id: UUID, before target: UUID) {
        guard id != target, let from = preferences.cities.firstIndex(where: { $0.id == id }), let to = preferences.cities.firstIndex(where: { $0.id == target }) else { return }
        let city = preferences.cities.remove(at: from); preferences.cities.insert(city, at: to); save()
    }
    func shift(_ id: UUID, by delta: Int) {
        guard let i = preferences.cities.firstIndex(where: { $0.id == id }), preferences.cities.indices.contains(i + delta) else { return }
        preferences.cities.swapAt(i, i + delta); save()
    }
    func flash(_ message: String) {
        noticeTask?.cancel(); notice = message; sizeChanged?()
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(6)); guard !Task.isCancelled else { return }
            self?.notice = nil; self?.undoCity = nil; self?.sizeChanged?()
        }
    }
    func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
            loginEnabled = SMAppService.mainApp.status == .enabled
            if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems(); flash("Approve KnoTime in Login Items") }
        } catch { flash("Login item unavailable — move KnoTime to Applications first") }
    }
}

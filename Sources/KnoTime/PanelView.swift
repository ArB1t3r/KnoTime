import SwiftUI
import AppKit
import UniformTypeIdentifiers
import TimeCore

private let mint = Color(red: 0.43, green: 0.78, blue: 0.60)
struct PanelView: View {
    @ObservedObject var store: ClockStore
    @ObservedObject var updater: AppUpdater
    @Environment(\.colorScheme) private var scheme
    @State private var dragging: UUID?
    @FocusState private var searchFocused: Bool
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.system(size: 18, weight: .light)).foregroundStyle(.secondary)
                TextField("Search", text: $store.query).textFieldStyle(.plain).font(.system(size: 15))
                    .focused($searchFocused).onSubmit { if let option = store.results.first { store.add(option) } }
                    .accessibilityLabel("Search cities")
                if !store.query.isEmpty { Button { store.query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain).accessibilityLabel("Clear search") }
            }.padding(.horizontal, 17).frame(height: 52)
            if !store.query.isEmpty { searchResults }
            Divider()
            TimeSlider(store: store).frame(height: 59)
            Divider()
            ScrollView {
                VStack(spacing: 0) {
                    if store.preferences.cities.isEmpty {
                        Text("Search for a city to add your first clock").font(.system(size: 12)).foregroundStyle(.secondary).frame(height: 42)
                    }
                    ForEach(store.preferences.cities) { city in
                        CityRow(store: store, city: city)
                            .onDrag { dragging = city.id; return NSItemProvider(object: city.id.uuidString as NSString) }
                            .onDrop(of: [.text], delegate: CityDropDelegate(city: city, store: store, dragging: $dragging))
                    }
                }.padding(.vertical, 10)
            }.frame(height: store.listHeight)
            Divider()
            Button {
                store.preferences.collapsed.toggle(); store.save()
            } label: {
                Image(systemName: store.preferences.collapsed ? "chevron.down" : "chevron.up")
                    .font(.system(size: 13, weight: .light)).foregroundStyle(.secondary).frame(maxWidth: .infinity).frame(height: 27).contentShape(Rectangle())
            }.buttonStyle(.plain).help(store.preferences.collapsed ? "Show settings" : "Hide settings").accessibilityLabel(store.preferences.collapsed ? "Show settings" : "Hide settings")
            if !store.preferences.collapsed { settings }
            if let notice = store.notice {
                Divider()
                HStack {
                    Text(notice).lineLimit(1).font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    if store.canUndo { Button("Undo") { store.undo() }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(mint) }
                }.padding(.horizontal, 15).frame(height: 33)
            }
        }
        .frame(width: 325)
        .background(scheme == .dark ? Color(red: 0.115, green: 0.12, blue: 0.128) : Color(red: 0.985, green: 0.985, blue: 0.985))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .onChange(of: store.query) { _, _ in store.sizeChanged?() }
        .onChange(of: store.visible) { _, visible in if !visible { searchFocused = false } }
        .onExitCommand { if !store.query.isEmpty { store.query = "" } else { NSApp.keyWindow?.orderOut(nil); store.close() } }
    }
    private var searchResults: some View {
        ScrollView {
            VStack(spacing: 0) {
                if store.results.isEmpty { Text("No matching city or time zone").font(.system(size: 12)).foregroundStyle(.secondary).frame(height: 43) }
                ForEach(store.results) { result in
                    Button { store.add(result) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.name).font(.system(size: 12))
                                Text(result.zone).font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "plus").foregroundStyle(.secondary)
                        }.padding(.horizontal, 17).frame(height: 43).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }.padding(.vertical, 6)
        }.frame(height: store.searchHeight)
    }
    private func setting(_ label: String, checked: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark").opacity(checked ? 1 : 0).frame(width: 15)
                Text(label); Spacer()
            }.font(.system(size: 14)).padding(.horizontal, 16).frame(height: 38).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
    private var settings: some View {
        VStack(spacing: 0) {
            setting("Date", checked: store.preferences.showDate) { store.preferences.showDate.toggle(); store.save() }
                .help("Show today's local date in the menu bar")
            setting("24 Hours", checked: store.preferences.twentyFour) { store.preferences.twentyFour.toggle(); store.save() }
            setting("Compact View", checked: store.preferences.compact) { store.preferences.compact.toggle(); store.save() }.help("Abbreviate city names in the menu bar")
            setting("Open at Login", checked: store.loginEnabled) { store.toggleLogin() }
            setting("Automatic Updates", checked: updater.automaticChecks) { updater.toggleAutomaticChecks() }
                .disabled(!updater.configured).help("Check daily; ask before installing")
            Button { updater.check() } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath").frame(width: 15)
                    Text("Check for Updates…"); Spacer()
                }.font(.system(size: 14)).padding(.horizontal, 16).frame(height: 38).contentShape(Rectangle())
            }.buttonStyle(.plain).disabled(updater.configured && !updater.canCheck)
            Divider()
            HStack(spacing: 12) {
                Image(systemName: "clock").frame(width: 15)
                Text("KnoTime")
                Spacer(); Text(updater.version).foregroundStyle(.tertiary).font(.system(size: 11))
            }.font(.system(size: 14)).padding(.horizontal, 16).frame(height: 43).help("Native time, shared moments. Clocks work offline.")
            Divider()
            Button { NSApp.terminate(nil) } label: {
                HStack(spacing: 12) { Image(systemName: "power").frame(width: 15); Text("Quit KnoTime"); Spacer() }
                    .font(.system(size: 14)).padding(.horizontal, 16).frame(height: 43).contentShape(Rectangle())
            }.buttonStyle(.plain)
        }.frame(height: 316)
    }
}

private struct CityDropDelegate: DropDelegate {
    let city: City
    let store: ClockStore
    @Binding var dragging: UUID?
    func dropEntered(info: DropInfo) { if let source = dragging { store.move(source, before: city.id) } }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool { dragging = nil; return true }
}

private struct CityRow: View {
    @ObservedObject var store: ClockStore
    let city: City
    @State private var hovering = false
    @State private var editing = false
    @State private var draft = ""
    @FocusState private var nameFocused: Bool
    private var daylight: Bool {
        guard let location = city.location else { return false }
        return Solar.isDaylight(at: store.displayDate, location: location)
    }
    private var difference: Int { TimeMath.dayDifference(store.displayDate, cityZone: city.timeZone, referenceZone: store.referenceZone) }
    private func showWorkSettings() { store.showWorkingHours?(city, .zero) }
    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 3) {
                    Image(systemName: daylight ? "sun.max.fill" : "moon.fill").font(.system(size: 12)).frame(width: 13)
                    Text(store.time(store.displayDate, zone: city.timeZone)).font(.system(size: store.preferences.twentyFour ? 14 : 11, weight: .regular)).monospacedDigit().fixedSize()
                }.foregroundStyle(daylight ? Color.black.opacity(0.86) : Color.white)
                    .padding(.horizontal, 7).frame(height: 24)
                    .background(daylight ? Color(red: 1, green: 0.78, blue: 0.19) : Color(red: 0.19, green: 0.18, blue: 0.46), in: Capsule())
                    .overlay(Capsule().strokeBorder(city.workEnabled && store.inOverlap ? mint : .clear, lineWidth: 1.5))
                .overlay(alignment: .bottom) {
                    if difference != 0 {
                        Text(abs(difference) > 1 ? "\(difference > 0 ? "+" : "")\(difference) days" : difference < 0 ? "Previous day" : "Next day")
                            .font(.system(size: 8, weight: .regular)).foregroundStyle(.secondary).fixedSize().offset(y: 10)
                    }
                }
                .frame(width: store.preferences.twentyFour ? 76 : 86, height: 24)
            if editing {
                TextField(city.name, text: $draft).textFieldStyle(.plain).font(.system(size: 14)).focused($nameFocused)
                    .onSubmit { store.rename(city.id, name: draft); editing = false }
                    .onExitCommand { editing = false }
                    .onChange(of: nameFocused) { _, focused in if !focused { editing = false } }
            } else {
                Text(city.name).font(.system(size: 14)).lineLimit(1).truncationMode(.tail).frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle()).onTapGesture { draft = city.name; editing = true; nameFocused = true }
                    .help("\(city.name) · \(city.zone)\nClick to rename · Drag to reorder")
            }
            HStack(spacing: 6) {
                WorkButton(enabled: city.workEnabled, name: city.name, onToggle: {
                    store.edit(city.id) { $0.workEnabled.toggle() }
                }, onConfigure: { anchor in store.showWorkingHours?(city, anchor) })
                    .frame(width: 17, height: 24)
                Button { store.edit(city.id) { $0.pinned.toggle() } } label: {
                    Image(systemName: city.pinned ? "eye" : "eye.slash").font(.system(size: 12)).foregroundStyle(city.pinned ? Color.primary.opacity(0.8) : Color.secondary.opacity(0.5))
                        .frame(width: 18, height: 24).contentShape(Rectangle())
                }.buttonStyle(.plain).help(city.pinned ? "Hide from menu bar" : "Show in menu bar").accessibilityLabel("Show \(city.name) in menu bar").accessibilityValue(city.pinned ? "On" : "Off")
            }
        }.padding(.horizontal, 15).frame(height: 42)
        .background(hovering ? Color.primary.opacity(0.035) : .clear)
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Working Hours…") { showWorkSettings() }
            Button("Rename") { draft = city.name; editing = true; nameFocused = true }
            Divider()
            Button("Move Up") { store.shift(city.id, by: -1) }
            Button("Move Down") { store.shift(city.id, by: 1) }
            Divider()
            Button("Remove City", role: .destructive) { store.remove(city) }
        }
    }
}

struct WorkHoursView: View {
    @ObservedObject var store: ClockStore
    let city: City
    let dismiss: () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var start = "09:00"
    @State private var end = "18:00"
    private var startMinute: Int? { TimeMath.parseClock(start) }
    private var endMinute: Int? { TimeMath.parseClock(end) }
    private var valid: Bool { startMinute != nil && endMinute != nil && startMinute != endMinute }
    private var explanation: String {
        guard let a = startMinute, let b = endMinute else { return "24-hour time · e.g. 09:00" }
        if a == b { return "Start and end must differ." }
        return a > b ? "Ends next day" : ""
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(city.name).font(.system(size: 14))
                Text("Working hours · Local time").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("From").font(.system(size: 11)).foregroundStyle(.secondary)
                    TextField("09:00", text: $start).accessibilityLabel("Work starts, local time")
                }
                Text("–").foregroundStyle(.secondary).padding(.top, 16)
                VStack(alignment: .leading, spacing: 5) {
                    Text("To").font(.system(size: 11)).foregroundStyle(.secondary)
                    TextField("18:00", text: $end).accessibilityLabel("Work ends, local time")
                }
            }.textFieldStyle(.plain).font(.system(size: 16, design: .monospaced))
                .padding(.vertical, 10).padding(.horizontal, 12)
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 7))
            if !explanation.isEmpty { Text(explanation).font(.system(size: 10)).foregroundStyle(valid ? Color.secondary : Color.orange) }
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    guard let a = startMinute, let b = endMinute, a != b else { return }
                    store.edit(city.id) { $0.workStart = a; $0.workEnd = b }; dismiss()
                }.keyboardShortcut(.defaultAction).disabled(!valid)
            }.buttonStyle(.plain).font(.system(size: 12)).padding(.top, 3)
        }.padding(16).frame(width: 250, height: 186)
        .background(scheme == .dark ? Color(red: 0.115, green: 0.12, blue: 0.128) : Color(red: 0.985, green: 0.985, blue: 0.985))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear { start = TimeMath.clockString(city.workStart); end = TimeMath.clockString(city.workEnd) }
    }
}

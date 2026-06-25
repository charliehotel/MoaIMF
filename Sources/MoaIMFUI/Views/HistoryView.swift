import AppKit
import MoaIMFCore
import SwiftUI

public enum HistoryFilter: String, CaseIterable, Identifiable {
  case all
  case renamed
  case collision
  case permission
  case error

  public var id: String { rawValue }

  func contains(_ kind: HistoryEventKind) -> Bool {
    switch self {
    case .all: true
    case .renamed: kind == .renamed
    case .collision: kind == .collision
    case .permission: kind == .permission
    case .error:
      [.error, .disconnected, .unsupportedFilesystem].contains(kind)
    }
  }
}

public enum HistoryDateScope: String, CaseIterable, Identifiable {
  case today
  case sevenDays
  case thirtyDays
  case all

  public var id: String { rawValue }

  func contains(
    _ date: Date,
    now: Date = Date(),
    calendar: Calendar = .current
  ) -> Bool {
    switch self {
    case .today:
      return calendar.isDate(date, inSameDayAs: now)
    case .sevenDays:
      return date >= calendar.date(byAdding: .day, value: -7, to: now) ?? date
    case .thirtyDays:
      return date >= calendar.date(byAdding: .day, value: -30, to: now) ?? date
    case .all:
      return true
    }
  }
}

enum HistorySearch {
  static func matches(
    _ event: HistoryEvent,
    query: String,
    title: String
  ) -> Bool {
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedQuery.isEmpty else { return true }

    let searchableText = [
      title,
      event.reason,
      event.previousURL?.path,
      event.resultingURL?.path,
      event.rootIdentifier,
    ]
    .compactMap { $0 }
    .joined(separator: "\n")

    return canonicalVariants(of: searchableText).contains { candidate in
      canonicalVariants(of: trimmedQuery).contains { queryVariant in
        candidate.localizedCaseInsensitiveContains(queryVariant)
      }
    }
  }

  private static func canonicalVariants(of text: String) -> [String] {
    var variants: [String] = []
    for variant in [
      text,
      text.precomposedStringWithCanonicalMapping,
      text.decomposedStringWithCanonicalMapping,
    ] where !variants.contains(variant) {
      variants.append(variant)
    }
    return variants
  }
}

public struct HistoryView: View {
  public static let minimumSize = NSSize(width: 584, height: 440)
  public static let preferredSize = minimumSize

  @ObservedObject private var controller: AppController
  @State private var dateScope: HistoryDateScope
  @State private var filter: HistoryFilter
  @State private var searchText: String

  public init(
    controller: AppController,
    dateScope: HistoryDateScope = .today,
    filter: HistoryFilter = .all,
    searchText: String = ""
  ) {
    self.controller = controller
    _dateScope = State(initialValue: dateScope)
    _filter = State(initialValue: filter)
    _searchText = State(initialValue: searchText)
  }

  public var body: some View {
    VStack(spacing: 0) {
      header

      Divider()

      if filteredEvents.isEmpty {
        VStack(spacing: 8) {
          Image(systemName: "clock").font(.largeTitle)
          Text(emptyMessage)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        historyList
      }
    }
    .frame(minWidth: Self.minimumSize.width, minHeight: Self.minimumSize.height)
  }

  private var historyList: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        ForEach(filteredEvents) { event in
          historyRow(for: event)
          Divider()
            .padding(.leading, 56)
        }
      }
    }
  }

  private func historyRow(for event: HistoryEvent) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: symbol(event.kind))
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 4) {
        Text(title(for: event))
          .font(.body)
          .lineLimit(2)
        Text(event.resultingURL?.path ?? event.previousURL?.path ?? event.rootIdentifier)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      Spacer()
      Text(event.timestamp, format: .dateTime.month().day().hour().minute())
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 28)
    .padding(.vertical, 10)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(MoaIMFLocalization.text("history.title"))
        .font(.title2)
        .fontWeight(.semibold)

      Text(resultSummary)
        .font(.subheadline)
        .foregroundStyle(.secondary)

      ViewThatFits(in: .horizontal) {
        HStack(spacing: 12) {
          dateScopePicker
          filterMenu
          searchField
        }

        VStack(alignment: .leading, spacing: 8) {
          dateScopePicker
          HStack(spacing: 12) {
            filterMenu
            searchField
          }
        }
      }
      .padding(.top, 2)
    }
    .padding(.horizontal, 28)
    .padding(.top, 16)
    .padding(.bottom, 12)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var dateScopePicker: some View {
    Picker("", selection: $dateScope) {
      ForEach(HistoryDateScope.allCases) { item in
        Text(dateScopeLabel(item)).tag(item)
      }
    }
    .labelsHidden()
    .pickerStyle(.segmented)
    .controlSize(.small)
    .fixedSize(horizontal: true, vertical: true)
  }

  private var filterMenu: some View {
    Menu {
      ForEach(HistoryFilter.allCases) { item in
        Button {
          filter = item
        } label: {
          if filter == item {
            Label(filterLabel(item), systemImage: "checkmark")
          } else {
            Text(filterLabel(item))
          }
        }
      }
    } label: {
      Text("\(MoaIMFLocalization.text("history.typeLabel")): \(filterLabel(filter))")
    }
    .buttonStyle(.bordered)
    .controlSize(.small)
    .fixedSize(horizontal: true, vertical: true)
  }

  private var searchField: some View {
    HistorySearchField(
      text: $searchText,
      placeholder: MoaIMFLocalization.text("history.searchPlaceholder")
    )
    .frame(width: 156, height: 24)
    .fixedSize(horizontal: true, vertical: true)
  }

  private var emptyMessage: String {
    searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? MoaIMFLocalization.text("history.empty")
      : MoaIMFLocalization.text("history.emptySearch")
  }

  private var resultSummary: String {
    String(
      format: MoaIMFLocalization.text("history.resultSummary"),
      dateScopeLabel(dateScope),
      filterLabel(filter),
      filteredEvents.count
    )
  }

  private var filteredEvents: [HistoryEvent] {
    controller.history.filter { event in
      dateScopeContains(event.timestamp)
        && filterContains(event.kind)
        && searchContains(event)
    }
  }

  private func dateScopeContains(_ date: Date) -> Bool {
    dateScope.contains(date)
  }

  private func filterContains(_ kind: HistoryEventKind) -> Bool {
    filter.contains(kind)
  }

  private func searchContains(_ event: HistoryEvent) -> Bool {
    HistorySearch.matches(event, query: searchText, title: title(for: event))
  }

  private func symbol(_ kind: HistoryEventKind) -> String {
    switch kind {
    case .renamed: "checkmark.circle"
    case .collision: "exclamationmark.triangle"
    case .permission: "lock.trianglebadge.exclamationmark"
    case .disconnected: "externaldrive.badge.exclamationmark"
    case .unsupportedFilesystem, .error: "xmark.octagon"
    }
  }

  private func title(for event: HistoryEvent) -> String {
    switch event.kind {
    case .renamed:
      MoaIMFLocalization.text("history.event.renamed")
    case .collision:
      MoaIMFLocalization.text("history.event.collision")
    case .permission:
      MoaIMFLocalization.text("history.event.permission")
    case .disconnected:
      MoaIMFLocalization.text("history.event.disconnected")
    case .unsupportedFilesystem:
      MoaIMFLocalization.text("history.event.unsupportedFilesystem")
    case .error:
      event.reason
    }
  }

  private func filterLabel(_ filter: HistoryFilter) -> String {
    switch filter {
    case .all: MoaIMFLocalization.text("filter.all")
    case .renamed: MoaIMFLocalization.text("history.filter.renamed")
    case .collision: MoaIMFLocalization.text("history.filter.collision")
    case .permission: MoaIMFLocalization.text("history.filter.permission")
    case .error: MoaIMFLocalization.text("history.filter.error")
    }
  }

  private func dateScopeLabel(_ scope: HistoryDateScope) -> String {
    switch scope {
    case .today: MoaIMFLocalization.text("history.scope.today")
    case .sevenDays: MoaIMFLocalization.text("history.scope.sevenDays")
    case .thirtyDays: MoaIMFLocalization.text("history.scope.thirtyDays")
    case .all: MoaIMFLocalization.text("history.scope.all")
    }
  }
}

private struct HistorySearchField: NSViewRepresentable {
  @Binding var text: String
  let placeholder: String

  func makeNSView(context: Context) -> NSSearchField {
    let field = NSSearchField()
    field.controlSize = .small
    field.placeholderString = placeholder
    field.sendsSearchStringImmediately = true
    field.delegate = context.coordinator
    field.target = context.coordinator
    field.action = #selector(Coordinator.searchFieldDidChange(_:))
    return field
  }

  func updateNSView(_ nsView: NSSearchField, context: Context) {
    if nsView.stringValue != text {
      nsView.stringValue = text
    }
    if nsView.placeholderString != placeholder {
      nsView.placeholderString = placeholder
    }
    context.coordinator.parent = self
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  final class Coordinator: NSObject, NSSearchFieldDelegate {
    var parent: HistorySearchField

    init(parent: HistorySearchField) {
      self.parent = parent
    }

    @MainActor @objc func searchFieldDidChange(_ sender: NSSearchField) {
      parent.text = sender.stringValue
    }

    @MainActor func controlTextDidChange(_ object: Notification) {
      guard let field = object.object as? NSSearchField else { return }
      parent.text = field.stringValue
    }
  }
}

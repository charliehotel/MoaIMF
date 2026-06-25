import MoaIMFCore
import SwiftUI

public struct StabilityRulesView: View {
  @ObservedObject private var controller: AppController
  @State private var selection: String?
  @State private var isAdding = false

  public init(controller: AppController) {
    self.controller = controller
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(MoaIMFLocalization.text("stability.description"))
        .foregroundStyle(.secondary)

      List(selection: $selection) {
        Section(MoaIMFLocalization.text("stability.builtIn")) {
          ForEach(builtIns) { rule in ruleRow(rule, locked: true) }
        }
        Section(MoaIMFLocalization.text("stability.custom")) {
          if userRules.isEmpty {
            Text(MoaIMFLocalization.text("history.empty"))
              .foregroundStyle(.secondary)
          }
          ForEach(userRules) { rule in
            ruleRow(rule, locked: false).tag(rule.id)
          }
        }
      }

      HStack(spacing: 0) {
        Button {
          isAdding = true
        } label: {
          Image(systemName: "plus")
        }
        .accessibilityLabel(MoaIMFLocalization.text("stability.add"))
        Button(role: .destructive, action: removeSelected) { Image(systemName: "minus") }
          .accessibilityLabel(MoaIMFLocalization.text("stability.remove"))
          .disabled(selection == nil)
      }
      .buttonStyle(.borderless)
    }
    .sheet(isPresented: $isAdding) {
      AddStabilityRuleView(controller: controller, isPresented: $isAdding)
    }
  }

  private var builtIns: [StabilityExclusionRule] {
    controller.stabilityRules.filter { $0.source == .builtIn }
  }

  private var userRules: [StabilityExclusionRule] {
    controller.stabilityRules.filter { $0.source == .user }
  }

  private func ruleRow(_ rule: StabilityExclusionRule, locked: Bool) -> some View {
    HStack {
      Image(systemName: locked ? "lock" : "text.badge.checkmark")
      Text(rule.pattern).font(.body.monospaced())
      Spacer()
      Text(kindLabel(rule.kind)).foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .combine)
  }

  private func removeSelected() {
    guard let selection else { return }
    Task {
      await controller.removeRule(id: selection)
      self.selection = nil
    }
  }
}

private struct AddStabilityRuleView: View {
  @ObservedObject var controller: AppController
  @Binding var isPresented: Bool
  @State private var kind: StabilityRuleKind = .suffix
  @State private var pattern = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(MoaIMFLocalization.text("stability.add"))
        .font(.title2.weight(.semibold))
      Picker(MoaIMFLocalization.text("stability.title"), selection: $kind) {
        ForEach([StabilityRuleKind.exactName, .suffix, .glob], id: \.rawValue) {
          Text(kindLabel($0)).tag($0)
        }
      }
      TextField(".aria2", text: $pattern)
        .textFieldStyle(.roundedBorder)
      Text(MoaIMFLocalization.text("stability.description"))
        .font(.caption)
        .foregroundStyle(.secondary)
      if !pattern.isEmpty, !isValid {
        Label(MoaIMFLocalization.text("stability.invalid"), systemImage: "exclamationmark.triangle")
          .foregroundStyle(.red)
      }
      HStack {
        Spacer()
        Button(MoaIMFLocalization.text("common.cancel"), role: .cancel) { isPresented = false }
        Button(MoaIMFLocalization.text("stability.add")) {
          Task {
            await controller.addRule(kind: kind, pattern: pattern)
            if controller.alert == nil { isPresented = false }
          }
        }
        .keyboardShortcut(.defaultAction)
        .disabled(!isValid)
      }
    }
    .padding(20)
    .frame(width: 430)
  }

  private var isValid: Bool {
    do {
      try StabilityExclusionMatcher.validate(kind: kind, pattern: pattern)
      return true
    } catch {
      return false
    }
  }
}

private func kindLabel(_ kind: StabilityRuleKind) -> String {
  switch kind {
  case .exactName: MoaIMFLocalization.text("stability.kind.exactName")
  case .suffix: MoaIMFLocalization.text("stability.kind.suffix")
  case .glob: MoaIMFLocalization.text("stability.kind.glob")
  }
}

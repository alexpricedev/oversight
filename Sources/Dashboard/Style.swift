import SwiftUI

extension ActionState {
    var symbolName: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .failure: "xmark.octagon.fill"
        case .inProgress: "clock.fill"
        case .neutral: "minus.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .success: .green
        case .failure: .red
        case .inProgress: .orange
        case .neutral: .secondary
        }
    }

    var label: String {
        switch self {
        case .success: "Success"
        case .failure: "Failure"
        case .inProgress: "Running"
        case .neutral: "Cancelled or skipped"
        }
    }
}

extension CIRollup {
    var symbolName: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .failure: "xmark.circle.fill"
        case .pending: "clock.fill"
        case .neutral: "minus.circle.fill"
        case .none: "questionmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .success: .green
        case .failure: .red
        case .pending: .orange
        case .neutral: .secondary
        case .none: .secondary
        }
    }
}

struct Badge: View {
    let text: String
    var tint: Color = .secondary

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(tint.opacity(0.14)))
            .foregroundStyle(tint)
    }
}

struct RepoBadge: View {
    let repo: RepoID

    var body: some View {
        Text(repo.name)
            .font(.system(size: 10, weight: .medium))
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.secondary.opacity(0.12)))
            .foregroundStyle(.secondary)
            .help(repo.slug)
    }
}

struct CIStatusIcon: View {
    let rollup: CIRollup

    var body: some View {
        Image(systemName: rollup.symbolName)
            .foregroundStyle(rollup.tint)
            .font(.callout)
            .help(rollup.label)
            .accessibilityLabel("CI \(rollup.label)")
    }
}

struct EmptyStateRow: View {
    let text: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.tertiary)
            Text(text)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .font(.callout)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

//
//  ReflectionSummaryView.swift
//  Reflectr
//
//  Created by Aalohan Thileepan on 22.09.2026.
//

import SwiftUI

/// Read-only display of a saved reflection.
struct ReflectionSummaryView: View {
    let reflection: Reflection

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ratings

            entry("What went well", reflection.whatWentWell, "checkmark.seal", .green)
            entry("What wasn't optimal", reflection.whatWasntOptimal, "exclamationmark.triangle", .orange)
            entry("Keep in mind", reflection.keepInMind, "brain.head.profile", .blue)
            entry("Try next time", reflection.tryNextTime, "flask", .accentColor)

            if let tags = reflection.tags, !tags.isEmpty {
                WrapTags(tags: tags)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var ratings: some View {
        let items: [(String, Int?)] = [
            ("Overall", reflection.feeling),
            ("Energy", reflection.energy),
            ("RPE", reflection.rpe)
        ]
        HStack {
            ForEach(items.filter { $0.1 != nil }, id: \.0) { label, value in
                VStack(spacing: 2) {
                    Text(value.map(String.init) ?? "—")
                        .font(.title3.bold())
                        .foregroundStyle(Color.accentColor)
                    Text(label).font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func entry(_ title: String, _ text: String?, _ icon: String, _ color: Color) -> some View {
        if let text, !text.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: icon)
                    .font(.caption.bold())
                    .foregroundStyle(color)
                Text(text).font(.body)
            }
        }
    }
}

/// Simple wrapping row of tag chips.
struct WrapTags: View {
    enum Style { case normal, suggestion }

    let tags: [String]
    var style: Style = .normal
    var onTap: ((String) -> Void)? = nil

    var body: some View {
        FlexibleWrap(items: tags) { tag in
            HStack(spacing: 4) {
                if style == .suggestion {
                    Image(systemName: "plus").font(.caption2)
                }
                Text(tag).font(.caption)
                if style == .normal, onTap != nil {
                    Image(systemName: "xmark").font(.system(size: 8))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(style == .suggestion ? Color.gray.opacity(0.12) : Color.accentColor.opacity(0.15))
            )
            .foregroundStyle(style == .suggestion ? Color.secondary : Color.accentColor)
            .onTapGesture { onTap?(tag) }
        }
    }
}

/// Lightweight flow layout so tag chips wrap onto multiple lines.
struct FlexibleWrap<Content: View>: View {
    let items: [String]
    @ViewBuilder let content: (String) -> Content

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(items, id: \.self) { content($0) }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [CGFloat] = [0]
        var rowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rows.append(0)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth == .infinity ? rowWidth : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

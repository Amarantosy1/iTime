import SwiftUI

// MARK: - Layout Algorithm

/// Assigns a display level (0-based) to each node using topological BFS.
/// Nodes at the same level are rendered in the same row.
/// Isolated nodes (not in any edge) are appended after connected nodes.
func flowchartAssignLevels(
    nodes: [FlowchartNode],
    edges: [FlowchartEdge]
) -> [String: Int] {
    let validIDs = Set(nodes.map(\.id))
    var successors: [String: [String]] = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, []) })
    var predecessorCount: [String: Int] = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, 0) })

    for edge in edges where validIDs.contains(edge.from) && validIDs.contains(edge.to) {
        successors[edge.from, default: []].append(edge.to)
        predecessorCount[edge.to, default: 0] += 1
    }

    var levels: [String: Int] = [:]
    var queue: [String] = predecessorCount.filter { $0.value == 0 }.map(\.key).sorted()
    queue.forEach { levels[$0] = 0 }

    var head = 0
    while head < queue.count {
        let id = queue[head]
        head += 1
        let currentLevel = levels[id] ?? 0
        for successor in successors[id, default: []] {
            let proposed = currentLevel + 1
            if proposed > (levels[successor] ?? 0) {
                levels[successor] = proposed
            }
            predecessorCount[successor, default: 1] -= 1
            if predecessorCount[successor, default: 0] <= 0 {
                queue.append(successor)
            }
        }
    }

    // Isolated nodes: not referenced in any edge.
    let connectedIDs = Set(edges.flatMap { [$0.from, $0.to] })
    let isolated = nodes.filter { !connectedIDs.contains($0.id) }
        .sorted { $0.timeRange < $1.timeRange }
    let maxLevel = levels.values.max() ?? -1
    for (offset, node) in isolated.enumerated() {
        levels[node.id] = maxLevel + 1 + offset
    }

    // Any remaining nodes not reached by BFS (e.g. in a cycle) get appended.
    var finalMax = levels.values.max() ?? 0
    for node in nodes where levels[node.id] == nil {
        finalMax += 1
        levels[node.id] = finalMax
    }

    return levels
}

// MARK: - Preference Key for Node Frames

private struct NodeFrameValue: Equatable {
    let id: String
    let frame: CGRect
}

private struct NodeFrameKey: PreferenceKey {
    static let defaultValue: [NodeFrameValue] = []

    static func reduce(value: inout [NodeFrameValue], nextValue: () -> [NodeFrameValue]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - FlowchartView

struct FlowchartView: View {
    let flowchart: AIConversationFlowchart
    let calendarColorHexByName: [String: String]

    @State private var nodeFrames: [String: CGRect] = [:]

    private let nodeWidth: CGFloat = 220
    private let horizontalSpacing: CGFloat = 20
    private let verticalSpacing: CGFloat = 52

    private var leveledRows: [[FlowchartNode]] {
        let levels = flowchartAssignLevels(nodes: flowchart.nodes, edges: flowchart.edges)
        guard !levels.isEmpty else { return [] }
        let maxLevel = levels.values.max() ?? 0
        return (0 ... maxLevel).map { level in
            flowchart.nodes
                .filter { levels[$0.id] == level }
                .sorted { $0.timeRange < $1.timeRange }
        }
    }

    var body: some View {
        if flowchart.nodes.isEmpty {
            Text("暂无流程数据")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
                )
        } else {
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    nodeGrid
                        .coordinateSpace(name: "flowchart")

                    Canvas { context, _ in
                        drawEdges(context: context)
                    }
                    .allowsHitTesting(false)
                }
                .padding()
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
            )
            .onPreferenceChange(NodeFrameKey.self) { values in
                nodeFrames = Dictionary(values.map { ($0.id, $0.frame) }, uniquingKeysWith: { _, last in last })
            }
        }
    }

    private var nodeGrid: some View {
        VStack(alignment: .center, spacing: verticalSpacing) {
            ForEach(Array(leveledRows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: horizontalSpacing) {
                    ForEach(row, id: \.id) { node in
                        FlowchartNodeView(node: node, calendarColorHexByName: calendarColorHexByName)
                            .frame(width: nodeWidth)
                            .background(
                                GeometryReader { geometry in
                                    Color.clear.preference(
                                        key: NodeFrameKey.self,
                                        value: [NodeFrameValue(
                                            id: node.id,
                                            frame: geometry.frame(in: .named("flowchart"))
                                        )]
                                    )
                                }
                            )
                    }
                }
            }
        }
    }

    private func drawEdges(context: GraphicsContext) {
        for edge in flowchart.edges {
            guard
                let fromFrame = nodeFrames[edge.from],
                let toFrame = nodeFrames[edge.to]
            else {
                continue
            }

            let start = CGPoint(x: fromFrame.midX, y: fromFrame.maxY)
            let end = CGPoint(x: toFrame.midX, y: toFrame.minY)
            let midY = (start.y + end.y) / 2

            var path = Path()
            path.move(to: start)
            path.addCurve(
                to: end,
                control1: CGPoint(x: start.x, y: midY),
                control2: CGPoint(x: end.x, y: midY)
            )
            context.stroke(path, with: .color(.secondary.opacity(0.6)), style: StrokeStyle(lineWidth: 1.5))

            let arrowSize: CGFloat = 6
            let tangent = CGPoint(x: end.x - end.x, y: end.y - midY)
            let angle = atan2(tangent.y, tangent.x == 0 ? 0.0001 : tangent.x)
            let leftWing = CGPoint(
                x: end.x - arrowSize * cos(angle - .pi / 6),
                y: end.y - arrowSize * sin(angle - .pi / 6)
            )
            let rightWing = CGPoint(
                x: end.x - arrowSize * cos(angle + .pi / 6),
                y: end.y - arrowSize * sin(angle + .pi / 6)
            )

            var arrowPath = Path()
            arrowPath.move(to: end)
            arrowPath.addLine(to: leftWing)
            arrowPath.move(to: end)
            arrowPath.addLine(to: rightWing)
            context.stroke(
                arrowPath,
                with: .color(.secondary.opacity(0.6)),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
            )
        }
    }
}

// MARK: - Node View

private struct FlowchartNodeView: View {
    let node: FlowchartNode
    let calendarColorHexByName: [String: String]

    private var calendarBadgeAccentColor: Color {
        guard
            let calendarName = node.calendarName,
            let hex = calendarColorHexByName[calendarName],
            let color = Self.color(fromHex: hex)
        else {
            return .secondary
        }
        return color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(node.timeRange)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(node.title)
                .font(.body.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            if let calendarName = node.calendarName {
                HStack(spacing: 6) {
                    Circle()
                        .fill(calendarBadgeAccentColor)
                        .frame(width: 7, height: 7)

                    Text(calendarName)
                        .font(.caption2)
                        .foregroundStyle(.primary.opacity(0.85))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(calendarBadgeAccentColor.opacity(0.16))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(calendarBadgeAccentColor.opacity(0.45), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    private static func color(fromHex hex: String) -> Color? {
        let sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard let value = UInt64(sanitized, radix: 16) else { return nil }

        switch sanitized.count {
        case 6:
            let red = Double((value >> 16) & 0xFF) / 255
            let green = Double((value >> 8) & 0xFF) / 255
            let blue = Double(value & 0xFF) / 255
            return Color(red: red, green: green, blue: blue)
        case 8:
            let alpha = Double((value >> 24) & 0xFF) / 255
            let red = Double((value >> 16) & 0xFF) / 255
            let green = Double((value >> 8) & 0xFF) / 255
            let blue = Double(value & 0xFF) / 255
            return Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
        default:
            return nil
        }
    }
}

import SwiftData
import SwiftUI

/// The child's saved drawings, plus ideas to start a new one from.
struct CreationsView: View {
    @Binding var path: [Route]
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Creation.updatedAt, order: .reverse) private var creations: [Creation]
    @State private var pendingDelete: Creation?

    private let columns = [GridItem(.adaptive(minimum: 220), spacing: 18)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                section("Start something new") {
                    LazyVGrid(columns: columns, spacing: 18) {
                        Button {
                            start(title: nextTitle, code: Creation.blankCode)
                        } label: {
                            newCard(title: String(localized: "Blank Page"), symbol: "plus")
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("newCreationButton")
                        ForEach(Idea.all) { idea in
                            Button {
                                start(title: idea.title, code: idea.code)
                            } label: {
                                newCard(title: idea.title, symbol: idea.symbol)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if !creations.isEmpty {
                    section("My drawings") {
                        LazyVGrid(columns: columns, spacing: 18) {
                            ForEach(creations) { creation in
                                NavigationLink(value: Route.creation(creation)) {
                                    CreationCard(creation: creation)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Delete", systemImage: "trash", role: .destructive) {
                                        pendingDelete = creation
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color(hex: 0xF3F6FB))
        .navigationTitle("Free Draw")
        .confirmationDialog(
            "Delete this drawing?", isPresented: .constant(pendingDelete != nil), titleVisibility: .visible,
            presenting: pendingDelete
        ) { creation in
            Button("Delete", role: .destructive) {
                modelContext.delete(creation)
                pendingDelete = nil
            }
            Button("Keep It", role: .cancel) {
                pendingDelete = nil
            }
        }
    }

    private var nextTitle: String {
        String(localized: "Drawing \(creations.count + 1)")
    }

    private func start(title: String, code: String) {
        let creation = Creation(title: title, code: code)
        modelContext.insert(creation)
        path.append(.creation(creation))
    }

    private func section(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
            content()
        }
    }

    private func newCard(title: String, symbol: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(Color(hex: 0xE5468C))
                .frame(height: 70)
            Text(title)
                .font(.system(size: 19, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(.background, in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color(hex: 0xE5468C).opacity(0.3), lineWidth: 2))
    }
}

/// A saved drawing with a small picture of what it draws.
struct CreationCard: View {
    let creation: Creation
    @State private var events: [TurtleEvent] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TurtleCanvas(
                events: events, progress: (events.count, 0),
                pose: Pose(position: .zero, heading: 0, visible: false), showGrid: false
            )
            .aspectRatio(1, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 16))
            .accessibilityHidden(true)
            Text(creation.title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .lineLimit(1)
            Text(creation.updatedAt, format: .dateTime.day().month().year())
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.background, in: .rect(cornerRadius: 22))
        .task(id: creation.code) {
            events = Interpreter.run(creation.code, seed: 7).events
        }
    }
}

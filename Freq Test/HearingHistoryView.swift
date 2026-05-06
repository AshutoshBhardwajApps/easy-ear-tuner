import SwiftUI
import SwiftData

struct HearingHistoryView: View {
    @Query(sort: \HearingResult.date, order: .reverse) private var results: [HearingResult]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                if results.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "waveform")
                            .font(.system(size: 48, weight: .thin))
                            .foregroundColor(.white.opacity(0.25))
                        Text("No tests yet")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.35))
                    }
                } else {
                    List {
                        ForEach(results) { result in
                            ResultRow(result: result)
                                .listRowBackground(Color.white.opacity(0.06))
                        }
                        .onDelete { offsets in
                            for i in offsets { modelContext.delete(results[i]) }
                            try? modelContext.save()
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Hearing History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton().foregroundColor(.green)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.green)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct ResultRow: View {
    let result: HearingResult

    var body: some View {
        HStack(spacing: 14) {
            // Reliability indicator dot
            Circle()
                .fill(reliabilityColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("\(result.maxFrequency, specifier: "%.0f") Hz")
                        .font(.headline.monospacedDigit())
                        .foregroundColor(.white)
                    Text("·")
                        .foregroundColor(.white.opacity(0.3))
                    Text(result.ear)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                }
                Text(result.ageComparison)
                    .font(.caption)
                    .foregroundColor(.green.opacity(0.85))
                Text(result.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.3))
            }

            Spacer()

            if result.falseTapCount > 0 {
                Text("\(result.falseTapCount) false")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(6)
            }
        }
        .padding(.vertical, 4)
    }

    private var reliabilityColor: Color {
        switch result.reliabilityEnum {
        case .high:   return .green
        case .medium: return .yellow
        case .low:    return .red
        }
    }
}

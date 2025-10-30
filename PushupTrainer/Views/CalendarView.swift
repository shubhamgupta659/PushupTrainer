//
//  CalendarView.swift
//  PushupTrainer
//

import SwiftUI

struct CalendarView: View {
    @State private var sessions: [WorkoutSession] = SessionStore.load()

    var body: some View {
        NavigationStack {
        List {
            if sessions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No workouts yet")
                        .font(.headline)
                    Text("Start your first session from the Workout tab to begin your journey!")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
            }
            ForEach(groupedByDay().sorted(by: { $0.key > $1.key }), id: \.key) { day, daySessions in
                Section(header: Text(day.formatted(date: .abbreviated, time: .omitted))) {
                    ForEach(daySessions, id: \.id) { s in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Reps: \(s.reps)")
                                Text("Duration: \(s.durationSeconds/60)m \(s.durationSeconds%60)s")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                                if let avg = s.averageHeartRateBPM, let max = s.maxHeartRateBPM {
                                    Text("HR avg/max: \(Int(avg))/\(Int(max)) bpm")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                                if let rec = s.recoveryHeartRateDropBPM {
                                    Text("Recovery: -\(Int(rec)) bpm (60s)")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                            }
                            Spacer()
                            Text("\(Int(s.caloriesBurned)) kcal")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                var all = SessionStore.load()
                                all.removeAll { $0.id == s.id }
                                SessionStore.save(all)
                                sessions = all
                                // Notify that sessions have been updated
                                NotificationCenter.default.post(name: NSNotification.Name("SessionsUpdated"), object: nil)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Activity")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: EditPlanView()) { Text("Edit Plan") }
            }
        }
        .onAppear { sessions = SessionStore.load() }
        }
    }

    private func groupedByDay() -> [Date: [WorkoutSession]] {
        let dict = Dictionary(grouping: sessions) { s -> Date in
            let comps = Calendar.current.dateComponents([.year, .month, .day], from: s.date)
            return Calendar.current.date(from: comps) ?? s.date
        }
        return dict
    }
}



//
//  PlanView.swift
//  PushupTrainer
//

import SwiftUI

struct PlanView: View {
    @State private var plan: WorkoutPlan? = PlanStore.load()

    var body: some View {
        List {
            if let plan = plan {
                Section("Plan Overview") {
                    HStack {
                        Text("Total Days")
                        Spacer()
                        Text("\(plan.totalDays)")
                    }
                    HStack {
                        Text("Progress")
                        Spacer()
                        Text("\(plan.days.filter { $0.isCompleted }.count) / \(plan.totalDays)")
                    }
                }

                Section("Daily Breakdown") {
                    ForEach(plan.days.prefix(30)) { day in
                        HStack {
                            Image(systemName: day.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(day.isCompleted ? .green : .secondary)
                            Text("Day \(day.dayNumber)")
                            Spacer()
                            Text("\(day.targetReps) reps")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Text("No plan available. Generate one in Settings.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Workout Plan")
        .defaultScrollAnchor(.top)
        .onAppear { plan = PlanStore.load() }
    }
}


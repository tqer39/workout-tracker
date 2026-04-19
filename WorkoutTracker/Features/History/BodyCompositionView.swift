import SwiftUI
import SwiftData
import Charts

struct BodyCompositionView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: [SortDescriptor(\BodyMetric.recordedAt, order: .reverse)])
    private var metrics: [BodyMetric]

    @State private var showingAdd = false
    @State private var syncError: String?

    private let healthKit: HealthKitService = LiveHealthKitService()

    var body: some View {
        List {
            Section {
                HStack {
                    Button {
                        Task { await sync() }
                    } label: {
                        Label("HealthKit から同期", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Spacer()
                    Button {
                        showingAdd = true
                    } label: {
                        Label("手動で追加", systemImage: "plus")
                    }
                }
                if let e = syncError {
                    Text(e).foregroundStyle(.red).font(.caption)
                }
            }

            if !chartPoints.isEmpty {
                Section("推移") {
                    Chart {
                        ForEach(chartPoints.filter { $0.weight != nil }) { p in
                            LineMark(
                                x: .value("日付", p.date),
                                y: .value("体重", p.weight ?? 0)
                            )
                            .foregroundStyle(by: .value("種別", "体重"))
                        }
                        ForEach(chartPoints.filter { $0.fat != nil }) { p in
                            LineMark(
                                x: .value("日付", p.date),
                                y: .value("体脂肪率", p.fat ?? 0)
                            )
                            .foregroundStyle(by: .value("種別", "体脂肪率"))
                        }
                    }
                    .frame(height: 220)
                }
            }

            Section("記録") {
                ForEach(metrics) { m in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(m.recordedAt, style: .date)
                            Text(m.recordedAt, style: .time)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            if let w = m.weightKg {
                                Text("\(String(format: "%.1f", w)) kg")
                            }
                            if let f = m.bodyFatPercent {
                                Text("\(String(format: "%.1f", f)) %")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Text(m.source == .healthKit ? "HK" : "手")
                            .font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                    }
                    .swipeActions {
                        Button("削除", role: .destructive) {
                            ctx.delete(m)
                            try? ctx.save()
                        }
                    }
                }
            }
        }
        .overlay {
            if metrics.isEmpty {
                ContentUnavailableView("データなし", systemImage: "figure",
                                       description: Text("HealthKit 同期または手動追加"))
            }
        }
        .sheet(isPresented: $showingAdd) {
            BodyMetricFormView()
        }
    }

    private struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let weight: Double?
        let fat: Double?
    }

    private var chartPoints: [Point] {
        metrics.sorted { $0.recordedAt < $1.recordedAt }
            .map { Point(date: $0.recordedAt, weight: $0.weightKg, fat: $0.bodyFatPercent) }
    }

    private func sync() async {
        syncError = nil
        do {
            try await healthKit.requestAuthorization()
            let to = Date()
            let from = Calendar.current.date(byAdding: .month, value: -6, to: to) ?? to
            let samples = try await healthKit.fetchBodyMetrics(from: from, to: to)
            for s in samples {
                let m = BodyMetric(
                    recordedAt: s.recordedAt,
                    weightKg: s.weightKg,
                    bodyFatPercent: s.bodyFatPercent,
                    source: .healthKit
                )
                ctx.insert(m)
            }
            try? ctx.save()
        } catch HealthKitError.unavailable {
            syncError = "この端末では HealthKit が使えません"
        } catch HealthKitError.denied {
            syncError = "HealthKit 権限が拒否されています"
        } catch {
            syncError = "同期に失敗: \(error.localizedDescription)"
        }
    }
}

struct BodyMetricFormView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @State private var recordedAt = Date()
    @State private var weightText = ""
    @State private var fatText = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("日時", selection: $recordedAt)
                TextField("体重 (kg)", text: $weightText)
                    .keyboardType(.decimalPad)
                TextField("体脂肪率 (%)", text: $fatText)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("手動記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(weightText.isEmpty && fatText.isEmpty)
                }
            }
        }
    }

    private func save() {
        let w = Double(weightText.replacingOccurrences(of: ",", with: "."))
        let f = Double(fatText.replacingOccurrences(of: ",", with: "."))
        let m = BodyMetric(
            recordedAt: recordedAt,
            weightKg: w,
            bodyFatPercent: f,
            source: .manual
        )
        ctx.insert(m)
        try? ctx.save()
        dismiss()
    }
}

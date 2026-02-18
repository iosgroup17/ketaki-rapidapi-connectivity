import SwiftUI
import Charts

struct EngagementChartView: View {
    let metrics: [DailyMetric]
    
    // 1. Filter and Sort for precision
    private var filteredAndSortedMetrics: [DailyMetric] {
        let range = currentWeekRange
        return metrics
            .filter { range.contains(Calendar.current.startOfDay(for: $0.date)) }
            .sorted { $0.date < $1.date }
    }
    
    // 2. Identify platforms present in the data to build the legend
    private var activePlatforms: [String] {
        Array(Set(filteredAndSortedMetrics.map { $0.platform.lowercased() })).sorted()
    }
    
    private let platformColors: [String: Color] = [
        "instagram": .pink,
        "twitter": .black,
        "linkedin": .blue
    ]
    
    var currentWeekRange: ClosedRange<Date> {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        let now = calendar.startOfDay(for: Date())
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        guard let monday = calendar.date(from: components) else { return now...now }
        let sunday = calendar.date(byAdding: .day, value: 6, to: monday)!
        return monday...sunday
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Chart {
                ForEach(filteredAndSortedMetrics) { item in
                    let dayStart = Calendar.current.startOfDay(for: item.date)
                    
                    // TREND LINE (Solid Thin)
                    LineMark(
                        x: .value("Day", dayStart),
                        y: .value("Engagement", item.engagement)
                    )
                    .foregroundStyle(by: .value("Platform", item.platform.lowercased()))
                    .interpolationMethod(.linear)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))

                    // DATA POINT
                    PointMark(
                        x: .value("Day", dayStart),
                        y: .value("Engagement", item.engagement)
                    )
                    .foregroundStyle(by: .value("Platform", item.platform.lowercased()))
                    .symbolSize(60)
                }
            }
            .chartForegroundStyleScale([
                "instagram": .pink,
                "twitter": .black,
                "linkedin": .blue
            ])
            .chartXScale(domain: currentWeekRange)
            .chartYScale(domain: .automatic(includesZero: true))
            .chartLegend(.hidden) // Keep default legend hidden to use our custom one
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    if let _ = value.as(Date.self) {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
                        AxisTick()
                        AxisValueLabel(format: .dateTime.weekday(.narrow), centered: false)
                            .font(.caption2.bold())
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    if let intValue = value.as(Int.self) {
                        AxisValueLabel(formatValue(intValue))
                    }
                }
            }
            .frame(minHeight: 200) // Ensure enough room for data
            
            // 🛑 NEW: CUSTOM LEGEND (Bottom Left)
            HStack(spacing: 16) {
                ForEach(activePlatforms, id: \.self) { platform in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(platformColors[platform] ?? .gray)
                            .frame(width: 8, height: 8)
                        Text(platform.capitalized)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.leading, 10) // Align with the start of the chart
        }
        .padding(.horizontal, 15)
        .padding(.top, 20)
        .padding(.bottom, 10)
        .background(Color(.systemBackground))
        .clipped()
    }
    
    func formatValue(_ value: Int) -> String {
        let num = Double(value)
        if num >= 1_000_000 { return String(format: "%.1fM", num / 1_000_000) }
        if num >= 1_000 { return String(format: "%.0fK", num / 1_000) }
        return "\(value)"
    }
}

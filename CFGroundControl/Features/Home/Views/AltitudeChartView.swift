//
//  AltitudeChartView.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 18/08/25.
//

import SwiftUI
import Charts

struct AltitudeChartView: View {
    
    @Binding var telemetryData: TelemetryData
    
    private var absoluteAltitude: String {
        guard let lastData = telemetryData.altitudeData.elements.last else { return "0.0" }
        return String(format: "%.1f", lastData.absoluteAltitude)
    }
    
    private var relativeAltitude: String {
        guard let lastData = telemetryData.altitudeData.elements.last else { return "0.0" }
        return String(format: "%.1f", lastData.relativeAltitude)
    }
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 6) {
            Text("Altitude")
                .font(.cfFont(.semiBold, .bodyLarge))
                .foregroundStyle(Color.cfColor(.black300))
            
            Chart {
                ForEach(telemetryData.altitudeData.elements) { data in
                    LineMark(
                        x: .value("Time", data.timestamp),
                        y: .value("Degrees", min(5, max(-5, data.relativeAltitude))),
                        series: .value("Axis", "Relative Altitude")
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
                }
                
                RuleMark(y: .value("Zero", 0))
                    .foregroundStyle(Color.cfColor(.black200))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
            .frame(height: 150)
            .chartYScale(domain: -5...5)
            .padding(.vertical, 10)
            .clipped()
            .chartYAxis {
                AxisMarks(position: .leading, values: .stride(by: 1)) { _ in
                    AxisGridLine()
                        .foregroundStyle(Color.cfColor(.black100))
                    AxisValueLabel()
                        .foregroundStyle(Color.cfColor(.black300))
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                        .foregroundStyle(Color.cfColor(.black100))
                }
            }
            .chartForegroundStyleScale([
                "Relative Altitude": .blue
            ])
            .chartLegend(position: .bottom, alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Label("Relative Altitude", systemImage: "minus")
                        .foregroundStyle(.blue)
                        .font(.cfFont(.semiBold, .small))
                }
            }
            
            HStack {
                Spacer()
                
                VStack {
                    Text("Absolute")
                        .font(.cfFont(.regular, .bodySmall))
                        .foregroundStyle(Color.cfColor(.black300))
                    
                    Text("\(absoluteAltitude) m")
                        .font(.cfFont(.regular, .small))
                        .foregroundStyle(Color.cfColor(.black300))
                }
                
                Spacer()
                
                VStack {
                    Text("Relative")
                        .font(.cfFont(.regular, .bodySmall))
                        .foregroundStyle(Color.cfColor(.black300))
                    
                    Text("\(relativeAltitude) m")
                        .font(.cfFont(.regular, .small))
                        .foregroundStyle(Color.cfColor(.black300))
                }
                
                Spacer()
            }
        }
    }
}

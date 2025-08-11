//
//  AttitudeChartView.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 04/08/25.
//

import SwiftUI
import Charts

struct AttitudeChartView: View {
    
    @Binding var telemetryData: TelemetryData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Attitude")
                .font(.cfFont(.semiBold, .bodySmall))
                .foregroundStyle(Color.cfColor(.black300))
            
            Chart {
                ForEach(telemetryData.attitudeData) { data in
                    LineMark(
                        x: .value("Time", data.timestamp),
                        y: .value("Degrees", min(45, max(-45, data.roll))),
                        series: .value("Axis", "Roll")
                    )
                    .foregroundStyle(.red)
                    .interpolationMethod(.catmullRom)
                }
                
                ForEach(telemetryData.attitudeData) { data in
                    LineMark(
                        x: .value("Time", data.timestamp),
                        y: .value("Degrees", min(45, max(-45, data.pitch))),
                        series: .value("Axis", "Pitch")
                    )
                    .foregroundStyle(.green)
                    .interpolationMethod(.catmullRom)
                }
                
                ForEach(telemetryData.attitudeData) { data in
                    LineMark(
                        x: .value("Time", data.timestamp),
                        y: .value("Degrees", min(45, max(-45, data.yaw))),
                        series: .value("Axis", "Yaw")
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
                }
                
                RuleMark(y: .value("Zero", 0))
                    .foregroundStyle(Color.cfColor(.black200))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
            .frame(height: 150)
            .chartYScale(domain: -45...45)
            .padding(.vertical, 10)
            .clipped()
            .chartYAxis {
                AxisMarks(position: .leading, values: .stride(by: 10)) { _ in
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
                "Roll": .red,
                "Pitch": .green,
                "Yaw": .blue
            ])
            .chartLegend(position: .bottom, alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Label("Roll", systemImage: "minus")
                        .foregroundStyle(.red)
                        .font(.cfFont(.semiBold, .small))
                    
                    Label("Pitch", systemImage: "minus")
                        .foregroundStyle(.green)
                        .font(.cfFont(.semiBold, .small))
                    
                    Label("Yaw", systemImage: "minus")
                        .foregroundStyle(.blue)
                        .font(.cfFont(.semiBold, .small))
                }
            }
        }
    }
}

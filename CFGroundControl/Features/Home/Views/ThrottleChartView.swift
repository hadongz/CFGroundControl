//
//  ThrottleChartView.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 04/08/25.
//

import SwiftUI
import Charts

struct ThrottleChartView: View {
    
    @Binding var telemetryData: TelemetryData
    
    var body: some View {
        AccordionView(title: "Throttle Demand") {
            Chart {
                ForEach(telemetryData.throttleData.elements) { data in
                    AreaMark(
                        x: .value("Time", data.timestamp),
                        y: .value("Throttle", data.value)
                    )
                    .foregroundStyle(.purple.opacity(0.3))
                    
                    LineMark(
                        x: .value("Time", data.timestamp),
                        y: .value("Throttle", data.value)
                    )
                    .foregroundStyle(.purple)
                }
                
                RuleMark(y: .value("Hover", 0.5))
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(dash: [5]))
            }
            .frame(height: 100)
            .chartYScale(domain: 0...1)
            .padding(.vertical, 10)
            .clipped()
            .chartYAxis {
                AxisMarks(position: .leading, values: .stride(by: 0.25)) { _ in
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
        }
    }
}

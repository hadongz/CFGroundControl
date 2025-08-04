//
//  PIDChartView.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 04/08/25.
//

import SwiftUI
import Charts

struct PIDChartView: View {
    
    @Binding var telemetryData: TelemetryData
    
    private var latestPIDData: EulerAngleData? {
        telemetryData.pidData.last
    }
    
    private func toDegrees(_ radians: Double) -> Double {
        radians * 180 / .pi
    }
    
    var body: some View {
        AccordionView(title: "PID Output") {
            VStack(spacing: 8) {
                PIDAxisIndicator(
                    axis: "Roll",
                    value: latestPIDData?.roll ?? 0,
                    color: .red,
                    maxValue: 5
                )
                
                PIDAxisIndicator(
                    axis: "Pitch",
                    value: latestPIDData?.pitch ?? 0,
                    color: .green,
                    maxValue: 5
                )
                
                PIDAxisIndicator(
                    axis: "Yaw",
                    value: latestPIDData?.yaw ?? 0,
                    color: .blue,
                    maxValue: 5
                )
                
                Spacer(minLength: 16)
                
                Chart {
                    ForEach(telemetryData.pidData) { data in
                        LineMark(
                            x: .value("Time", data.timestamp),
                            y: .value("Output", data.roll),
                            series: .value("Axis", "Roll")
                        )
                        .foregroundStyle(.red)
                        
                        LineMark(
                            x: .value("Time", data.timestamp),
                            y: .value("Output", data.pitch),
                            series: .value("Axis", "Pitch")
                        )
                        .foregroundStyle(.green)
                        
                        LineMark(
                            x: .value("Time", data.timestamp),
                            y: .value("Output", data.yaw),
                            series: .value("Axis", "Yaw")
                        )
                        .foregroundStyle(.blue)
                    }
                    
                    RuleMark(y: .value("Zero", 0))
                        .foregroundStyle(.gray)
                        .lineStyle(StrokeStyle(dash: [5]))
                }
                .frame(height: 150)
                .chartYScale(domain: -5...5)
                .padding(.vertical, 10)
                .clipped()
                .chartYAxis {
                    AxisMarks(position: .leading, values: .stride(by: 2.5)) { _ in
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
            .padding(.vertical, 12)
        }
    }
}

fileprivate struct PIDAxisIndicator: View {
    let axis: String
    let value: Float
    let color: Color
    let maxValue: Float
    
    private var degrees: Float {
        value * 180 / .pi
    }
    
    private var percentage: Float {
        value / maxValue
    }
    
    private var isHighCorrection: Bool {
        abs(value) > maxValue * 0.5
    }
    
    private var barWidth: CGFloat {
        CGFloat(abs(percentage)) * 90
    }
    
    private var barColor: Color {
        isHighCorrection ? Color.orange : color.opacity(0.8)
    }
    
    private var valueColor: Color {
        isHighCorrection ? Color.orange : Color.cfColor(.black300)
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                Text(axis)
                    .font(.cfFont(.semiBold, .bodySmall))
                    .foregroundStyle(color)
                    .frame(width: geometry.size.width * 0.2, alignment: .leading)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.cfColor(.black100, opacity: 0.5))
                        .frame(height: 20)
                    
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: 2, height: 20)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: barWidth, height: 16)
                        .offset(x: percentage > 0 ? barWidth / 2 : -barWidth / 2)
                        .animation(.easeOut(duration: 0.1), value: value)
                }
                .frame(width: geometry.size.width * 0.6)
                
                Text(String(format: "%.1f°", degrees))
                    .font(.cfFont(.regular, .bodySmall))
                    .foregroundStyle(valueColor)
                    .frame(width: geometry.size.width * 0.2, alignment: .trailing)
            }
        }
        .frame(height: 20)
    }
}

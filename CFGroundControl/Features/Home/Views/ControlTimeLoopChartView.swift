//
//  ControlTimeLoopChartView.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 09/08/25.
//

import SwiftUI
import Charts

struct ControlTimeLoopChartView: View {
    
    @Binding var telemetryData: TelemetryData
    
    var lastData: ControlLoopTimeData? {
        return telemetryData.controlLoopTimeData.last
    }
    
    var firstData: ControlLoopTimeData? {
        return telemetryData.controlLoopTimeData.first
    }
    
    var body: some View {
        AccordionView(title: "Control Time Loop (Hz)") {
            VStack(spacing: 8) {
                HStack(spacing: 16) {
                    if let lastData {
                        VStack(spacing: 2) {
                            Text("Avg")
                                .font(.cfFont(.semiBold, .bodySmall))
                                .foregroundStyle(Color.cfColor(.black300))
                            
                            Text("\(lastData.avgFreqHz)")
                                .font(.cfFont(.regular, .bodyLarge))
                                .foregroundStyle(Color.cfColor(.black300))
                        }
                        
                        VStack(spacing: 2) {
                            Text("Current")
                                .font(.cfFont(.semiBold, .bodySmall))
                                .foregroundStyle(Color.cfColor(.black300))
                            
                            Text("\(lastData.currentFreqHz)")
                                .font(.cfFont(.regular, .bodyLarge))
                                .foregroundStyle(Color.cfColor(.black300))
                        }
                        
                        VStack(spacing: 2) {
                            Text("Min")
                                .font(.cfFont(.semiBold, .bodySmall))
                                .foregroundStyle(Color.cfColor(.black300))
                            
                            Text("\(lastData.minFreqHz)")
                                .font(.cfFont(.regular, .bodyLarge))
                                .foregroundStyle(Color.cfColor(.black300))
                        }
                        
                        VStack(spacing: 2) {
                            Text("Max")
                                .font(.cfFont(.semiBold, .bodySmall))
                                .foregroundStyle(Color.cfColor(.black300))
                            
                            Text("\(lastData.maxFreqHz)")
                                .font(.cfFont(.regular, .title))
                                .foregroundStyle(Color.cfColor(.black300))
                        }
                    } else {
                        Text("No data yet")
                            .font(.cfFont(.semiBold, .bodyLarge))
                            .foregroundStyle(Color.cfColor(.black300))
                            .padding(.vertical, 25)
                    }
                }
                
                if let firstData, let lastData {
                    Chart {
                        RectangleMark(
                            xStart: .value("Start", firstData.timestamp),
                            xEnd: .value("End", lastData.timestamp),
                            yStart: .value("Y Start", 0),
                            yEnd: .value("Y End", 750)
                        )
                        .foregroundStyle(.red.opacity(0.15))
                        
                        RectangleMark(
                            xStart: .value("Start", firstData.timestamp),
                            xEnd: .value("End", lastData.timestamp),
                            yStart: .value("Y Start", 750),
                            yEnd: .value("Y End", 1000)
                        )
                        .foregroundStyle(.yellow.opacity(0.15))
                        
                        RectangleMark(
                            xStart: .value("Start", firstData.timestamp),
                            xEnd: .value("End", lastData.timestamp),
                            yStart: .value("Y Start", 1000),
                            yEnd: .value("Y End", 2000)
                        )
                        .foregroundStyle(.green.opacity(0.15))
                        
                        ForEach(telemetryData.controlLoopTimeData) { data in
                            LineMark(
                                x: .value("Time", data.timestamp),
                                y: .value("Current Freq Hz", data.currentFreqHz)
                            )
                            .foregroundStyle(colorForFrequency(data.currentFreqHz))
                            .lineStyle(StrokeStyle(lineWidth: 3))
                        }
                    }
                    .frame(height: 250)
                    .chartYScale(domain: 500...2000)
                    .padding(.vertical, 10)
                    .clipped()
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .stride(by: 100)) { _ in
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
                    .chartLegend(position: .bottom, alignment: .leading, spacing: 8) {
                        HStack(spacing: 15) {
                            HStack(spacing: 4) {
                                Rectangle()
                                    .fill(.red)
                                    .frame(width: 16, height: 3)
                                Text("< 750Hz")
                                    .font(.cfFont(.semiBold, .small))
                            }
                            
                            HStack(spacing: 4) {
                                Rectangle()
                                    .fill(.yellow)
                                    .frame(width: 16, height: 3)
                                Text("750-1000Hz")
                                    .font(.cfFont(.semiBold, .small))
                            }
                            
                            HStack(spacing: 4) {
                                Rectangle()
                                    .fill(.green)
                                    .frame(width: 16, height: 3)
                                Text("≥ 1000Hz")
                                    .font(.cfFont(.semiBold, .small))
                            }
                        }
                    }
                }
                


            }
            .padding(.vertical, 12)
        }
    }
    
    private func colorForFrequency(_ frequency: Int) -> Color {
        switch frequency {
        case ..<750:
            return .red
        case 750..<1000:
            return .yellow
        default:
            return .green
        }
    }
}

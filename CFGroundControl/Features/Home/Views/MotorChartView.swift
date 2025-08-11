//
//  MotorChartView.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 04/08/25.
//

import SwiftUI
import Charts

struct MotorChartView: View {
    
    @Binding var telemetryData: TelemetryData
    
    private var latestMotorData: MotorData? {
        telemetryData.motorData.last
    }
    
    private var averagePWM: Int {
        guard let latest = latestMotorData else { return 1000 }
        return (latest.motor1 + latest.motor2 + latest.motor3 + latest.motor4) / 4
    }
    
    private func isBalanced(_ value: Int) -> Bool {
        abs(value - averagePWM) < Int(Double(averagePWM) * 0.05)
    }
    
    var body: some View {
        AccordionView(title: "Motor PWM Values") {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    MotorIndicator(
                        label: "M1",
                        value: latestMotorData?.motor1 ?? 1000,
                        average: averagePWM,
                        color: .red,
                        isBalanced: isBalanced(latestMotorData?.motor1 ?? 1000)
                    )
                    
                    MotorIndicator(
                        label: "M2",
                        value: latestMotorData?.motor2 ?? 1000,
                        average: averagePWM,
                        color: .blue,
                        isBalanced: isBalanced(latestMotorData?.motor2 ?? 1000)
                    )
                    
                    MotorIndicator(
                        label: "M3",
                        value: latestMotorData?.motor3 ?? 1000,
                        average: averagePWM,
                        color: .green,
                        isBalanced: isBalanced(latestMotorData?.motor3 ?? 1000)
                    )
                    
                    MotorIndicator(
                        label: "M4",
                        value: latestMotorData?.motor4 ?? 1000,
                        average: averagePWM,
                        color: .orange,
                        isBalanced: isBalanced(latestMotorData?.motor4 ?? 1000)
                    )
                }
                
                HStack {
                    Text("Average PWM:")
                        .font(.cfFont(.regular, .bodySmall))
                        .foregroundStyle(Color.cfColor(.black200))
                    Text("\(averagePWM)")
                        .font(.cfFont(.semiBold, .bodySmall))
                        .foregroundStyle(Color.cfColor(.black300))
                }
            }
            .padding(.vertical, 12)
        }
    }
}

fileprivate struct MotorIndicator: View {
    
    let label: String
    let value: Int
    let average: Int
    let color: Color
    let isBalanced: Bool
    
    private var percentageOfMax: Double {
        Double(value - 1000) / 1000.0
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.cfFont(.semiBold, .bodySmall))
                .foregroundStyle(color)
            
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.cfColor(.black100, opacity: 0.5))
                    .frame(width: 60, height: 120)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(isBalanced ? color.opacity(0.8) : Color.red)
                    .frame(width: 60, height: max(4, 120 * percentageOfMax))
                    .animation(.easeOut(duration: 0.2), value: Double(value))
                
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: 60, height: 2)
                    .offset(y: -(120 * Double(average - 1000) / 1000.0))
            }
            
            Text("\(value)")
                .font(.cfFont(.regular, .small))
                .foregroundStyle(isBalanced ? Color.cfColor(.black300) : .red)
        }
    }
}

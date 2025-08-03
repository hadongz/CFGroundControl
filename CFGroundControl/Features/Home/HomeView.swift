//
//  HomeView.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 03/08/25.
//

import SwiftUI
import GameController

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    
    @State var connectionAnimationId: UUID = UUID()
    @State var isBlinking: Bool = false
    
    init(viewModel: HomeViewModel = HomeViewModel()) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.cfColor(.white),
                    Color.cfColor(.lightYellow),
                    Color.cfColor(.yellow)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView {
                    VStack(spacing: 20) {
                        Spacer(minLength: 0)
                        
                        if viewModel.isMAVLinkConnected {
                            telemetryGrid
                        }

                        connectionStatusCard
                        
                        if viewModel.isMAVLinkConnected && viewModel.isStickConnected {
                            controllerInputCard
                        }
                        
                        if viewModel.isMAVLinkConnected {
                            mavlinkMessagesCard
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .GCControllerDidConnect)) { _ in
            guard let controller = GCController.controllers().first else { return }
            viewModel.stickDidConnect(controller)
        }
        .onReceive(NotificationCenter.default.publisher(for: .GCControllerDidDisconnect)) { _ in
            viewModel.stickDidDisconnect()
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CF Ground Control")
                        .font(.cfFont(.bold, .title))
                        .foregroundColor(Color.cfColor(.jetBlack))
                    
                    Text("ESP8266 MAVLink Controller")
                        .font(.cfFont(.regular, .small))
                        .foregroundColor(Color.cfColor(.black300))
                }
                
                Spacer()
                
                connectionIndicator
            }
            
            Divider()
                .background(Color.cfColor(.black100))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.cfColor(.white))
    }
    
    private var connectionIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(viewModel.isMAVLinkConnected ? Color.green : Color.red)
                .frame(width: 10, height: 10)
                .opacity(!viewModel.isMAVLinkConnected ? 1.0 : (isBlinking ? 1.0 : 0.3))
                .id(connectionAnimationId)
                .onChange(of: viewModel.isMAVLinkConnected, perform: { newValue in
                    if newValue {
                        withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                            isBlinking = true
                        }
                    } else {
                        isBlinking = false
                        connectionAnimationId = UUID()
                    }
                })
            
            Text(viewModel.isMAVLinkConnected ? "CONNECTED" : "OFFLINE")
                .font(.cfFont(.semiBold, .bodyLarge))
                .foregroundColor(viewModel.isMAVLinkConnected ? Color.green : Color.red)
        }
    }
    
    // MARK: - Connection Status Card
    private var connectionStatusCard: some View {
        ModernCardView {
            VStack(spacing: 16) {
                HStack {
                    Text("Connection")
                        .font(.cfFont(.bold, .title))
                        .foregroundColor(.cfColor(.jetBlack))
                    
                    Spacer()
                    
                    if viewModel.isMAVLinkConnected {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundColor(.cfColor(.orange))
                    }
                }
                
                VStack(spacing: 12) {
                    InfoRowView(label: "Status", value: viewModel.connectionStatus)
                    InfoRowView(label: "Protocol", value: "MAVLink")
                    InfoRowView(label: "Port", value: viewModel.port)
                    
                    if let error = viewModel.errorMessage {
                        InfoRowView(label: "Error", value: error, isError: true)
                    }
                }
                
                HStack(spacing: 12) {
                    ModernButtonView(
                        title: "Connect",
                        icon: "wifi",
                        color: .cfColor(.darkYellow),
                        isEnabled: !viewModel.isMAVLinkConnected
                    ) {
                        viewModel.connectToMAVLink()
                        viewModel.connectToMAVLink()
                    }
                    
                    ModernButtonView(
                        title: "Disconnect",
                        icon: "wifi.slash",
                        color: .red,
                        isEnabled: viewModel.isMAVLinkConnected
                    ) {
                        viewModel.disconnectMAVLink()
                    }
                }
            }
        }
    }
    
    // MARK: - Telemetry Grid
    private var telemetryGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 8) {
            TelemetryCardView(
                title: "Armed",
                value: viewModel.telemetryData.isArmed ? "YES" : "NO",
                icon: "airplane",
                color: viewModel.telemetryData.isArmed ? .green : .red
            )
            
            TelemetryCardView(
                title: "Controller",
                value: viewModel.isStickConnected ? "CONNECTED" : "OFFLINE",
                icon: "gamecontroller.fill",
                color: viewModel.isStickConnected ? .green : .red
            )
        }
    }
    
    // MARK: - Controller Input Visualization
    private var controllerInputCard: some View {
        ModernCardView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Controller Inputs")
                    .font(.cfFont(.bold, .title))
                    .foregroundColor(Color.cfColor(.jetBlack))
                
                HStack(spacing: 20) {
                    StickVisualizationView(
                        title: "Roll/Pitch",
                        x: viewModel.leftStickX,
                        y: viewModel.leftStickY
                    )
                    
                    Spacer()
                    
                    StickVisualizationView(
                        title: "Yaw/Throttle",
                        x: viewModel.rightStickX,
                        y: viewModel.rightStickY
                    )
                }
                
                VStack(spacing: 8) {
                    HStack {
                        InputValueView(label: "Roll", value: viewModel.leftStickX, alignment: .leading)
                        Spacer()
                        InputValueView(label: "Pitch", value: viewModel.leftStickY, alignment: .leading)
                    }
                    
                    HStack {
                        InputValueView(label: "Yaw", value: viewModel.rightStickX, alignment: .trailing)
                        Spacer()
                        InputValueView(label: "Throttle", value: viewModel.rightStickY, alignment: .trailing)
                    }
                }
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - MAVLink Messages
    private var mavlinkMessagesCard: some View {
        ModernCardView {
            VStack(alignment: .leading, spacing: 12) {
                Text("MAVLink Messages")
                    .font(.cfFont(.bold, .title))
                    .foregroundColor(Color.cfColor(.jetBlack))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Messages:")
                        .font(.cfFont(.regular, .bodySmall))
                        .foregroundColor(.cfColor(.black300))
                    if viewModel.telemetryData.statusText.isEmpty {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.cfColor(.black100).opacity(0.3))
                            .frame(height: 120)
                            .overlay(
                                Text("Message log will appear here...")
                                    .font(.cfFont(.regular, .small))
                                    .foregroundColor(.cfColor(.black300))
                            )
                    } else {
                        ScrollView(.vertical, showsIndicators: true) {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(viewModel.telemetryData.statusText.indices.reversed(), id: \.self) { index in
                                    Text(viewModel.telemetryData.statusText[index])
                                        .font(.cfFont(.regular, .small))
                                        .foregroundColor(.cfColor(.black300))
                                }
                            }
                            .padding(8)
                        }
                        .background(Color.cfColor(.black100).opacity(0.3))
                        .cornerRadius(8)
                        .frame(height: 200)
                    }
                }
            }
        }
    }
}

//
//  SessionListView.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 05/08/25.
//

import SwiftUI

struct SessionListView: View {
    
    @EnvironmentObject var appUtility: AppUtility
    @StateObject var viewModel: SessionListViewModel
    
    @State private var showDeleteAlert = false
    @State private var sessionToDelete: SessionFolderData?
    
    init(viewModel: SessionListViewModel = SessionListViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationBarView(title: "Session List") {
            ScrollView {
                if viewModel.sessionList.isEmpty {
                    VStack {
                        Text("No session found")
                            .font(.cfFont(.semiBold, .bodyLarge))
                            .foregroundStyle(Color.cfColor(.black300))
                    }
                    .padding(20)
                    
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.sessionList, id: \.id) { session in
                            HStack(spacing: 10) {
                                Text(session.name)
                                    .font(.cfFont(.regular, .bodySmall))
                                    .foregroundStyle(Color.cfColor(.black300))
                                
                                Spacer()
                                
                                Button {
                                    guard let zipURL = viewModel.zipSession(session) else { return }
                                    let shareableFile = ShareableFile(url: zipURL, title: session.name)
                                    appUtility.share(items: [shareableFile]) {
                                        try? FileManager.default.removeItem(at: zipURL)
                                    }
                                } label: {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.blue)
                                }
                                
                                Button {
                                    sessionToDelete = session
                                    showDeleteAlert = true
                                } label: {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.red)
                                }

                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .frame(height: 40)
                            .background(Color.cfColor(.white))
                            .cornerRadius(8)
                            .subtleShadow()
                        }
                    }
                    .padding(20)
                }
            }
            .background(Color.cfColor(.lightYellow))
            .onViewDidLoad {
                viewModel.loadSessionList()
            }
            .alert("Delete Session", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let session = sessionToDelete {
                        viewModel.deleteSession(session)
                        sessionToDelete = nil
                    }
                }
            } message: {
                Text("Are you sure you want to delete this session? This action cannot be undone.")
            }
        }
    }
}


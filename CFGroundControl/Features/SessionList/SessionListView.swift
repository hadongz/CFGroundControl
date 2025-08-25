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
    @State private var deleteSectionIndex: Int?
    @State private var sessionToDelete: SessionFolderData?
    
    init(viewModel: SessionListViewModel = SessionListViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationBarView(title: "Session List", rightItemView: AnyView(rightNavBarView)) {
            ScrollView {
                if viewModel.sessionSections.isEmpty {
                    Spacer(minLength: 100)
                    
                    VStack(spacing: 10) {
                        Image.illustration(.illustrationWarning)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 200, height: 250)
                            
                        Text("No session found")
                            .font(.cfFont(.semiBold, .title))
                            .foregroundStyle(Color.cfColor(.black300))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(20)
                    
                } else {
                    sectionsListView
                }
            }
            .background(
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
            )
            .onViewDidLoad {
                viewModel.loadSessionList()
            }
            .alert("Delete Session", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let session = sessionToDelete, let sectionIndex = deleteSectionIndex {
                        viewModel.deleteSession(session, sectionIndex: sectionIndex)
                        sessionToDelete = nil
                    }
                }
            } message: {
                Text("Are you sure you want to delete this session? This action cannot be undone.")
            }
        }
    }
    
    private var rightNavBarView: some View {
        Button {
            guard let zipUrl = viewModel.shareAllSession() else { return }
            let shareableFile = ShareableFile(url: zipUrl, title: "DroneSessions")
            appUtility.share(items: [shareableFile]) {
                try? FileManager.default.removeItem(at: zipUrl)
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.cfColor(.darkYellow))
        }

    }
    
    private var sectionsListView: some View {
        LazyVStack(spacing: 16) {
            ForEach(Array(viewModel.sessionSections.enumerated()), id: \.offset) { index, section in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(section.sectionTitle)
                            .font(.cfFont(.semiBold, .bodyLarge))
                            .foregroundStyle(Color.cfColor(.black500))
                        
                        Spacer()
                        
                        Text("\(section.sessions.count) session\(section.sessions.count == 1 ? "" : "s")")
                            .font(.cfFont(.regular, .bodySmall))
                            .foregroundStyle(Color.cfColor(.black300))
                    }
                    .padding(.horizontal, 20)
                    
                    LazyVStack(spacing: 8) {
                        ForEach(section.sessions, id: \.id) { session in
                            SessionRowView(
                                session: session,
                                onShare: { session in
                                    guard let zipURL = viewModel.zipSession(session) else { return }
                                    let shareableFile = ShareableFile(url: zipURL, title: session.name)
                                    appUtility.share(items: [shareableFile]) {
                                        try? FileManager.default.removeItem(at: zipURL)
                                    }
                                },
                                onDelete: { session in
                                    sessionToDelete = session
                                    deleteSectionIndex = index
                                    showDeleteAlert = true
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .padding(.vertical, 20)
    }
}

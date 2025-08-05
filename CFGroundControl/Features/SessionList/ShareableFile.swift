//
//  ShareableFile.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 06/08/25.
//

import Foundation
import LinkPresentation

final class ShareableFile: NSObject, UIActivityItemSource {
    
    private let url: URL
    private let title: String
    
    init(url: URL, title: String) {
        self.url = url
        self.title = title
        super.init()
    }
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return self.url
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return self.url
    }
    
    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = self.title
        metadata.iconProvider = NSItemProvider(contentsOf: self.url)
        
        return metadata
    }
}

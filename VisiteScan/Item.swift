//
//  Item.swift
//  VisiteScan
//
//  Created by Erich Lutz on 2026/07/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}

//
//  NotchPadBlock.swift
//  boringNotch
//

import Foundation

public enum BlockType: Codable, Hashable, Equatable {
    case text
    case todo(isCompleted: Bool)
    case bullet
    case heading1
    case heading2
    case code

    private enum CodingKeys: String, CodingKey {
        case kind
        case isCompleted
    }

    private enum Kind: String, Codable {
        case text
        case todo
        case bullet
        case heading1
        case heading2
        case code
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .text:
            self = .text
        case .todo:
            let completed = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
            self = .todo(isCompleted: completed)
        case .bullet:
            self = .bullet
        case .heading1:
            self = .heading1
        case .heading2:
            self = .heading2
        case .code:
            self = .code
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text:
            try container.encode(Kind.text, forKey: .kind)
        case .todo(let isCompleted):
            try container.encode(Kind.todo, forKey: .kind)
            try container.encode(isCompleted, forKey: .isCompleted)
        case .bullet:
            try container.encode(Kind.bullet, forKey: .kind)
        case .heading1:
            try container.encode(Kind.heading1, forKey: .kind)
        case .heading2:
            try container.encode(Kind.heading2, forKey: .kind)
        case .code:
            try container.encode(Kind.code, forKey: .kind)
        }
    }

    public var isTodo: Bool {
        if case .todo = self { return true }
        return false
    }

    public var isCompleted: Bool {
        if case .todo(let completed) = self { return completed }
        return false
    }
}

public struct NotchPadBlock: Identifiable, Codable, Hashable, Equatable {
    public let id: UUID
    public var type: BlockType
    public var content: String
    public var createdAt: Date

    public init(id: UUID = UUID(), type: BlockType = .text, content: String = "", createdAt: Date = Date()) {
        self.id = id
        self.type = type
        self.content = content
        self.createdAt = createdAt
    }

    public var isCompleted: Bool {
        return type.isCompleted
    }

    public var isTodo: Bool {
        return type.isTodo
    }
}

public enum NotchPadMode: String, Codable, CaseIterable {
    case freeform = "Notes"
    case checklist = "Checklist"
}

public struct NotchPadData: Codable {
    public var freeformText: String
    public var checklistItems: [NotchPadBlock]
    public var mode: NotchPadMode

    public init(freeformText: String = "", checklistItems: [NotchPadBlock] = [], mode: NotchPadMode = .freeform) {
        self.freeformText = freeformText
        self.checklistItems = checklistItems
        self.mode = mode
    }
}

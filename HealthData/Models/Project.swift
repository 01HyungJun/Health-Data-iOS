import Foundation

struct Project: Codable, Identifiable {
    let id: Int
    let projectName: String
    let description: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id = "projectId"
        case projectName
        case description
        case createdAt
    }
}

struct ProjectResponse: Codable {
    // projects 배열은 ["java.util.ArrayList", [실제 프로젝트 배열]] 형태로 옴
    let projects: [ProjectArrayItem]
    
    var projectList: [Project] {
        guard projects.count > 1 else { return [] }
        
        // projects[0]은 "java.util.ArrayList" 문자열
        // projects[1]이 실제 프로젝트 배열
        if case .projectArray(let projects) = projects[1] {
            return projects
        }
        return []
    }
}

enum ProjectArrayItem: Codable {
    case string(String)
    case projectArray([Project])
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let projects = try? container.decode([Project].self) {
            self = .projectArray(projects)
        } else {
            throw DecodingError.typeMismatch(
                ProjectArrayItem.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected String or [Project]"
                )
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let string):
            try container.encode(string)
        case .projectArray(let projects):
            try container.encode(projects)
        }
    }
} 
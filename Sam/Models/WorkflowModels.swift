//
//  WorkflowModels.swift
//  Sam
//
//  Created by AI Assistant on 2024-01-01.
//

import Foundation

// MARK: - Workflow Step Types

enum WorkflowStepType: String, CaseIterable, Codable {
    case fileOperation = "file_operation"
    case appControl = "app_control"
    case systemCommand = "system_command"
    case userInput = "user_input"
    case conditional = "conditional"
    case delay = "delay"
    case textProcessing = "text_processing"
    case notification = "notification"
}

// MARK: - Workflow Step Definition

struct WorkflowStepDefinition: Identifiable, Codable {
    let id: UUID
    let name: String
    let type: WorkflowStepType
    let parameters: [String: AnyCodable]
    let continueOnError: Bool
    let retryCount: Int
    let timeout: TimeInterval
    let condition: WorkflowCondition?
    
    init(
        id: UUID = UUID(),
        name: String,
        type: WorkflowStepType,
        parameters: [String: Any] = [:],
        continueOnError: Bool = false,
        retryCount: Int = 0,
        timeout: TimeInterval = 30.0,
        condition: WorkflowCondition? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.parameters = parameters.mapValues { AnyCodable($0) }
        self.continueOnError = continueOnError
        self.retryCount = retryCount
        self.timeout = timeout
        self.condition = condition
    }
}

// MARK: - Workflow Condition

struct WorkflowCondition: Codable {
    enum ConditionType: String, Codable {
        case equals = "equals"
        case notEquals = "not_equals"
        case contains = "contains"
        case greaterThan = "greater_than"
        case lessThan = "less_than"
        case fileExists = "file_exists"
        case appRunning = "app_running"
        case custom = "custom"
    }
    
    let type: ConditionType
    let variable: String
    let value: AnyCodable
    let conditionOperator: String?
    
    init(type: ConditionType, variable: String, value: Any, conditionOperator: String? = nil) {
        self.type = type
        self.variable = variable
        self.value = AnyCodable(value)
        self.conditionOperator = conditionOperator
    }
}

// MARK: - Workflow Definition

struct WorkflowDefinition: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let steps: [WorkflowStepDefinition]
    let variables: [String: AnyCodable]
    let triggers: [WorkflowTrigger]
    let isEnabled: Bool
    let createdAt: Date
    let modifiedAt: Date
    let version: Int
    let tags: [String]
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        steps: [WorkflowStepDefinition] = [],
        variables: [String: Any] = [:],
        triggers: [WorkflowTrigger] = [],
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        version: Int = 1,
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.steps = steps
        self.variables = variables.mapValues { AnyCodable($0) }
        self.triggers = triggers
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.version = version
        self.tags = tags
    }
}

// MARK: - Workflow Trigger

struct WorkflowTrigger: Identifiable, Codable {
    enum TriggerType: String, CaseIterable, Codable {
        case manual = "manual"
        case scheduled = "scheduled"
        case fileChanged = "file_changed"
        case appLaunched = "app_launched"
        case systemEvent = "system_event"
        case hotkey = "hotkey"
        case webhook = "webhook"
    }
    
    let id: UUID
    let type: TriggerType
    let parameters: [String: AnyCodable]
    let isEnabled: Bool
    
    init(id: UUID = UUID(), type: TriggerType, parameters: [String: Any] = [:], isEnabled: Bool = true) {
        self.id = id
        self.type = type
        self.parameters = parameters.mapValues { AnyCodable($0) }
        self.isEnabled = isEnabled
    }
}

// MARK: - Workflow Execution Context

@MainActor
class WorkflowExecutionContext: ObservableObject {
    @Published var variables: [String: Any] = [:]
    @Published var currentStepIndex: Int = 0
    @Published var isRunning: Bool = false
    @Published var isPaused: Bool = false
    @Published var error: Error?
    
    let workflowId: UUID
    let executionId: UUID
    let startTime: Date
    var endTime: Date?
    
    init(workflowId: UUID) {
        self.workflowId = workflowId
        self.executionId = UUID()
        self.startTime = Date()
    }
    
    func setVariable(_ key: String, value: Any) {
        variables[key] = value
    }
    
    func getVariable(_ key: String) -> Any? {
        return variables[key]
    }
}

// MARK: - Workflow Execution Result

struct WorkflowExecutionResult: Codable {
    let executionId: UUID
    let workflowId: UUID
    let success: Bool
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let completedSteps: Int
    let totalSteps: Int
    let error: String?
    let stepResults: [WorkflowStepResult]
    let variables: [String: AnyCodable]
    
    var executionTime: TimeInterval {
        return duration
    }
}

// MARK: - Workflow Step Result

struct WorkflowStepResult: Identifiable, Codable {
    let id: UUID
    let stepId: UUID
    let stepName: String
    let success: Bool
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let output: String?
    let error: String?
    let retryCount: Int
    
    init(
        stepId: UUID,
        stepName: String,
        success: Bool,
        startTime: Date,
        endTime: Date,
        output: String? = nil,
        error: String? = nil,
        retryCount: Int = 0
    ) {
        self.id = UUID()
        self.stepId = stepId
        self.stepName = stepName
        self.success = success
        self.startTime = startTime
        self.endTime = endTime
        self.duration = endTime.timeIntervalSince(startTime)
        self.output = output
        self.error = error
        self.retryCount = retryCount
    }
}

// MARK: - Workflow Error Types

enum WorkflowError: LocalizedError {
    case stepExecutionFailed(stepName: String, error: Error)
    case conditionNotMet(condition: String)
    case timeoutExceeded(stepName: String)
    case userCancelled
    case invalidParameters(stepName: String, parameter: String)
    case workflowNotFound(id: UUID)
    case executionContextMissing
    case dependencyNotMet(dependency: String)
    
    var errorDescription: String? {
        switch self {
        case .stepExecutionFailed(let stepName, let error):
            return "Step '\(stepName)' failed: \(error.localizedDescription)"
        case .conditionNotMet(let condition):
            return "Condition not met: \(condition)"
        case .timeoutExceeded(let stepName):
            return "Step '\(stepName)' timed out"
        case .userCancelled:
            return "Workflow execution was cancelled by user"
        case .invalidParameters(let stepName, let parameter):
            return "Invalid parameter '\(parameter)' in step '\(stepName)'"
        case .workflowNotFound(let id):
            return "Workflow not found: \(id)"
        case .executionContextMissing:
            return "Workflow execution context is missing"
        case .dependencyNotMet(let dependency):
            return "Dependency not met: \(dependency)"
        }
    }
}

// MARK: - AnyCodable Helper

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
}
import Foundation
import SwiftUI

// MARK: - Note Template Model
public struct NoteTemplate: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let description: String
    public let icon: String
    public let defaultFolder: String
    public let contentTemplate: String
    
    public func resolveContent(title: String, folder: String = "General") -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let dateString = formatter.string(from: Date())
        
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        let timeString = formatter.string(from: Date())
        
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd"
        let isoDate = isoFormatter.string(from: Date())
        
        var content = contentTemplate
        content = content.replacingOccurrences(of: "{{title}}", with: title)
        content = content.replacingOccurrences(of: "{{date}}", with: dateString)
        content = content.replacingOccurrences(of: "{{time}}", with: timeString)
        content = content.replacingOccurrences(of: "{{iso_date}}", with: isoDate)
        content = content.replacingOccurrences(of: "{{folder}}", with: folder)
        return content
    }
}

// MARK: - Built-in Template Library
public struct TemplateLibrary {
    public static let meetingNotes = NoteTemplate(
        id: "meeting-notes",
        title: "Meeting Notes",
        description: "Structured agenda, participants, discussion log, and action items.",
        icon: "person.3.fill",
        defaultFolder: "Meetings",
        contentTemplate: """
        # 📋 {{title}}
        
        > **Date**: {{date}} at {{time}}  
        > **Folder**: [[{{folder}}]]  
        > **Attendees**: @  
        
        ---
        
        ## 🎯 Objective & Agenda
        1. Context & Goals
        2. Key Discussion Points
        3. Blockers & Decisions
        
        ## 💬 Discussion Notes
        - 
        
        ## ⚖️ Key Decisions
        - [x] Decision 1: 
        
        ## ✅ Action Items
        - [ ] Task 1 (@owner) - due by Friday
        - [ ] Task 2 (@owner) - due next week
        
        ## 🔗 Related Notes
        - [[Projects]] • [[General]]
        """
    )
    
    public static let cornellLecture = NoteTemplate(
        id: "cornell-lecture",
        title: "Cornell Academic Lecture",
        description: "Two-column cue & lecture notes format with bottom executive summary.",
        icon: "graduationcap.fill",
        defaultFolder: "Lectures",
        contentTemplate: """
        # 🎓 {{title}}
        
        > **Course**:   
        > **Date**: {{date}}  
        > **Topic**:   
        
        ---
        
        ## 🔍 Key Cues & Questions
        *What are the core principles?*
        - Key concept 1:
        - Key concept 2:
        
        ## 📝 Lecture Notes
        ### 1. Introduction & Background
        - Detailed point A
        - Detailed point B
        
        ### 2. Core Theorems & Equations
        $$
        f(x) = \\int_{-\\infty}^{\\infty} \\hat{f}(\\xi) e^{2 \\pi i \\xi x} d\\xi
        $$
        
        ### 3. Case Studies & Real-World Examples
        - 
        
        ---
        
        ## 📌 Executive Summary
        > Write a 2-3 sentence summary synthesizing the most critical takeaways from this session.
        """
    )
    
    public static let technicalRFC = NoteTemplate(
        id: "technical-rfc",
        title: "Technical Architecture (RFC)",
        description: "Problem statement, architecture diagram, API specs, and trade-offs.",
        icon: "cpu.fill",
        defaultFolder: "Engineering",
        contentTemplate: """
        # 🏗️ RFC: {{title}}
        
        > **Author**:   
        > **Status**: Proposed / Under Review  
        > **Created**: {{date}}  
        
        ---
        
        ## 1. Problem Statement & Motivation
        What problem does this proposal solve and why is it important now?
        
        ## 2. Architecture & Design
        ```mermaid
        flowchart TD
            Client[Client Application] --> Gateway[API Gateway]
            Gateway --> Auth[Auth Service]
            Gateway --> Engine[Core Processing Engine]
            Engine --> Database[(Secure Vault)]
        ```
        
        ## 3. Proposed Solution & API Specification
        ```swift
        protocol VaultService {
            func fetchRecords() async throws -> [Record]
            func syncAttachments() async -> Result<Void, Error>
        }
        ```
        
        ## 4. Trade-Offs & Alternatives Considered
        | Alternative | Pros | Cons |
        | --- | --- | --- |
        | Option A | High performance | Complex migration |
        | Option B | Simple setup | Limited scalability |
        
        ## 5. Security & Privacy Considerations
        - 100% On-device local execution
        """
    )
    
    public static let podcastInterview = NoteTemplate(
        id: "podcast-interview",
        title: "Podcast & Interview",
        description: "Guest background, question timeline, notable quotes, and takeaways.",
        icon: "mic.fill",
        defaultFolder: "Interviews",
        contentTemplate: """
        # 🎙️ Interview: {{title}}
        
        > **Guest**:   
        > **Host**:   
        > **Recorded**: {{date}}  
        
        ---
        
        ## 👤 Guest Background
        - **Current Role**: 
        - **Known For**: 
        - **Key Links**: 
        
        ## ❓ Interview Flow & Questions
        1. **Opening / Origin Story**: 
        2. **Core Discussion**: 
        3. **Future Outlook & Advice**: 
        
        ## 💡 Memorable Quotes
        > "Quote from guest here."
        
        ## 🔑 Key Takeaways & Action Points
        - [ ] Follow up on resource mentioned:
        - [ ] Connect with guest on:
        """
    )
    
    public static let dailyReflection = NoteTemplate(
        id: "daily-reflection",
        title: "Daily Focus & Log",
        description: "Top 3 priorities, time-blocked log, wins, and daily reflection.",
        icon: "sun.max.fill",
        defaultFolder: "Daily",
        contentTemplate: """
        # ☀️ Daily Log: {{date}}
        
        ---
        
        ## 🎯 Top 3 Priorities
        - [ ] 1. 
        - [ ] 2. 
        - [ ] 3. 
        
        ## ⏱️ Daily Log
        - **09:00** - Standup & planning
        - **11:00** - Deep work session
        - **14:00** - Review & meetings
        
        ## 🌟 Wins of the Day
        - 
        
        ## 💭 Evening Reflection
        - What went well today?
        - What could be improved tomorrow?
        """
    )
    
    public static let allTemplates: [NoteTemplate] = [
        meetingNotes,
        cornellLecture,
        technicalRFC,
        podcastInterview,
        dailyReflection
    ]
}

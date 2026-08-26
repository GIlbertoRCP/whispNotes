import SwiftUI

// MARK: - Interactive Calendar & Daily Notes Hub
struct CalendarModalView: View {
    @Binding var isOpen: Bool
    @Binding var notes: [NoteItem]
    @Binding var selectedNoteId: UUID?
    
    @AppStorage("isDarkMode") private var isDarkMode = true
    @AppStorage("colorTheme") private var colorTheme = "Classic Minimal"
    
    @State private var displayedMonth: Date = Date()
    @State private var selectedDate: Date = Date()
    
    private var primaryAccent: Color {
        ThemeColors.primary(colorTheme, isDark: isDarkMode)
    }
    
    private var secondaryAccent: Color {
        ThemeColors.secondary(colorTheme, isDark: isDarkMode)
    }
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    init(isOpen: Binding<Bool>, notes: Binding<[NoteItem]>, selectedNoteId: Binding<UUID?>) {
        self._isOpen = isOpen
        self._notes = notes
        self._selectedNoteId = selectedNoteId
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            // Left Panel: Interactive Month Calendar Grid
            VStack(spacing: 16) {
                // Top Calendar Header
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.title2)
                            .foregroundColor(primaryAccent)
                        
                        Text(monthYearString(from: displayedMonth))
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    // Navigation Controls
                    HStack(spacing: 6) {
                        Button(action: { changeMonth(by: -1) }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .bold))
                                .padding(7)
                                .background(Color.cardBackground(isDarkMode))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .help("Previous Month")
                        
                        Button("Today") {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                displayedMonth = Date()
                                selectedDate = Date()
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(isDarkMode ? Color.white.opacity(0.12) : Color.black.opacity(0.06))
                        .cornerRadius(6)
                        
                        Button(action: { changeMonth(by: 1) }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .padding(7)
                                .background(Color.cardBackground(isDarkMode))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .help("Next Month")
                    }
                }
                .padding(.horizontal, 4)
                
                // Days of Week Header
                HStack(spacing: 0) {
                    ForEach(daysOfWeek, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(isDarkMode ? Color(red: 148/255, green: 163/255, blue: 184/255) : Color(red: 100/255, green: 116/255, blue: 139/255))
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // Calendar Days Grid
                let days = daysInMonth(for: displayedMonth)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                    ForEach(days, id: \.self) { date in
                        if let date = date {
                            let isCurrentSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                            let isToday = calendar.isDateInToday(date)
                            let noteCount = notesForDate(date).count
                            
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.12)) {
                                    selectedDate = date
                                }
                            }) {
                                VStack(spacing: 3) {
                                    Text("\(calendar.component(.day, from: date))")
                                        .font(.system(size: 13, weight: isToday || isCurrentSelected ? .bold : .medium))
                                        .foregroundColor(
                                            isCurrentSelected
                                                ? (isDarkMode && (colorTheme == "Classic Minimal" || colorTheme == "Nord Arctic" || colorTheme == "Rose Pine") ? Color(red: 15/255, green: 23/255, blue: 42/255) : .white)
                                                : (isToday ? primaryAccent : (isDarkMode ? .white : Color(red: 30/255, green: 41/255, blue: 59/255)))
                                        )
                                    
                                    // Activity Heatmap Dot Indicator
                                    if noteCount > 0 {
                                        HStack(spacing: 2) {
                                            ForEach(0..<min(3, noteCount), id: \.self) { _ in
                                                Circle()
                                                    .fill(isCurrentSelected ? Color.black.opacity(0.6) : primaryAccent)
                                                    .frame(width: 4, height: 4)
                                            }
                                        }
                                    } else {
                                        Spacer()
                                            .frame(height: 4)
                                    }
                                }
                                .frame(height: 44)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isCurrentSelected ? primaryAccent : (isToday ? primaryAccent.opacity(0.12) : Color.cardBackground(isDarkMode)))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isToday && !isCurrentSelected ? primaryAccent : Color.subtleBorder(isDarkMode), lineWidth: isToday ? 1.5 : 0.5)
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            // Empty cell for alignment
                            Spacer()
                                .frame(height: 44)
                        }
                    }
                }
                
                Spacer()
                
                // Bottom Action Row: Open Daily Note for Selected Date
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("JOURNAL FOR THIS DAY")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                        Text(dateFormatter.string(from: selectedDate))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isDarkMode ? .white : Color(red: 15/255, green: 23/255, blue: 42/255))
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        openOrCreateDailyNote(for: selectedDate)
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "square.and.pencil")
                            Text("Open Daily Note")
                        }
                        .font(.system(size: 11.5, weight: .bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(primaryAccent)
                        .foregroundColor(isDarkMode && (colorTheme == "Classic Minimal" || colorTheme == "Nord Arctic" || colorTheme == "Rose Pine") ? Color(red: 15/255, green: 23/255, blue: 42/255) : .white)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Color.cardBackground(isDarkMode))
                .cornerRadius(10)
            }
            .padding(20)
            .frame(width: 480)
            .background(Color.panelBackground(isDarkMode))
            
            Divider()
                .background(Color.subtleBorder(isDarkMode))
            
            // Right Panel: Notes On Selected Date
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NOTES TIMELINE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(isDarkMode ? Color(red: 148/255, green: 163/255, blue: 184/255) : Color(red: 100/255, green: 116/255, blue: 139/255))
                        
                        let dateNotes = notesForDate(selectedDate)
                        Text("\(dateNotes.count) \(dateNotes.count == 1 ? "note" : "notes") on \(shortDateFormatter.string(from: selectedDate))")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(isDarkMode ? .white : Color(red: 15/255, green: 23/255, blue: 42/255))
                    }
                    
                    Spacer()
                    
                    Button(action: { isOpen = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                Divider()
                    .background(Color.subtleBorder(isDarkMode))
                
                let dayNotes = notesForDate(selectedDate)
                if dayNotes.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 36))
                            .foregroundColor(secondaryAccent.opacity(0.7))
                        Text("No notes recorded on this date.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            openOrCreateDailyNote(for: selectedDate)
                        }) {
                            Text("+ Create Journal Entry")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(primaryAccent.opacity(0.15))
                                .foregroundColor(primaryAccent)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(dayNotes) { item in
                                Button(action: {
                                    selectedNoteId = item.id
                                    TabNavigationManager.shared.openNote(item.id)
                                    isOpen = false
                                }) {
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: item.pdfPath != nil ? "doc.richtext.fill" : (item.audioPath != nil ? "waveform" : "doc.text"))
                                            .font(.system(size: 12))
                                            .foregroundColor(primaryAccent)
                                            .padding(.top, 2)
                                        
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.title.isEmpty ? "Untitled Note" : item.title)
                                                .font(.system(size: 12.5, weight: .bold))
                                                .foregroundColor(isDarkMode ? .white : Color(red: 15/255, green: 23/255, blue: 42/255))
                                                .lineLimit(1)
                                            
                                            Text(item.folder)
                                                .font(.system(size: 9.5, weight: .semibold))
                                                .foregroundColor(secondaryAccent)
                                            
                                            Text(item.content.replacingOccurrences(of: "\n", with: " "))
                                                .font(.system(size: 11, weight: .regular))
                                                .foregroundColor(isDarkMode ? Color(red: 203/255, green: 213/255, blue: 225/255) : Color(red: 71/255, green: 85/255, blue: 105/255))
                                                .lineLimit(2)
                                        }
                                        
                                        Spacer()
                                        
                                        Text(timeFormatter.string(from: item.timestamp))
                                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(10)
                                    .background(Color.cardBackground(isDarkMode))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.subtleBorder(isDarkMode), lineWidth: 0.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(20)
            .frame(width: 320)
            .background(Color.sidebarBackground(isDarkMode))
        }
        .frame(width: 800, height: 530)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.subtleBorder(isDarkMode), lineWidth: 1)
        )
    }
    
    // MARK: - Date Helpers
    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .full
        return df
    }
    
    private var shortDateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .medium
        return df
    }
    
    private var timeFormatter: DateFormatter {
        let df = DateFormatter()
        df.timeStyle = .short
        return df
    }
    
    private func monthYearString(from date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMMM yyyy"
        return df.string(from: date)
    }
    
    private func changeMonth(by amount: Int) {
        if let newDate = calendar.date(byAdding: .month, value: amount, to: displayedMonth) {
            displayedMonth = newDate
        }
    }
    
    private func daysInMonth(for date: Date) -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else { return [] }
        let firstDay = monthInterval.start
        let weekday = calendar.component(.weekday, from: firstDay) // 1 = Sunday
        
        var days: [Date?] = Array(repeating: nil, count: weekday - 1)
        
        var current = firstDay
        while current < monthInterval.end {
            days.append(current)
            if let next = calendar.date(byAdding: .day, value: 1, to: current) {
                current = next
            } else {
                break
            }
        }
        
        // Pad end of grid
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
    
    private func notesForDate(_ date: Date) -> [NoteItem] {
        notes.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
    }
    
    private func openOrCreateDailyNote(for date: Date) {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let dateString = df.string(from: date)
        
        if let existing = notes.first(where: { $0.folder == "Daily Notes" && $0.title == dateString }) {
            selectedNoteId = existing.id
            TabNavigationManager.shared.openNote(existing.id)
        } else {
            let dailyNote = NoteItem(
                title: dateString,
                folder: "Daily Notes",
                content: "# Daily Journal — \(dateString)\n\n### Morning Focus & Intentions\n- [ ] Review lecture notes & priorities\n- [ ] Focus study goals\n\n### Daily Meeting & Study Notes\nType notes here...\n\n### Evening Reflections & Learnings\nKey takeaways from today:\n",
                timestamp: date,
                audioPath: nil,
                transcript: [],
                isStandalone: true,
                bookmarks: []
            )
            notes.insert(dailyNote, at: 0)
            selectedNoteId = dailyNote.id
            TabNavigationManager.shared.openNote(dailyNote.id)
            NotesDataManager.shared.saveNotes(notes)
        }
        isOpen = false
    }
}

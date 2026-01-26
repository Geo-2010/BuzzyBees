//
//  FilterView.swift
//  Rural-Activities
//

import SwiftUI

struct FilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(EventManager.self) private var eventManager

    @State private var selectedTypes: Set<EventType> = []
    @State private var location = ""
    @State private var keyword = ""
    @State private var useStartDate = false
    @State private var startDate = Date()
    @State private var useEndDate = false
    @State private var endDate = Date()
    @State private var selectedSort: SortOption = .eventDate

    var body: some View {
        NavigationStack {
            Form {
                Section("Sort By") {
                    ForEach(SortOption.allCases) { option in
                        Button {
                            selectedSort = option
                        } label: {
                            HStack {
                                Text(option.rawValue)
                                    .foregroundStyle(.white)
                                Spacer()
                                if selectedSort == option {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppTheme.gold)
                                }
                            }
                        }
                    }
                }

                Section("Event Type") {
                    ForEach(EventType.allCases) { eventType in
                        Button {
                            toggleType(eventType)
                        } label: {
                            HStack {
                                Label(eventType.rawValue, systemImage: eventType.icon)
                                    .foregroundStyle(.white)
                                Spacer()
                                if selectedTypes.contains(eventType) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppTheme.gold)
                                }
                            }
                        }
                    }
                }

                Section("Location") {
                    TextField("Filter by location", text: $location)
                }

                Section("Keyword") {
                    TextField("Search in title or description", text: $keyword)
                }

                Section("Date Range") {
                    Toggle("From date", isOn: $useStartDate)
                    if useStartDate {
                        DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    }

                    Toggle("To date", isOn: $useEndDate)
                    if useEndDate {
                        DatePicker("End", selection: $endDate, displayedComponents: .date)
                    }
                }

                Section {
                    Button("Clear All Filters", role: .destructive) {
                        clearFilters()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.black)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppTheme.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.gold)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applyFilters()
                    }
                    .foregroundStyle(AppTheme.gold)
                }
            }
            .onAppear {
                loadCurrentFilters()
            }
        }
        .tint(AppTheme.gold)
        .preferredColorScheme(.dark)
    }

    private func toggleType(_ type: EventType) {
        if selectedTypes.contains(type) {
            selectedTypes.remove(type)
        } else {
            selectedTypes.insert(type)
        }
    }

    private func loadCurrentFilters() {
        let filters = eventManager.activeFilters
        selectedTypes = filters.eventTypes
        location = filters.location
        keyword = filters.keyword
        selectedSort = eventManager.sortOption
        if let start = filters.startDate {
            useStartDate = true
            startDate = start
        }
        if let end = filters.endDate {
            useEndDate = true
            endDate = end
        }
    }

    private func clearFilters() {
        selectedTypes = []
        location = ""
        keyword = ""
        useStartDate = false
        useEndDate = false
        startDate = Date()
        endDate = Date()
        selectedSort = .eventDate
    }

    private func applyFilters() {
        let filters = FilterCriteria(
            eventTypes: selectedTypes,
            location: location.trimmingCharacters(in: .whitespaces),
            keyword: keyword.trimmingCharacters(in: .whitespaces),
            startDate: useStartDate ? startDate : nil,
            endDate: useEndDate ? endDate : nil
        )
        eventManager.applyFilters(filters)
        eventManager.sortOption = selectedSort
        dismiss()
    }
}

#Preview {
    FilterView()
        .environment(EventManager())
}

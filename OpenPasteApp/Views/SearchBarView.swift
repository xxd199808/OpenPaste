import SwiftUI
import Combine
import CoreData

// MARK: - SearchBarView
/// Search bar with multi-dimensional filtering and debouncing.
/// Filters by content text, content type, date range, and source app.
struct SearchBarView: View {
    // MARK: - Properties

    /// Current search query text
    @Binding var searchText: String

    /// Selected content type filter (nil = all types)
    @Binding var selectedContentType: String?

    /// Selected date range filter (nil = all time)
    @Binding var selectedDateRange: DateRange?

    /// Selected source app filter (nil = all apps)
    @Binding var selectedSourceApp: String?

    /// Available content types from clipboard items
    let availableContentTypes: [String]

    /// Available source apps from clipboard items
    let availableSourceApps: [String]

    /// Debounce delay in milliseconds
    private let debounceDelay: TimeInterval = 0.15 // 150ms

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            // Search input field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search clipboard history...", text: $searchText)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Search")

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)

            // Filter options
            HStack(spacing: 8) {
                // Content type filter
                FilterMenu(
                    title: contentTypeFilterTitle,
                    options: ["All Types"] + availableContentTypes,
                    selection: selectedContentType,
                    onSelectionChange: { newType in
                        selectedContentType = newType == "All Types" ? nil : newType
                    }
                )

                // Date range filter
                FilterMenu(
                    title: dateRangeFilterTitle,
                    options: DateRange.allCases.map { $0.displayName },
                    selection: selectedDateRange?.displayName,
                    onSelectionChange: { newRange in
                        selectedDateRange = DateRange.allCases.first { $0.displayName == newRange }
                    }
                )

                // Source app filter
                FilterMenu(
                    title: sourceAppFilterTitle,
                    options: ["All Apps"] + availableSourceApps,
                    selection: selectedSourceApp,
                    onSelectionChange: { newApp in
                        selectedSourceApp = newApp == "All Apps" ? nil : newApp
                    }
                )

                Spacer()
            }
            .font(.caption)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Search and filter options")
    }

    // MARK: - Computed Properties

    private var contentTypeFilterTitle: String {
        selectedContentType ?? "Type"
    }

    private var dateRangeFilterTitle: String {
        selectedDateRange?.displayName ?? "Time"
    }

    private var sourceAppFilterTitle: String {
        selectedSourceApp ?? "Source"
    }
}

// MARK: - FilterMenu

/// Dropdown menu for filter selection
struct FilterMenu: View {
    let title: String
    let options: [String]
    let selection: String?
    let onSelectionChange: (String) -> Void

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(option) {
                    onSelectionChange(option)
                }
                .accessibilityLabel(option)
                .accessibilityAddTraits(selection == option ? [.isSelected] : [])
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
        }
    }
}

// MARK: - SearchPredicateBuilder

/// Builds NSPredicate for multi-dimensional search filtering
struct SearchPredicateBuilder {
    /// Build a compound predicate from search criteria
    /// - Parameters:
    ///   - searchText: Text to search for in content
    ///   - contentType: Optional content type filter
    ///   - dateRange: Optional date range filter
    ///   - sourceApp: Optional source app filter
    /// - Returns: NSPredicate for Core Data filtering
    static func buildPredicate(
        searchText: String,
        contentType: String?,
        dateRange: DateRange?,
        sourceApp: String?
    ) -> NSPredicate? {
        var predicates: [NSPredicate] = []

        // Content text search (case-insensitive)
        if !searchText.isEmpty {
            let contentPredicate = NSPredicate(
                format: "content CONTAINS[cd] %@",
                searchText
            )
            predicates.append(contentPredicate)
        }

        // Content type filter
        if let contentType = contentType {
            let typePredicate = NSPredicate(
                format: "contentType == %@",
                contentType
            )
            predicates.append(typePredicate)
        }

        // Date range filter
        if let dateRangePredicate = dateRange?.predicate {
            predicates.append(dateRangePredicate)
        }

        // Source app filter
        if let sourceApp = sourceApp {
            let appPredicate = NSPredicate(
                format: "sourceApp == %@",
                sourceApp
            )
            predicates.append(appPredicate)
        }

        // Combine all predicates with AND
        if predicates.isEmpty {
            return nil // No filters
        } else if predicates.count == 1 {
            return predicates.first
        } else {
            return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
    }
}

// MARK: - DebouncedTextPublisher

/// Publisher that debounces search text changes
extension Published.Publisher where Value: Equatable {
    /// Debounce publisher to avoid excessive filtering
    /// - Parameter delay: Delay in seconds (default: 0.15 for 150ms)
    /// - Returns: Debounced publisher
    func debounceText(delay: TimeInterval = 0.15) -> AnyPublisher<Value, Never> {
        self
            .debounce(for: .milliseconds(Int(delay * 1000)), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        SearchBarView(
            searchText: .constant("test"),
            selectedContentType: .constant(nil),
            selectedDateRange: .constant(nil),
            selectedSourceApp: .constant(nil),
            availableContentTypes: [
                "public.utf8-plain-text",
                "public.image",
                "public.file-url"
            ],
            availableSourceApps: [
                "Safari",
                "Finder",
                "VSCode"
            ]
        )

        Divider()

        SearchBarView(
            searchText: .constant(""),
            selectedContentType: .constant("public.image"),
            selectedDateRange: .constant(.pastWeek),
            selectedSourceApp: .constant("Safari"),
            availableContentTypes: [
                "public.utf8-plain-text",
                "public.image",
                "public.file-url"
            ],
            availableSourceApps: [
                "Safari",
                "Finder",
                "VSCode"
            ]
        )
    }
    .padding()
}

import WidgetKit
import SwiftUI

struct BudgetMeWidgetEntry: TimelineEntry {
    let date: Date
}

struct BudgetMeWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BudgetMeWidgetEntry {
        BudgetMeWidgetEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (BudgetMeWidgetEntry) -> Void) {
        completion(BudgetMeWidgetEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetMeWidgetEntry>) -> Void) {
        completion(Timeline(entries: [BudgetMeWidgetEntry(date: Date())], policy: .never))
    }
}

struct BudgetMeWidgetView: View {
    var body: some View {
        Link(destination: URL(string: "budgetme://quicklog")!) {
            VStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                Text("Log Expense")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.03, green: 0.05, blue: 0.10))
        }
    }
}

struct BudgetMeWidget: Widget {
    let kind = "BudgetMeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BudgetMeWidgetProvider()) { _ in
            BudgetMeWidgetView()
        }
        .configurationDisplayName("Budget Me")
        .description("Tap to log an expense instantly.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}

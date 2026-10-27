import Flocon
import SwiftUI

struct DashboardScreen: View {
    @State private var tableRowCount = 0

    var body: some View {
        SampleScreenContainer(screen: .dashboard) {
            SampleSection(title: "Dashboard") {
                SampleActionRow(title: "Change user", detail: "Updates the live \"User\" section", buttonTitle: "Change") {
                    SampleDashboard.shared.randomizeUserName()
                    return nil
                }
            }
            SampleSection(title: "Tables") {
                SampleActionRow(title: "Add table row", detail: "Adds a row to the table \"sample_users\"", buttonTitle: "Add") {
                    tableRowCount += 1
                    Flocon.tablePlugin.table("sample_users").log(
                        TableColumnConfig("index", "\(tableRowCount)"),
                        TableColumnConfig("name", ["Alice", "Bob", "Charlie", "Dana"].randomElement()!),
                        TableColumnConfig("score", "\(Int.random(in: 0...100))")
                    )
                    return "row #\(tableRowCount)"
                }
            }
        }
    }
}

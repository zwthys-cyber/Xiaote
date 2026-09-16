import UIKit
import SwiftUI

final class MainTableViewController: UITableViewController {

    private let sections = DemoSection.allCases

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "TeslaBLEKeyKit"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    }

    // MARK: - DataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].items.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let item = sections[indexPath.section].items[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = item.title
        config.secondaryText = item.subtitle
        config.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    // MARK: - Delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let section = sections[indexPath.section]
        let item = section.items[indexPath.row]
        let detailView = detailView(for: section, row: indexPath.row)
        let hostingVC = UIHostingController(rootView: detailView)
        hostingVC.title = item.title
        navigationController?.pushViewController(hostingVC, animated: true)
    }

    // MARK: - Routing

    private func detailView(for section: DemoSection, row: Int) -> AnyView {
        switch section {
        case .keyManagement:
            return AnyView(KeyManagementView(initialDemo: row))
        case .ble:
            if row == 0 {
                return AnyView(BLEScannerView())
            } else {
                return AnyView(VINToNameView())
            }
        case .crypto:
            return AnyView(CryptoDemoView(useTeslaNonce: row == 1))
        case .bleFraming:
            return AnyView(BLEFramingView(chunked: row == 1))
        case .vehicleConfig:
            return AnyView(VehicleConfigView())
        case .vehicleCommands:
            return AnyView(VehicleCommandsView())
        case .pairingAndStatus:
            return AnyView(PairingStatusView())
        }
    }
}

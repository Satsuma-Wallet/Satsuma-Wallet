//
//  SettingsViewController.swift
//  Satsuma
//
//  Created by Peter Denton on 5/8/23.
//

import UIKit

class SettingsViewController: UIViewController, UINavigationControllerDelegate {
    
    @IBOutlet weak var settingsTable: UITableView!
    

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        settingsTable.delegate = self
        settingsTable.dataSource = self
        navigationController?.delegate = self
        navigationItem.title = "Settings"
    }
    
    
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    private enum Section: Int {
        case network
        case fee
    }
    
//    private func headerName(for section: Section) -> String {
//        switch section {
//        case .network:
//            return "Tor"
//        }
//    }
    
    func blankCell() -> UITableViewCell {
        let cell = UITableViewCell()
        cell.selectionStyle = .none
        cell.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        return cell
    }
    
    private func torCell(_ indexPath: IndexPath) -> UITableViewCell {
        let torCell = settingsTable.dequeueReusableCell(withIdentifier: "torCell", for: indexPath)
        let torToggle = torCell.viewWithTag(1) as! UISwitch
        let torEnabled = UserDefaults.standard.object(forKey: "torEnabled") as? Bool ?? true
        torToggle.setOn(torEnabled, animated: false)
        torToggle.addTarget(self, action: #selector(toggleTor(_:)), for: .valueChanged)
        return torCell
    }
    
    private func feeCell(_ indexPath: IndexPath) -> UITableViewCell {
        let feeCell = settingsTable.dequeueReusableCell(withIdentifier: "feeCell", for: indexPath)
        let feeSegmentedControl = feeCell.viewWithTag(1) as! UISegmentedControl
        let feePriority = UserDefaults.standard.object(forKey: "feePriority") as? String ?? "high"
        if feePriority == "high" {
            feeSegmentedControl.selectedSegmentIndex = 0
        } else {
            feeSegmentedControl.selectedSegmentIndex = 1
        }
        feeSegmentedControl.addTarget(self, action: #selector(selectFee(_:)), for: .valueChanged)
        return feeCell
    }
    
    @objc func toggleTor(_ sender: UISwitch) {
        UserDefaults.standard.setValue(sender.isOn, forKey: "torEnabled")
        if !sender.isOn {
            TorClient.sharedInstance.resign()
        }
    }
    
    @objc func selectFee(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            UserDefaults.standard.set("high", forKey: "feePriority")
        default:
            UserDefaults.standard.set("low", forKey: "feePriority")
        }
    }
}

extension SettingsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
            
        case .network:
            return torCell(indexPath)
            
        case .fee:
            return feeCell(indexPath)
        
        default:
            return blankCell()
        }
    }
    
//    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
//        let header = UIView()
//        header.backgroundColor = UIColor.clear
//        header.frame = CGRect(x: 0, y: 0, width: view.frame.size.width - 32, height: 50)
//
//        let textLabel = UILabel()
//        textLabel.textAlignment = .left
//        textLabel.font = UIFont.systemFont(ofSize: 20, weight: .regular)
//        textLabel.textColor = .white
//        textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)
//
//        if let section = Section(rawValue: section) {
//            textLabel.text = headerName(for: section)
//        }
//
//        header.addSubview(textLabel)
//        return header
//    }
    
//    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
//        return 50
//    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 54
    }
    
//    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        switch Section(rawValue: indexPath.section) {
//        case .network:
//            print("tor row selected")
//        default:
//            break
//        }
//    }
    
}

extension SettingsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
}

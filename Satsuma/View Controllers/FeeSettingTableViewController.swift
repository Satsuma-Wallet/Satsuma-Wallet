//
//  FeeSettingTableViewController.swift
//  Satsuma
//
//  Created by Peter Denton on 5/24/23.
//

import UIKit

class FeeSettingTableViewController: UITableViewController {
    
    var highFeeRate = 0
    var lowFeeRate = 0
    var standardFeeRate = 0
    var minimumFeeRate = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return 4
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "feeCell", for: indexPath)
        let feePriority = UserDefaults.standard.object(forKey: "feePriority") as? String ?? "high"
        
        switch indexPath.row {
        case 0:
            cell.textLabel!.text = "High priority"
            if highFeeRate > 0 {
                cell.textLabel!.text = "High priority ~\(highFeeRate) s/vB"
            }
            if feePriority == "high" {
                cell.setSelected(true, animated: true)
                cell.accessoryType = .checkmark
            } else {
                cell.setSelected(false, animated: true)
                cell.accessoryType = .none
            }
    
        case 1:
            cell.textLabel!.text = "Standard priority"
            if standardFeeRate > 0 {
                cell.textLabel!.text = "Standard priority ~\(standardFeeRate) s/vB"
            }
            if feePriority == "standard" {
                cell.setSelected(true, animated: true)
                cell.accessoryType = .checkmark
            } else {
                cell.setSelected(false, animated: true)
                cell.accessoryType = .none
            }
        case 2:
            cell.textLabel!.text = "Low priority"
            if lowFeeRate > 0 {
                cell.textLabel!.text = "Low priority ~\(lowFeeRate) s/vB"
            }
            if feePriority == "low" {
                cell.setSelected(true, animated: true)
                cell.accessoryType = .checkmark
            } else {
                cell.setSelected(false, animated: true)
                cell.accessoryType = .none
            }
        case 3:
            cell.textLabel!.text = "Minimum priority"
            if minimumFeeRate > 0 {
                cell.textLabel!.text = "Minimum priority ~\(minimumFeeRate) s/vB"
            }
            if feePriority == "minimum" {
                cell.setSelected(true, animated: true)
                cell.accessoryType = .checkmark
            } else {
                cell.setSelected(false, animated: true)
                cell.accessoryType = .none
            }
        default:
            break
        }
        
        cell.selectionStyle = .none
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.row {
        case 0:
            UserDefaults.standard.set("high", forKey: "feePriority")
        case 1:
            UserDefaults.standard.set("standard", forKey: "feePriority")
        case 2:
            UserDefaults.standard.set("low", forKey: "feePriority")
        case 3:
            UserDefaults.standard.set("minimum", forKey: "feePriority")
        default:
            break
        }
        tableView.reloadData()
    }
    

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

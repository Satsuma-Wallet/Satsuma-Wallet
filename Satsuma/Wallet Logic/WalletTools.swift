//
//  WalletTools.swift
//  Satsuma
//
//  Created by Peter Denton on 5/8/23.
//

// MARK: TODO - ENSURE ALL RETURNS ARE CONVERTED TO COMPLETIONS.

import Foundation
import LibWally

// A single place for all backend wallet related code, anything that uses LibWally.

class WalletTools {
    
    static let shared = WalletTools() /// So we can reuse the same instance of this class rather then recreating it, better memory usage.
    var currentIndex = 0 /// For looping through each address when updating our utxo database.
    let coinType = 1/// Hardcoded for testnet.
    let network:Network = .testnet
    
    private init() {}
    // MARK: - Wallet creation
    
    // Creates a wallet with a provided passphrase.
    func create(passphrase: String, completion: @escaping ((message: String?, created: Bool)) -> Void) {
        
        // Ensures the wallet creation code happens on a background thread, makes the app run smoothly, otherwise it can interfere with the UI and make it jerky.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in /// "weak self" ensures we prevent memory leaks which are bad security and keeps memory usage in check.
            guard let self = self else { return }
            
            // Gets our 24 seed words in string format.
            guard let mnemonic = self.seedWords() else {
                completion(("Mnemonic creation failed", false))
                return
            }
            
            // Encrypts our mnmeonic, which converts it to data.
            guard let encryptedMnemonic = Crypto.encrypt(mnemonic.utf8) else {
                completion(("Menmonic encryption failed.", false))
                return
            }
            
            // Derives our master key (root xprv) from the mnemonic and passphrase.
            guard let mk = masterKey(words: mnemonic, passphrase: passphrase) else {
                completion(("Master key derivation failed.", false))
                return
            }
            
            // Derives our bip84 account xprv (m/84h/1h/0h) so we can encrypt it and save it. Used for deriving private keys for signing inputs.
            guard let bip84Xprv = bip84Xprv(masterKey: mk) else {
                completion(("Failed deriving bip84 xprv.", false))
                return
            }
            
            // Encrypts the string bip84 xprv and converts it to data.
            guard let encryptedBip84Xprv = Crypto.encrypt(bip84Xprv.utf8) else {
                completion(("Failed encrypting bip84 xprv.", false))
                return
            }
            
            // Derives the bip84 account xpub from the bip84 account xprv.
            guard let bip84Xpub = HDKey(bip84Xprv)?.xpub else {
                completion(("Failed derving bip84 xpub.", false))
                return
            }
            
            // Constructs our wallet dictionary which is saved to Core Data.
            let dict:[String:Any] = [
                "mnemonic": encryptedMnemonic,
                "id": UUID(),
                "receiveIndex": 0.0,
                "changeIndex": 0.0,
                "bip84Xprv": encryptedBip84Xprv,
                "bip84Xpub": bip84Xpub
            ]
            
            // Saves our wallet dictionary.
            CoreDataService.saveEntity(dict: dict, entityName: .wallets) { walletSaved in
                
                // Ensures it was saved.
                guard walletSaved else {
                    completion(("Wallet was not saved.", false))
                    return
                }
                
                // Derive 20 receive addresses and 20 change addresses from our wallets bip84 xpub.
                guard let recAddresses = self.addresses(wallet: Wallet(dict), change: 0),
                      let changeAddresses = self.addresses(wallet: Wallet(dict), change: 1) else {
                    completion(("Address derivation failed.", false))
                    return
                }
                
                // Loops through each receive address and saves it to Core Data.
                for (i, recAddress) in recAddresses.enumerated() {
                    
                    CoreDataService.saveEntity(dict: recAddress, entityName: .receiveAddr) { saved in
                        guard saved else {
                            completion(("Address failed to save.", false))
                            return
                        }
                        
                        if i + 1 == recAddresses.count {
                            
                            // Finished saving receive addresses, now we loop through change addresses.
                            for (x, changeAddress) in changeAddresses.enumerated() {
                                
                                CoreDataService.saveEntity(dict: changeAddress, entityName: .changeAddr) { saved in
                                    guard saved else {
                                        completion(("Address failed to save.", false))
                                        return
                                    }
                                    
                                    if x + 1 == changeAddresses.count {
                                        // Finished saving our change addresses
                                        completion((nil, true))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Generates a 24 word BIP39 mnemonic from 32 bytes of entropy created from the devices secure enclave.
    private func seedWords() -> String? {
        
        // Generate 32 bytes of cryptographically secure entropy with the secure element.
        let bytesCount = 32
        var randomBytes = [UInt8](repeating: 0, count: bytesCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytesCount, &randomBytes)
        guard status == errSecSuccess else { return nil }
        
        // Get the triple sha256 hash of the entropy.
        let data = Crypto.sha256hash(Crypto.sha256hash(Crypto.sha256hash(Data(randomBytes))))
        
        // Pass our 32 bytes of entropy to Libwally to create a 24 word BIP39 mnemonic.
        let entropy = BIP39Entropy(data)
        guard let mnemonic = BIP39Mnemonic(entropy) else { return nil }
        return mnemonic.description
    }
    
    // Returns the master key xprv so that we may derive child keys to add to our keypool.
    private func masterKey(words: String, passphrase: String) -> String? {
        
        // Converts the mnemonic string to a LibWally BIP39Mnemonic.
        guard let mnmemonic = BIP39Mnemonic(words) else { return nil }
        
        // Gets the LibWally seed hex from the LibWally BIP39Mnemonic and the passphrase.
        let seedHex = mnmemonic.seedHex(passphrase)
        
        // Gets the LibWally HDKey master key (root xprv) from the seed hex and provided network (testnet/mainnet).
        guard let hdMasterKey = HDKey(seedHex, self.network),
              let xpriv = hdMasterKey.xpriv else { return nil } /// Gets the xprv from the hd master key.
        
        return xpriv
    }
    
    // Returns the string account bip84 xprv from the string root master key.
    private func bip84Xprv(masterKey: String) -> String? {
        
        // The derivation path for the derived xpub. cointype == 0 is mainnet, cointype == 1 is testnet.
        let path = "m/84h/\(coinType)h/0h"
        
        // Converts the string master key to an HDKey object and derives the bip84 account hdkey from it.
        guard let hdMasterKey = HDKey(masterKey),
              let accountKey = try? hdMasterKey.derive(path) else { return nil }
        
        // Returns the bip84 account xprv.
        return accountKey.xpriv
    }
    
    // Returns an array of address objects which are then saved to Core Data during wallet creation.
    private func addresses(wallet: Wallet, change: Int) -> [[String:Any]]? {
        
        guard let bip84xpub = wallet.bip84Xpub else { return nil }
        
        var addresses:[[String:Any]] = []
        
        // We set the wallets max index dynamically, so we know which range of addresses to derive, and whether they are change or receive addresses.
        var walletIndex = 0
        if change == 0 {
            walletIndex = Int(wallet.receiveIndex)
        } else {
            walletIndex = Int(wallet.changeIndex)
        }
        
        // Limit the keypool to 20 addresses for receive and 20 for change.
        // 40 total will be saved to Core Data.
        let maxIndex = walletIndex + 19
        
        for i in walletIndex...maxIndex {
            guard let (address, pubkey) = addressPubkey(xpub: bip84xpub, path: "/\(change)/\(i)") as? (String, Data) else { return nil }
            
            // add pubkey too
            addresses.append([
                "address": address,
                "index": i,
                "id": UUID(),
                "pubkey": pubkey,
                "derivation": "m/84h/\(coinType)h/0h/\(change)/\(i)"
            ])
        }
        
        return addresses
    }
    
    // Returns a bip84 xpub from a master key (root xprv). coinType represents whether it is mainnet or testnet. Account should always be 0.
    private func bip84AccountXpub(masterKey: String) -> String? {
        
        // The derivation path for the derived xpub. cointype == 0 is mainnet, cointype == 1 is testnet.
        let path = "m/84h/\(self.coinType)h/0h"
        
        // Converts the string master key to an HDKey object and derives the bip84 account hdkey from it.
        guard let hdMasterKey = HDKey(masterKey),
              let accountKey = try? hdMasterKey.derive(path) else { return nil }
        
        // Returns the bip84 account xpub.
        return accountKey.xpub
    }
    
    // Returns the derived address and pubkey from the bip84 xpub. Used when adding keys to our keypool.
    private func addressPubkey(xpub: String, path: String) -> ((address: String?, pubkey: Data?)) {
        
        // Converts the xpub string to HDKey object.
        guard let hdKey = HDKey(xpub) else { return (nil,nil) }
        
        // Derives the child HDKey from the bip84 xpub HDKey.
        guard let hdkey = try? hdKey.derive(path) else { return (nil,nil) }
        
        // Gets the native segwit address from the derived HDKey.
        let address = hdkey.address(.payToWitnessPubKeyHash)
        
        // Returns the string aaddress and pubkey data which are saved to Core Data in an address object.
        return (address.description, hdkey.pubKey.data)
    }
    
    
    // Refills the keypool if the maximum address index is less then 5 away from the wallet index. 5 is arbitrary...
    func refillKeypool(completion: @escaping ((Bool)) -> Void) {
        
        // Fetch our wallet from Core Data.
        CoreDataService.retrieveEntity(entityName: .wallets) { wallets in
            
            // Ensure wallet was fetched.
            guard let wallets = wallets, wallets.count > 0 else {
                completion(true)
                return
            }
            
            let wallet = Wallet(wallets[0]) /// Wallet object.
            
            // Checks our change address keypool as compared to the wallet change address index to see if we need to refill the change keypool.
            func checkChangeAddresses() {
                
                // Fetches our change addresses from Core Data.
                CoreDataService.retrieveEntity(entityName: .changeAddr) { changeAddresses in
                    
                    // Ensures change addresses were returned from Core data.
                    guard let changeAddresses = changeAddresses else {
                        completion(false)
                        return
                    }
                    
                    let lastChangeAddr = Address_Cache(changeAddresses[changeAddresses.count - 1]) /// The last change address.
                    
                    // Compares the last change address index to the wallet change index, if the difference is less then 6 we refill.
                    if (lastChangeAddr.index - wallet.changeIndex) < 6 {
                        // Need to refill the change keypool.
                        
                        // Get 20 new change addresses based on the current wallet change index.
                        guard let newChangeAddresses = self.addresses(wallet: wallet, change: 1) else {
                            completion(false)
                            return
                        }
                        
                        // Loop through the new change addresses.
                        for (i, newChangeAddress) in newChangeAddresses.enumerated() {
                            
                            // Save each.
                            CoreDataService.saveEntity(dict: newChangeAddress, entityName: .changeAddr) { saved in
                                guard saved else {
                                    completion(false)
                                    return
                                }
                                
                                if i + 1 == newChangeAddresses.count {
                                    // Loop has finished, we are done.
                                    completion(true)
                                }
                            }
                        }
                    } else {
                        // No need to refill, we are done.
                        completion(true)
                    }
                }
            }
            
            // Fetches our receive addresses from Core Data.
            CoreDataService.retrieveEntity(entityName: .receiveAddr) { recAddresses in
                
                // Ensures receive addresses were returned from Core data.
                guard let recAddresses = recAddresses else {
                    completion(false)
                    return
                }
                
                let lastRecAddr = Address_Cache(recAddresses[recAddresses.count - 1]) /// The last receive address.
                
                // Compares the last receive address index to the wallet receive index, if the difference is less then 6 we refill.
                if (lastRecAddr.index - wallet.receiveIndex) < 6  {
                    // Need to refill.
                    
                    // Get 20 new receive addresses based on the current wallet receive index.
                    guard let newAddresses = self.addresses(wallet: wallet, change: 0) else {
                        completion(false)
                        return
                    }
                    
                    // Loop through the new receive addresses.
                    for (i, newRecAddress) in newAddresses.enumerated() {
                        
                        // Save each.
                        CoreDataService.saveEntity(dict: newRecAddress, entityName: .receiveAddr) { saved in
                            guard saved else {
                                completion(false)
                                return
                            }
                            
                            if i + 1 == newAddresses.count {
                                // Loop finsished we now check the change addresses.
                                checkChangeAddresses()
                            }
                        }
                    }
                } else {
                    // No need to refill receive address keypool, check the change address keypool.
                    checkChangeAddresses()
                }
            }
        }
    }
    
    // MARK: Functions for updating our utxo data base.
    
    // Entry point for updating our local utxo and address database.
    func updateCoreData(completion: @escaping ((message: String?, success: Bool)) -> Void) {
        
        // Fetch existing utxos from Core Data so they can be compared to fetched utxos.
        CoreDataService.retrieveEntity(entityName: .utxos) { [weak self] utxos in
            guard let self = self else { return }
            
            // Ensures utxo entity exists and was returned.
            guard let utxos = utxos else {
                completion(("Utxo entity in Core Data does not exist.", false))
                return
            }
            
            // Passes our saved utxos and completion handler to the next function.
            self.updateUtxoDatabase(utxos: utxos, completion: completion)
        }
    }
    
    // Updates our utxo and address database.
    private func updateUtxoDatabase(utxos: [[String:Any]],
                                    completion: @escaping ((message: String?, success: Bool)) -> Void) {
        
        // Fetch all of our receive addresses from Core Data.
        CoreDataService.retrieveEntity(entityName: .receiveAddr) { recAddresses in
            guard let recAddresses = recAddresses else {
                completion(("No receive address Core Data entity.", false))
                return
            }
            
            // Fetch all of our change addresses from Core Data.
            CoreDataService.retrieveEntity(entityName: .changeAddr) { changeAddresses in
                guard let changeAddresses = changeAddresses else {
                    completion(("No change address Core Data entity.", false))
                    return
                }
                
                // Ensure we start from the first address.
                self.currentIndex = 0
                
                // Fetch utxos from our addresses and compare to any existing utxos to update our data base.
                self.createUtxosFromAddresses(addresses: recAddresses + changeAddresses,
                                              completion: completion)
            }
        }
    }
    
    /* Here we loop through our keypool to find any new utxos or detect consumed utxos/addresses.
    First we get our wallet which would be updated with any new keys if it was just refilled.
    We then check the wallet change/receive index and we query the address if the wallet index
    is less then or equal to the address index. If no fetched utxos are found for a given address
    then we know we can delete any saved utxos that are associated with that address and the address
    itself. This way we keep a minimum amount of addresses in our keypool that need to be queried and
    automatically add more if required.*/
    private func createUtxosFromAddresses(addresses: [[String:Any]],
                                          completion: @escaping ((message: String?, success: Bool)) -> Void) {
        
        // Fetch our wallet.
        CoreDataService.retrieveEntity(entityName: .wallets) { [weak self] wallets in
            guard let self = self else { return }
            
            guard let wallets = wallets else {
                completion(("Core Data wallet entity does not exist.", false))
                return
            }
            
            let wallet = Wallet(wallets[0]) /// Our wallet.
            
            // The wallet keeps track of the receive address index and change address index and increments them by one if a utxo is seen.
            // Print statements make debugging easy for now.
            let maxIndex = addresses.count - 1
            print("maxIndex: \(maxIndex)")
            
            // The current index starts at 0 and increments up to the total number of addresses so that each may be queried if needed.
            let address = addresses[self.currentIndex] /// The address to be queried.
            print("address: \(address["address"] as! String): \(address["index"] as! Int)") /// Prints the address and its index for debugging.
            
            // Converts the address dictionary from Core Data to an easy to use struct.
            let addr = Address_Cache(address)
            
            // Wallet receive address index.
            let walletReceiveIndex = Int(wallet.receiveIndex)
            print("walletReceiveIndex: \(walletReceiveIndex)")
                        
            // Wallet change address index.
            let walletChangeIndex = Int(wallet.changeIndex)
            print("walletChangeIndex: \(walletChangeIndex)")
            
            // If the address in question has an index less then or equal to the wallet index we check it for utxos from mempool/esplora.
            let addressIndex = addr.index
            let shouldFetchReceive = !self.isChangeAddress(addr) && Int(addressIndex) <= walletReceiveIndex
            let shouldFetchChange = self.isChangeAddress(addr) && Int(addressIndex) <= walletChangeIndex
            
            // Convenience func to either increment our currentIndex by one so that we can query the next address or finish.
            func finish() {
                if self.currentIndex < maxIndex {
                    // We know we need to check the next address so we recursively call the function. Not great but it works well.
                    self.currentIndex += 1
                    self.createUtxosFromAddresses(addresses: addresses, completion: completion)
                    
                } else {
                    // We have reached the last address and can finish.
                    self.currentIndex = 0
                    completion((nil, true))
                    
                }
            }
            
            if shouldFetchReceive || shouldFetchChange {
                // Fetch utxos from the API for the given address.
                MempoolRequest.sharedInstance.command(method: .utxo(address: addr.address)) { [weak self] (response, errorDesc) in
                    guard let self = self else { return }
                    
                    // Ensures we received a valid response.
                    guard let fetchedUtxos = response as? [[String:Any]] else {
                        completion((errorDesc, false))
                        return
                    }
                    
                    // Fetch our locally saved utxos so that we can compare them to the fetched utxos for the given address.
                    CoreDataService.retrieveEntity(entityName: .utxos) { existingUtxoDicts in
                        
                        // Ensures our utxo entity exists in Core Data.
                        guard let existingUtxoDicts = existingUtxoDicts else {
                            completion(("Utxo Core Data entity does not exist", false))
                            return
                        }
                        
                        // The locally saved utxos that are assocuated with the given address. For now, an empty array.
                        var filteredUtxos:[[String:Any]] = []
                        
                        // Loop through our existing utxos and populate our filtered array with relevant utxos to the given address.
                        for existingUtxoDict in existingUtxoDicts {
                            let existingUtxo = Utxo_Cache(existingUtxoDict)
                            
                            // Check the address we are querying matches the utxo address, if so append it to the filtered array.
                            if existingUtxo.address == addr.address {
                                filteredUtxos.append(existingUtxoDict)
                            }
                        }
                        
                        if filteredUtxos.count == 0 && fetchedUtxos.count > 0 {
                            // There are no locally saved utxos for the given address, but there are fetched utxos, we know we need to save them.
                            
                            self.saveFetchedUtxos(fetchedUtxos: fetchedUtxos,
                                                  address: addr,
                                                  wallet: wallet) { (message, success) in
                                guard success else {
                                    completion((message, false))
                                    return
                                }
                                finish()
                            }
                            
                        } else if fetchedUtxos.count == 0 {
                            // There are no fetched utxos for the given address, we need to make sure our local database removes any
                            // utxos associated with that address and the address itself.
                            
                            if filteredUtxos.count == 0  {
                                // There are also no locally saved utxos for that address so we know we are finished here.
                                finish()
                                
                            } else {
                                // There are no fetched utxos but there are locally saved utxos, now we know we need to delete them.
                                
                                // Loop through our locally saved utxos that are associated with the given address.
                                for (i, existingUtxo) in filteredUtxos.enumerated() {
                                    let existingUtxo = Utxo_Cache(existingUtxo)
                                    print("delete this utxo: \(existingUtxo.address)")/// Printing to make debugging easy.
                                    
                                    // Delete the utxo.
                                    CoreDataService.deleteEntity(id: existingUtxo.id, entityName: .utxos) { deleted in
                                        guard deleted else {
                                            completion(("Failed deleting consumed utxo.", false))
                                            return
                                        }
                                        
                                        // Check if it is a change address so we know where to delete the address from.
                                        if self.isChangeAddress(addr) {
                                            print("delete change address: \(addr.address)")
                                            
                                            // Delete the change address from the keypool.
                                            CoreDataService.deleteEntity(id: addr.id, entityName: .changeAddr) { deleted in
                                                guard deleted else {
                                                    completion(("Failed deleting used change address.", false))
                                                    return
                                                }
                                            }
                                            
                                        } else {
                                            // Its a receive address.
                                            print("delete receive address: \(addr.address)")
                                            
                                            // Delete the receive address from the keypool.
                                            CoreDataService.deleteEntity(id: addr.id, entityName: .receiveAddr) { deleted in
                                                guard deleted else {
                                                    completion(("Failed deleting used receive address.", false))
                                                    return
                                                }
                                            }
                                        }
                                        
                                        if i + 1 == filteredUtxos.count {
                                            // We have looped through all of our locally saved utxos, the above should be done and we are finished.
                                            finish()
                                        }
                                    }
                                }
                            }
                            
                        } else {
                            // We have fetched utxos for the given address.
                            // First check if it exists locally or not.
                            
                            // Loop through the fetched utxos.
                            for (f, fetchedUtxoDict) in fetchedUtxos.enumerated() {
                                let fetchedUtxo = Utxo_Fetched(fetchedUtxoDict)
                                
                                var existsLocally = false
                                
                                // Loop through the saved utxos to compare them.
                                for (i, existingUtxo) in filteredUtxos.enumerated() {
                                    let existingUtxo = Utxo_Cache(existingUtxo)
                                    
                                    // The outpoint is unique identifier for each utxo, if the fetched utxo outpoint matches the saved utxo outpoint we know they are the same utxo.
                                    if existingUtxo.outpoint == fetchedUtxo.outpoint {
                                        // The utxo exists locally, can check if it needs to be updated.
                                        existsLocally = true
                                        
                                        // If the confirmed value does not match then we need to update it. It was saved unconfirmed but has now been confirmed.
                                        if existingUtxo.confirmed != fetchedUtxo.confirmed {
                                            
                                            // Need to update confirmed value.
                                            CoreDataService.update(id: existingUtxo.id,
                                                                   keyToUpdate: "confirmed",
                                                                   newValue: fetchedUtxo.confirmed,
                                                                   entity: .utxos) { updated in
                                                
                                                guard updated else {
                                                    completion(("Failed updating confirmed value.", false))
                                                    return
                                                }
                                            }
                                        }
                                    }
                                    
                                    if i + 1 == filteredUtxos.count {
                                        // We finished looping through our locally saved utxos.
                                        
                                        if !existsLocally {
                                            // The fetched utxo does not exist locally, save it.
                                            self.saveFetchedUtxos(fetchedUtxos: [fetchedUtxoDict],
                                                                  address: addr,
                                                                  wallet: wallet) { (message, success) in
                                                
                                                guard success else {
                                                    completion((message, false))
                                                    return
                                                }
                                                
                                                if f + 1 == fetchedUtxos.count {
                                                    // Both loops have finished, we are done.
                                                    finish()
                                                }
                                            }
                                        } else if f + 1 == fetchedUtxos.count {
                                            // The fetched utxo already exists locally, our loops have finished, we are done with the given address.
                                            finish()
                                            
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
             
            // Below if statements are called if the address is beyond the wallets index for the given address.
            // Meaning there is no need to query them for utxos.
            } else if self.currentIndex == maxIndex {
                // The current index matches the total number of addresses in our database, we are finished here.
                self.currentIndex = 0
                completion((nil, true))
                
            } else {
                // If the current index is lower than the number of addresses in our database then we know we need to query the next address.
                finish()
            }
        }
    }
    
    // Change addresses will always have /1/ in its derivation path.
    private func isChangeAddress(_ address: Address_Cache) -> Bool {
        return address.derivation.contains("/1/")
    }
    
    // MARK: - Transaction Creation
    
    // Sweeps the wallet to a provided address. Returns the hex raw tx, fee in satoshis, and the amount sent in btc.
    func sweepWallet(destinationAddress: String,
                     completion: @escaping ((message: String?, (rawTx: String, fee: Int, amount: Double)?)) -> Void) {
        
        // Fetch the recommended fee from the mempool api.
        MempoolRequest.sharedInstance.command(method: .fee) { (response, errorDesc) in
            
            // Ensure we get a valid response.
            guard let response = response as? [String:Any] else {
                completion(("Failed fetching recommended fees: \(errorDesc ?? "Unknown.")", nil))
                return
            }
            
            let feeTarget = RecommendedFee(response).target /// Our fee target as per settings.
            
            // Fetch our saved utxos from Core Data.
            CoreDataService.retrieveEntity(entityName: .utxos) { [weak self] utxos in
                guard let self = self else { return }
                
                // Ensure utxos were fetched from Core Data.
                guard let utxos = utxos else {
                    completion(("Failed fetching utxos.", nil))
                    return
                }
                
                var utxosToConsume:[Utxo_Cache] = [] /// Our potential utxos to be used as  inputs.
                
                // Loop through our locally saved utxos.
                for (i, utxo) in utxos.enumerated() {
                    
                    let u = Utxo_Cache(utxo)
                    
                    // Append utxo to our array.
                    utxosToConsume.append(u)
                    
                    if i + 1 == utxos.count {
                        // The loop has finished.
                        
                        // Fetch inputs, input derivation paths and total input amount from the utxo array.
                        guard let (inputDerivs, inputs, totalInputAmount) = self.inputs(utxos: utxosToConsume) else {
                            completion(("Failed fetching inputs from utxos,", nil))
                            return
                        }
                        
                        // Calculate the WU (Weight Units) of our inputs, add 124 for the output and 42 for other tx data.
                        // https://bitcoin.stackexchange.com/a/92600
                        let estimatedTxSizeWu = (inputs.count * 272) + 124 + 42
                        let estimatedVBytes = estimatedTxSizeWu / 4
                        let estimtatedFee = UInt64(estimatedVBytes * feeTarget)
                        
                        // Ensure we have enough funds to cover our fee.
                        guard totalInputAmount > estimtatedFee else {
                            completion(("Fee exceeds total available funds.", nil))
                            return
                        }
                        
                        // Get output amount by subtracting our fee from the total funds available.
                        let amountToSend = totalInputAmount - UInt64(estimtatedFee)
                        
                        // Create our single output.
                        guard let output = self.output(address: destinationAddress, amount: Satoshi(amountToSend)) else {
                            completion(("Failed fetching output.", nil))
                            return
                        }
                        
                        // Create the unsinged transaction.
                        let tx = Transaction(inputs, [output])
                        
                        // Sign the transaction.
                        self.signTransaction(inputDerivs: inputDerivs, tx: tx) { (message, rawTx) in
                            
                            // Return an optional error message, the raw tx, the fee and the amount to send in btc.
                            completion((message, (rawTx!.rawTx, rawTx!.fee, Double(amountToSend).btcAmountDouble)))
                        }
                    }
                }
            }
        }
    }
    
    // Create a raw transaction to the destination address for the specified amount.
    // A change address is provided as well as the fee target.
    func createTx(destinationAddress: String,
                  changeAddress: Address_Cache,
                  btcAmountToSend: Double,
                  feeTarget: Int,
                  completion: @escaping ((message: String?, (rawTx: String, fee: Int)?)) -> Void) {
                
        // Get our utxos to be consumed as inputs.
        utxosForInputs(btcAmountToSend: btcAmountToSend, feeTarget: feeTarget) { (message, utxos) in
            
            // Ensure utxos were returned.
            guard let utxos = utxos else {
                completion((message, nil))
                return
            }
            
            // Fetch the input derivations which allow is to easily sign each input, the inputs themselves and the total input amount to calculate change amount.
            guard let (inputDerivs, inputs, totalInputAmount) = self.inputs(utxos: utxos) else {
                completion(("Creating inputs failed.", nil))
                return
            }
            
            // Create our outputs.
            var outputs:[TxOutput] = []
            let amountSats = Satoshi(btcAmountToSend.satsAmount)
            
            // Create the destination output first.
            guard let output = self.output(address: destinationAddress, amount: amountSats) else {
                completion(("Creating output failed.", nil))
                return
            }
            
            // Append it to the output array.
            outputs.append(output)
            
            // Fetch the recommended fee.
            MempoolRequest.sharedInstance.command(method: .fee) { (response, errorDesc) in
                
                // Ensure a valid response was returned.
                guard let response = response as? [String:Any] else {
                    completion(("Failed fee estimation: \(errorDesc ?? "Unknown.")", nil))
                    return
                }
                
                let feeTarget = RecommendedFee(response).target /// Our fee target as per settings.
                
                // Calculate the WU (Weight Units) of our inputs, add 124 for the output and 42 for other tx data.
                // https://bitcoin.stackexchange.com/a/92600
                let estimatedTxSizeWu = (inputs.count * 272) + 248 + 42
                let estimatedVBytes = estimatedTxSizeWu / 4 /// Divide WU by 4 to get vBytes.
                let estimtatedFee = estimatedVBytes * feeTarget
                
                // Checks whether we have enough funds and whether change is required.
                if totalInputAmount + UInt64(estimtatedFee) > amountSats {
                    // Calculate change amount.
                    let changeAmount = (totalInputAmount - amountSats) - UInt64(estimtatedFee)
                    
                    // Create our change output.
                    guard let changeOutput = self.output(address: changeAddress.address, amount: Satoshi(changeAmount)) else {
                        return
                    }
                    
                    // Append to our existing output.
                    outputs.append(changeOutput)
                                        
                    // Now we have our inputs and outputs we can create the transaction.
                    let tx = Transaction(inputs, outputs)
                    self.signTransaction(inputDerivs: inputDerivs, tx: tx, completion: completion)
                    
                } else if totalInputAmount + UInt64(estimtatedFee) == amountSats {
                    // Input amount plus the fee exactly equals the output amount, do not need change.
                    // MARK: - TODO Test if this replaces our sweep function.
                    let tx = Transaction(inputs, outputs)
                    self.signTransaction(inputDerivs: inputDerivs, tx: tx, completion: completion)
                    
                } else if totalInputAmount < UInt64(estimtatedFee) {
                    completion(("Fee exceeds available funds.", nil))
                    
                } else {
                    completion(("Insufficient funds.", nil))
                    
                }
            }
        }
    }
    
    // Returns a LibWally TxInput. Converts local utxo object to TxInput.
    private func input(utxo: Utxo_Cache) -> TxInput? {
        // Get all values needed for an input.
        guard let prevTx = Transaction(utxo.txid) else { return nil }
        guard let pubkey = PubKey(utxo.pubkey, self.network) else { print("pubkey nil"); return nil }
        guard let inputAddress = Address(utxo.address) else { return nil }
        let scriptPubKey = inputAddress.scriptPubKey
        let witness = Witness(.payToWitnessPubKeyHash(pubkey))
        
        // Return the TxInput.
        return TxInput(
            prevTx,
            UInt32(utxo.vout),
            Satoshi(utxo.value),
            nil,
            witness,
            scriptPubKey
        )
    }
    
    // Returns a LibWally TxOutput. Converts an address and an amount to a TxOutput.
    private func output(address: String, amount: Satoshi) -> TxOutput? {
        guard let outputAddress = Address(address) else { return nil }
        let scriptPubKey = outputAddress.scriptPubKey
        return TxOutput(scriptPubKey, amount, self.network)
    }
    
    // Returns the input derivation paths, used for deriving the private keys to sign each input, an array of TxInput, and the total input amount in Satoshis.
    private func inputs(utxos: [Utxo_Cache]) -> (inputDerivs: [String], inputs: [TxInput], totalInputAmount: Satoshi)? {
        var inputDerivs:[String] = []       /// Allows us to easily fetch the corresponding private keys to sign the transaction.
        var inputs:[TxInput] = []           /// Array of TxInputs.
        var totalInputAmount:Satoshi = 0    /// Allows us to easily calculate the change output amount.
        
        // Loop through the utxos to populate our array of inputs.
        for utxo in utxos {
            // Convert utxo to a TxInput
            guard let input = self.input(utxo: utxo) else {
                print("input failing")
                return nil
            }
            
            // Update the total input amount so we know how much change we need to create (if any).
            totalInputAmount += Satoshi(utxo.value)
            
            // Update the derivation path of each input so we know which private keys to fetch to sign each input.
            inputDerivs.append(utxo.derivation)
            
            // Add the input to our input array.
            inputs.append(input)
        }
        
        return (inputDerivs, inputs, totalInputAmount)
    }
    
    // Returns a signed transaction and its fee in satoshis from provided input derivations and an unsigned transaction.
    private func signTransaction(inputDerivs: [String],
                                 tx: Transaction,
                                 completion: @escaping ((message: String?, (rawTx: String, fee: Int)?)) -> Void) {
        
        var privKeys:[HDKey] = []
        var tx = tx
        
        // Loop through our derivation paths for each input to get the private keys required to sign the transaction.
        for (d, derivationPath) in inputDerivs.enumerated() {
            let derivArray = derivationPath.split(separator: "/") /// We split the derivation path into an array: [m, 84h, 1h, 0h, 0, 1]
            let childPath = "\(derivArray[4])/\(derivArray[5])" /// Last two indexes of the array which allows us to derive child keys from the account xprv.
            
            // Use the last two indexes of the array to derive a private key from the bip84 account xprv (m/84h/1h/0h).
            WalletTools.shared.privateKey(path: childPath) { (message, privateKey) in
                // Ensure a private key was returned.
                guard let privateKey = privateKey else {
                    completion(("Failed deriving the private key.", nil))
                    return
                }
                
                // We have the private key, append it to our array of private keys.
                privKeys.append(privateKey)
                
                // The loop is finished.
                if d + 1 == inputDerivs.count {
                    // Sign the transaction with our private key array.
                    guard let signedTx = self.signedTx(tx: &tx, privKeys: privKeys) else {
                        completion(("Signing raw transaction failed.", nil))
                        return
                    }
                                        
                    completion((nil, signedTx))
                }
            }
        }
    }
    
    // Returns the signed transaction as a hex string and its fee from the unsigned transaction and private keys.
    private func signedTx(tx: inout Transaction, privKeys: [HDKey]) -> (rawTx: String, fee: Int)? {
        guard let fee = tx.fee, /// Gets the fee.
              tx.sign(privKeys), /// Signs the transaction with provate keys.
              let signedRawTx = tx.description else { /// Gets the raw hex string of the signed raw transaction.
            return nil
        }
        
        return (rawTx: signedRawTx, fee: Int(fee))
    }
    
    // Fetches utxos we can use as inputs for a given amount we want to spend and fee.
    private func utxosForInputs(btcAmountToSend: Double,
                                feeTarget: Int,
                                completion: @escaping ((message: String?, utxos: [Utxo_Cache]?)) -> Void) {
        
        // Fetches all of our saved utxos.
        CoreDataService.retrieveEntity(entityName: .utxos) { utxos in
            
            // Ensures utxos were returned.
            guard let utxos = utxos, utxos.count > 0 else {
                completion(("No utxos to spend.", nil))
                return
            }
            
            var utxosToConsume:[Utxo_Cache] = []
            var totalUtxoAmount = 0.0
            var inputWU = 272 // WU per native segwit input.
            let estimatedWUForOutputs = 248 + 42 /// There should be two outputs (WU for native segwit output is 124 and 42 for other transaction data.
            
            var amountPlusFee = btcAmountToSend /// Total input amount required for the transaction.
            
            // Loop through all of our utxos.
            for (i, utxo) in utxos.enumerated() {
                let utxo = Utxo_Cache(utxo)
                
                // If the total utxo amount is less then the total amount needed for the transaction we know we need to append another utxo.
                // MARK: - TODO Make this much better!
                if totalUtxoAmount < amountPlusFee, utxo.confirmed {
                    totalUtxoAmount += utxo.doubleValueSats.btcAmountDouble
                    inputWU += inputWU
                    utxosToConsume.append(utxo)
                }
                
                // Update each value after looping each utxo.
                let estimatedTxSizeWu = inputWU + estimatedWUForOutputs
                let estimatedVBytes = estimatedTxSizeWu / 4
                let estimtatedFee = estimatedVBytes * feeTarget
                amountPlusFee += Double(estimtatedFee).btcAmountDouble
                
                if i + 1 == utxos.count {
                    // Loop has finished.
                    if totalUtxoAmount >= amountPlusFee {
                        // We have enough utxos to cover the fees and outputs, we are finished.
                        completion((nil, utxosToConsume))
                        
                    } else {
                        // HFSP.
                        completion(("Insufficient funds.", nil))
                        
                    }
                }
            }
        }
    }
    
    // Utility for checking whether an address is valid or not.
    func validAddress(string: String) -> Bool {
        return Address(string) != nil
    }
    
    // Returns a derived private key to be used when signing transaction inputs.
    private func privateKey(path: String, completion: @escaping ((message: String?, privateKey: HDKey?)) -> Void) {

        // Fetches our wallet from Core Data.
        CoreDataService.retrieveEntity(entityName: .wallets) { wallets in
            guard let wallets = wallets else { return }
            
            let wallet = Wallet(wallets[0]) /// Our wallet object.
            
            // Ensures we have a bip84 account xprv saved locally.
            guard let bip84xprv = wallet.bip84Xprv else {
                completion(("No bip84 xprv saved.", nil))
                return
            }
            
            // Decrypts the bip84 xprv using the private key we store to the devices keychain. Convert it from data to string.
            guard let decryptedBip84Xprv = Crypto.decrypt(bip84xprv), let bip84Xprv = decryptedBip84Xprv.utf8String else {
                completion(("Failed decrypting the bip84 xprv", nil))
                return
            }
            
            // Converts the string key to a LibWally HDKey object.
            guard let hdKey = HDKey(bip84Xprv) else {
                completion(("Failed converting base58 xprv to hdkey.", nil))
                return
            }
            
            // Derive the private key using the provided derivation path from the HDKey object.
            guard let hdDerivedkey = try? hdKey.derive(path) else {
                completion(("Failed deriving our hd key from string xprv.", nil))
                return
            }
            
            // Return the private key.
            completion((nil, hdDerivedkey))
        }
    }
    
    // MARK: Core Data helpers
    // These functions are utility functions to save/update/delete items from our database.
    // We generally only want to know if they fail which should not happen.
    
    // Saves an address object.
    private func saveAddress(dict: [String:Any],
                             entityName: ENTITY,
                             completion: @escaping ((message: String?, created: Bool)) -> Void) {
        
        CoreDataService.saveEntity(dict: dict, entityName: entityName) { saved in
            guard saved else {
                completion(("Address failed to save.", false))
                return
            }
        }
    }
    
    // Updates a utxos confirmed value, aka whether it has been mined in a block or not.
    private func updateConfirmedValue(utxo: Utxo_Cache, completion: @escaping ((Bool)) -> Void) {
        
        CoreDataService.update(id: utxo.id,
                               keyToUpdate: "confirmed",
                               newValue: true,
                               entity: .utxos) { updated in
            
            print("utxo confirmed value updated")
            completion((updated))
        }
    }
    
    // Saves a fetched utxo to our local data base.
    private func saveFetchedUtxos(fetchedUtxos: [[String:Any]],
                                  address: Address_Cache,
                                  wallet: Wallet,
                                  completion: @escaping ((message: String?, success: Bool)) -> Void) {
        
        for (i, fetchedUtxo) in fetchedUtxos.enumerated() {
            let newUtxo = Utxo_Fetched(fetchedUtxo)
            
            let dictToSave:[String:Any] = [
                "id": UUID(),                       /// Unique identifier so we can update/delete specific utxos later.
                "vout": newUtxo.vout,               /// Index of the utxo in the previous transaction outputs. Used when comparing utxos/creating inputs.
                "txid": newUtxo.txid,               /// String hex id of the utxo's previous transaction. Used when comparing utxos/creating inputs.
                "value": newUtxo.value,             /// Satoshi amount of our utxo.
                "confirmed": newUtxo.confirmed,     /// Boolean to display whether our balance is confirmed or not.
                "address": address.address,         /// The string address of the utxo, used to derive the scriptpubkey when creating an input.
                "pubkey": address.pubkey,           /// The data representation of the utxo's pubkey, used to derive the witness when creating an input.
                "derivation": address.derivation    /// Used to fetch the corresponding private key to sign the input.
            ]
            
            // Saves the utxo and returns the success bool.
            CoreDataService.saveEntity(dict: dictToSave, entityName: .utxos) { [weak self] saved in
                guard let self = self else { return }
                
                // Ensure it was saved.
                guard saved else {
                    completion(("Failed saving new utxo.", false))
                    return
                }
                
                // Checks if it is a change or receive address.
                if self.isChangeAddress(address) {
                    
                    // If the indexes match we need to update the wallets change index.
                    if address.index == wallet.changeIndex {
                        
                        CoreDataService.update(id: wallet.id,
                                               keyToUpdate: "changeIndex",
                                               newValue: wallet.changeIndex + 1.0,
                                               entity: .wallets) { updated in
                            
                            guard updated else {
                                completion(("Failed updating wallet change index.", false))
                                return
                            }
                            
                            print("Updated change index.")
                        }
                    }
                    
                // If the indexes match we need to update the wallets receive index.
                } else if address.index == wallet.receiveIndex {
                    
                    CoreDataService.update(id: wallet.id,
                                           keyToUpdate: "receiveIndex",
                                           newValue: wallet.receiveIndex + 1.0,
                                           entity: .wallets) { updated in
                        
                        guard updated else {
                            completion(("Failed updating wallet receive index.", false))
                            return
                        }
                        
                        print("Updated receive index.")
                    }
                }
                
                if i + 1 == fetchedUtxos.count {
                    completion((nil, true))
                }
            }
        }
    }
    
}

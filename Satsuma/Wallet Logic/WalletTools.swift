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
    
    static let shared = WalletTools()
    var currentIndex = 0
    let coinType = 1/// Hardcoded for testnet.
    let network:Network = .testnet
    
    private init() {}
    // MARK: Wallet creation
    
    func create(completion: @escaping ((message: String?, created: Bool)) -> Void) {
        print("create")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            guard let mnemonic = self.seedWords() else {
                completion(("Mnemonic creation failed", false))
                return
            }
            
            guard let encryptedMnemonic = Crypto.encrypt(mnemonic.utf8) else {
                completion(("Menmonic encryption failed.", false))
                return
            }
            
            let dict:[String:Any] = [
                "mnemonic": encryptedMnemonic,
                "id": UUID(),
                "receiveIndex": 0.0,
                "changeIndex": 0.0
            ]
            
            CoreDataService.saveEntity(dict: dict, entityName: .wallets) { walletSaved in
                guard walletSaved else {
                    completion(("Wallet was not saved.", false))
                    return
                }
                
                guard let recAddresses = self.addresses(wallet: Wallet(dict), coinType: self.coinType, change: 0),
                      let changeAddresses = self.addresses(wallet: Wallet(dict), coinType: self.coinType, change: 1) else {
                    completion(("Address derivation failed.", false))
                    return
                }
                
                for (i, recAddress) in recAddresses.enumerated() {
                    self.saveAddress(dict: recAddress, entityName: .receiveAddr, completion: completion)
                    if i + 1 == recAddresses.count {
                        for (x, changeAddress) in changeAddresses.enumerated() {
                            self.saveAddress(dict: changeAddress, entityName: .changeAddr, completion: completion)
                            if x + 1 == changeAddresses.count {
                                completion((nil, true))
                            }
                        }
                    }
                }
            }
        }
    }
        
    private func seedWords() -> String? {
        print("seedWords")
        /// Generate 32 bytes of cryptographically secure entropy with the secure element.
        let bytesCount = 32
        var randomBytes = [UInt8](repeating: 0, count: bytesCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytesCount, &randomBytes)
        guard status == errSecSuccess else { return nil }
        
        /// Get the triple sha256 hash of the entropy.
        var data = Crypto.sha256hash(Crypto.sha256hash(Crypto.sha256hash(Data(randomBytes))))
        
        /// Remove half so we end up with 16 bytes of entropy, which translates to a 12 word seed phrase.
        data = data.subdata(in: Range(0...15))
        
        /// Pass our 16 bytes of entropy to Libwally to create a 12 word BIP39 mnemonic.
        let entropy = BIP39Entropy(data)
        guard let mnemonic = BIP39Mnemonic(entropy) else { return nil }
        return mnemonic.description
    }
    
    // MARK: Functions for updating our utxo data base.
    func updateCoreData(completion: @escaping ((message: String?, success: Bool)) -> Void) {
        print("updateDoreData")
        /// Fetch our wallet.
        CoreDataService.retrieveEntity(entityName: .wallets) { wallets in
            guard let wallets = wallets, wallets.count > 0 else {
                completion(("No wallet exists.", false))
                return
            }
            
            let wallet = Wallet(wallets[0])
            
            /// Fetch any existing utxos from Core Data.
            CoreDataService.retrieveEntity(entityName: .utxos) { utxos in
                guard let utxos = utxos else {
                    completion(("Utxo entity in Core Data does not exist.", false))
                    return
                }
                
                self.updateUtxoDatabase(utxos: utxos, completion: completion)
            }
        }
    }
    
    private func updateUtxoDatabase(utxos: [[String:Any]],
                                    completion: @escaping ((message: String?, success: Bool)) -> Void) {
        print("updateUtxoDatabase")
        /// Fetch all of our receive addresses.
        CoreDataService.retrieveEntity(entityName: .receiveAddr) { recAddresses in
            guard let recAddresses = recAddresses else {
                completion(("No receive address Core Data entity.", false))
                return
            }
            
            /// Fetch all of our change addresses.
            CoreDataService.retrieveEntity(entityName: .changeAddr) { changeAddresses in
                guard let changeAddresses = changeAddresses else {
                    completion(("No change address Core Data entity.", false))
                    return
                }
                
                /// Ensure we start from the first address.
                self.currentIndex = 0
                
                /// Fetch utxos from our addresses and compare to any existing utxos to update our data base.
                self.createUtxosFromAddresses(addresses: recAddresses + changeAddresses,
                                              completion: completion)
            }
        }
    }
    
    /// Here we loop through our keypool to find any new utxos or detect consumed utxos.
    private func createUtxosFromAddresses(addresses: [[String:Any]],
                                         completion: @escaping ((message: String?, success: Bool)) -> Void) {
        print("createUtxosFromAddresses")
        CoreDataService.retrieveEntity(entityName: .wallets) { [weak self] wallets in
            guard let self = self else { return }
            
            guard let wallets = wallets else {
                completion(("Core Data wallet entity does not exist.", false))
                return
            }
            
            let wallet = Wallet(wallets[0])
            
            /// The wallet keeps track of the receive address index and change address index and increments them by one if a utxo is seen.
            let maxIndex = addresses.count - 1
            print("maxIndex: \(maxIndex)")
            
            /// The current index starts at 0 and increments up to the wallets receive/change index.
            let address = addresses[self.currentIndex]
            print("address: \(address["address"] as! String): \(address["index"] as! Int)")
            
            /// Converts the address dictionary from Core Data to an easy to use struct.
            let addr = Address_Cache(address)
            
            /// The wallets current receive address index.
            let receiveIndex = Int(wallet.receiveIndex)
            
            /// The wallets current change address index.
            let changeIndex = Int(wallet.changeIndex)
            
            /// If the address in question has an index less then or equal to the wallet index we check it for utxos from mempool/esplora.
            let shouldFetchReceive = !self.isChangeAddress(address: addr) && Int(addr.index) <= receiveIndex
            let shouldFetchChange = self.isChangeAddress(address: addr) && Int(addr.index) <= changeIndex
            
            if shouldFetchReceive || shouldFetchChange {
                /// Fetch utxos from the API.
                MempoolRequest.sharedInstance.command(method: .utxo(address: addr.address)) { [weak self] (response, errorDesc) in
                    guard let self = self else { return }
                    
                    guard let fetchedUtxos = response as? [[String:Any]] else {
                        completion((errorDesc, false))
                        return
                    }
                    
                    func finish() {
                        print("finish")
                        if self.currentIndex < maxIndex {
                            self.currentIndex += 1
                            self.createUtxosFromAddresses(addresses: addresses, completion: completion)
                        } else {
                            self.currentIndex = 0
                            completion((nil, true))
                        }
                    }
                    
                    CoreDataService.retrieveEntity(entityName: .utxos) { existingUtxos in
                        guard let existingUtxos = existingUtxos else {
                            completion(("Utxo Core Data entity does not exist", false))
                            return
                        }
                        
                        if existingUtxos.count == 0 && fetchedUtxos.count > 0 {
                            self.saveFetchedUtxos(fetchedUtxos: fetchedUtxos, address: addr, wallet: wallet) { (message, success) in
                                guard success else {
                                    completion((message, false))
                                    return
                                }
                                finish()
                            }
                        } else if fetchedUtxos.count == 0 {
                            // check local utxos here to delete any associated with that address
                            print("check local utxos here to delete any associated with the address. Can probably delete the address from keypool too.")
                            if existingUtxos.count == 0 {
                                finish()
                            } else {
                                for (i, existingUtxo) in existingUtxos.enumerated() {
                                    let existingUtxo = Utxo_Cache(existingUtxo)
                                    if existingUtxo.address == addr.address {
                                        print("delete this utxo: \(existingUtxo.address)")
                                        CoreDataService.deleteEntity(id: existingUtxo.id, entityName: .utxos) { deleted in
                                            guard deleted else {
                                                completion(("Failed deleting consumed utxo.", false))
                                                return
                                            }
                                            if i + 1 == existingUtxos.count {
                                                finish()
                                            }
                                        }
                                    } else if i + 1 == existingUtxos.count {
                                        finish()
                                    }
                                }
                            }
                            
                        } else {
                            // we have saved utxos and fetched utxos
                            // first check if it exists locally or not
                            
                            for (f, fetchedUtxoDict) in fetchedUtxos.enumerated() {
                                let fetchedUtxo = Utxo_Fetched(fetchedUtxoDict)
                                                            
                                var existsLocally = false
                                
                                for (i, existingUtxo) in existingUtxos.enumerated() {
                                    let existingUtxo = Utxo_Cache(existingUtxo)
                                    
                                    if existingUtxo.outpoint == fetchedUtxo.outpoint {
                                        // we know it exists locally already, can check if it needs to be updated
                                        existsLocally = true
                                        print("Exists locally.")
                                        
                                        if existingUtxo.confirmed != fetchedUtxo.confirmed {
                                            // need to update confirmed value
                                            print("Need to update confirmed value.")
                                            CoreDataService.update(id: existingUtxo.id, keyToUpdate: "confirmed", newValue: fetchedUtxo.confirmed, entity: .utxos) { updated in
                                                guard updated else {
                                                    completion(("Failed updating confirmed value.", false))
                                                    return
                                                }
                                            }
                                        }
                                    }
                                    
                                    if i + 1 == existingUtxos.count {
                                        if !existsLocally {
                                            // save it
                                            print("Does not exist locally, save it.")
                                            self.saveFetchedUtxos(fetchedUtxos: [fetchedUtxoDict], address: addr, wallet: wallet) { (message, success) in
                                                guard success else {
                                                    completion((message, false))
                                                    return
                                                }
                                                
                                                if f + 1 == fetchedUtxos.count {
                                                    // loops have finished
                                                    finish()
                                                }
                                            }
                                            
                                        } else if f + 1 == fetchedUtxos.count {
                                            // loops have finished
                                            finish()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
            /// If the current index matches the total number of addresses in our database then we know we are finished here.
            } else if self.currentIndex == maxIndex {
                print("currentIndex == maxIndex")
                self.currentIndex = 0
                completion((nil, true))
            
            } else {
                /// If the current index is lower than the number of addresses in our database then we know we need to query the next address.
                if self.currentIndex < maxIndex {
                    print("currentIndex < maxIndex")
                    self.currentIndex += 1
                    self.createUtxosFromAddresses(addresses: addresses, completion: completion)
                    
                /// If the current index matches the number of addresses in our database then we know we are finished here.
                /// If any of the above were to fail we would never reach this point.
                } else {
                    self.currentIndex = 0
                    completion((nil, true))
                }
            }
        }
    }
    
    /// Change addresses will always have /1/ in its derivation path.
    private func isChangeAddress(address: Address_Cache) -> Bool {
        return address.derivation.contains("/1/")
    }
    
    // MARK: TRANSACTION CREATION - WIP ⚠️
    // MARK: TODO - Make fee dynamic as per mempool API
    
    /// Entry point for creating a transaction.
    func createTx(destinationAddress: String,
                  changeAddress: Address_Cache,
                  btcAmountToSend: Double,
                  completion: @escaping ((message: String?, (rawTx: String, fee: Int)?)) -> Void) {
        
        print("createTx")
        
        /// First, get our utxos to be consumed.
        utxosForInputs(btcAmountToSend: btcAmountToSend) { (message, utxos) in
            guard let utxos = utxos else {
                completion((message, nil))
                return
            }
            
            /// Allows us to easily fetch the corresponding private keys to sign the transaction.
            /// Array of TxInputs.
            /// Allows us to easily calculate the change output amount.
            guard let (inputDerivs, inputs, totalInputAmount) = self.inputs(utxos: utxos) else {
                completion(("Creating inputs failed.", nil))
                return
            }
            
            /// Create our outputs.
            var outputs:[TxOutput] = []
            let amountSats = Satoshi(btcAmountToSend.satsAmount)
            
            /// Start with destination output.
            guard let output = self.output(address: destinationAddress, amount: amountSats) else {
                completion(("Creating output failed.", nil))
                return
            }
            /// Appends it to the output array.
            outputs.append(output)
            
            /// If our total input amount is greater then the amount we want to send then we will need a change output.
            // MARK: TODO - Need to add mining fee estimation here to avoid making a change output if it is exactly over by the mining fee?
            print("totalInputAmount: \(totalInputAmount)")
            print("amountSats: \(amountSats)")
            if totalInputAmount > amountSats {
                print("need an additional output for change.")
                /// Calculate change amount.
                /// Get our change amount. 500 is the hardcoded mining fee for testing.
                // MARK: TODO - Do not hardcode the mining fee.
                let changeAmount = (totalInputAmount - amountSats) - 500
                
                /// Create our change output.
                guard let changeOutput = self.output(address: changeAddress.address, amount: Satoshi(changeAmount)) else {
                    return
                }
                /// Append to our existing output.
                outputs.append(changeOutput)
                
                /// Now we have our inputs and outputs we can create the transaction.
                let tx = Transaction(inputs, outputs)
                self.signTransaction(inputDerivs: inputDerivs, tx: tx, completion: completion)
            }
        }
    }
    
    private func input(utxo: Utxo_Cache) -> TxInput? {
        /// Get all values needed for an input.
        guard let prevTx = Transaction(utxo.txid) else { return nil }
        guard let pubkey = PubKey(utxo.pubkey, self.network) else { print("pubkey nil"); return nil }
        guard let inputAddress = Address(utxo.address) else { return nil }
        let scriptPubKey = inputAddress.scriptPubKey
        let witness = Witness(.payToWitnessPubKeyHash(pubkey))
        
        /// Return the input.
        return TxInput(
            prevTx,
            UInt32(utxo.vout),
            Satoshi(utxo.value),
            nil,
            witness,
            scriptPubKey
        )
    }
    
    /// Returns our output.
    private func output(address: String, amount: Satoshi) -> TxOutput? {
        guard let outputAddress = Address(address) else { return nil }
        let scriptPubKey = outputAddress.scriptPubKey
        return TxOutput(scriptPubKey, amount, self.network)
    }
    
    private func inputs(utxos: [Utxo_Cache]) -> (inputDerivs: [String], inputs: [TxInput], totalInputAmount: Satoshi)? {
        var inputDerivs:[String] = []       /// Allows us to easily fetch the corresponding private keys to sign the transaction.
        var inputs:[TxInput] = []           /// Array of TxInputs.
        var totalInputAmount:Satoshi = 0    /// Allows us to easily calculate the change output amount.
        
        /// Loop through the utxos to populate our array of inputs.
        for utxo in utxos {
            /// Convert utxo to a TxInput
            guard let input = self.input(utxo: utxo) else {
                print("input failing")
                return nil
            }
            /// Update the total input amount so we know how much change we need to create (if any).
            totalInputAmount += Satoshi(utxo.value)
            
            /// Update the derivation path of each input so we know which private keys to fetch to sign each input.
            inputDerivs.append(utxo.derivation)
            
            /// Add the input to our input array.
            inputs.append(input)
        }
        
        return (inputDerivs, inputs, totalInputAmount)
    }
    
    private func changeAddress(wallet: Wallet) -> Address_Cache? {
        guard let address = address(wallet: wallet, isChange: 1, index: Int(wallet.changeIndex)) else {
            return nil
        }
        return Address_Cache(address)
    }
    
    private func signTransaction(inputDerivs: [String], tx: Transaction, completion: @escaping ((message: String?, (rawTx: String, fee: Int)?)) -> Void) {
        var privKeys:[HDKey] = []
        var tx = tx
        /// Loop through our derivation paths for each input to get the private keys required to sign the transaction.
        for (d, derivationPath) in inputDerivs.enumerated() {
            WalletTools.shared.privateKey(path: derivationPath) { (message, privateKey) in
                guard let privateKey = privateKey else { return }
                /// We have the private key, append it to our array of private keys.
                privKeys.append(privateKey)
                
                /// The loop is finished.
                if d + 1 == inputDerivs.count {
                    /// Sign the transaction with our private key array.
                    guard let signedTx = self.signedTx(tx: &tx, privKeys: privKeys) else {
                        completion(("Signing raw transaction failed.", nil))
                        return
                    }
                    
                    completion((nil, signedTx))
                }
            }
        }
    }
    
    /// Returns the signed transaction as a hex string.
    private func signedTx(tx: inout Transaction, privKeys: [HDKey]) -> (rawTx: String, fee: Int)? {
        print("signedTx")
        let fee = Int(tx.fee!)
        guard tx.sign(privKeys) else { return nil }
        return (rawTx: tx.description!, fee: fee)
    }
    
    /// Fetches utxos we can use as inputs for a given amount we want to spend.
    private func utxosForInputs(btcAmountToSend: Double,
                          completion: @escaping ((message: String?, utxos: [Utxo_Cache]?)) -> Void) {
        print("getInputs")
        /// Fetches all of our saved utxos.
        CoreDataService.retrieveEntity(entityName: .utxos) { utxos in
            guard let utxos = utxos, utxos.count > 0 else {
                completion(("No utxos to spend.", nil))
                return
            }
            
            var utxosToConsume:[Utxo_Cache] = []
            var totalUtxoAmount = 0.0
            
            for (i, utxo) in utxos.enumerated() {
                let utxo = Utxo_Cache(utxo)
                /// Checks if we need to keep adding utxos to be used as inputs based on the amount of the inputs and the amount to spend.
                /// Only allows confirmed utxos to be added as inputs.
                
                // MARK: TODO - Ensure mining fee will also be covered.
                print("totalUtxoAmount: \(totalUtxoAmount)")
                print("btcAmountToSend: \(btcAmountToSend)")
                
                let amountPlusFee = btcAmountToSend + 0.000005
                
                if totalUtxoAmount < amountPlusFee, utxo.doubleValueSats.btcAmountDouble < amountPlusFee, utxo.confirmed {
                    totalUtxoAmount += utxo.doubleValueSats.btcAmountDouble
                    utxosToConsume.append(utxo)
                } else if totalUtxoAmount < amountPlusFee, utxo.doubleValueSats.btcAmountDouble > amountPlusFee, utxo.confirmed {
                    totalUtxoAmount += utxo.doubleValueSats.btcAmountDouble
                    utxosToConsume.append(utxo)
                }
                
                if i + 1 == utxos.count {
                    /// Input amount now exceeds the amount to send, we can return our utxos to be used as inputs.
                    if totalUtxoAmount >= amountPlusFee {
                        print("we have enough inputs now. need to make sure we have enough for the fee too.")
                        completion((nil, utxosToConsume))
                    } else {
                        completion(("Insufficient funds.", nil))
                    }
                }
            }
        }
    }
    
    /// Utility for checking whether an address is valid or not.
    func validAddress(string: String) -> Bool {
        return Address(string) != nil
    }
    
    /// Returns an array of address objects which are then saved to Core Data during wallet creation.
    private func addresses(wallet: Wallet, coinType: Int, change: Int) -> [[String:Any]]? {
        print("addresses")
        // Decrypts the wallet's seed in order to get the root xprv.
        guard let decryptedSeed = Crypto.decrypt(wallet.mnemonic),
                let words = decryptedSeed.utf8String,
                let xpriv = masterKey(words: words, passphrase: "") else { return nil }
        
        // Derives the bip84 xpub from the wallets root xprv.
        guard let addrXpub = bip84AccountXpub(masterKey: xpriv, coinType: self.coinType, account: 0) else { return nil }
        
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
            guard let (address, pubkey) = addressPubkey(xpub: addrXpub, path: "/\(change)/\(i)") as? (String, Data) else { return nil }
            
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
    
    // Returns an individual address object to add to our keypool in case we max out. Perhaps we should just fill another 20?
    private func address(wallet: Wallet, isChange: Int, index: Int) -> [String:Any]? {
        print("address")
        // Decrypts the wallet's seed in order to get the root xprv.
        guard let decryptedSeed = Crypto.decrypt(wallet.mnemonic),
              let words = decryptedSeed.utf8String,
              let xpriv = masterKey(words: words, passphrase: "") else { return nil }
        
        // Derives the bip84 xpub from the wallets root xprv.
        guard let addrXpub = bip84AccountXpub(masterKey: xpriv, coinType: self.coinType, account: 0) else { return nil }
        
        // Fetches the address and pubkey from the bip84 xpub and our specified derivation.
        guard let (address, pubkey) = addressPubkey(xpub: addrXpub, path: "/\(isChange)/\(index)") as? (String, Data) else { return nil }
        
        // Returns the address object to be saved into Core Data.
        return [
            "address": address,
            "index": index,
            "id": UUID(),
            "pubkey": pubkey,
            "derivation": "m/84h/\(coinType)h/0h/\(isChange)/\(index)"
        ]
    }
    
    // Returns the master key xprv so that we may derive child keys to add to our keypool.
    private func masterKey(words: String, passphrase: String) -> String? {
        print("masterKey")
        guard let mnmemonic = BIP39Mnemonic(words) else { return nil }
        let seedHex = mnmemonic.seedHex(passphrase)
        
        guard let hdMasterKey = HDKey(seedHex, self.network),
              let xpriv = hdMasterKey.xpriv else { return nil }
        
        return xpriv
    }
    
    /// Returns a derived individual private key to be used when signing inputs during transaction creation.
    private func privateKey(path: String, completion: @escaping ((message: String?, privateKey: HDKey?)) -> Void) {
        print("privateKey")
        // Fetches our wallet object from Core Data.
        CoreDataService.retrieveEntity(entityName: .wallets) { wallets in
            guard let wallets = wallets else { return }
            
            // We are only using one wallet, this makes it easy to update the app to work with multiple wallets in the future.
            let wallet = Wallet(wallets[0])
            
            // Decrypts our encrypted mnemonic.
            guard let decryptedWords = Crypto.decrypt(wallet.mnemonic), let words = decryptedWords.utf8String else { return }
            
            // Fetches the root xprv.
            guard let masterKey = self.masterKey(words: words, passphrase: "") else { return }
            
            // Converts the master key from a string to HDKey object.
            guard let hdMasterKey = HDKey(masterKey) else { return }
            
            // Derive the private key we need to sign with from our root hdkey (xprv).
            guard let hdDerivedkey = try? hdMasterKey.derive(path) else { return }
            
            // Return the derived private key.
            completion((nil, hdDerivedkey))
        }
    }
    
    /// Returns a bip84 xpub from a master key (root xprv). coinType represents whether it is mainnet or testnet. Account should always be 0.
    private func bip84AccountXpub(masterKey: String, coinType: Int, account: Int) -> String? {
        print("bip84AccountXpub")
        // The derivation path for the derived xpub. cointype == 0 is mainnet, cointype == 1 is testnet.
        let path = "m/84h/\(coinType)h/\(account)h"
        
        // Converts the string master key to an HDKey object and derives the bip84 account hdkey from it.
        guard let hdMasterKey = HDKey(masterKey),
            let accountKey = try? hdMasterKey.derive(path) else { return nil }
        
        // Returns the bip84 account xpub.
        return accountKey.xpub
    }
    
    /// Returns the derived address and pubkey from the bip84 xpub. Used when adding keys to our keypool.
    private func addressPubkey(xpub: String, path: String) -> ((address: String?, pubkey: Data?)) {
        print("addressPubkey")
        // Converts the xpub string to HDKey object.
        guard let hdKey = HDKey(xpub) else { return (nil,nil) }
        
        // Derives the child HDKey from the bip84 xpub HDKey.
        guard let hdkey = try? hdKey.derive(path) else { return (nil,nil) }
        
        // Gets the native segwit address from the derived HDKey.
        let address = hdkey.address(.payToWitnessPubKeyHash)
        
        // Returns the string aaddress and pubkey data which are saved to Core Data in an address object.
        return (address.description, hdkey.pubKey.data)
    }
    
    // MARK: Core Data helpers
    // These functions are utility functions to save/update/delete items from our database. We generally only want to know if they fail which should not happen.
    
    /// Saves an address object.
    private func saveAddress(dict: [String:Any],
                     entityName: ENTITY,
                     completion: @escaping ((message: String?, created: Bool)) -> Void) {
        print("saveAddress")
        CoreDataService.saveEntity(dict: dict, entityName: entityName) { saved in
            guard saved else {
                completion(("Address failed to save.", false))
                return
            }
        }
    }
    
    /// Updates a utxos confirmed value aka whether it has been mined in a block or not.
    private func updateConfirmedValue(utxo: Utxo_Cache, completion: @escaping ((Bool)) -> Void) {
        print("updateConfirmedValue")
        CoreDataService.update(id: utxo.id,
                               keyToUpdate: "confirmed",
                               newValue: true,
                               entity: .utxos) { updated in
            
            print("utxo confirmed value updated")
            completion((updated))
        }
    }
    
    /// Saves a fetched utxo to our local data base.
    private func saveFetchedUtxos(fetchedUtxos: [[String:Any]],
                                 address: Address_Cache,
                                  wallet: Wallet,
                                  completion: @escaping ((message: String?, success: Bool)) -> Void) {
        print("saveFetchedUtxos")
        
        for (i, fetchedUtxo) in fetchedUtxos.enumerated() {
            let newUtxo = Utxo_Fetched(fetchedUtxo)
            
            let dictToSave:[String:Any] = [
                "id": UUID(),                       /// Unique identifier so we can update/delete specific utxos later.
                "vout": newUtxo.vout,           /// Index of the utxo in the previous transaction outputs. Used when comparing utxos/creating inputs.
                "txid": newUtxo.txid,           /// String hex id of the utxo's previous transaction. Used when comparing utxos/creating inputs.
                "value": newUtxo.value,         /// Satoshi amount of our utxo.
                "confirmed": newUtxo.confirmed, /// Boolean to display whether our balance is confirmed or not.
                "address": address.address,         /// The string address of the utxo, used to derive the scriptpubkey when creating an input.
                "pubkey": address.pubkey,           /// The data representation of the utxo's pubkey, used to derive the witness when creating an input.
                "derivation": address.derivation    /// Used to fetch the corresponding private key to sign the input.
            ]
            
            /// Saves it and returns the success bool.
            CoreDataService.saveEntity(dict: dictToSave, entityName: .utxos) { saved in
                guard saved else {
                    completion(("Failed saving new utxo.", false))
                    return
                }
                
                if self.isChangeAddress(address: address) {
                    if address.index == wallet.changeIndex {
                        print("update the wallet change index by one")
                        CoreDataService.update(id: wallet.id, keyToUpdate: "changeIndex", newValue: wallet.changeIndex + 1.0, entity: .wallets) { updated in
                            guard updated else {
                                completion(("Failed updating wallet change index.", false))
                                return
                            }
                            print("Updated change index.")
                        }
                    }
                } else if address.index == wallet.receiveIndex {
                    print("update the wallet receive index")
                    CoreDataService.update(id: wallet.id, keyToUpdate: "receiveIndex", newValue: wallet.receiveIndex + 1.0, entity: .wallets) { updated in
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
    
    // Updates our wallet receive index by one and adds the corresponding address to the receive keypool.
    private func updateWalletIndex(wallet: Wallet, isChange: Bool, completion: @escaping ((Bool)) -> Void) {
        print("updateWalletReceiveIndex")
        
        /// The new index to be saved.
        var updatedIndex:Double
        var keyToUpdate:String
        var change:Int
        var entity:ENTITY
        
        switch isChange {
        case false:
            updatedIndex = wallet.changeIndex + 1.0
            keyToUpdate = "changeIndex"
            change = 1
            entity = .changeAddr
        default:
            updatedIndex = wallet.receiveIndex + 1.0
            keyToUpdate = "receiveIndex"
            change = 0
            entity = .receiveAddr
        }
        
        /// Update the existing index to the new one.
        CoreDataService.update(id: wallet.id,
                               keyToUpdate: keyToUpdate,
                               newValue: updatedIndex,
                               entity: .wallets) { [weak self] updated in
            
            guard let self = self else { return }
            print("wallet index updated to \(updatedIndex)")
            
            /// Ensure it was updated.
            guard updated else {
                completion((false))
                return
            }
            
            /// Derive the new receive address as per the updated index.
            guard let newAddress = self.address(wallet: wallet,
                                                isChange: change,
                                                index: Int(updatedIndex)) else {
                completion((false))
                return
            }
            
            /// Saves the new receive address to the receive keypool.
            self.saveAddress(dict: newAddress, entityName: entity) { (message, saved) in
                completion((saved))
            }
        }
    }
}

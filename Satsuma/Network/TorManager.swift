//
//  TorManager.swift
//  Satsuma
//
//  Created by Peter Denton on 5/5/23.
//

import Foundation
import Tor

protocol OnionManagerDelegate: AnyObject {
    func torConnProgress(_ progress: Int)
    func torConnFinished()
    func torConnDifficulties()
}

class TorClient: NSObject, URLSessionDelegate {
    
    enum TorState {
        case none
        case started
        case connected
        case stopped
        case refreshing
    }
    
    public var state: TorState = .none
    public var cert:Data?
    
    static let sharedInstance = TorClient()
    private var config: TorConfiguration = TorConfiguration()
    private var thread: TorThread?
    private var controller: TorController?
    private var authDirPath = ""
    var isRefreshing = false
    
    // The tor url session configuration.
    // Start with default config as fallback.
    private lazy var sessionConfiguration: URLSessionConfiguration = .default

    // The tor client url session including the tor configuration.
    lazy var session = URLSession(configuration: sessionConfiguration)
    
    // Start the tor client.
    func start(delegate: OnionManagerDelegate?) {
        weak var weakDelegate = delegate
        state = .started
        
        var proxyPort = 19055
        var dnsPort = 12347
#if targetEnvironment(simulator)
        proxyPort = 19056
        dnsPort = 12348
#endif
        
        sessionConfiguration.connectionProxyDictionary = [kCFProxyTypeKey: kCFProxyTypeSOCKS,
                                          kCFStreamPropertySOCKSProxyHost: "localhost",
                                          kCFStreamPropertySOCKSProxyPort: proxyPort]
        
        session = URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: .main)
        
#if targetEnvironment(macCatalyst)
        // Code specific to Mac.
#else
        // Code to exclude from Mac.
        session.configuration.urlCache = URLCache(memoryCapacity: 0, diskCapacity: 0, diskPath: nil)
#endif
        
        //add V3 auth keys to ClientOnionAuthDir if any exist
        createTorDirectory()
        thread = nil
        
        config.options = [
            "DNSPort": "\(dnsPort)",
            "AutomapHostsOnResolve": "1",
            "SocksPort": "\(proxyPort)",//OnionTrafficOnly
            "AvoidDiskWrites": "1",
            "ClientOnionAuthDir": "\(self.authDirPath)",
            "LearnCircuitBuildTimeout": "1",
            "NumEntryGuards": "8",
            "SafeSocks": "1",
            "LongLivedPorts": "80,443",
            "NumCPUs": "2",
            "DisableDebuggerAttachment": "1",
            "SafeLogging": "1"
            //"ExcludeExitNodes": "1",
            //"StrictNodes": "1"
        ]
        
        //self?.config.arguments = ["--defaults-torrc \(NSTemporaryDirectory()).torrc"]
        self.config.cookieAuthentication = true
        self.config.dataDirectory = URL(fileURLWithPath: self.torPath())
        self.config.controlSocket = self.config.dataDirectory?.appendingPathComponent("cp")
        self.thread = TorThread(configuration: self.config)
        
        // Initiate the controller.
        if self.controller == nil {
            self.controller = TorController(socketURL: self.config.controlSocket!)
        }
        
        // Start a tor thread.
        self.thread?.start()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // Connect Tor controller.
            do {
                if !(self.controller?.isConnected ?? false) {
                    do {
                        try self.controller?.connect()
                    } catch {
                        print("error=\(error)")
                    }
                }
                
                let cookie = try Data(
                    contentsOf: self.config.dataDirectory!.appendingPathComponent("control_auth_cookie"),
                    options: NSData.ReadingOptions(rawValue: 0)
                )
                
                self.controller?.authenticate(with: cookie) { (success, error) in
                    if let error = error {
                        print("error = \(error.localizedDescription)")
                        return
                    }
                    
                    var progressObs: Any? = nil
                    progressObs = self.controller?.addObserver(forStatusEvents: {
                        (type: String, severity: String, action: String, arguments: [String : String]?) -> Bool in
                        if arguments != nil {
                            if arguments!["PROGRESS"] != nil {
                                let progress = Int(arguments!["PROGRESS"]!)!
                                weakDelegate?.torConnProgress(progress)
                                if progress >= 100 {
                                    self.controller?.removeObserver(progressObs)
                                }
                                return true
                            }
                        }
                        return false
                    })
                    
                    var observer: Any? = nil
                    observer = self.controller?.addObserver(forCircuitEstablished: { established in
                        if established {
                            self.state = .connected
                            weakDelegate?.torConnFinished()
                            self.controller?.removeObserver(observer)
                            
                        } else if self.state == .refreshing {
                            self.state = .connected
                            self.controller?.removeObserver(observer)
                        }
                    })
                }
            } catch {
                weakDelegate?.torConnDifficulties()
                self.state = .none
            }
        }
    }
    
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let trust = challenge.protectionSpace.serverTrust else {
            return
        }
        
        let credential = URLCredential(trust: trust)
        
        if let certData = self.cert,
            let remoteCert = SecTrustGetCertificateAtIndex(trust, 0) {
            let remoteCertData = SecCertificateCopyData(remoteCert) as NSData
            let certData = Data(base64Encoded: certData)
            
            if let pinnedCertData = certData,
                remoteCertData.isEqual(to: pinnedCertData as Data) {
                completionHandler(.useCredential, credential)
            } else {
                completionHandler(.rejectProtectionSpace, nil)
            }
        } else {
            completionHandler(.useCredential, credential)
        }
    }
    
    func resign() {
        controller?.disconnect()
        controller = nil
        thread?.cancel()
        thread = nil
        state = .stopped
    }
    
    private func createTorDirectory() {
        do {
            try FileManager.default.createDirectory(atPath: self.torPath(),
                                                    withIntermediateDirectories: true,
                                                    attributes: [FileAttributeKey.posixPermissions: 0o700])
        } catch {
            print("Directory previously created.")
        }
        //addTorrc()
        //createHiddenServiceDirectory()
    }
    
    private func torPath() -> String {
        #if targetEnvironment(simulator)
            let path = NSSearchPathForDirectoriesInDomains(.applicationDirectory, .userDomainMask, true).first ?? ""
            return "\(path.split(separator: Character("/"))[0..<2].joined(separator: "/"))/.tor_tmp"
        #else
            return "\(NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first ?? "")/tor"
        #endif
    }
    
    func turnedOff() -> Bool {
        return false
    }
}

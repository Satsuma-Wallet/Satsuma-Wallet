//
//  ScanOrPasteInvoiceViewController.swift
//  Satsuma
//
//  Created by Peter Denton on 5/11/23.
//

import UIKit
import AVKit

class ScanOrPasteInvoiceViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    @IBOutlet weak var scanIconImageView: UIImageView!
    @IBOutlet weak var scannerImageView: UIImageView!
    @IBOutlet weak var enableCameraView: UIStackView!
    var deniedAccess = false
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var address = ""
    var amount = 0.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        scanIconImageView.alpha = 0
        enableCameraView.alpha = 0
        scannerImageView.alpha = 0
        checkCameraAccess()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if (captureSession?.isRunning == true) {
            captureSession.stopRunning()
        }
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    @IBAction func enterTextAction(_ sender: Any) {
        
    }
    
    
    @IBAction func enableCameraAction(_ sender: Any) {
        if deniedAccess {
            openSettings()
        } else {
            presentCameraPermission()
        }
    }
    
    private func removeCameraAccessView() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.enableCameraView.removeFromSuperview()
            self.scanIconImageView.alpha = 1
            self.scannerImageView.alpha = 1
            self.showScanner()
        }
    }
    
    private func showCameraAccessView() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.enableCameraView.alpha = 1
        }
    }
    
    func checkCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied:
            print("Denied, request permission from settings")
            deniedAccess = true
            showCameraAccessView()
        case .restricted:
            print("Restricted, device owner must approve")
            showCameraAccessView()
        case .authorized:
            print("Authorized, proceed")
            removeCameraAccessView()
        case .notDetermined:
            presentCameraPermission()
        @unknown default:
            fatalError()
        }
    }
    
    private func presentCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] success in
            guard let self = self else { return }
            
            if success {
                print("Permission granted, proceed")
                self.removeCameraAccessView()
            } else {
                print("Permission denied")
                self.showCameraAccessView()
            }
        }
    }
    
    private func openSettings() {
        let alertController = UIAlertController(title: "Camera access was denied.",
                                                message: "Tap settings, navigate to Satsuma and enable camera access manually to proceed.",
                                                preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Cancel", style: .default))
        alertController.addAction(UIAlertAction(title: "Settings", style: .cancel) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: { _ in
                    self.checkCameraAccess()
                })
            }
        })
        
        present(alertController, animated: true)
    }
    
    private func showScanner() {
        scannerImageView.backgroundColor = UIColor.black
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        
        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            failed()
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            failed()
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        scannerImageView.layer.addSublayer(previewLayer)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.captureSession.startRunning()
        }
    }
    
    private func failed() {
        let ac = UIAlertController(title: "Scanning not supported", message: "Your device does not support scanning a code from an item. Please use a device with a camera.", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
        captureSession = nil
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession.stopRunning()
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            found(code: stringValue)
        }
        
        dismiss(animated: true)
    }
    
    func found(code: String) {
        if parseTextInput(text: code) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.performSegue(withIdentifier: "segueToTextInput", sender: self)
            }
        }
    }
    
    func validAddress(string: String) -> Bool {
        return WalletTools.shared.validAddress(string: string)
    }
    
    private func validBip21Invoice(string: String) -> (address: String?, amount: Double?, label: String?, message: String?) {
        return BIP21InvoiceParser.shared.parseInvoice(url: string)
    }
    
    private func parseTextInput(text: String) -> Bool {
        if validAddress(string: text) {
            address = text
            return true
        } else {
            let (address, amount, _, _) = validBip21Invoice(string: text)
            guard let address = address else {
                return false
            }
            self.address = address
            if let amount = amount {
                self.amount = amount
            }
            
            return true
        }
    }
    
    
    
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destination.
     // Pass the selected object to the new view controller.
         switch segue.identifier {
         case "segueToTextInput":
             guard let vc = segue.destination as? TextInputViewController else { return }
             vc.amount = amount
             vc.address = address
         default:
             break
         }
     }
     
    
}

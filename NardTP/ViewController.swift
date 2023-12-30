//
//  ViewController.swift
//  NardTP
//
//  Created by Mohammed Hussein on 30/12/2023.
//

import UIKit
import StarIO10
import WebKit

class ViewController: UIViewController, WKNavigationDelegate, UIDocumentPickerDelegate, UITextFieldDelegate {
    
    @IBOutlet weak var img: UIImageView!
    
    @IBOutlet weak var txtURL: UITextField!
    
    var webView: WKWebView!
    
    let identifier = "2550722011301040"
    
    var selectedInterface: InterfaceType = InterfaceType.usb
    
    var printer: StarPrinter?
    
    var filePath: String?
    
    var showImg = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        webView = WKWebView(frame: .init(x: 0, y: 0, width: 450, height: 600))
        webView.navigationDelegate = self
        txtURL.delegate = self
        let starConnectionSettings = StarConnectionSettings(interfaceType: selectedInterface, identifier: identifier)
        printer = StarPrinter(starConnectionSettings)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("document.readyState", completionHandler: { (complete, error) in
            guard let complete = complete as? String, error == nil else {
                return
            }
            if complete == "complete" {
                self.convertHTMLToPDF() { [self] (pdfData, error) in
                    if let error = error {
                        print("Error converting HTML to PDF: \(error)")
                    } else if let pdfData = pdfData {
                        self.printPDF(pdfData: pdfData, showImage: self.showImg)
                    }
                }
            }
        })
    }
    
    @IBAction func btnCreateLongInvoice(_ sender: Any) {
        self.img.image = nil
        if let filePath = Bundle.main.path(forResource: "longInvoicetml", ofType: "txt") {
            self.filePath = filePath
        }
    }
    
    @IBAction func btnCreateShortInvoice_en(_ sender: Any) {
        self.img.image = nil
        if let filePath = Bundle.main.path(forResource: "shortInvoicetml", ofType: "txt") {
            self.filePath = filePath
        }
    }
    
    @IBAction func btnCreateShortInvoice_ar(_ sender: Any) {
        self.img.image = nil
        if let filePath = Bundle.main.path(forResource: "shortInvoicetml_ar", ofType: "txt") {
            self.filePath = filePath
        }
    }
    
    @IBAction func btnPrint(_ sender: Any) {
        self.showImg = false
        self.img.image = nil
        if let filePath = self.filePath {
            if let htmlString = try? String(contentsOfFile: filePath) {
                webView.loadHTMLString(htmlString, baseURL: nil)
            }
        }else {
            self.showAlert(message: "You should create an invoice before printing")
        }
    }
    
    @IBAction func btnShowImgAndPrint(_ sender: Any) {
        self.showImg = true
        self.img.image = nil
        if let filePath = self.filePath, let htmlString = try? String(contentsOfFile: filePath) {
            webView.loadHTMLString(htmlString, baseURL: nil)
        } else {
            self.showAlert(message: "You should create an invoice before printing")
        }
    }
    
    
    func concatenatePDFPages(pdfData: Data) -> UIImage? {
        guard let provider = CGDataProvider(data: pdfData as CFData) else {
            return nil
        }
        
        if let pdfDocument = CGPDFDocument(provider) {
            var concatenatedImage: UIImage?
            for pageIndex in 1...pdfDocument.numberOfPages {
                if let pdfPage = pdfDocument.page(at: pageIndex) {
                    let pageRect = pdfPage.getBoxRect(.mediaBox)
                    let renderer = UIGraphicsImageRenderer(size: pageRect.size)
                    let image = renderer.image { context in
                        UIColor.white.set()
                        context.fill(pageRect)
                        context.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
                        context.cgContext.scaleBy(x: 1.0, y: -1.0)
                        context.cgContext.drawPDFPage(pdfPage)
                    }
                    if concatenatedImage == nil {
                        concatenatedImage = image
                    } else {
                        concatenatedImage = concatenateImagesVertically(topImage: concatenatedImage!, bottomImage: image)
                    }
                }
            }
            return concatenatedImage
        }
        return nil
    }
    
    func concatenateImagesVertically(topImage: UIImage, bottomImage: UIImage) -> UIImage {
        let newSize = CGSize(width: max(topImage.size.width, bottomImage.size.width), height: topImage.size.height + bottomImage.size.height)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        topImage.draw(in: CGRect(x: 0, y: 0, width: topImage.size.width, height: topImage.size.height))
        bottomImage.draw(in: CGRect(x: 0, y: topImage.size.height, width: bottomImage.size.width, height: bottomImage.size.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage!
    }
    
    func convertHTMLToPDF(completionHandler: @escaping (Data?, Error?) -> Void) {
        webView.createPDF { result in
            switch result {
            case .success(let pdfData):
                completionHandler(pdfData, nil)
            case .failure(let error):
                print("Error creating PDF: \(error.localizedDescription)")
            }
        }
    }
    
    func showAlert(message: String) {
        let alertController = UIAlertController(title: "Alert", message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(okAction)
        present(alertController, animated: true, completion: nil)
    }
    
    func printPDF(pdfData: Data, showImage: Bool = true) {
        if let concatenatedImage = self.concatenatePDFPages(pdfData: pdfData) {
            if showImage { self.img.image = concatenatedImage }
            let builder = StarXpandCommand.StarXpandCommandBuilder()
            _ = builder.addDocument(StarXpandCommand.DocumentBuilder()
                .addPrinter(StarXpandCommand.PrinterBuilder()
                    .actionPrintImage(StarXpandCommand.Printer.ImageParameter(image: concatenatedImage, width: 600))
                    .actionCut(StarXpandCommand.Printer.CutType.partial)
                )
            )
            
            let command = builder.getCommands()
            Task {
                do {
                    try await self.printer?.open()
                    defer {
                        Task {
                            await self.printer?.close()
                        }
                    }
                    try await self.printer?.print(command: command)
                    print("Success")
                } catch let error {
                    self.showAlert(message: "Error: \(error)")
                }
            }
        } else {
            self.showAlert(message: "Error concatenating PDF pages.")
        }
    }
    
    @IBAction func btnPDF(_ sender: Any) {
        let documentPicker = UIDocumentPickerViewController(documentTypes: ["com.adobe.pdf"], in: .import)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        present(documentPicker, animated: true, completion: nil)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let selectedFileURL = urls.first else {
            return
        }
        do {
            let pdfData = try Data(contentsOf: selectedFileURL)
            self.printPDF(pdfData: pdfData)
        } catch {
            self.showAlert(message: "Error reading PDF file: \(error.localizedDescription)")
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.txtURL.resignFirstResponder()
        if let text = self.txtURL.text, !text.isEmpty {
            if let htmlURL = URL(string: text) {
                let request = URLRequest(url: htmlURL)
                webView.load(request)
            } else {
                self.showAlert(message: "Invalid URL")
            }
        } else {
            self.showAlert(message: "URL is empty")
        }
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.img.image = nil
    }
    
}

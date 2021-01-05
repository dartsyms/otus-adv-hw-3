//
//  ViewController.swift
//  hwappthird
//

import UIKit
import CoreML
import Vision

class ViewController: UIViewController {
  
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var cameraButton: UIButton!
    @IBOutlet var photoLibraryButton: UIButton!
    @IBOutlet var resultsView: UIView!
    @IBOutlet var resultsLabel: UILabel!
    @IBOutlet var resultsConstraint: NSLayoutConstraint!
    
    lazy var classificationRequest: VNCoreMLRequest? = {
        let config = MLModelConfiguration()
        config.allowLowPrecisionAccumulationOnGPU = true
        guard let snacks  = try? SnackClassifier_1(configuration: config),
              let visionModel = try? VNCoreMLModel(for: snacks.model) else { return nil }
        let request = VNCoreMLRequest(model: visionModel, completionHandler: { [weak self] request, error in
            self?.process(for: request, error: error)
        })
        
        request.imageCropAndScaleOption = .centerCrop
        return request
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        cameraButton.isEnabled = UIImagePickerController.isSourceTypeAvailable(.camera)
        resultsView.alpha = 0
    }
    
    @IBAction func takePicture() {
        presentPhotoPicker(sourceType: .camera)
    }
    
    @IBAction func choosePhoto() {
        presentPhotoPicker(sourceType: .photoLibrary)
    }
    
    func presentPhotoPicker(sourceType: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = sourceType
        present(picker, animated: true)
        hideResultsView()
    }
    
    func showResultsView(delay: TimeInterval = 0.1) {
        resultsConstraint.constant = 100
        view.layoutIfNeeded()
        
        UIView.animate(withDuration: 0.5, delay: delay, usingSpringWithDamping: 0.6,
                       initialSpringVelocity: 0.6, options: .beginFromCurrentState, animations: {
            self.resultsView.alpha = 1
            self.resultsConstraint.constant = -10
            self.view.layoutIfNeeded()
           })
    }
    
    func hideResultsView() {
        UIView.animate(withDuration: 0.3) {
            self.resultsView.alpha = 0
        }
    }
    
    func classify(image: UIImage) {
        guard let ciImage = CIImage(image: image) else { return }
        guard let request = self.classificationRequest else { return }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
            try? handler.perform([request])
        }
    }
    
    func process(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            if let results = request.results as? [VNClassificationObservation] {
                if results.isEmpty {
                    self.resultsLabel.text = "Nothing found"
                } else {
                    let top = results.prefix(1).map { observation in
                        String(format: "%@ %.1f%%", observation.identifier, observation.confidence * 100)
                    }
                    self.resultsLabel.text = top.joined(separator: "\n")
                }
            } else if let error = error {
                self.resultsLabel.text = "Error: \(error.localizedDescription)"
            } else {
                self.resultsLabel.text = "???"
            }
            self.showResultsView()
        }
    }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        let image = info[.originalImage] as! UIImage
        imageView.image = image
        
        classify(image: image)
    }
}



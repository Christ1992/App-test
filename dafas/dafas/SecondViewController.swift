//
//  SecondViewController.swift
//  dafas
//
//  Created by yingjie on 2017/8/21.
//  Copyright © 2017年 yingjie. All rights reserved.
//

import UIKit

class SecondViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate{

    @IBOutlet weak var CameraView: UIImageView!
    
    let imageTaker = UIImagePickerController()
    
    @IBAction func TakePic(_ sender: Any) {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
        imageTaker.allowsEditing = false
        imageTaker.sourceType = .camera
        imageTaker.cameraCaptureMode = .photo
        imageTaker.modalPresentationStyle = .fullScreen
        present(imageTaker,animated: true,completion: nil)
    }
    else {
        noCamera()
        }    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageTaker.delegate = self
       
    }
    
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            self.CameraView.contentMode = .scaleAspectFit
            self.CameraView.image = pickedImage
        }
        
        dismiss(animated: true, completion: nil)
    }
    
    
    func noCamera(){
        let alertVC = UIAlertController(
            title: "No Camera",
            message: "Sorry, this device has no camera",
            preferredStyle: .alert)
        let okAction = UIAlertAction(
            title: "OK",
            style:.default,
            handler: nil)
        alertVC.addAction(okAction)
        present(
            alertVC,
            animated: true,
            completion: nil)
    }

}


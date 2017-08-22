//
//  FirstViewController.swift
//  dafas
//
//  Created by yingjie on 2017/8/21.
//  Copyright © 2017年 yingjie. All rights reserved.
//

import UIKit

class FirstViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var Imageview: UIImageView!
    let imagePicker = UIImagePickerController()
    @IBAction func selectPic(_ sender: UIButton) {
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .photoLibrary
        imagePicker .modalPresentationStyle=UIModalPresentationOverCurrentContext
        self.present(self.imagePicker, animated: true, completion: nil)
        
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imagePicker.delegate = self
        
    }

     func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            self.Imageview.contentMode = .scaleAspectFit
            self.Imageview.image = pickedImage
        }
        
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }

}


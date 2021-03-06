//
//  ImagePickerView.swift
//  FirebaseTestProject
//
//  Created by Tim Miller on 8/30/21.
//

import UIKit
import SwiftUI

struct ImagePickerView: UIViewControllerRepresentable {
    typealias SourceType = UIImagePickerController.SourceType
    
    var sourceType: SourceType
    @Binding var selection: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeCoordinator() -> Coordinator {
        .init(view: self)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = sourceType
        imagePicker.delegate = context.coordinator
        imagePicker.allowsEditing = true
        return imagePicker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        
    }
}

extension ImagePickerView {
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var view: ImagePickerView
        
        init(view: ImagePickerView) {
            self.view = view
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            guard let image = info[.editedImage] as? UIImage else { return }
            view.selection = image
            view.dismiss()
        }
    }
}

extension ImagePickerView.SourceType: Identifiable {
    public var id: RawValue { rawValue }
}

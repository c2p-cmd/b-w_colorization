//
//  UIImagePicker.swift
//  BWColorizer
//
//  Created by Sharan Thakur on 20/07/24.
//

import SwiftUI
import UniformTypeIdentifiers

struct UIImagePickerView: UIViewControllerRepresentable {
    let uiImage: Binding<UIImage?>
    let onDone: () -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let vc = UIImagePickerController()
        vc.delegate = context.coordinator
        
        vc.allowsEditing = true
        vc.mediaTypes = [ UTType.image.identifier ]
        
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // no update
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: UIImagePickerView
        
        init(_ parent: UIImagePickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            
            if let editedImage = info[.editedImage] as? UIImage {
                self.parent.uiImage.wrappedValue = editedImage
                self.parent.onDone()
                return
            }
            
            if let originalImage = info[.originalImage] as? UIImage {
                self.parent.uiImage.wrappedValue = originalImage
                self.parent.onDone()
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            self.parent.onDone()
        }
    }
}

//
//  ContentView.swift
//  BWColorizer
//
//  Created by Sharan Thakur on 20/07/24.
//

import CoreML
import SwiftUI

struct ContentView: View {
    @State var vm = ViewModel()
    
    var body: some View {
        NavigationStack {
            MainBody
                .navigationTitle("B&W Colorizer")
        }
    }
    
    var MainBody: some View {
        Form {
            Button("Pick Image", systemImage: "photo") {
                vm.isBusy = true
                vm.showPicker = true
            }
            .fontWeight(.semibold)
            .fullScreenCover(isPresented: $vm.showPicker) {
                PickerView
            }
            
            HStack {
                if let inputImage = vm.inputImage {
                    Image(uiImage: inputImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(.rect(cornerRadius: 10, style: .continuous))
                }
                
                if let outputImage = vm.outputImage {
                    Image(uiImage: outputImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(.rect(cornerRadius: 10, style: .continuous))
                }
                
                if vm.outputImage == nil && vm.inputImage == nil {
                    Text("Please choose a Black & White Image")
                }
            }
        }
        .toolbar {
            if let inputImage = vm.inputImage, let outputImage = vm.outputImage {
                ToolbarItem(placement: .automatic) {
                    ShareLink(
                        items: [
                            Photo(image: inputImage, caption: "B&W Image"),
                            Photo(image: outputImage, caption: "Colorized Image")
                        ],
                        subject: Text("B&W image and colorized Image!")
                    ) { img in
                        SharePreview(img.caption, image: img.image)
                    }
                }
            }
            
            if let inputImage = vm.inputImage {
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        vm.process(from: inputImage)
                    } label: {
                        HStack {
                            Image(systemName: "paintpalette.fill")
                            Text("Colorize!")
                                .fontWeight(.semibold)
                        }
                    }
                    .tint(.orange)
                    .buttonStyle(BorderedButtonStyle())
                }
            }
        }
        .disabled(vm.isModelEnabled == false || vm.isBusy)
        .alert(isPresented: vm.showError, error: vm.error) { _ in
        } message: { error in
            Text(error.errorDescription ?? String(describing: error))
        }
        .overlay(alignment: .center) {
            if vm.isBusy {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    
                    ProgressView()
                }
            }
        }
    }
    
    var PickerView: some View {
        UIImagePickerView(uiImage: $vm.inputImage) {
            self.vm.showPicker = false
            self.vm.isBusy = false
        }
        .ignoresSafeArea()
    }
}

extension ContentView {
    @Observable
    class ViewModel {
        private let model: ECCV16Colorize?
        
        var inputImage: UIImage?
        var outputImage: UIImage?
        var error: AppError?
        
        var showPicker = false
        var isBusy = true
        
        var showError: Binding<Bool> {
            Binding {
                self.error != nil
            } set: { _ in
                self.error = nil
            }
        }
        
        var isModelEnabled: Bool {
            model != nil
        }
        
        init() {
            do {
                guard let url = Bundle.main.url(forResource: "ECCV16Colorize", withExtension: "mlmodelc") else {
                    throw URLError(.badURL)
                }
                let modelConfig = MLModelConfiguration()
                modelConfig.computeUnits = .cpuAndGPU
                
                self.model = try ECCV16Colorize(contentsOf: url, configuration: modelConfig)
            } catch {
                self.error = AppError(String(describing: error))
                self.model = nil
            }
            self.isBusy = false
        }
        
        /// Creates a task to run ineference so the Main thread isn't blocked
        func process(from uiImage: UIImage) {
            Task.init {
                self.isBusy = true
                self.outputImage = nil
                let originalImage = uiImage.resized(toWidth: 512)

                guard let (originalL, resizedL) = originalImage.toL() else {
                    self.error = AppError("Cannot convert to Lab color space")
                    return
                }
                guard let model else { return }
                let output = try await model.prediction(input: ECCV16ColorizeInput(input1: resizedL)).var_336ShapedArray
                
                let colorizedImage = Colorizer.processColorizer(originalL: originalL, resizedL: resizedL, abOutput: output)
                
                if colorizedImage == nil {
                    self.error = AppError("Could not colorize image oops!")
                }
                
                self.outputImage = colorizedImage
                self.isBusy = false
            }
        }
    }
}

#Preview {
    ContentView()
}

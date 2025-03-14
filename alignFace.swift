//
//  Untitled.swift

import UIKit
import Vision

extension UIImage {
    
    func alignFace(completion: @escaping (UIImage?, UIImage?) -> Void) {
        guard let cgImage = self.cgImage else {
            completion(nil, nil)
            return
        }
        
        let faceDetectionRequest = VNDetectFaceRectanglesRequest { request, error in
            guard let face = (request.results as? [VNFaceObservation])?.first else {
                completion(nil, nil)
                return
            }
            
            let faceRect = face.boundingBox.scaled(to: self.size)
            guard let croppedImage = self.cropped(to: faceRect) else {
                completion(nil, nil)
                return
            }
                        
            croppedImage.detectFaceLandmarks { rotatedImage in
                completion(croppedImage, rotatedImage)
            }
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        try? handler.perform([faceDetectionRequest])
    }

    func cropped(to rect: CGRect) -> UIImage? {
        let scaledRect = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
        guard let croppedCgImage = cgImage?.cropping(to: scaledRect) else { return nil }
        return UIImage(cgImage: croppedCgImage, scale: scale, orientation: .up)
    }
    
    private func detectFaceLandmarks(completion: @escaping (UIImage?) -> Void) {
        
        guard let cgImage = self.cgImage else { completion(nil); return }
        
        let request = VNDetectFaceLandmarksRequest { request, error in
            guard let face = (request.results as? [VNFaceObservation])?.first,
                  let landmarks = face.landmarks,
                  let leftEye = landmarks.leftEye?.normalizedPoints.first,
                  let rightEye = landmarks.rightEye?.normalizedPoints.first,
                  let nose = landmarks.nose?.normalizedPoints.first else {
                completion(nil)
                return
            }
            
            let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
            let faceBoundingBox = face.boundingBox.scaled(to: imageSize)
            
            let leftEyePos = self.convertNormalizedPoint(leftEye, to: faceBoundingBox)
            let rightEyePos = self.convertNormalizedPoint(rightEye, to: faceBoundingBox)
            let nosePos = self.convertNormalizedPoint(nose, to: faceBoundingBox)
            
            let deltaY = leftEyePos.y - rightEyePos.y
            let deltaX = leftEyePos.x - rightEyePos.x
            let angle = atan2(deltaY, deltaX)
            
            guard let rotatedImage = self.rotated(by: -angle, around: nosePos) else {
                completion(nil)
                return
            }
            
            completion(rotatedImage)
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try? handler.perform([request])
    }

    private func convertNormalizedPoint(_ point: CGPoint, to rect: CGRect) -> CGPoint {
        return CGPoint(
            x: rect.origin.x + point.x * rect.width,
            y: rect.origin.y + (1 - point.y) * rect.height
        )
    }

    func rotated(by angle: CGFloat, around center: CGPoint) -> UIImage? {
        let radians = angle
        let rotatedRect = CGRect(origin: .zero, size: self.size)
            .applying(CGAffineTransform(rotationAngle: radians))
        let newSize = CGSize(
            width: abs(rotatedRect.width),
            height: abs(rotatedRect.height)
        )
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        context.translateBy(x: newSize.width/2, y: newSize.height/2)
        context.rotate(by: radians + .pi)
        self.draw(in: CGRect(
            x: -self.size.width/2 + (center.x - self.size.width/2),
            y: -self.size.height/2 + (center.y - self.size.height/2),
            width: self.size.width,
            height: self.size.height
        ))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
}

extension CGRect {
    func scaled(to size: CGSize) -> CGRect {
        return CGRect(
            x: self.origin.x * size.width,
            y: (1 - self.origin.y - self.height) * size.height,
            width: self.width * size.width,
            height: self.height * size.height
        )
    }
}

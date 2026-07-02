import CoreImage
import CoreImage.CIFilterBuiltins
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct IconVariantGenerator {
    let context = CIContext(options: [.useSoftwareRenderer: false])

    func run(inputURL: URL, darkURL: URL, tintedURL: URL) throws {
        guard let inputImage = CIImage(contentsOf: inputURL) else {
            throw NSError(domain: "IconVariantGenerator", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "无法读取输入图标：\(inputURL.path)"
            ])
        }

        try writeDarkVariant(from: inputImage, to: darkURL)
        try writeTintedVariant(from: inputImage, to: tintedURL)
    }

    private func writeDarkVariant(from input: CIImage, to outputURL: URL) throws {
        let controls = CIFilter.colorControls()
        controls.inputImage = input
        controls.brightness = -0.18
        controls.contrast = 1.18
        controls.saturation = 0.78

        let exposure = CIFilter.exposureAdjust()
        exposure.inputImage = controls.outputImage
        exposure.ev = -0.42

        let gamma = CIFilter.gammaAdjust()
        gamma.inputImage = exposure.outputImage
        gamma.power = 1.08

        let color = CIFilter.colorMatrix()
        color.inputImage = gamma.outputImage
        color.rVector = CIVector(x: 0.44, y: 0.03, z: 0.03, w: 0)
        color.gVector = CIVector(x: 0.02, y: 0.42, z: 0.05, w: 0)
        color.bVector = CIVector(x: 0.00, y: 0.06, z: 0.66, w: 0)
        color.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)

        guard let filtered = context.createCGImage(color.outputImage ?? input, from: input.extent) else {
            throw NSError(domain: "IconVariantGenerator", code: 5, userInfo: [
                NSLocalizedDescriptionKey: "无法生成深色图标内容：\(outputURL.path)"
            ])
        }

        try writeDarkPNG(image: filtered, to: outputURL)
    }

    private func writeTintedVariant(from input: CIImage, to outputURL: URL) throws {
        let monochrome = CIFilter.colorMonochrome()
        monochrome.inputImage = input
        monochrome.color = CIColor(red: 0.27, green: 0.48, blue: 1.0)
        monochrome.intensity = 0.98

        let controls = CIFilter.colorControls()
        controls.inputImage = monochrome.outputImage
        controls.brightness = -0.14
        controls.contrast = 1.06
        controls.saturation = 0.0

        let color = CIFilter.colorMatrix()
        color.inputImage = controls.outputImage
        color.rVector = CIVector(x: 0.34, y: 0.05, z: 0.04, w: 0)
        color.gVector = CIVector(x: 0.10, y: 0.46, z: 0.08, w: 0)
        color.bVector = CIVector(x: 0.18, y: 0.28, z: 0.88, w: 0)
        color.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)

        guard let filtered = context.createCGImage(color.outputImage ?? input, from: input.extent) else {
            throw NSError(domain: "IconVariantGenerator", code: 8, userInfo: [
                NSLocalizedDescriptionKey: "无法生成着色图标内容：\(outputURL.path)"
            ])
        }

        try writeTintedPNG(image: filtered, to: outputURL)
    }

    private func writePNG(image: CIImage, to outputURL: URL) throws {
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            throw NSError(domain: "IconVariantGenerator", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "无法生成输出图像：\(outputURL.path)"
            ])
        }

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw NSError(domain: "IconVariantGenerator", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "无法创建输出文件：\(outputURL.path)"
            ])
        }

        CGImageDestinationAddImage(destination, cgImage, nil)

        if !CGImageDestinationFinalize(destination) {
            throw NSError(domain: "IconVariantGenerator", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "无法写入输出文件：\(outputURL.path)"
            ])
        }
    }

    private func writeDarkPNG(image: CGImage, to outputURL: URL) throws {
        let width = image.width
        let height = image.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError(domain: "IconVariantGenerator", code: 6, userInfo: [
                NSLocalizedDescriptionKey: "无法创建深色图标绘制上下文：\(outputURL.path)"
            ])
        }

        let canvasRect = CGRect(x: 0, y: 0, width: width, height: height)
        let backgroundRadius = CGFloat(width) * 0.225
        let contentInset = CGFloat(width) * 0.055
        let contentRect = canvasRect.insetBy(dx: contentInset, dy: contentInset)
        let contentRadius = backgroundRadius * 0.78

        context.setFillColor(CGColor(red: 0.03, green: 0.03, blue: 0.04, alpha: 1))
        let backgroundPath = CGPath(
            roundedRect: canvasRect,
            cornerWidth: backgroundRadius,
            cornerHeight: backgroundRadius,
            transform: nil
        )
        context.addPath(backgroundPath)
        context.fillPath()

        context.saveGState()
        let contentPath = CGPath(
            roundedRect: contentRect,
            cornerWidth: contentRadius,
            cornerHeight: contentRadius,
            transform: nil
        )
        context.addPath(contentPath)
        context.clip()
        context.draw(image, in: contentRect)
        context.restoreGState()

        context.setStrokeColor(CGColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1))
        context.setLineWidth(CGFloat(width) * 0.009)
        context.addPath(backgroundPath)
        context.strokePath()

        guard let composed = context.makeImage() else {
            throw NSError(domain: "IconVariantGenerator", code: 7, userInfo: [
                NSLocalizedDescriptionKey: "无法生成深色图标最终图像：\(outputURL.path)"
            ])
        }

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw NSError(domain: "IconVariantGenerator", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "无法创建输出文件：\(outputURL.path)"
            ])
        }

        CGImageDestinationAddImage(destination, composed, nil)

        if !CGImageDestinationFinalize(destination) {
            throw NSError(domain: "IconVariantGenerator", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "无法写入输出文件：\(outputURL.path)"
            ])
        }
    }

    private func writeTintedPNG(image: CGImage, to outputURL: URL) throws {
        let width = image.width
        let height = image.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError(domain: "IconVariantGenerator", code: 9, userInfo: [
                NSLocalizedDescriptionKey: "无法创建着色图标绘制上下文：\(outputURL.path)"
            ])
        }

        let canvasRect = CGRect(x: 0, y: 0, width: width, height: height)
        let backgroundRadius = CGFloat(width) * 0.225
        let contentInset = CGFloat(width) * 0.05
        let contentRect = canvasRect.insetBy(dx: contentInset, dy: contentInset)
        let contentRadius = backgroundRadius * 0.78

        context.setFillColor(CGColor(red: 0.22, green: 0.43, blue: 0.94, alpha: 1))
        let backgroundPath = CGPath(
            roundedRect: canvasRect,
            cornerWidth: backgroundRadius,
            cornerHeight: backgroundRadius,
            transform: nil
        )
        context.addPath(backgroundPath)
        context.fillPath()

        context.saveGState()
        let contentPath = CGPath(
            roundedRect: contentRect,
            cornerWidth: contentRadius,
            cornerHeight: contentRadius,
            transform: nil
        )
        context.addPath(contentPath)
        context.clip()
        context.setAlpha(0.92)
        context.draw(image, in: contentRect)
        context.restoreGState()

        context.setStrokeColor(CGColor(red: 0.15, green: 0.30, blue: 0.74, alpha: 1))
        context.setLineWidth(CGFloat(width) * 0.008)
        context.addPath(backgroundPath)
        context.strokePath()

        guard let composed = context.makeImage() else {
            throw NSError(domain: "IconVariantGenerator", code: 10, userInfo: [
                NSLocalizedDescriptionKey: "无法生成着色图标最终图像：\(outputURL.path)"
            ])
        }

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw NSError(domain: "IconVariantGenerator", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "无法创建输出文件：\(outputURL.path)"
            ])
        }

        CGImageDestinationAddImage(destination, composed, nil)

        if !CGImageDestinationFinalize(destination) {
            throw NSError(domain: "IconVariantGenerator", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "无法写入输出文件：\(outputURL.path)"
            ])
        }
    }
}

let arguments = CommandLine.arguments
guard arguments.count == 4 else {
    fputs("Usage: swift scripts/update_app_icon_variants.swift <input> <dark-output> <tinted-output>\n", stderr)
    exit(1)
}

let generator = IconVariantGenerator()
try generator.run(
    inputURL: URL(fileURLWithPath: arguments[1]),
    darkURL: URL(fileURLWithPath: arguments[2]),
    tintedURL: URL(fileURLWithPath: arguments[3])
)

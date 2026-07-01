//
//  WatermarkRenderer.swift
//  WorkStamp
//
//  Created by Codex on 2026/7/1.
//

import UIKit

struct WatermarkRenderPayload {
    let timestamp: Date
    let snapshot: LocationSnapshot
    let attendanceStatus: String
    let workdayLabel: String
    let fontSize: Double
    let position: WatermarkPosition
}

enum WatermarkRenderer {
    static func render(image: UIImage, payload: WatermarkRenderPayload) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale

        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))

            let lines = watermarkLines(from: payload)
            let font = UIFont.systemFont(ofSize: payload.fontSize * image.size.width / 390.0, weight: .bold)
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = payload.position.textAlignment
            paragraph.lineSpacing = max(2, font.pointSize * 0.1)

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph
            ]

            let shadow = NSShadow()
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.55)
            shadow.shadowBlurRadius = 8
            shadow.shadowOffset = CGSize(width: 0, height: 2)

            var shadowAttributes = attributes
            shadowAttributes[.shadow] = shadow

            let text = lines.joined(separator: "\n")
            let attributedText = NSAttributedString(string: text, attributes: shadowAttributes)
            let maxWidth = image.size.width * 0.78
            let boundingRect = attributedText.boundingRect(
                with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).integral

            let inset: CGFloat = max(22, image.size.width * 0.035)
            let origin = payload.position.textOrigin(
                imageSize: image.size,
                textSize: boundingRect.size,
                inset: inset
            )

            attributedText.draw(
                with: CGRect(origin: origin, size: boundingRect.size),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
        }
    }

    private static func watermarkLines(from payload: WatermarkRenderPayload) -> [String] {
        [
            DateFormatter.workStampTimestamp.string(from: payload.timestamp),
            payload.attendanceStatus,
            coordinateLine(from: payload.snapshot),
            "地址：\(payload.snapshot.address ?? "定位中或不可用")",
            altitudeLine(from: payload.snapshot),
            payload.workdayLabel
        ]
    }

    private static func coordinateLine(from snapshot: LocationSnapshot) -> String {
        guard let latitude = snapshot.latitude,
              let longitude = snapshot.longitude else {
            return "经纬度：定位中或不可用"
        }

        return "经纬度：\(latitude.workStampCoordinateString), \(longitude.workStampCoordinateString)"
    }

    private static func altitudeLine(from snapshot: LocationSnapshot) -> String {
        guard let altitude = snapshot.altitude else {
            return "海拔：不可用"
        }

        return "海拔：\(altitude.workStampAltitudeString)m"
    }
}

private extension WatermarkPosition {
    var textAlignment: NSTextAlignment {
        switch self {
        case .topLeft, .bottomLeft:
            return .left
        case .topRight, .bottomRight:
            return .right
        }
    }

    func textOrigin(imageSize: CGSize, textSize: CGSize, inset: CGFloat) -> CGPoint {
        switch self {
        case .topLeft:
            return CGPoint(x: inset, y: inset)
        case .topRight:
            return CGPoint(x: imageSize.width - textSize.width - inset, y: inset)
        case .bottomLeft:
            return CGPoint(x: inset, y: imageSize.height - textSize.height - inset)
        case .bottomRight:
            return CGPoint(x: imageSize.width - textSize.width - inset, y: imageSize.height - textSize.height - inset)
        }
    }
}

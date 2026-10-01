import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

enum ConfigurationQR {
    static func image(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8); filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8,y: 8))
        guard let image = CIContext().createCGImage(scaled,from:scaled.extent) else { return nil }
        return UIImage(cgImage:image)
    }
}
struct QRCodeView: View {
    let text: String
    @State private var image: UIImage?
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage:image).interpolation(.none).resizable().scaledToFit()
            } else { Text("请复制配置").font(.system(size:10)).foregroundColor(.black) }
        }.padding(6).background(Color.white,in:RoundedRectangle(cornerRadius:12))
            .onAppear { image = ConfigurationQR.image(text) }
            .onChange(of:text) { image = ConfigurationQR.image($0) }
            .accessibilityLabel("当前代理配置二维码").accessibilityIdentifier("configuration-qr")
    }
}

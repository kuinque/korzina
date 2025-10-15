import UIKit

extension UIColor {
    
    
    static let firstMC = UIColor(hex: "#FFC6DA")
    static let secondMC = UIColor(hex: "#D1E760")
    static let primaryColor = UIColor(hex: "#3B9255")
    static let barColor = UIColor(hex: "#FFFCF2")
    
    static let unselect = UIColor(hex: "#9CA3AF")
    static let locColor = UIColor(hex: "#276A3F")
    
    
    
    convenience init?(hex: String, alpha: CGFloat = 1.0) {
        var cleanedHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanedHex = cleanedHex.hasPrefix("#") ? String(cleanedHex.dropFirst()) : cleanedHex
        
        guard cleanedHex.count == 6 || cleanedHex.count == 8 else { return nil }
            
        var hexValue: UInt64 = 0
        Scanner(string: cleanedHex).scanHexInt64(&hexValue)
            
        let hasAlpha = cleanedHex.count == 8
        let extractedAlpha = hasAlpha ? CGFloat((hexValue & 0xFF000000) >> 24) / 255.0 : alpha
        let finalAlpha = hasAlpha ? extractedAlpha : alpha
            
        let red = CGFloat((hexValue & 0x00FF0000) >> 16) / 255.0
        let green = CGFloat((hexValue & 0x0000FF00) >> 8) / 255.0
        let blue = CGFloat(hexValue & 0x000000FF) / 255.0
            
        self.init(red: red, green: green, blue: blue, alpha: finalAlpha)
     }
    
   
    
    func withReducedSaturation(_ factor: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        // Получаем HSB-компоненты
        getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
    
        let newSaturation = saturation * factor
        

        return UIColor(hue: hue, saturation: newSaturation, brightness: brightness, alpha: alpha)
    }
}

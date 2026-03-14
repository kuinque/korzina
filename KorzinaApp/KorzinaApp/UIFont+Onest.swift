import UIKit

extension UIFont {
    /// Основной шрифт приложения - Onest
    static func onest(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        // Пробуем разные варианты имени шрифта
        let fontNames = ["Onest-Regular", "Onest", "Onest Regular"]
        for fontName in fontNames {
            if let onestFont = UIFont(name: fontName, size: size) {
                return onestFont
            }
        }
        // Fallback на системный шрифт, если Onest не загрузился
        return UIFont.systemFont(ofSize: size, weight: weight)
    }
    
    /// Удобные методы для разных размеров и весов
    static func onestRegular(size: CGFloat) -> UIFont {
        return onest(size: size, weight: .regular)
    }
    
    static func onestMedium(size: CGFloat) -> UIFont {
        // Пробуем загрузить Onest-Medium напрямую
        let fontNames = ["Onest-Medium", "Onest Medium"]
        for fontName in fontNames {
            if let onestFont = UIFont(name: fontName, size: size) {
                return onestFont
            }
        }
        // Fallback на обычный Onest или системный шрифт
        return onest(size: size, weight: .medium)
    }
    
    static func onestSemibold(size: CGFloat) -> UIFont {
        // Пробуем загрузить Onest-SemiBold напрямую
        let fontNames = ["Onest-SemiBold", "Onest SemiBold", "Onest-SemiBold"]
        for fontName in fontNames {
            if let onestFont = UIFont(name: fontName, size: size) {
                return onestFont
            }
        }
        // Fallback на обычный Onest или системный шрифт
        return onest(size: size, weight: .semibold)
    }
    
    static func onestBold(size: CGFloat) -> UIFont {
        return onest(size: size, weight: .bold)
    }
}


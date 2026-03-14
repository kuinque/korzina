import UIKit

/// Design tokens для точного соответствия дизайну Figma
/// Все значения в точках (points) - iOS автоматически конвертирует их в пиксели на @2x/@3x экранах
struct DesignTokens {
    
    // MARK: - Spacing (Отступы)
    struct Spacing {
        /// 4pt - минимальный отступ
        static let xs: CGFloat = 4
        
        /// 8pt - маленький отступ
        static let sm: CGFloat = 8
        
        /// 12pt - средний отступ
        static let md: CGFloat = 12
        
        /// 16pt - стандартный отступ
        static let lg: CGFloat = 16
        
        /// 20pt - большой отступ
        static let xl: CGFloat = 20
        
        /// 24pt - очень большой отступ
        static let xxl: CGFloat = 24
        
        /// 32pt - экстра большой отступ
        static let xxxl: CGFloat = 32
        
        /// 40pt - максимальный отступ
        static let huge: CGFloat = 40
        
        // Специфичные отступы из Figma (если отличаются от стандартных)
        /// Отступ для заголовков
        static let titleTop: CGFloat = 16
        
        /// Отступ для адреса под заголовком
        static let addressTop: CGFloat = 4
        
        /// Отступ для поисковой строки
        static let searchBarTop: CGFloat = 12
        
        /// Отступ для ячеек магазинов
        static let storeCellPadding: CGFloat = 4
        
        /// Вертикальный отступ между рядами магазинов
        static let storeRowSpacing: CGFloat = 20
        
        /// Горизонтальный отступ между ячейками
        static let storeCellSpacing: CGFloat = 4
    }
    
    // MARK: - Sizes (Размеры)
    struct Sizes {
        /// Размер иконок
        struct Icon {
            static let xs: CGFloat = 12
            static let sm: CGFloat = 16
            static let md: CGFloat = 20
            static let lg: CGFloat = 24
            static let xl: CGFloat = 32
        }
        
        /// Размеры кнопок
        struct Button {
            static let height: CGFloat = 44
            static let heightSmall: CGFloat = 36
            static let heightLarge: CGFloat = 56
        }
        
        /// Размеры ячеек магазинов
        struct StoreCell {
            static let height: CGFloat = 150
            static let logoContainerWidth: CGFloat = 160
            static let logoContainerHeight: CGFloat = 100
            static let cornerRadius: CGFloat = 12
            static let logoCornerRadius: CGFloat = 20
        }
        
        /// Размеры поисковой строки
        struct SearchBar {
            static let height: CGFloat = 44
        }
        
        /// Размеры шрифтов (используются через UIFont, но здесь для справки)
        struct Font {
            static let title: CGFloat = 30
            static let body: CGFloat = 16
            static let caption: CGFloat = 14
            static let largeTitle: CGFloat = 48
        }
    }
    
    // MARK: - Corner Radius (Скругления)
    struct CornerRadius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 20
        static let round: CGFloat = 999 // Для полностью круглых элементов
    }
    
    // MARK: - Screen Margins (Отступы от краев экрана)
    struct ScreenMargins {
        /// Стандартный горизонтальный отступ от краев экрана
        static let horizontal: CGFloat = 16
        
        /// Стандартный вертикальный отступ
        static let vertical: CGFloat = 16
        
        /// Отступ для safe area
        static let safeAreaTop: CGFloat = 0
    }
    
    // MARK: - Helper Methods
    
    /// Конвертирует значение из Figma (в пикселях) в точки iOS
    /// В большинстве случаев 1px Figma = 1pt iOS, но можно использовать для масштабирования
    /// - Parameter figmaPixels: Значение в пикселях из Figma
    /// - Returns: Значение в точках для iOS
    static func fromFigma(_ figmaPixels: CGFloat) -> CGFloat {
        // Если дизайн сделан для @1x, то 1px = 1pt
        // Если дизайн сделан для @2x, то нужно делить на 2
        // По умолчанию предполагаем, что Figma использует @1x значения
        return figmaPixels
    }
    
    /// Конвертирует значение из Figma для @2x дизайна
    /// - Parameter figmaPixels: Значение в пикселях из Figma (@2x)
    /// - Returns: Значение в точках для iOS
    static func fromFigma2x(_ figmaPixels: CGFloat) -> CGFloat {
        return figmaPixels / 2.0
    }
    
    /// Конвертирует значение из Figma для @3x дизайна
    /// - Parameter figmaPixels: Значение в пикселях из Figma (@3x)
    /// - Returns: Значение в точках для iOS
    static func fromFigma3x(_ figmaPixels: CGFloat) -> CGFloat {
        return figmaPixels / 3.0
    }
}

// MARK: - Convenience Extensions
extension CGFloat {
    /// Быстрый доступ к стандартным отступам
    var spacing: CGFloat {
        switch self {
        case 4: return DesignTokens.Spacing.xs
        case 8: return DesignTokens.Spacing.sm
        case 12: return DesignTokens.Spacing.md
        case 16: return DesignTokens.Spacing.lg
        case 20: return DesignTokens.Spacing.xl
        case 24: return DesignTokens.Spacing.xxl
        case 32: return DesignTokens.Spacing.xxxl
        case 40: return DesignTokens.Spacing.huge
        default: return self
        }
    }
}


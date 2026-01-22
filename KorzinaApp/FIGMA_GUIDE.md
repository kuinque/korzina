# Руководство по использованию дизайна из Figma

Это руководство поможет вам точно перенести отступы и размеры из Figma в iOS приложение.

## Как работать с дизайн-токенами

### 1. Структура DesignTokens

Все значения из Figma хранятся в файле `Core/DesignTokens.swift`. Структура организована по категориям:

- **Spacing** - отступы между элементами
- **Sizes** - размеры элементов (иконки, кнопки, ячейки и т.д.)
- **CornerRadius** - скругления углов
- **ScreenMargins** - отступы от краев экрана

### 2. Как перенести значение из Figma

#### Шаг 1: Откройте Figma и выберите элемент
1. Выберите элемент в Figma
2. Посмотрите на панель справа (Properties) - там указаны все размеры и отступы

#### Шаг 2: Определите тип значения
- **Отступ (padding/margin)** → используйте `DesignTokens.Spacing.*`
- **Размер элемента** → используйте `DesignTokens.Sizes.*`
- **Скругление углов** → используйте `DesignTokens.CornerRadius.*`
- **Отступ от края экрана** → используйте `DesignTokens.ScreenMargins.*`

#### Шаг 3: Выберите подходящую константу или добавьте новую

**Если значение стандартное (4, 8, 12, 16, 20, 24, 32, 40):**
```swift
// Используйте готовые константы
view.pinLeft(to: parentView, DesignTokens.Spacing.lg) // 16pt
```

**Если значение уникальное:**
1. Добавьте новую константу в `DesignTokens.swift`:
```swift
struct Spacing {
    // ... существующие константы
    static let myCustomSpacing: CGFloat = 28 // значение из Figma
}
```

2. Используйте в коде:
```swift
view.pinTop(to: otherView, DesignTokens.Spacing.myCustomSpacing)
```

### 3. Важно: Пиксели vs Точки

**В Figma значения указаны в пикселях (px)**
**В iOS используются точки (points/pt)**

**Правило конвертации:**
- Если дизайн в Figma сделан для @1x (375x812 для iPhone X): **1px = 1pt**
- Если дизайн в Figma сделан для @2x (750x1624): **1px = 0.5pt** (нужно делить на 2)
- Если дизайн в Figma сделан для @3x (1125x2436): **1px = 0.33pt** (нужно делить на 3)

**Как узнать масштаб дизайна в Figma:**
1. Посмотрите на размеры артборда
2. iPhone X (@1x) = 375x812
3. iPhone X (@2x) = 750x1624
4. iPhone X (@3x) = 1125x2436

**Если не уверены:**
- Обычно дизайны делают для @1x, поэтому можно использовать значения напрямую
- Если видите, что значения слишком большие на реальном устройстве, используйте функции:
  - `DesignTokens.fromFigma2x(value)` - для @2x дизайна
  - `DesignTokens.fromFigma3x(value)` - для @3x дизайна

### 4. Примеры использования

#### Отступы
```swift
// Стандартный отступ слева
label.pinLeft(to: view, DesignTokens.ScreenMargins.horizontal) // 16pt

// Отступ между элементами
secondView.pinTop(to: firstView.bottomAnchor, DesignTokens.Spacing.md) // 12pt

// Кастомный отступ (если нужно добавить)
view.pinTop(to: otherView, DesignTokens.Spacing.myCustomSpacing)
```

#### Размеры
```swift
// Размер кнопки
button.setHeight(DesignTokens.Sizes.Button.height) // 44pt

// Размер иконки
iconImageView.widthAnchor.constraint(equalToConstant: DesignTokens.Sizes.Icon.sm) // 16pt

// Размер ячейки магазина
cell.setHeight(DesignTokens.Sizes.StoreCell.height) // 150pt
```

#### Скругления
```swift
// Скругление углов
view.layer.cornerRadius = DesignTokens.CornerRadius.lg // 12pt

// Полностью круглый элемент
avatarImageView.layer.cornerRadius = DesignTokens.CornerRadius.round
```

### 5. Чеклист при переносе дизайна

- [ ] Все отступы используют константы из `DesignTokens.Spacing`
- [ ] Все размеры используют константы из `DesignTokens.Sizes`
- [ ] Все скругления используют константы из `DesignTokens.CornerRadius`
- [ ] Отступы от краев экрана используют `DesignTokens.ScreenMargins`
- [ ] Нет хардкодных числовых значений (кроме 0)
- [ ] Значения соответствуют дизайну в Figma

### 6. Добавление новых значений

Если в дизайне появилось новое значение, которого нет в `DesignTokens`:

1. **Определите категорию:**
   - Отступ → `Spacing`
   - Размер → `Sizes` (с подкатегорией: Icon, Button, StoreCell и т.д.)
   - Скругление → `CornerRadius`
   - Отступ от края → `ScreenMargins`

2. **Добавьте константу:**
```swift
struct Spacing {
    // ... существующие
    static let productCardSpacing: CGFloat = 18 // новое значение из Figma
}
```

3. **Используйте в коде:**
```swift
productCard.pinTop(to: headerView, DesignTokens.Spacing.productCardSpacing)
```

### 7. Проверка соответствия дизайну

После реализации экрана:

1. **Визуальная проверка:**
   - Откройте приложение на устройстве/симуляторе
   - Откройте тот же экран в Figma
   - Сравните отступы и размеры визуально

2. **Точная проверка:**
   - Используйте инструменты разработчика (Reveal, Flipper) для измерения
   - Сравните значения с дизайном в Figma

3. **Автоматизация (опционально):**
   - Можно создать скрипт для экспорта значений из Figma
   - Использовать Figma API для автоматической синхронизации

### 8. Полезные ссылки

- [Figma iOS Design Guidelines](https://www.figma.com/community/file/748505339483365119)
- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [iOS Points vs Pixels](https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions)

---

**Важно:** Всегда используйте константы из `DesignTokens` вместо хардкодных значений. Это обеспечит:
- Единообразие дизайна
- Легкость изменений (меняете в одном месте)
- Точное соответствие Figma


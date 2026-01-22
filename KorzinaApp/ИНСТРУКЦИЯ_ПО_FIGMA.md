# Как использовать значения из Figma в проекте

## Быстрый старт

### 1. Добавьте файл DesignTokens.swift в проект Xcode

1. Откройте проект в Xcode
2. Правой кнопкой на папку `KorzinaApp` → `Add Files to "KorzinaApp"...`
3. Выберите файл `Core/DesignTokens.swift`
4. Убедитесь, что стоит галочка "Copy items if needed" и выбран правильный Target

### 2. Использование в коде

**Вместо хардкодных значений:**
```swift
// ❌ Плохо
view.pinLeft(to: parentView, 16)
label.font = UIFont.onestRegular(size: 16)
button.setHeight(44)

// ✅ Хорошо
view.pinLeft(to: parentView, DesignTokens.ScreenMargins.horizontal)
label.font = UIFont.onestRegular(size: DesignTokens.Sizes.Font.body)
button.setHeight(DesignTokens.Sizes.Button.height)
```

### 3. Как добавить новое значение из Figma

**Пример:** В Figma у элемента отступ 28px

1. Откройте `Core/DesignTokens.swift`
2. Добавьте константу в нужную категорию:
```swift
struct Spacing {
    // ... существующие значения
    static let mySpacing: CGFloat = 28 // значение из Figma
}
```

3. Используйте в коде:
```swift
view.pinTop(to: otherView, DesignTokens.Spacing.mySpacing)
```

### 4. Важно про пиксели и точки

- **Figma показывает значения в пикселях (px)**
- **iOS использует точки (points/pt)**

**Обычно:** Если дизайн сделан для iPhone X (@1x), то 1px = 1pt (можно использовать напрямую)

**Если значения кажутся слишком большими:**
- Дизайн может быть для @2x → используйте `DesignTokens.fromFigma2x(value)`
- Дизайн может быть для @3x → используйте `DesignTokens.fromFigma3x(value)`

### 5. Доступные константы

#### Отступы (Spacing)
- `DesignTokens.Spacing.xs` = 4pt
- `DesignTokens.Spacing.sm` = 8pt
- `DesignTokens.Spacing.md` = 12pt
- `DesignTokens.Spacing.lg` = 16pt
- `DesignTokens.Spacing.xl` = 20pt
- `DesignTokens.Spacing.xxl` = 24pt
- `DesignTokens.Spacing.xxxl` = 32pt
- `DesignTokens.Spacing.huge` = 40pt

#### Размеры (Sizes)
- `DesignTokens.Sizes.Icon.sm` = 16pt
- `DesignTokens.Sizes.Button.height` = 44pt
- `DesignTokens.Sizes.StoreCell.height` = 150pt
- И другие...

#### Скругления (CornerRadius)
- `DesignTokens.CornerRadius.sm` = 4pt
- `DesignTokens.CornerRadius.md` = 8pt
- `DesignTokens.CornerRadius.lg` = 12pt
- И другие...

#### Отступы от краев (ScreenMargins)
- `DesignTokens.ScreenMargins.horizontal` = 16pt

### 6. Пример обновленного кода

Файл `MainView.swift` уже обновлен и использует константы из `DesignTokens`. Посмотрите на него как на пример.

### 7. Чеклист

При работе с новым экраном:
- [ ] Все отступы используют `DesignTokens.Spacing.*`
- [ ] Все размеры используют `DesignTokens.Sizes.*`
- [ ] Все скругления используют `DesignTokens.CornerRadius.*`
- [ ] Нет хардкодных чисел (кроме 0)

---

**Вопросы?** Смотрите подробное руководство в `FIGMA_GUIDE.md`


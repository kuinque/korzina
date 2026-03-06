"""
Нормализатор названий товаров для единообразного сравнения.

Приводит названия к единому стандарту:
- Конвертация единиц измерения (0.9л → 900мл, 1.5кг → 1500г)
- Раскрытие сокращений (пастер. → пастеризованное)
- Замена синонимов на каноничные формы
- Очистка от шума (маркировки, спецсимволы)
"""
import re
from typing import Optional


# ---------------------------------------------------------------------------
#  Сокращения → полная форма
# ---------------------------------------------------------------------------
ABBREVIATIONS: dict[str, str] = {
    # Молочная продукция
    "пастер.": "пастеризованное",
    "пастериз.": "пастеризованное",
    "ультрапаст.": "ультрапастеризованное",
    "ультрапастер.": "ультрапастеризованное",
    "стерил.": "стерилизованное",
    "стерилиз.": "стерилизованное",
    "обезжир.": "обезжиренное",
    "нежирн.": "нежирный",
    "безлакт.": "безлактозное",
    "кисломол.": "кисломолочный",
    "сливоч.": "сливочное",
    "сгущ.": "сгущённое",
    "топл.": "топлёное",
    "плав.": "плавленый",

    # Единицы / упаковка
    "шт.": "шт",
    "упак.": "упаковка",
    "уп.": "упаковка",
    "бут.": "бутылка",
    "пак.": "пакет",
    "т/пак": "тетрапак",
    "т/п": "тетрапак",

    # Качество / сорт
    "высш.": "высший",
    "в/с": "высший сорт",
    "1/с": "первый сорт",
    "в/сорт": "высший сорт",

    # Общее
    "жирн.": "жирность",
    "м.д.ж.": "жирность",
    "мдж": "жирность",
    "б/к": "бескостный",
    "б/ш": "бесшкурный",
    "с/м": "свежемороженый",
    "зам.": "замороженный",
    "заморож.": "замороженный",
    "охл.": "охлаждённый",
    "охлажд.": "охлаждённый",
    "копч.": "копчёный",
    "варен.": "варёный",
    "вар.": "варёный",
    "п/к": "полукопчёный",
    "в/к": "варёно-копчёный",
    "с/к": "сырокопчёный",

    # Мясо
    "филе кур.": "филе куриное",
    "кур.": "куриный",
    "свин.": "свиной",
    "говяд.": "говяжий",
    "говяж.": "говяжий",
    "индюш.": "индюшиный",

    # Хлеб / выпечка
    "нарез.": "нарезанный",
    "подов.": "подовый",

    # Прочее
    "натур.": "натуральный",
    "фильтр.": "фильтрованное",
    "нефильтр.": "нефильтрованное",
    "газир.": "газированный",
    "негаз.": "негазированный",
    "концентр.": "концентрированный",
}

# ---------------------------------------------------------------------------
#  Синонимы → каноничная форма
# ---------------------------------------------------------------------------
SYNONYMS: dict[str, str] = {
    # Единицы (приведение «гр» и «грамм» к «г»)
    "гр": "г",
    "грамм": "г",
    "граммов": "г",
    "миллилитров": "мл",
    "литров": "л",
    "литр": "л",
    "килограмм": "кг",
    "килограммов": "кг",

    # Продукты
    "молочко": "молоко",
    "кефирчик": "кефир",
    "творожок": "творог",
    "маслице": "масло",
    "водичка": "вода",
    "водица": "вода",
    "картофель": "картошка",
    "помидор": "томат",
    "помидоры": "томаты",

    # Жирность
    "процент": "%",
    "проц": "%",
    "проц.": "%",

    # Бренды / вариации написания
    "простоквашино": "простоквашино",
    "домик в деревне": "домик в деревне",
}

# ---------------------------------------------------------------------------
#  Маркировки для удаления
# ---------------------------------------------------------------------------
MARKINGS_TO_REMOVE: list[str] = [
    "без змж", "бзмж", "змж", "мжд",
    "гост", "ту",
    "халяль", "halal",
    "eco", "эко",
    "био", "bio",
    "organic",
    "premium", "премиум",
    "акция", "sale", "new", "новинка",
    "хит",
]

# ---------------------------------------------------------------------------
#  Regex для единиц измерения
# ---------------------------------------------------------------------------

# Литры → миллилитры:  0.9л → 900мл, 1,5 л → 1500мл
_RE_LITERS_DECIMAL = re.compile(
    r'(\d+)[.,](\d+)\s*л(?:итр(?:а|ов)?)?(?=\b|\s|$)', re.IGNORECASE
)
_RE_LITERS_WHOLE = re.compile(
    r'(?<!\d[.,])(\d+)\s*л(?:итр(?:а|ов)?)?(?=\b|\s|$)', re.IGNORECASE
)

# Килограммы → граммы:  0.5кг → 500г, 1,2 кг → 1200г
_RE_KG_DECIMAL = re.compile(
    r'(\d+)[.,](\d+)\s*кг(?=\b|\s|$)', re.IGNORECASE
)
_RE_KG_WHOLE = re.compile(
    r'(?<!\d[.,])(\d+)\s*кг(?=\b|\s|$)', re.IGNORECASE
)

# «гр» → «г»  (200гр → 200г)
_RE_GR = re.compile(r'(\d+)\s*гр(?=\b|\s|$)', re.IGNORECASE)

# Убираем пробел между числом и единицей: «200 г» → «200г», «500 мл» → «500мл»
_RE_UNIT_SPACE = re.compile(r'(\d+)\s+(г|мл|шт|л|кг)(?=\b|\s|$)', re.IGNORECASE)

# Мультиупаковки: «6х0.9л», «6x900мл», «12 x 0,33л»
_RE_MULTIPACK = re.compile(
    r'(\d+)\s*[xхXХ*]\s*', re.IGNORECASE
)

# Запятая в десятичных дробях: 3,2% → 3.2%
_RE_COMMA_DECIMAL = re.compile(r'(\d+),(\d+)')

# Проценты жирности без знака: «жирность 3.2» → «3.2%»
_RE_FAT_PERCENT = re.compile(r'(?:жирн(?:ость)?\.?\s*)(\d+(?:\.\d+)?)\s*(?:%)?', re.IGNORECASE)


def _convert_liters_decimal(match: re.Match) -> str:
    whole = int(match.group(1))
    frac_str = match.group(2)
    frac = int(frac_str)
    divisor = 10 ** len(frac_str)
    ml = int((whole + frac / divisor) * 1000)
    return f"{ml}мл"


def _convert_liters_whole(match: re.Match) -> str:
    liters = int(match.group(1))
    return f"{liters * 1000}мл"


def _convert_kg_decimal(match: re.Match) -> str:
    whole = int(match.group(1))
    frac_str = match.group(2)
    frac = int(frac_str)
    divisor = 10 ** len(frac_str)
    grams = int((whole + frac / divisor) * 1000)
    return f"{grams}г"


def _convert_kg_whole(match: re.Match) -> str:
    kg = int(match.group(1))
    return f"{kg * 1000}г"


def _convert_gr(match: re.Match) -> str:
    return f"{match.group(1)}г"


def _normalize_fat_percent(match: re.Match) -> str:
    return f"{match.group(1)}%"


class TitleNormalizer:
    """
    Нормализатор названий товаров.

    Использование:
        normalizer = TitleNormalizer()
        result = normalizer.normalize("Молоко пастер. 3,2% 0.9 л БЗМЖ")
        # → "молоко пастеризованное 3.2% 900мл"
    """

    def __init__(
        self,
        abbreviations: Optional[dict[str, str]] = None,
        synonyms: Optional[dict[str, str]] = None,
        markings: Optional[list[str]] = None,
    ):
        self._abbreviations = abbreviations or ABBREVIATIONS
        self._synonyms = synonyms or SYNONYMS
        self._markings = markings or MARKINGS_TO_REMOVE

        self._abbr_pattern = self._build_abbr_pattern(self._abbreviations)
        self._marking_patterns = self._build_marking_patterns(self._markings)
        self._synonym_pattern = self._build_synonym_pattern(self._synonyms)

    # ---- public API -------------------------------------------------------

    def normalize(self, title: str) -> str:
        """
        Полная нормализация названия товара.

        Порядок операций:
        1. lowercase
        2. Запятые в числах → точки (3,2 → 3.2)
        3. Единицы измерения → каноничные (л→мл, кг→г, гр→г)
        4. Раскрытие сокращений
        5. Удаление маркировок
        6. Замена синонимов
        7. Нормализация процентов жирности
        8. Очистка пробелов/знаков
        """
        if not title:
            return ""

        text = title.lower().strip()

        # Унифицируем кавычки и спецсимволы
        text = re.sub(r'[«»""„‟\'\']', '"', text)
        text = re.sub(r'[®™©]', '', text)

        # Запятые в числах → точки
        text = _RE_COMMA_DECIMAL.sub(r'\1.\2', text)

        # -- Единицы измерения --
        text = _RE_LITERS_DECIMAL.sub(_convert_liters_decimal, text)
        text = _RE_LITERS_WHOLE.sub(_convert_liters_whole, text)
        text = _RE_KG_DECIMAL.sub(_convert_kg_decimal, text)
        text = _RE_KG_WHOLE.sub(_convert_kg_whole, text)
        text = _RE_GR.sub(_convert_gr, text)
        text = _RE_UNIT_SPACE.sub(r'\1\2', text)

        # Мультиупаковки: нормализуем разделитель
        text = _RE_MULTIPACK.sub(r'\1x', text)

        # Сокращения → полная форма
        if self._abbr_pattern:
            text = self._abbr_pattern.sub(
                lambda m: self._abbreviations[m.group(0).lower()], text
            )

        # Удаление маркировок
        for pat in self._marking_patterns:
            text = pat.sub('', text)

        # Синонимы
        if self._synonym_pattern:
            text = self._synonym_pattern.sub(
                lambda m: self._synonyms[m.group(0).lower()], text
            )

        # Нормализация жирности: «жирность 3.2» → «3.2%»
        text = _RE_FAT_PERCENT.sub(_normalize_fat_percent, text)

        # -- Финальная очистка --
        text = re.sub(r'[-–—]', ' ', text)            # дефисы → пробелы
        text = re.sub(r'[,;:]+', ' ', text)            # знаки препинания → пробел
        text = re.sub(r'[()[\]{}]', '', text)           # скобки
        text = re.sub(r'"', '', text)                   # кавычки
        text = re.sub(r'\s+', ' ', text).strip()        # лишние пробелы

        return text

    # ---- internal helpers -------------------------------------------------

    @staticmethod
    def _build_abbr_pattern(abbreviations: dict[str, str]) -> Optional[re.Pattern]:
        if not abbreviations:
            return None
        escaped = [re.escape(k) for k in sorted(abbreviations, key=len, reverse=True)]
        return re.compile(r'(?<!\w)(' + '|'.join(escaped) + r')(?!\w)', re.IGNORECASE)

    @staticmethod
    def _build_marking_patterns(markings: list[str]) -> list[re.Pattern]:
        patterns = []
        for m in markings:
            patterns.append(
                re.compile(rf'(?<!\w){re.escape(m)}(?!\w)', re.IGNORECASE)
            )
        return patterns

    @staticmethod
    def _build_synonym_pattern(synonyms: dict[str, str]) -> Optional[re.Pattern]:
        if not synonyms:
            return None
        escaped = [re.escape(k) for k in sorted(synonyms, key=len, reverse=True)]
        return re.compile(r'(?<!\w)(' + '|'.join(escaped) + r')(?!\w)', re.IGNORECASE)


# Singleton-экземпляр для переиспользования
_default_normalizer: Optional[TitleNormalizer] = None


def get_normalizer() -> TitleNormalizer:
    """Получить экземпляр нормализатора (singleton)."""
    global _default_normalizer
    if _default_normalizer is None:
        _default_normalizer = TitleNormalizer()
    return _default_normalizer


def normalize_title(title: str) -> str:
    """Удобная функция-обёртка для быстрой нормализации."""
    return get_normalizer().normalize(title)

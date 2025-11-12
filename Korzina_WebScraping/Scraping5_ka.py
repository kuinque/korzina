import undetected_chromedriver as uc
from selenium.webdriver.common.by import By
import time
import re
import os
from typing import Optional, List
from dotenv import load_dotenv
from supabase import create_client, Client

load_dotenv()

supabase: Client = create_client(
    os.getenv("SUPABASE_URL"),
    os.getenv("SUPABASE_KEY")
)



def setup_undetected_driver():

    options = uc.ChromeOptions()

    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--start-maximized')

    driver = uc.Chrome(options=options, version_main=None)

    print(" Undetected Chrome запущен")
    return driver


def human_behavior(driver):
    time.sleep(2)

    for i in range(3):
        driver.execute_script(f"window.scrollTo(0, {(i + 1) * 400});")
        time.sleep(0.8)

    driver.execute_script("window.scrollTo(0, 0);")
    time.sleep(1)


def extract_price(driver) -> Optional[float]:

    try:
        price_meta = driver.find_element(By.CSS_SELECTOR, 'meta[itemprop="price"]')
        price_value = price_meta.get_attribute('content')
        if price_value:
            price_kopecks = float(price_value)
            print(f"    Цена (meta): {price_value}₽ = {price_kopecks} копеек")
            return price_kopecks
    except:
        pass

    try:
        rubles_elem = driver.find_element(By.CSS_SELECTOR, 'span.css-cy4ypf')
        rubles_text = rubles_elem.text.strip()
        rubles = int(re.sub(r'[^\d]', '', rubles_text))

        kopecks = 0
        try:
            kopecks_elem = driver.find_element(By.CSS_SELECTOR, 'span.css-1j4x839, span.css-w9opm3')
            kopecks_text = kopecks_elem.text.strip()
            kopecks = int(re.sub(r'[^\d]', '', kopecks_text))
        except:
            kopecks = 0

        price_kopecks = (rubles * 100 + kopecks) / 100

        print(f"     Цена: {rubles}₽ {kopecks}коп = {price_kopecks} копеек")
        print(f"        (проверка: {price_kopecks :.2f}₽)")

        return price_kopecks

    except Exception as e:
        print(f"   ️ Ошибка извлечения цены: {e}")

    return None


def extract_images(driver) -> List[str]:
    images = []

    try:
        img_elements = driver.find_elements(By.CSS_SELECTOR, 'img[itemprop="image"], img.chakra-image')

        for img in img_elements:
            src = img.get_attribute('src')
            if src and ('x5static' in src or '5ka.ru' in src):
                if src.startswith('//'):
                    src = 'https:' + src
                if src not in images:
                    images.append(src)
                    if len(images) >= 5:
                        break
    except:
        pass

    return images


def parse_product(driver, url: str, category_name: str = None) -> Optional[dict]:
    print(f"\n Парсинг: {url}")

    try:
        driver.get(url)
        print("    Ожидание 8 секунд...")
        time.sleep(8)

        human_behavior(driver)

        if 'Forbidden' in driver.title or 'Forbidden' in driver.page_source[:1000]:
            print("    Forbidden (доступ запрещён)")
            return None

        title = None
        try:
            title = driver.find_element(By.CSS_SELECTOR, 'h1').text.strip()
            if title:
                print(f"    Название: {title}")
        except:
            print(f"    Название не найдено")

        price = extract_price(driver)
        if not price:
            print(f"    Цена не найдена")

        images = extract_images(driver)
        print(f"    Изображений: {len(images)}")

        category = category_name

        if not category:
            try:
                breadcrumbs = driver.find_elements(By.CSS_SELECTOR, 'a[href*="/catalog/"]')
                if breadcrumbs:
                    category = breadcrumbs[-1].text.strip()
                    print(f"    Категория (breadcrumbs): {category}")
            except:
                pass
        else:
            print(f"    Категория: {category}")

        description = None

        desc_selectors = [
            '[itemprop="description"]',
            '.product-description',
            '[class*="description"]',
            '[class="css-ampwp8"]',
            '[class="css-1tocvoq"]',
            '.chakra-text',
            '[class="css-w3vte1"]',
            'div[class*="css-"] p'
        ]

        description = None

        for selector in desc_selectors:
            try:
                desc_elem = driver.find_element(By.CSS_SELECTOR, selector)
                desc_text = desc_elem.text.strip()

                # Дополнительная защита: пропускаем текст, если начинается со "Состав"
                if desc_text.lower().startswith("Состав"):
                    continue

                if desc_text and len(desc_text) > 20:
                    description = desc_text
                    print(f"    Описание: {description[:1000]}...")
                    break
            except:
                continue

        if not description:
            print(f"   ️  Описание не найдено")

        product = {
            'title': title,
            'price': price,
            'currency': 'RUB',
            'description': description,
            'images': images,
            'category_id': None,
            'category_name': category,
            'tags': None,
            'seller_name': 'Пятёрочка',
        }

        return product

    except Exception as e:
        print(f"    Ошибка: {e}")
        return None

def parse_category(category_url: str, max_products: int = 5):
    print(" ПАРСИНГ КАТЕГОРИИ С UNDETECTED-CHROMEDRIVER")
    print(f"URL: {category_url}")
    print(f"Максимум товаров: {max_products}")

    driver = None

    try:
        driver = setup_undetected_driver()

        print("1️⃣ Открытие главной страницы...")
        driver.get("https://5ka.ru/")
        print("    Ждём 5 секунд...")
        time.sleep(5)

        driver.execute_script("window.scrollTo(0, 500);")
        time.sleep(1)
        driver.execute_script("window.scrollTo(0, 0);")
        time.sleep(2)

        print("2️⃣ Открытие категории...")
        driver.get(category_url)
        print("   ⏳ Ждём 15 секунд для полной загрузки...")
        time.sleep(15)

        try:
            category_elem = driver.find_element(By.CSS_SELECTOR, 'h2[data-qa="catalog-category-title"]')
            category_name = category_elem.text.strip()
            print(f"    Категория: {category_name}")
        except Exception as e:
            category_name = "Неизвестная категория"
            print(f"   ️ Не удалось определить категорию: {e}")

        page_source = driver.page_source
        if 'Forbidden' in driver.title or 'Forbidden' in page_source[:1000]:
            print("    FORBIDDEN! Сайт заблокировал доступ к категории")
            print("    Используйте прямые ссылки на товары (test_direct_urls)")

            # Сохраняем для анализа
            with open('forbidden_debug.html', 'w', encoding='utf-8') as f:
                f.write(page_source)
            print("    HTML сохранён в forbidden_debug.html")

            driver.quit()
            return []
        print("3️⃣ Прокрутка до конца страницы (lazy loading)...")

        last_count = 0
        no_change_count = 0

        while no_change_count < 3:  # Останавливаемся если 3 раза подряд ничего не загрузилось
            # Прокручиваем в конец
            driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
            time.sleep(3)  # Даём время на загрузку

            # Считаем сколько товаров сейчас на странице
            links = driver.find_elements(By.CSS_SELECTOR, 'a[href*="/product/"]')
            current_count = len(links)


            # Если количество не изменилось — увеличиваем счётчик
            if current_count == last_count:
                no_change_count += 1
            else:
                no_change_count = 0  # Сбрасываем если загрузились новые

            last_count = current_count

        print(f"   ✅ Прокрутка завершена. Всего товаров: {last_count}")

        driver.execute_script("window.scrollTo(0, 0);")
        time.sleep(3)

        print("4️⃣ Поиск товаров...\n")

        product_links = []

        all_links = driver.find_elements(By.TAG_NAME, 'a')

        for link in all_links:
            href = link.get_attribute('href')
            if href and '/product/' in href and '5ka.ru' in href:
                if href not in product_links:
                    product_links.append(href)
                    print(f"   ✓ {href}")
                    if len(product_links) >= max_products:
                        break

        print(f"\n    Найдено товаров: {len(product_links)}\n")

        if len(product_links) == 0:
            print("    Товары не найдены!")
            print("    Попробуйте другой URL категории")
            driver.quit()
            return []

        all_products = []

        for i, url in enumerate(product_links, 1):
            print(f"ТОВАР {i}/{len(product_links)}")

            product = parse_product(driver, url, category_name)

            if product and product['title']:
                save_to_supabase([product])  # Передаём список с одним товаром
                print(f"   💾 Товар сохранён в БД")

            if i < len(product_links):
                print(f"\n Пауза 3 сек...")
                time.sleep(3)

        # ИТОГИ
        print(f" ИТОГИ")
        print(f"Всего URL: {len(product_links)}")
        print(f"Успешно: {len(all_products)}")
        print(f"Ошибок: {len(product_links) - len(all_products)}")

        #if all_products:
         #   save_to_supabase(all_products)

        return all_products

    except Exception as e:
        print(f" Критическая ошибка: {e}")
        import traceback
        traceback.print_exc()
        return []

    finally:
        if driver:
            print("\n️ Пауза 5 сек перед закрытием...")
            time.sleep(5)
            driver.quit()


def parse_direct_urls(product_urls: List[str], category_name: str = None):
    print(" ПАРСИНГ ПО ПРЯМЫМ ССЫЛКАМ")
    print(f"Товаров: {len(product_urls)}")
    if category_name:
        print(f"Категория: {category_name}")

    driver = None

    try:
        driver = setup_undetected_driver()

        print(" Открытие главной страницы...")
        driver.get("https://5ka.ru/")
        time.sleep(5)

        all_products = []

        for i, url in enumerate(product_urls, 1):
            print(f"\n{'=' * 70}")
            print(f"ТОВАР {i}/{len(product_urls)}")
            print(f"{'=' * 70}")

            product = parse_product(driver, url, category_name=category_name)

            if product and product['title']:
                all_products.append(product)

            if i < len(product_urls):
                time.sleep(3)

        # Итоги
        print(f" РЕЗУЛЬТАТЫ")
        print(f"Всего: {len(product_urls)}")
        print(f"Успешно: {len(all_products)}")

        # Сохранение
        if all_products:
            save_to_supabase(all_products)

        return all_products

    finally:
        if driver:
            time.sleep(3)
            driver.quit()


def save_to_supabase(products: List[dict]) -> bool:
    valid = [p for p in products if p.get('title') and p.get('price')]
    if not valid:
        print("️ Нет данных для сохранения")
        return False
    try:
        print(f" Сохранение {len(valid)} товаров в БД...")
        supabase.table('offers').insert(valid).execute()
        print(f" Сохранено!")
        return True
    except Exception as e:
        print(f" Ошибка БД: {e}")
        return False



def test_category():
    category_url = "https://5ka.ru/catalog/khleb-i-vypechka--251C12888/"
    parse_category(category_url, max_products=200)


def test_direct_urls():
    category = "Снеки и чипсы"
    urls = [
        "https://5ka.ru/product/chipsy-kartofelnye-russkaya-kartoshka-so-vkusom-sm--4035779/"
    ]
    parse_direct_urls(urls, category_name=category)


if __name__ == "__main__":
    print("UNDETECTED-CHROMEDRIVER")
    print("1. test_category()     - Категория")
    print("2. test_direct_urls()  - Прямые ссылки")

    test_category()
    #test_direct_urls()
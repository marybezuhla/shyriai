# Приватність · Ширяй

**Коротко:** Ширяй нічого не надсилає й нічого не збирає. Інтернету він не має взагалі: у застосунку немає жодного дозволу, що стосується людини чи телефона (лише один внутрішній технічний дозвіл бібліотеки AndroidX), і збірка зупиняється, якщо зʼявиться інший.

## Які дані є

Один маленький файл на телефоні (до 64 КБ) у власній папці застосунку. У ньому:

- обраний режим, тема, мова й розмір тексту;
- чи ввімкнено батьківський замок;
- які уроки й місії пройдено, окремо для кожного режиму;
- яку камеру обрано для кожної машини.

Імені, віку, контактів, місця, фото, звуку чи будь-яких ідентифікаторів немає.

## Хто їх бачить

- **Лише цей телефон.** Інші застосунки не мають доступу до папки Ширяя.
- **Хмарної копії немає:** резервне копіювання Android вимкнено (`allowBackup="false"`), CI це перевіряє.
- **Перенесення на новий телефон:** на Android 12 і новіших пряме перенесення з телефона на телефон може скопіювати цей файл: рушій Godot поки не дає це вимкнути. У файлі лише налаштування й прогрес.
- **GitHub** бачить звичайні дані про завантаження (адресу, з якої завантажено APK), як і будь-який сайт. Сам застосунок до GitHub не звертається.

## Як усе стерти

- **Налаштування → Прогрес → «Почати спочатку в режимі …»**: стирає уроки й місії поточного режиму.
- **Налаштування → Прогрес → «Стерти всі дані»**: стирає прогрес усіх режимів і всі налаштування.
- Обидві дії можна одразу «Повернути».
- **Видалення застосунку** прибирає файл повністю. Після цього прогрес починається заново.

---

# Privacy · Shyriai

**In short:** Shyriai sends nothing and collects nothing. It has no internet at all: the app has no permission that concerns you or your phone (only one internal technical permission of the AndroidX library), and the build stops if any other appears.

## What data there is

One small file on the phone (up to 64 KB), in the app's own folder. It holds:

- the chosen mode, theme, language and text size;
- whether the grown-ups' lock is on;
- which lessons and missions are done, per mode;
- which camera is chosen for each vehicle.

No name, age, contacts, location, photos, sound or identifiers of any kind.

## Who can see it

- **Only this phone.** Other apps cannot reach Shyriai's folder.
- **No cloud copy:** Android backup is off (`allowBackup="false"`), and CI checks it.
- **Moving to a new phone:** on Android 12 and newer, direct phone-to-phone transfer may copy this file: the Godot engine does not yet let it be switched off. The file holds only settings and progress.
- **GitHub** sees the usual download data (the address the APK was downloaded from), like any website. The app itself never contacts GitHub.

## How to erase it

- **Settings → Progress → "Start over in … mode"** erases the lessons and missions of the current mode.
- **Settings → Progress → "Erase all data"** erases progress in every mode and all settings.
- Both can be undone straight away.
- **Uninstalling the app** removes the file completely. After that, progress starts again.

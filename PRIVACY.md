# Приватність · Ширяй

**Коротко:** Ширяй нічого не надсилає й нічого не збирає. Інтернету він не має взагалі: у застосунку немає жодного дозволу Android, і збірка зупиняється, якщо дозвіл зʼявиться.

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
- **GitHub** бачить звичайні дані про завантаження (адресу, з якої завантажено APK), як і будь-який сайт. Сам застосунок до GitHub не звертається.

## Як усе стерти

- **Налаштування → Прогрес → «Почати спочатку в режимі …»**: стирає уроки й місії поточного режиму.
- **Налаштування → Прогрес → «Стерти всі дані»**: стирає прогрес усіх режимів і всі налаштування.
- Обидві дії можна одразу «Повернути».
- **Видалення застосунку** прибирає файл повністю. Після цього, як і на новому телефоні, прогрес починається заново.

---

# Privacy · Shyriai

**In short:** Shyriai sends nothing and collects nothing. It has no internet at all: the app has no Android permissions, and the build stops if one appears.

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
- **GitHub** sees the usual download data (the address the APK was downloaded from), like any website. The app itself never contacts GitHub.

## How to erase it

- **Settings → Progress → "Start over in … mode"** erases the lessons and missions of the current mode.
- **Settings → Progress → "Erase all data"** erases progress in every mode and all settings.
- Both can be undone straight away.
- **Uninstalling the app** removes the file completely. After that, as on a new phone, progress starts again.

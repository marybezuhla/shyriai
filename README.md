# Ширяй · Shyriai

Офлайн-тренажер пілотування дронів і наземних роботів для Android. Для дітей і дорослих. Українська та англійська. Безкоштовно, без реклами, акаунтів та інтернету. Потрібен Android 7 або новіший і OpenGL ES 3.0.

> Відгуки й помилки: [Issues](../../issues).

## Особливості

- 🛸 **Шість курсів.** Камерний дрон, FPV-дрон, наземний робот (НРК), літак, аерозйомка й пошук, перехоплення навчальної мішені.
- 🧒 **Три режими, у кожного свій прогрес.** Дитячий: розбитися неможливо, ігрові завдання, світла тема й батьківський замок. Простий: дрон допомагає, є підказки. Дорослий: інерція, вітер, батарея, FPV аж до Acro.
- 🎯 **Уроки й місії.** Від простого до складного, з чіткими умовами зарахування. Місії рятувальні й навчальні: пошук у полі, доставка, евакуація, знімки після повені. Без бойових подробиць.
- 🎮 **Керування.** Екранні стіки, геймпад або справжній пульт через USB; Mode 2 чи Mode 1. Три камери: «З землі», «За дроном» і з самої машини.
- 📘 **Підручник пілота.** 10 розділів із малюнками й питаннями «Перевір себе», словничок на 40 слів і дитяча «Книжечка пілота».
- 🌻 **Соняшники, посвідчення й відзнаки.** До трьох соняшників за урок, посвідчення пілота за курс, 14 відзнак і загальний підсумок навчання.
- 🌫️ **Погода й вільний політ.** Вітер, туман, зима, вечір; політ без завдання.
- 🎨 **Теми й текст.** Світлі й темні теми, три розміри тексту.
- 🔊 **Звук** моторів і сигналів створюється в коді, вимикається в налаштуваннях.

## Встановлення

- 📲 **Напряму:** завантажте файл `.apk` звідси: [github.com/marybezuhla/shyriai/releases/latest](https://github.com/marybezuhla/shyriai/releases/latest).
- 🔄 **З оновленнями:** скористайтеся безкоштовним застосунком Obtainium. Його можна встановити з F-Droid: [f-droid.org/packages/dev.imranr.obtainium.fdroid](https://f-droid.org/packages/dev.imranr.obtainium.fdroid) (F-Droid — це безкоштовний каталог застосунків для Android, щось на зразок Google Play. Усі застосунки там мають відкритий код, без реклами й стеження, а перед публікацією їх перевіряють і збирають самі укладачі каталогу). В Obtainium натисніть «Додати застосунок» і вставте посилання `github.com/marybezuhla/shyriai`.

## Прозорість

- **Дозволи:** жодних, що стосуються людини чи телефону; є лише внутрішній технічний дозвіл бібліотеки AndroidX. Збірка зупиняється, якщо з'являється будь-який інший дозвіл, а надто дозвіл на інтернет.
- **Дані:** налаштування й прогрес лише на телефоні, в одному маленькому файлі; хмарну копію вимкнено. Пряме перенесення на новий телефон (Android 12+) вимкнути не можна, тож тоді файл може перенестися.
- **Підпис:** справжній APK підписано сертифікатом із відбитком SHA-256 `BF:06:A3:A2:27:BB:10:32:DC:B1:41:C8:92:93:85:80:72:A5:A0:0A:F2:BF:70:39:4A:44:9E:B3:25:FF:2E:1F`. Перевірити без жодного застосунку: `apksigner verify --print-certs shyriai-<версія>.apk` (з Android SDK Build Tools) має показати саме цей відбиток (малими літерами й без двокрапок).
- **Збірка:** APK збирається з цього коду в GitHub Actions і підписується лише після схвалення авторки. Godot і його шаблони звіряються за SHA-512.
- **Доступність:** текст можна збільшити; програми читання екрана (TalkBack) поки не підтримуються: рушій Godot на Android їм нічого не передає.
- **Як створено:** код написано за допомогою ШІ (Claude, Anthropic) під керівництвом і з тестуванням авторки.
- **Застереження:** тренажер не замінює занять з інструктором і не дає права на польоти. Перед справжнім польотом дізнайтеся, де і як дозволено літати.

Godot 4.7 · GDScript. Ліцензія GNU GPL версії 3 або (на ваш вибір) будь-якої пізнішої (GPL-3.0-or-later). Бібліотеки й джерела — [NOTICE.md](NOTICE.md), приватність — [PRIVACY.md](PRIVACY.md), вразливості — [SECURITY.md](SECURITY.md).

---

# Shyriai · English

An offline trainer for piloting drones and ground robots, for Android. For kids and adults. Ukrainian and English. Free, no ads, no accounts, no internet. Requires Android 7 or newer and OpenGL ES 3.0.

> Feedback and bugs: [Issues](../../issues).

## Features

- 🛸 **Six courses.** Camera drone, FPV drone, ground robot (UGV), plane, aerial survey and search, intercepting a training target.
- 🧒 **Three modes, each with its own progress.** Kids: crashing is impossible, playful tasks, a light look and a grown-ups' lock. Simple: the drone helps, with hints. Adult: inertia, wind, battery, FPV up to Acro.
- 🎯 **Lessons and missions.** From easy to hard, with clear pass conditions. Missions are rescue and training only: a search in a field, delivery, evacuation, pictures after a flood. No combat details.
- 🎮 **Controls.** On-screen sticks, a gamepad or a real radio over USB; Mode 2 or Mode 1. Three cameras: from the ground, behind the drone and from the craft itself.
- 📘 **The pilot's book.** 10 chapters with drawings and "Check yourself" questions, a glossary of 40 words and a little book for kids.
- 🌻 **Sunflowers, licences and badges.** Up to three sunflowers per lesson, a pilot's licence per course, 14 badges and the overall progress.
- 🌫️ **Weather and free flight.** Wind, fog, winter, evening; flying with no task.
- 🎨 **Looks and text.** Light and dark themes, three text sizes.
- 🔊 **Sound** of motors and signals is made in code and can be turned off in settings.

## Install

- 📲 **Directly:** download the `.apk` file from [github.com/marybezuhla/shyriai/releases/latest](https://github.com/marybezuhla/shyriai/releases/latest).
- 🔄 **With updates:** use the free app Obtainium, available on F-Droid: [f-droid.org/packages/dev.imranr.obtainium.fdroid](https://f-droid.org/packages/dev.imranr.obtainium.fdroid) (F-Droid is a free catalogue of Android apps, a bit like Google Play: every app there is open source, without ads or tracking, and is checked and built by the catalogue's maintainers before publishing). In Obtainium tap "Add App" and paste `github.com/marybezuhla/shyriai`.

## Transparency

- **Permissions:** none that concern you or your phone; only an internal technical permission of the AndroidX library. The build stops if any other permission appears, internet above all.
- **Data:** settings and progress stay on the phone, in one small file; cloud backup is off. Direct transfer to a new phone (Android 12+) cannot be switched off, so the file may be copied then.
- **Signature:** the genuine APK is signed with a certificate whose SHA-256 fingerprint is `BF:06:A3:A2:27:BB:10:32:DC:B1:41:C8:92:93:85:80:72:A5:A0:0A:F2:BF:70:39:4A:44:9E:B3:25:FF:2E:1F`. To check it without any app: `apksigner verify --print-certs shyriai-<version>.apk` (from the Android SDK Build Tools) must show this fingerprint (in lower case, without the colons).
- **Build:** the APK is built from this code in GitHub Actions and signed only after the author's approval. Godot and its templates are checked by SHA-512.
- **Accessibility:** text can be made larger; screen readers (TalkBack) are not supported yet: the Godot engine passes them nothing on Android.
- **How it was made:** the code was written with AI (Claude, Anthropic), directed and tested by the author.
- **Disclaimer:** the trainer does not replace lessons with an instructor and gives no right to fly. Before a real flight, find out where and how flying is allowed.

Godot 4.7 · GDScript. Licence: GNU GPL version 3 or (at your option) any later version (GPL-3.0-or-later). Libraries and sources: [NOTICE.md](NOTICE.md), privacy: [PRIVACY.md](PRIVACY.md), vulnerabilities: [SECURITY.md](SECURITY.md).

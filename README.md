# Ширяй · Shyriai

Тренажер пілотування для Android: камерні й FPV-дрони та наземні роботизовані комплекси (НРК). Для дітей і дорослих. Українська та англійська. Безкоштовно, без реклами й акаунтів, без інтернету. Потрібен Android 7 або новіший і OpenGL ES 3.0.

> **Тестова версія.** Є всі три машини: камерний дрон (8 уроків, 2 місії), FPV-дрон (6 уроків, 4 місії) і НРК (5 уроків, 4 місії), курс аерозйомки й розвідки (5 уроків, 3 місії; для дітей 3 уроки й фотоальбом), курс перехоплення (5 уроків, 3 місії; для дітей метелики), а також картки теорії. До версії 1.0 лишилися нові місії й питання до теорії, а потім незалежний аудит.

## Задум

- 🧒 **Три режими, у кожного свій прогрес.** Дитячий: розбитися неможливо, ігрові завдання, майже без тексту. Простий: дрон допомагає вирівнюватися, є підказки. Дорослий: повна фізика з інерцією, вітром і батареєю.
- 🛸 **Три машини.** Камерний дрон, який сам зависає. FPV-дрон з режимами Angle, Horizon і Acro. НРК з гусеничним керуванням, рельєфом і затримкою відео.
- 👪 **Дитячий режим** має свою світлу тему «Ранок» і більший текст. За бажанням є батьківський замок: щоб вийти з дитячого режиму чи відкрити налаштування, треба розв'язати приклад.
- 👀 **Три камери.** «З землі»: як пілот, що стоїть із пультом, так вчаться літати по-справжньому. «За дроном»: легше для початку. «Камера»: вигляд з самого дрона, для пошуку й огляду.
- 🎯 **Навчання й місії.** Уроки від простого до складного з чіткими умовами зарахування. Місії — ті самі навички в сюжеті: пошук у полі, траса з воротами, доставка вантажу, евакуація пораненого. Для дітей — кошеня на даху, обручі, посилка бабусі.
- 🎮 **Керування.** Екранні стіки, геймпад і справжній пульт через USB, щоб моторна памʼять переносилася на реальний дрон. Розкладка Mode 2 або Mode 1 і мʼякші стіки для точних рухів.
- 📷 **Аерозйомка й розвідка.** Окремий курс: камера донизу, чіткий знімок, висота й деталі, облет, сітка; місії з пошуку людини, огляду дахів і лічби наметів зі звітом після посадки. Для дітей «Фотограф».
- 🎯 **Перехоплення.** Окремий курс на FPV-дроні: наздогнати навчальну мішень, зрізати коло, упередження, зустрічні курси, сутінки й туман. Мішень абстрактна, перехоплення — торкання. Для дітей «Метелики».
- 🌫️ **Погода.** Туман і зима у вільному польоті та в місіях.
- 🌻 **Соняшники й посвідчення.** За кожен урок від одного до трьох соняшників: за проходження, за політ без дотиків і за швидкість. Найкращий час зберігається. За всі уроки машини видається посвідчення пілота, а в дитячому режимі грамота.
- 🕊️ **Вільний політ.** Без завдання: вітер, час доби й золоті кулі для розваги.
- 🔊 **Звук.** Мотори, що відгукуються на газ, дзвіночок за зарахований урок і сигнал втрати звʼязку. Звук створюється в коді, без аудіофайлів, і вимикається в налаштуваннях.
- 📘 **Теорія.** Короткі картки: перед польотом, безпека батарей, втрата сигналу, правила польотів в Україні.

Ширяй вчить пілотування як такого. Бойових і тактичних сценаріїв тут немає, тож застосунок можна спокійно давати дітям і використовувати в школах.

## Встановлення

- 📲 **Напряму:** завантажте файл `.apk` звідси: [github.com/marybezuhla/shyriai/releases/latest](https://github.com/marybezuhla/shyriai/releases/latest).
- 🔄 **З оновленнями:** скористайтеся безкоштовним застосунком Obtainium. Його можна встановити з F-Droid: [f-droid.org/packages/dev.imranr.obtainium.fdroid](https://f-droid.org/packages/dev.imranr.obtainium.fdroid). В Obtainium натисніть «Додати застосунок» і вставте посилання `github.com/marybezuhla/shyriai`.

## Прозорість

- **Дозволи:** жодних, які стосуються людини чи телефона; є лише один внутрішній технічний дозвіл бібліотеки AndroidX. Збірка зупиняється, якщо в APK зʼявляється будь-який інший дозвіл, а надто дозвіл на інтернет.
- **Дані:** налаштування й прогрес зберігаються лише на телефоні, в одному маленькому файлі. Хмарну копію Android вимкнено, тож після видалення застосунку прогрес починається заново. Пряме перенесення на новий телефон (Android 12+) рушій Godot вимкнути не дозволяє, тож тоді файл може перенестися. У налаштуваннях можна почати режим спочатку або стерти всі дані, і одразу «Повернути». Докладніше — [PRIVACY.md](PRIVACY.md).
- **Підпис:** справжній APK підписано сертифікатом із відбитком SHA-256 `BF:06:A3:A2:27:BB:10:32:DC:B1:41:C8:92:93:85:80:72:A5:A0:0A:F2:BF:70:39:4A:44:9E:B3:25:FF:2E:1F`. Перевірити завантажений файл: `apksigner verify --print-certs shyriai-<версія>.apk` — рядок `SHA-256 digest` має збігтися (там він малими літерами й без двокрапок).
- **Збірка:** APK збирається з цього коду в GitHub Actions. Godot і його шаблони звіряються за SHA-512. APK підписується лише після схвалення авторки.
- **Доступність:** розмір тексту можна збільшити в налаштуваннях. Програми читання екрана (TalkBack) поки не підтримуються: рушій Godot на Android їм нічого не передає.
- **Вразливості:** як повідомити — [SECURITY.md](SECURITY.md).
- **Як створено:** код написано за допомогою ШІ (Claude, Anthropic) під керівництвом і з тестуванням авторки.
- **Застереження:** тренажер не замінює занять з інструктором і не дає права на польоти. Перед справжнім польотом дізнайтеся, де і як дозволено літати.

© 2026 marybezuhla. Godot 4.7 · GDScript. Ліцензія GPL-3.0 або новіша. Шрифти Unbounded і Manrope — SIL Open Font License 1.1.

---

# Shyriai · English

A piloting trainer for Android: camera and FPV drones, and ground robots (UGVs). For kids and adults. Ukrainian and English. Free, no ads, no accounts, no internet. Requires Android 7 or newer and OpenGL ES 3.0.

> **Test version.** All three vehicles are here: the camera drone (8 lessons, 2 missions), the FPV drone (6 lessons, 4 missions) and the UGV (5 lessons, 4 missions), the aerial survey course (5 lessons, 3 missions; 3 lessons and a photo album for kids), the interception course (5 lessons, 3 missions; butterflies for kids), plus the theory cards. Before version 1.0 come new missions and theory questions, then an independent audit.

## The idea

- 🧒 **Three modes, each with its own progress.** Kids: crashing is impossible, playful tasks, hardly any text. Simple: the drone helps you level out, with hints. Adult: full physics with inertia, wind and battery.
- 🛸 **Three vehicles.** A camera drone that hovers by itself. An FPV drone with Angle, Horizon and Acro modes. A UGV with tank steering, terrain and video delay.
- 👪 **Kids mode** has its own light Morning look and larger text. An optional grown-ups' lock asks for a sum to be solved before leaving Kids mode or opening settings.
- 👀 **Three cameras.** From the ground: as a pilot standing with the radio, the way real flying is learnt. Behind the drone: easier to start with. Camera: the view from the drone itself, for searching and surveying.
- 🎯 **Lessons and missions.** Lessons from easy to hard, each with clear pass conditions. Missions use the same skills in a story: a search in a field, a gate course, cargo delivery, casualty evacuation. For kids: a kitten on a roof, hoops, a parcel for granny.
- 🎮 **Controls.** On-screen sticks, a gamepad, and a real radio over USB, so muscle memory carries over to a real drone. Mode 2 or Mode 1 layout, and softer sticks for fine moves.
- 📷 **Aerial survey.** A course of its own: camera down, sharp pictures, height and detail, orbit, grid; missions to find a person, check roofs and count tents, with a report after landing. "Photographer" for kids.
- 🎯 **Interception.** A course of its own on the FPV drone: catch up with a training target, cut the corner, lead it, meet it head on, in the evening and in fog. The target is abstract; a touch counts. "Butterflies" for kids.
- 🌫️ **Weather.** Fog and winter in free flight and in missions.
- 🌻 **Sunflowers and licences.** One to three sunflowers per lesson: for passing, for flying without a touch, and for speed. Best times are kept. All of a vehicle's lessons earn a pilot's licence, or a certificate in Kids mode.
- 🕊️ **Free flight.** No task: wind, time of day and gold balls for fun.
- 🔊 **Sound.** Motors that answer the throttle, a chime when a lesson counts and a beep when the link drops. The sound is made in code, with no audio files, and can be turned off in settings.
- 📘 **Theory.** Short cards: before you fly, battery safety, lost signal, flying rules in Ukraine.

Shyriai teaches piloting itself. There are no combat or tactical scenarios, so it is fine for kids and for schools.

## Install

- 📲 **Directly:** download the `.apk` file from [github.com/marybezuhla/shyriai/releases/latest](https://github.com/marybezuhla/shyriai/releases/latest).
- 🔄 **With updates:** use the free app Obtainium, available on F-Droid: [f-droid.org/packages/dev.imranr.obtainium.fdroid](https://f-droid.org/packages/dev.imranr.obtainium.fdroid). In Obtainium tap "Add App" and paste `github.com/marybezuhla/shyriai`.

## Transparency

- **Permissions:** none that concern you or your phone; there is only one internal technical permission of the AndroidX library. The build stops if any other permission appears in the APK, internet above all.
- **Data:** settings and progress stay on the phone, in one small file. Android cloud backup is off, so after uninstalling progress starts again. Direct transfer to a new phone (Android 12+) cannot be switched off in the Godot engine, so the file may be copied then. Settings can start a mode over or erase all data, with an immediate Undo. More in [PRIVACY.md](PRIVACY.md).
- **Signature:** the genuine APK is signed with a certificate whose SHA-256 fingerprint is `BF:06:A3:A2:27:BB:10:32:DC:B1:41:C8:92:93:85:80:72:A5:A0:0A:F2:BF:70:39:4A:44:9E:B3:25:FF:2E:1F`. To check a downloaded file: `apksigner verify --print-certs shyriai-<version>.apk`; the `SHA-256 digest` line must match (it is printed in lower case, without the colons).
- **Build:** the APK is built from this code in GitHub Actions. Godot and its templates are checked by SHA-512. The APK is signed only after the author's approval.
- **Accessibility:** text size can be increased in settings. Screen readers (TalkBack) are not supported yet: the Godot engine passes them nothing on Android.
- **Vulnerabilities:** how to report one is in [SECURITY.md](SECURITY.md).
- **How it was made:** the code was written with AI (Claude, Anthropic), directed and tested by the author.
- **Disclaimer:** the trainer does not replace lessons with an instructor and gives no right to fly. Before a real flight, find out where and how flying is allowed.

© 2026 marybezuhla. Godot 4.7 · GDScript. GPL-3.0-or-later licence. Unbounded and Manrope fonts: SIL Open Font License 1.1.

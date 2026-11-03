# Ширяй · Shyriai

Тренажер пілотування для Android: камерні й FPV-дрони та наземні роботизовані комплекси (НРК). Для дітей і дорослих. Українська та англійська. Безкоштовно, без реклами й акаунтів, без інтернету. Потрібен Android 7 або новіший.

> **Рання розробка.** Версія 0.1 — це каркас: головний екран, уроки, місії, теорія й налаштування. Сам політ з'явиться в наступних версіях.

## Задум

- 🧒 **Три режими.** Дитячий: розбитися неможливо, ігрові завдання, майже без тексту. Простий: дрон допомагає вирівнюватися, є підказки. Дорослий: повна фізика з інерцією, вітром і батареєю.
- 🛸 **Три машини.** Камерний дрон, який сам зависає. FPV-дрон з режимами Angle, Horizon і Acro. НРК з гусеничним керуванням, рельєфом і затримкою відео.
- 🎯 **Навчання й місії.** Уроки від простого до складного з чіткими умовами зарахування. Місії — ті самі навички в сюжеті: пошук у полі, траса з воротами, доставка вантажу, евакуація пораненого. Для дітей — кошеня на даху, обручі, посилка бабусі.
- 🎮 **Керування.** Екранні стіки, геймпад і справжній пульт через USB, щоб моторна памʼять переносилася на реальний дрон.
- 📘 **Теорія.** Короткі картки: перед польотом, безпека батарей, втрата сигналу, правила польотів в Україні.

Ширяй вчить пілотування як такого. Бойових і тактичних сценаріїв тут немає, тож застосунок можна спокійно давати дітям і використовувати в школах.

## Встановлення

- 📲 **Напряму:** завантажте файл `.apk` звідси: [github.com/Marybezu/shyriai/releases/latest](https://github.com/Marybezu/shyriai/releases/latest).
- 🔄 **З оновленнями:** скористайтеся безкоштовним застосунком Obtainium. Його можна встановити з F-Droid: [f-droid.org/packages/dev.imranr.obtainium.fdroid](https://f-droid.org/packages/dev.imranr.obtainium.fdroid). В Obtainium натисніть «Додати застосунок» і вставте посилання `github.com/Marybezu/shyriai`.

## Прозорість

- **Дозволи:** жодних. Збірка зупиняється, якщо в APK зʼявляється будь-який дозвіл, а надто дозвіл на інтернет.
- **Дані:** налаштування й прогрес зберігаються лише на телефоні, в одному маленькому файлі. Хмарну копію Android вимкнено.
- **Підпис:** справжній APK підписано сертифікатом із відбитком SHA-256 `BF:06:A3:A2:27:BB:10:32:DC:B1:41:C8:92:93:85:80:72:A5:A0:0A:F2:BF:70:39:4A:44:9E:B3:25:FF:2E:1F`.
- **Збірка:** APK збирається з цього коду в GitHub Actions. Godot і його шаблони звіряються за SHA-512. APK підписується лише після схвалення авторки.
- **Як створено:** код написано за допомогою ШІ (Claude, Anthropic) під керівництвом і з тестуванням авторки.
- **Застереження:** тренажер не замінює занять з інструктором і не дає права на польоти. Перед справжнім польотом дізнайтеся, де і як дозволено літати.

Godot 4.7 · GDScript. Ліцензія GPL-3.0 або новіша. Шрифти Unbounded і Manrope — SIL Open Font License 1.1.

---

# Shyriai · English

A piloting trainer for Android: camera and FPV drones, and ground robots (UGVs). For kids and adults. Ukrainian and English. Free, no ads, no accounts, no internet. Requires Android 7 or newer.

> **Early development.** Version 0.1 is the frame: home screen, lessons, missions, theory and settings. Flying itself comes in the next versions.

## The idea

- 🧒 **Three modes.** Kids: crashing is impossible, playful tasks, hardly any text. Simple: the drone helps you level out, with hints. Adult: full physics with inertia, wind and battery.
- 🛸 **Three vehicles.** A camera drone that hovers by itself. An FPV drone with Angle, Horizon and Acro modes. A UGV with tank steering, terrain and video delay.
- 🎯 **Lessons and missions.** Lessons from easy to hard, each with clear pass conditions. Missions use the same skills in a story: a search in a field, a gate course, cargo delivery, casualty evacuation. For kids: a kitten on a roof, hoops, a parcel for granny.
- 🎮 **Controls.** On-screen sticks, a gamepad, and a real radio over USB, so muscle memory carries over to a real drone.
- 📘 **Theory.** Short cards: before you fly, battery safety, lost signal, flying rules in Ukraine.

Shyriai teaches piloting itself. There are no combat or tactical scenarios, so it is fine for kids and for schools.

## Install

- 📲 **Directly:** download the `.apk` file from [github.com/Marybezu/shyriai/releases/latest](https://github.com/Marybezu/shyriai/releases/latest).
- 🔄 **With updates:** use the free app Obtainium, available on F-Droid: [f-droid.org/packages/dev.imranr.obtainium.fdroid](https://f-droid.org/packages/dev.imranr.obtainium.fdroid). In Obtainium tap "Add App" and paste `github.com/Marybezu/shyriai`.

## Transparency

- **Permissions:** none. The build stops if any permission appears in the APK, internet above all.
- **Data:** settings and progress stay on the phone, in one small file. Android cloud backup is off.
- **Signature:** the genuine APK is signed with a certificate whose SHA-256 fingerprint is `BF:06:A3:A2:27:BB:10:32:DC:B1:41:C8:92:93:85:80:72:A5:A0:0A:F2:BF:70:39:4A:44:9E:B3:25:FF:2E:1F`.
- **Build:** the APK is built from this code in GitHub Actions. Godot and its templates are checked by SHA-512. The APK is signed only after the author's approval.
- **How it was made:** written with AI assistance (Claude, Anthropic), directed and tested by the author.
- **Disclaimer:** the trainer does not replace lessons with an instructor and gives no right to fly. Before a real flight, find out where and how flying is allowed.

Godot 4.7 · GDScript. GPL-3.0-or-later licence. Unbounded and Manrope fonts: SIL Open Font License 1.1.

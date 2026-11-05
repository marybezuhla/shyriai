# Безпека · Ширяй

## Як повідомити про вразливість

Будь ласка, не відкривайте публічне issue. Скористайтеся приватним звітом GitHub: вкладка **Security → Report a vulnerability** у цьому репозиторії.

## Строки

- Підтвердження отримання — **протягом 3 днів**.
- Критична вразливість — виправлення **протягом 7 днів**.
- Решта — у найближчому випуску.

## Що підтримується

Лише остання версія з [Releases](https://github.com/marybezuhla/shyriai/releases/latest).

## Мінімальна версія Android

Android 7 (API 24) і OpenGL ES 3.0. Це найнижча версія, яку підтримують шаблони рушія Godot 4.7. Застосунок не має дозволів і мережі, тож старіша версія Android не відкриває йому додаткових ризиків.

## Справжній APK

Сертифікат підпису, SHA-256: `BF:06:A3:A2:27:BB:10:32:DC:B1:41:C8:92:93:85:80:72:A5:A0:0A:F2:BF:70:39:4A:44:9E:B3:25:FF:2E:1F`.
Перевірка: `apksigner verify --print-certs shyriai-<версія>.apk`.

---

# Security · Shyriai

## How to report a vulnerability

Please do not open a public issue. Use GitHub's private reporting: **Security → Report a vulnerability** in this repository.

## Timelines

- Receipt acknowledged **within 3 days**.
- A critical vulnerability fixed **within 7 days**.
- Anything else in the next release.

## Supported versions

Only the latest version on [Releases](https://github.com/marybezuhla/shyriai/releases/latest).

## Minimum Android version

Android 7 (API 24) and OpenGL ES 3.0: the lowest the Godot 4.7 engine templates support. The app has no permissions and no network, so an older Android version does not expose it to extra risk.

## The genuine APK

Signing certificate, SHA-256: `BF:06:A3:A2:27:BB:10:32:DC:B1:41:C8:92:93:85:80:72:A5:A0:0A:F2:BF:70:39:4A:44:9E:B3:25:FF:2E:1F`.
To check: `apksigner verify --print-certs shyriai-<version>.apk`.

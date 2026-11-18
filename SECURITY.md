# Безпека · Security

**Українською**

**Як повідомити про вразливість.** Приватно, через GitHub: вкладка Security → «Report a vulnerability» у цьому репозиторії. Будь ласка, не пишіть про вразливість у звичайних Issues, поки її не виправлено.

**Строки.**
- Підтвердження, що звіт отримано, — протягом 3 днів.
- Критичну вразливість (доступ до чужих даних, підроблене оновлення) виправляю протягом 7 днів.
- Решту — у найближчому випуску.

**Що підтримується.** Лише остання версія з [Releases](https://github.com/marybezuhla/shyriai/releases/latest). Виправлення виходять новою версією; старі не оновлюються.

**Мінімальна версія Android — 7** (API 24) і OpenGL ES 3.0: найнижча, яку підтримують шаблони рушія Godot 4.7. Застосунок не має дозволів і мережі, тож старіша версія Android не відкриває йому додаткових ризиків.

**Як перевірити, що APK справжній.** Сертифікат підпису має SHA-256 `BF:06:A3:A2:27:BB:10:32:DC:B1:41:C8:92:93:85:80:72:A5:A0:0A:F2:BF:70:39:4A:44:9E:B3:25:FF:2E:1F`. Перевірка: `apksigner verify --print-certs shyriai-<версія>.apk` (apksigner є в Android SDK Build Tools).

---

**In English**

**How to report a vulnerability.** Privately, through GitHub: the Security tab → Report a vulnerability in this repository. Please do not describe it in public Issues until it is fixed.

**Timelines.**
- Receipt is confirmed within 3 days.
- A critical vulnerability (access to someone's data, a forged update) is fixed within 7 days.
- Others in the next release.

**Supported versions.** Only the latest one in [Releases](https://github.com/marybezuhla/shyriai/releases/latest). Fixes come as a new version; older ones are not updated.

**Minimum Android version: 7** (API 24) and OpenGL ES 3.0: the lowest the Godot 4.7 export templates support. The app has no permissions and no network, so an older Android opens no extra risks for it.

**How to check that an APK is genuine.** The signing certificate's SHA-256 is `BF:06:A3:A2:27:BB:10:32:DC:B1:41:C8:92:93:85:80:72:A5:A0:0A:F2:BF:70:39:4A:44:9E:B3:25:FF:2E:1F`. Check: `apksigner verify --print-certs shyriai-<version>.apk` (apksigner comes with the Android SDK Build Tools).

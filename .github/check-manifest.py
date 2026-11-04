#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Reads the compiled AndroidManifest.xml inside an APK (no Android tools needed) and fails if
# backups are allowed, the app is debuggable, cleartext traffic is allowed, or anything other
# than the expected components can be started by other apps.
import struct
import sys
import zipfile

# Exported on purpose: the launcher icon, and AndroidX's profile receiver, which only the
# system can reach (it needs android.permission.DUMP).
EXPORTED_OK = {
    "com.godot.game.GodotAppLauncher": None,
    "androidx.profileinstaller.ProfileInstallReceiver": "android.permission.DUMP",
}
COMPONENTS = {"activity", "activity-alias", "service", "receiver", "provider"}


def elements(data):
    """Yields (tag, {attribute: value}) for every element, in order."""
    pos, strings = 8, []
    while pos < len(data):
        kind, header, size = struct.unpack_from("<HHI", data, pos)
        if size < 8:
            raise ValueError("damaged manifest")
        if kind == 0x0001:  # string pool
            count, _, flags, start, _ = struct.unpack_from("<IIIII", data, pos + 8)
            utf8 = flags & 0x100
            offsets = struct.unpack_from("<%dI" % count, data, pos + header)
            for off in offsets:
                p = pos + start + off
                if utf8:
                    p += 2 if data[p] & 0x80 else 1
                    n = data[p]
                    p += 1
                    if n & 0x80:
                        n = ((n & 0x7F) << 8) | data[p]
                        p += 1
                    strings.append(data[p:p + n].decode("utf-8", "replace"))
                else:
                    n = struct.unpack_from("<H", data, p)[0]
                    strings.append(data[p + 2:p + 2 + 2 * n].decode("utf-16-le", "replace"))
        elif kind == 0x0102:  # start of an element
            _, name, attr_start, attr_size, count = struct.unpack_from("<iiHHH", data, pos + 16)
            attrs = {}
            for i in range(count):
                a = pos + 16 + attr_start + i * attr_size
                _, attr, raw, _, _, dtype, value = struct.unpack_from("<iiiHBBI", data, a)
                if raw >= 0:
                    attrs[strings[attr]] = strings[raw]
                elif dtype == 0x12:  # boolean
                    attrs[strings[attr]] = "true" if value else "false"
                else:
                    attrs[strings[attr]] = hex(value)
            yield strings[name], attrs
        pos += size


def main(apk):
    data = zipfile.ZipFile(apk).read("AndroidManifest.xml")
    if data[:4] != b"\x03\x00\x08\x00":
        print("::error::Manifest: not a compiled Android XML file")
        sys.exit(1)
    errors, app_seen = [], False
    for tag, attrs in elements(data):
        print(tag, " ".join("%s=%s" % kv for kv in attrs.items()))
        if tag == "application":
            app_seen = True
            if attrs.get("allowBackup") != "false":
                errors.append("allowBackup is not false")
            # A value taken from a resource cannot be read here: treat it as switched on.
            if attrs.get("debuggable", "false") != "false":
                errors.append("debuggable is not false")
            if attrs.get("testOnly", "false") != "false":
                errors.append("testOnly is not false")
            if attrs.get("usesCleartextTraffic", "false") != "false":
                errors.append("cleartext traffic is allowed")
        if tag in COMPONENTS and attrs.get("exported", "false") != "false":
            name = attrs.get("name", "?")
            if name not in EXPORTED_OK:
                errors.append("unexpected exported component: " + name)
            elif EXPORTED_OK[name] and attrs.get("permission") != EXPORTED_OK[name]:
                errors.append("%s must need %s" % (name, EXPORTED_OK[name]))
    if not app_seen:
        errors.append("no application element: could not read the manifest")
    for e in errors:
        print("::error::Manifest: " + e)
    if errors:
        sys.exit(1)
    print("Manifest OK")


if __name__ == "__main__":
    main(sys.argv[1])

#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Fails if app/i18n/strings.csv has a key the code can never ask for.

Keys are built in code from pieces ("SUM_" + key, key + "_GOAL", "ORG_%s_WHAT"), so a key counts
as used when it is a literal in a script, or can be put together from literal pieces: a prefix
or format found in the scripts, a key, and suffixes such as _KIDS, _M1 or _A. This is a
safety net, not a proof: a key that only looks reachable still passes.
"""
import csv
import glob
import re
import sys

APP = sys.argv[1] if len(sys.argv) > 1 else "app"
src = "\n".join(open(p, encoding="utf-8").read() for p in glob.glob(APP + "/scripts/**/*.gd", recursive=True))
lits = set(re.findall(r'"([A-Za-z0-9_%]+)"', src))
words = {l for l in lits if re.fullmatch(r"[A-Z][A-Z0-9_]*", l)}
pieces = {l for l in lits if re.fullmatch(r"_?[A-Z0-9][A-Z0-9_]*_?", l)}
formats = [re.compile("^" + re.escape(l).replace("%s", "[A-Z0-9_]+").replace("%d", "[0-9]+") + "$")
           for l in lits if "%" in l and re.fullmatch(r"[A-Z0-9_%sd]+", l)]
# Keys with a prefix cut off in code: "SUM_" + key.trim_prefix("MIS_").
for cut in re.findall(r'trim_prefix\("([A-Z0-9_]+)"\)', src):
    words |= {w[len(cut):] for w in words if w.startswith(cut)}
# Lower-case ids that the code upper-cases into keys ("camera" -> "VEH_CAMERA").
ids = {l.upper() for l in lits if re.fullmatch(r"[a-z][a-z0-9_]*", l)}
SUFFIXES = ("_KIDS", "_M1", "_A", "_B", "_C", "_WHY")

keys = [r[0] for r in csv.reader(open(APP + "/i18n/strings.csv", encoding="utf-8"))][1:]
known = set(keys)


def reachable(k: str) -> bool:
    if k in words or any(f.match(k) for f in formats):
        return True
    for s in SUFFIXES:
        if k.endswith(s) and reachable(k[: -len(s)]):
            return True
    if re.search(r"_\d+$", k) and reachable(re.sub(r"_\d+$", "", k)):
        return True  # numbered: LETTER_3, Q_CARD_2
    # prefix + known word or id, or known word + suffix piece
    for p in pieces:
        if k.startswith(p) and (k[len(p):] in words | ids or k[len(p):] in known and k[len(p):] != k):
            return True
        if k.endswith(p) and p.startswith("_") and k[: -len(p)] in words | ids:
            return True
    return False


unused = [k for k in keys if not reachable(k)]
for k in unused:
    print("::error::strings.csv: no code asks for " + k)
sys.exit(1 if unused else 0)

#!/usr/bin/env python3
"""Make a Skia/PDF output byte-reproducible by stripping the document dates.

Headless Chromium (Skia/PDF) writes /CreationDate and /ModDate into the PDF's
Info dictionary using wall-clock time, so every build differs.  qpdf has no
flag to drop just those two keys (--remove-info landed in qpdf 12), but it can
rewrite the file deterministically via --update-from-json.  This script dumps
the live Info dictionary, removes the two date keys, and re-serializes in place
with a deterministic /ID so two runs over date-differing inputs produce
identical bytes.

Usage: normalize-pdf.py PDF
"""
import json
import os
import subprocess
import sys
import tempfile


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit("usage: normalize-pdf.py PDF")
    pdf = sys.argv[1]

    dump = subprocess.run(
        ["qpdf", "--json=2", pdf], check=True, capture_output=True, text=True
    ).stdout
    doc = json.loads(dump)
    objects = doc["qpdf"][1]

    info_key = next(
        key
        for key, entry in objects.items()
        if isinstance(entry.get("value"), dict)
        and "/CreationDate" in entry["value"]
    )
    info = {
        k: v
        for k, v in objects[info_key]["value"].items()
        if k not in ("/CreationDate", "/ModDate")
    }
    update = {"qpdf": [{"jsonversion": 2}, {info_key: {"value": info}}]}

    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".json", delete=False, encoding="utf-8"
    ) as fh:
        json.dump(update, fh)
        update_path = fh.name

    try:
        subprocess.run(
            [
                "qpdf",
                "--deterministic-id",
                f"--update-from-json={update_path}",
                "--replace-input",
                pdf,
            ],
            check=True,
        )
    finally:
        os.unlink(update_path)


if __name__ == "__main__":
    main()

# Mykyta Nikitenko — CV (vendored, self-contained: no CDN at render time)
# Run recipes from the repo root inside `nix develop`.

set shell := ["bash", "-uc"]

out := "Mykyta Nikitenko - Rust AI Systems Engineer.pdf"

# Build css/tailwind.css from css/input.css (Tailwind v3, content = index.html)
css:
	tailwindcss -i css/input.css -o css/tailwind.css --minify

# Generate the PDF (rebuilds CSS first). Headless Chromium loads index.html
# from the filesystem; all assets (CSS, font, images) are local.
pdf: css
	exec 3>&1; chromium --headless=new --disable-gpu --no-sandbox --log-level=3 --use-gl=angle --use-angle=swiftshader --no-pdf-header-footer --virtual-time-budget=10000 --print-to-pdf="{{out}}" index.html 2>&1 1>&3 3>&- | grep -v -e 'vk_renderer' -e 'ANGLE Display::initialize' -e 'VerifyExtensionsPresent' 1>&2 3>&-; ec="${PIPESTATUS[0]}"; exec 3>&-; exit "$ec"
	@test -f "{{out}}" || { echo "ERROR: {{out}} was not created" >&2; exit 1; }
	@python3 normalize-pdf.py "{{out}}"
	@size=$(stat -c%s "{{out}}" 2>/dev/null || stat -f%z "{{out}}"); if [ "$size" -lt 51200 ]; then echo "ERROR: {{out}} is only ${size} bytes (<50KB) — looks blank/broken" >&2; exit 1; fi
	@if ! info=$(pdfinfo "{{out}}" 2>&1); then echo "ERROR: {{out}} is not a valid PDF (pdfinfo failed):" >&2; echo "$info" >&2; exit 1; fi; pages=$(echo "$info" | awk '/^Pages:/{print $2}'); if [ "$pages" != "3" ]; then echo "WARNING: page count is ${pages}, expected 3" >&2; else echo "OK: page count is 3"; fi
	@echo "wrote {{out}}"
	@if hits=$(pdftotext "{{out}}" - | grep -n "TODO"); then echo "$hits" >&2; echo "ERROR: TODO(s) above are VISIBLE in the rendered PDF" >&2; exit 1; else echo "OK: no visible TODOs in the PDF"; fi
	@if hits=$(grep -n "TODO(" index.html); then echo "$hits" >&2; echo "ERROR: unresolved TODO(s) in index.html" >&2; exit 1; else echo "OK: no TODOs in index.html"; fi

# Dump the PDF's extracted text (verify section order and content)
inspect:
	pdftotext "{{out}}" -

# List TODOs: visible ones ship in the PDF, HTML-comment ones do not
todo:
	@echo "--- VISIBLE in the PDF (these ship) ---"
	@pdftotext "{{out}}" - | grep -n "TODO" || echo "(none)"
	@echo "--- HTML comments in index.html (not rendered) ---"
	@grep -n "TODO(" index.html || echo "(none)"

# Serve the CV locally for browser inspection (http://localhost:8000/)
serve:
	python3 -m http.server 8000

# default
default: pdf

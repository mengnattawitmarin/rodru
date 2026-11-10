#!/usr/bin/env python3
"""Refresh data/radiation.json from the Office of Atoms for Peace (ปส.) weekly
gamma-dose report (PDF). Run by .github/workflows/radiation.yml.

Strategy (best effort — keeps the old file when anything looks wrong):
  1. Find the newest report PDF via the site's WordPress media API, falling
     back to the site search page.
  2. Extract text with `pdftotext -layout`.
  3. Parse rows "<station no> ... <value> ± <err>" (or "-" for no reading).
  4. Write only if ≥ 10 stations parsed and values are plausible.

Exit code 0 always (so the schedule does not spam failures); problems are
printed as GitHub ::warning:: annotations.
"""
import datetime as dt
import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "radiation.json")
SITE = "https://www.oap.go.th"
UA = {"User-Agent": "RODRU-radiation-bot/1.0 (+github.com/mengnattawitmarin/rodru)"}
KEYWORD = "รังสีแกมมา"

THAI_MONTHS = ["มกราคม", "กุมภาพันธ์", "มีนาคม", "เมษายน", "พฤษภาคม", "มิถุนายน", "กรกฎาคม",
               "สิงหาคม", "กันยายน", "ตุลาคม", "พฤศจิกายน", "ธันวาคม"]
THAI_MONTHS_SHORT = ["ม.ค.", "ก.พ.", "มี.ค.", "เม.ย.", "พ.ค.", "มิ.ย.", "ก.ค.", "ส.ค.", "ก.ย.", "ต.ค.", "พ.ย.", "ธ.ค."]


def warn(msg):
    print(f"::warning title=radiation update::{msg}")


def get(url, timeout=40):
    # OAP file names are Thai — percent-encode non-ASCII (keeps existing %xx escapes)
    url = urllib.parse.quote(url, safe=":/?&=%#+,;@!$'()*~")
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def find_pdfs():
    """Return candidate (date_iso, url, title) newest first."""
    out = []
    q = urllib.parse.quote(KEYWORD)
    try:
        items = json.loads(get(f"{SITE}/wp-json/wp/v2/media?search={q}&per_page=20&orderby=date&order=desc"))
        for it in items:
            url = it.get("source_url", "")
            title = (it.get("title") or {}).get("rendered", "")
            if url.lower().endswith(".pdf"):
                out.append((it.get("date", ""), url, title))
    except Exception as e:  # noqa: BLE001
        warn(f"WP media API failed: {e}")
    if not out:
        try:
            html = get(f"{SITE}/?s={q}").decode("utf-8", "ignore")
            for url in re.findall(r'https?://[^"\'\s>]+\.pdf', html):
                if KEYWORD in urllib.parse.unquote(url):
                    m = re.search(r"/uploads/(\d{4})/(\d{2})/", url)
                    out.append((f"{m.group(1)}-{m.group(2)}-01" if m else "", url, ""))
        except Exception as e:  # noqa: BLE001
            warn(f"site search failed: {e}")
    out.sort(key=lambda x: x[0], reverse=True)
    return out


VALUE = re.compile(r"(\d+\.\d+)\s*(?:±|\+/-|\+-|±)\s*(\d+\.\d+)")


def parse(text):
    """Return {station_id: (value|None, err|None, status)}."""
    rows = {}
    for raw in text.splitlines():
        line = raw.strip()
        m = re.match(r"^(\d{1,2})[\s.)]+(.*)$", line)
        if not m:
            continue
        sid = int(m.group(1))
        if not 1 <= sid <= 22 or sid in rows:
            continue
        rest = m.group(2)
        v = VALUE.search(rest)
        if v:
            val, err = float(v.group(1)), float(v.group(2))
            status = "ปกติ" if 0 < val <= 0.3 else ("สูงกว่าปกติ" if val > 0.3 else "ไม่ทราบ")
            rows[sid] = (val, err, status)
        elif "ซ่อม" in rest:
            rows[sid] = (None, None, "อยู่ระหว่างการซ่อมบำรุง")
        elif "ติดตั้ง" in rest:
            rows[sid] = (None, None, "อยู่ระหว่างการติดตั้งสถานี")
    return rows


def period_from(text, url, title):
    hay = " ".join([title, urllib.parse.unquote(url), text[:600]])
    # e.g. 250869-310869  (ddmmyy Buddhist year)
    m = re.search(r"(\d{2})(\d{2})(\d{2})\s*[-–]\s*(\d{2})(\d{2})(\d{2})", hay)
    if m:
        d1, m1, _, d2, m2, y2 = (int(x) for x in m.groups())
        if 1 <= m1 <= 12 and 1 <= m2 <= 12:
            return f"{d1}{'' if m1 == m2 else ' ' + THAI_MONTHS_SHORT[m1 - 1]}–{d2} {THAI_MONTHS_SHORT[m2 - 1]} 25{y2:02d}"
    # e.g. 12 พฤษภาคม – 18 พฤษภาคม 2569
    mon = "|".join(THAI_MONTHS + ["กรกฏาคม"])
    m = re.search(rf"(\d{{1,2}})\s*({mon})?\s*[-–]?\s*(\d{{1,2}})\s*({mon})\s*(25\d\d)", hay)
    if m:
        return f"{m.group(1)} {m.group(2) or ''} – {m.group(3)} {m.group(4)} {m.group(5)}".replace("  ", " ").strip()
    return None


def main():
    cur = json.load(open(OUT, encoding="utf-8"))
    cands = find_pdfs()
    if not cands:
        warn("no report PDF found — keeping existing data")
        return
    date, url, title = cands[0]
    print("newest report:", date, url)
    if url == cur.get("source_url"):
        print("already up to date")
        return
    tmp = tempfile.mkdtemp()
    pdf_path = os.path.join(tmp, "r.pdf")
    open(pdf_path, "wb").write(get(url))
    txt = subprocess.run(["pdftotext", "-layout", pdf_path, "-"], capture_output=True, text=True).stdout
    if len(txt.strip()) < 50:
        warn("PDF has almost no extractable text (scanned image?) — OCR would be needed")
    rows = parse(txt)
    print(f"parsed {len(rows)} stations:", rows)
    good = [v for v in rows.values() if v[0] is not None]
    if len(rows) < 10 or len(good) < 8:
        warn(f"parsed only {len(rows)} stations from {url} — layout may have changed; keeping existing data")
        sample = txt[:2500].replace("%", "%25").replace("\r", "").replace("\n", "%0A")
        print(f"::warning title=pdftotext sample::{sample}")
        raw = subprocess.run(["pdftotext", "-raw", pdf_path, "-"], capture_output=True, text=True).stdout[:2500]
        print("::warning title=pdftotext raw sample::" + raw.replace("%", "%25").replace("\n", "%0A"))
        return
    if any(v[0] > 50 for v in good):
        warn("implausible value (>50 µSv/h) — keeping existing data for manual review")
        return
    for st in cur["stations"]:
        if st["id"] in rows:
            st["value"], st["err"], st["status"] = rows[st["id"]]
        else:
            st["value"], st["err"], st["status"] = None, None, "ไม่มีข้อมูลในรายงาน"
    cur["source_url"] = url
    cur["period"] = period_from(txt, url, title) or (date[:10] if date else cur.get("period"))
    cur["updated"] = dt.datetime.now(dt.timezone(dt.timedelta(hours=7))).isoformat(timespec="minutes")
    json.dump(cur, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("updated", OUT, "period", cur["period"])


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # noqa: BLE001
        warn(f"unexpected error: {e}")
    sys.exit(0)

#!/usr/bin/env python3
"""Pack the whole project's source into ONE markdown file for pasting/uploading
into any AI chat (ChatGPT, Gemini, Claude...). Usage: python3 tool/make_bundle.py [out.md]"""
import os, subprocess, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, "RODRU_bundle.md")
files = subprocess.check_output(["git", "ls-files"], cwd=root, text=True).split()
skip = (".png", ".keystore", ".jpg")
order = ["AGENTS.md", "README.md", "pubspec.yaml"]
files = order + sorted(f for f in files if f not in order and not f.endswith(skip) and f != "RODRU_bundle.md")
lang = {".dart": "dart", ".yaml": "yaml", ".yml": "yaml", ".py": "python", ".sh": "bash", ".md": "markdown"}
with open(out, "w", encoding="utf-8") as o:
    o.write("# RODRU รอดรู้ — รวมซอร์สโค้ดทั้งโปรเจกต์ (ไฟล์เดียว)\n\n")
    o.write("วิธีใช้: ส่งไฟล์นี้ให้ AI ใดก็ได้ แล้วบอกว่า \"อ่าน AGENTS.md ในไฟล์นี้ก่อน แล้วช่วยพัฒนาต่อ — ตอบกลับเป็นไฟล์เต็มที่แก้ พร้อม path\"\n")
    o.write("Repo: https://github.com/mengnattawitmarin/rodru\n\n## รายชื่อไฟล์\n")
    o.writelines(f"- `{f}`\n" for f in files)
    for f in files:
        ext = os.path.splitext(f)[1]
        body = open(os.path.join(root, f), encoding="utf-8").read()
        fence = "````" if "```" in body else "```"
        o.write(f"\n\n---\n## FILE: `{f}`\n{fence}{lang.get(ext, '')}\n{body}\n{fence}\n")
print(out)

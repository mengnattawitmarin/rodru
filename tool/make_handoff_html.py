#!/usr/bin/env python3
"""Build RODRU_handoff.html — one self-contained page with ready-to-copy AI prompts
and every source file (copy per file, download whole bundle .md).
Usage: python3 tool/make_handoff_html.py [out.html]"""
import html, os, subprocess, sys, datetime

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, "RODRU_handoff.html")
files = subprocess.check_output(["git", "ls-files"], cwd=root, text=True).split()
skip = (".png", ".keystore", ".jpg")
order = ["AGENTS.md", "README.md", "pubspec.yaml"]
files = order + sorted(f for f in files if f not in order and not f.endswith(skip))
commit = subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], cwd=root, text=True).strip()
today = datetime.date.today().isoformat()
REPO = "https://github.com/mengnattawitmarin/rodru"

PROMPTS = [
    ("1 · ส่งงานให้ AI ตัวอื่น", "แนบไฟล์ HTML นี้ (หรือ RODRU_bundle.md / ZIP) แล้ววางข้อความนี้",
     f"""คุณคือนักพัฒนา Flutter มืออาชีพ ช่วยพัฒนาแอป "RODRU รอดรู้" (แอปเตรียมรับมือภัยพิบัติภาษาไทย) ต่อ
ไฟล์ที่แนบมีซอร์สโค้ดทั้งโปรเจกต์ (repo: {REPO})

ขั้นตอน:
1. อ่าน AGENTS.md ให้จบก่อน (ภาพรวม โครงสร้างโค้ด กติกา งานถัดไป)
2. งานที่ต้องการรอบนี้: [พิมพ์สิ่งที่อยากได้ เช่น "เพิ่มการแจ้งเตือน push ตามพื้นที่" หรือ "แก้บั๊ก ..."]
3. ทำตามกติกาใน AGENTS.md: UI ภาษาไทย, HTTP อยู่ใน services/api.dart, ใช้ withValues(alpha:), permission ใหม่แก้ใน tool/patch_platforms.py, เพิ่ม test ให้ logic ใหม่
4. อธิบายสั้น ๆ ว่าแก้อะไร ไฟล์ไหน เพราะอะไร

รูปแบบการส่งกลับ (สำคัญมาก):
- ถ้าสร้างไฟล์ได้: ส่ง ZIP ทั้งโปรเจกต์ โครงสร้างโฟลเดอร์เดิม
- ถ้าทำ ZIP ไม่ได้: ส่งเฉพาะไฟล์ที่แก้/เพิ่ม เป็น "ไฟล์เต็มทุกบรรทัด" ห้ามย่อ ห้ามเขียน "...โค้ดเดิม..." ใช้หัวข้อแบบนี้ทุกไฟล์:
  ## FILE: `path/ของ/ไฟล์.dart`
  ```dart
  (โค้ดเต็ม)
  ```
- ถ้าลบไฟล์ ให้เขียน ## DELETE: `path`
- เพิ่มแถวใน "บันทึกการส่งต่อ" ของ AGENTS.md (วันที่, ชื่อ AI, ทำอะไร, ค้าง/ข้อควรรู้) และส่ง AGENTS.md ฉบับเต็มกลับมาด้วย"""),
    ("2 · ถ้า AI ตอบมาไม่ครบ / ถูกตัด", "ใช้เมื่อคำตอบโดนตัดกลางทาง หรือมีโค้ดย่อ",
     """คำตอบเมื่อกี้ไม่ครบ ช่วยส่งต่อจากจุดที่ค้าง โดย:
- ส่งไฟล์ที่ยังไม่ครบใหม่ทั้งไฟล์ ตั้งแต่บรรทัดแรก
- ห้ามย่อหรือเขียน "...โค้ดเดิม..."
- ใช้หัวข้อ ## FILE: `path` เหมือนเดิม
- ส่งทีละไม่เกิน 3 ไฟล์ แล้วบอกว่าเหลือไฟล์ไหนอีก"""),
    ("3 · นำกลับมาพัฒนาต่อกับ Claude", "เปิดแชตใหม่ในโปรเจกต์ นักสร้างapp แนบไฟล์ที่ได้กลับมา แล้ววางข้อความนี้",
     f"""นี่คือโค้ดแอป RODRU ที่ AI ตัวอื่นพัฒนาต่อมา (repo: {REPO})
1. อ่าน AGENTS.md และบันทึกการส่งต่อ
2. รวมไฟล์ที่แนบเข้า repo (ตรวจว่าไม่มีไฟล์หาย โค้ดไม่ถูกย่อ ไม่มี syntax พัง)
3. push ขึ้น main ให้ GitHub สร้าง APK ใหม่ ถ้า build ไม่ผ่านให้แก้จนผ่าน
4. สรุปว่ามีอะไรเปลี่ยน แล้วส่งลิงก์ดาวน์โหลด APK"""),
]

lang = {".dart": "dart", ".yaml": "yaml", ".yml": "yaml", ".py": "python", ".sh": "bash", ".md": "markdown"}
file_blocks, toc = [], []
total_lines = 0
for i, f in enumerate(files):
    body = open(os.path.join(root, f), encoding="utf-8").read()
    n = body.count("\n") + 1
    total_lines += n
    toc.append(f'<a href="#f{i}"><span>{html.escape(f)}</span><small>{n}</small></a>')
    file_blocks.append(
        f'<details class="file" id="f{i}" data-path="{html.escape(f)}" data-lang="{lang.get(os.path.splitext(f)[1], "")}">'
        f'<summary><span class="path">{html.escape(f)}</span><span class="meta">{n} บรรทัด</span>'
        f'<button class="btn sm" data-copy-file>คัดลอก</button></summary>'
        f'<pre><code>{html.escape(body)}</code></pre></details>'
    )

prompt_blocks = "".join(
    f'<section class="prompt"><div class="ph"><div><h3>{html.escape(t)}</h3><p>{html.escape(d)}</p></div>'
    f'<button class="btn" data-copy-prompt>คัดลอกพรอมต์</button></div><pre class="ptext">{html.escape(p)}</pre></section>'
    for t, d, p in PROMPTS
)

page = f"""<!doctype html>
<html lang="th"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>RODRU Handoff</title>
<style>
:root{{--bg:#071526;--panel:#10263C;--panel2:#153B5C;--line:#ffffff1a;--text:#e8eef5;--mute:#9fb0c2;--blue:#39A9FF;--amber:#FFC857;--green:#55D68B;--red:#FF5D52}}
*{{box-sizing:border-box}}body{{margin:0;background:var(--bg);color:var(--text);font:15px/1.55 system-ui,-apple-system,"Segoe UI","Noto Sans Thai",sans-serif}}
.wrap{{max-width:1000px;margin:0 auto;padding:24px 16px 80px}}
header h1{{margin:0;font-size:30px;letter-spacing:-.5px}}header p{{margin:4px 0 0;color:var(--mute)}}
.tags{{display:flex;flex-wrap:wrap;gap:8px;margin:14px 0 6px}}.tag{{background:var(--panel);border:1px solid var(--line);border-radius:99px;padding:4px 12px;font-size:13px;color:var(--mute)}}
.tag a{{color:var(--blue);text-decoration:none}}
h2{{font-size:20px;margin:34px 0 10px}}
.steps{{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:10px}}
.step{{background:var(--panel);border:1px solid var(--line);border-radius:16px;padding:14px}}.step b{{color:var(--amber)}}
.prompt{{background:var(--panel);border:1px solid var(--line);border-radius:18px;margin:12px 0;overflow:hidden}}
.ph{{display:flex;gap:12px;align-items:flex-start;justify-content:space-between;padding:14px 16px;background:var(--panel2)}}
.ph h3{{margin:0;font-size:16px}}.ph p{{margin:2px 0 0;color:var(--mute);font-size:13px}}
.ptext{{margin:0;padding:14px 16px;white-space:pre-wrap;word-break:break-word;font:14px/1.6 inherit;font-family:inherit}}
.btn{{flex:none;background:var(--blue);color:#05121f;border:0;border-radius:10px;padding:8px 14px;font:600 14px inherit;font-family:inherit;cursor:pointer}}
.btn:hover{{filter:brightness(1.1)}}.btn.sm{{padding:4px 10px;font-size:12px;background:#ffffff14;color:var(--text)}}.btn.ok{{background:var(--green)}}
.btn.alt{{background:var(--amber)}}
.toolbar{{display:flex;flex-wrap:wrap;gap:8px;margin:10px 0}}
.toc{{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:4px;background:var(--panel);border:1px solid var(--line);border-radius:16px;padding:10px}}
.toc a{{display:flex;justify-content:space-between;gap:8px;color:var(--text);text-decoration:none;padding:4px 8px;border-radius:8px;font:12.5px ui-monospace,Menlo,Consolas,monospace}}
.toc a:hover{{background:#ffffff10}}.toc small{{color:var(--mute)}}
.file{{background:var(--panel);border:1px solid var(--line);border-radius:14px;margin:8px 0;overflow:hidden}}
.file summary{{display:flex;align-items:center;gap:10px;padding:10px 14px;cursor:pointer;list-style:none}}
.file summary::-webkit-details-marker{{display:none}}
.file .path{{flex:1;font:600 13.5px ui-monospace,Menlo,Consolas,monospace;word-break:break-all}}.file .meta{{color:var(--mute);font-size:12px}}
.file[open] summary{{border-bottom:1px solid var(--line)}}
pre code{{display:block}}.file pre{{margin:0;padding:14px;overflow:auto;max-height:70vh;font:12.5px/1.5 ui-monospace,Menlo,Consolas,monospace;background:#050f1c}}
.warn{{border-left:3px solid var(--amber);background:#2a2412;padding:10px 14px;border-radius:10px;color:#f3e3b5;font-size:14px}}
footer{{margin-top:40px;color:var(--mute);font-size:12px}}
@media (max-width:600px){{.ph{{flex-direction:column}}.btn{{width:100%}}.file summary .btn{{width:auto}}}}
</style></head><body><div class="wrap">
<header>
<h1>🛡️ RODRU รอดรู้ — ชุดส่งต่องานให้ AI</h1>
<p>แอปเตรียมรับมือภัยพิบัติ (Flutter · Android/iOS) · v0.2 · commit {commit} · สร้างเมื่อ {today}</p>
<div class="tags">
<span class="tag">Repo: <a href="{REPO}">{REPO.replace("https://","")}</a></span>
<span class="tag">APK: <a href="{REPO}/releases/latest">releases/latest</a></span>
<span class="tag">{len(files)} ไฟล์ · {total_lines:,} บรรทัด</span>
</div>
</header>

<h2>วิธีใช้</h2>
<div class="steps">
<div class="step"><b>1.</b> แนบไฟล์ HTML นี้ให้ AI ตัวอื่น แล้ววาง <b>พรอมต์ 1</b> (แก้วงเล็บ [งานที่ต้องการ])</div>
<div class="step"><b>2.</b> ถ้า AI รับ HTML ไม่ได้ กด <b>ดาวน์โหลด bundle .md</b> แล้วแนบไฟล์นั้นแทน</div>
<div class="step"><b>3.</b> ได้โค้ดกลับมา → เปิดแชตใหม่ในโปรเจกต์ <b>นักสร้างapp</b> แนบไฟล์ แล้ววาง <b>พรอมต์ 3</b></div>
</div>

<h2>พรอมต์พร้อมใช้</h2>
{prompt_blocks}
<p class="warn">AI ในแชตทั่วไปมักตัดคำตอบยาว ๆ ให้สั่งงานทีละเรื่องเล็ก ๆ และขอเฉพาะไฟล์ที่แก้ ถ้าโดนตัดให้ใช้พรอมต์ 2</p>

<h2>ซอร์สโค้ดทั้งหมด</h2>
<div class="toolbar">
<button class="btn" id="dlBundle">ดาวน์โหลด bundle .md (ทุกไฟล์)</button>
<button class="btn alt" id="copyAll">คัดลอกโค้ดทั้งหมด</button>
<button class="btn sm" id="expand">เปิดทุกไฟล์</button>
<button class="btn sm" id="collapse">ปิดทุกไฟล์</button>
</div>
<div class="toc">{''.join(toc)}</div>
{''.join(file_blocks)}
<footer>ไม่รวมไฟล์ไบนารี (ไอคอน .png, คีย์ทดสอบ .keystore) — ดึงจาก repo ได้ · สร้างใหม่ด้วย <code>python3 tool/make_handoff_html.py</code></footer>
</div>
<script>
function flash(b,t){{const o=b.textContent;b.textContent=t||'คัดลอกแล้ว ✓';b.classList.add('ok');setTimeout(()=>{{b.textContent=o;b.classList.remove('ok')}},1600)}}
async function copy(text,b){{try{{await navigator.clipboard.writeText(text);flash(b)}}catch(e){{const t=document.createElement('textarea');t.value=text;document.body.appendChild(t);t.select();try{{document.execCommand('copy');flash(b)}}catch(_){{flash(b,'คัดลอกไม่ได้')}}t.remove()}}}}
function bundle(){{let s='# RODRU รอดรู้ — รวมซอร์สโค้ดทั้งโปรเจกต์\\n\\nอ่าน AGENTS.md ก่อนเริ่มงาน · Repo: {REPO}\\n';
document.querySelectorAll('.file').forEach(f=>{{const c=f.querySelector('code').textContent;const fence=c.includes('```')?'````':'```';s+='\\n\\n---\\n## FILE: `'+f.dataset.path+'`\\n'+fence+f.dataset.lang+'\\n'+c+'\\n'+fence+'\\n'}});return s}}
document.querySelectorAll('[data-copy-prompt]').forEach(b=>b.onclick=()=>copy(b.closest('.prompt').querySelector('.ptext').textContent,b));
document.querySelectorAll('[data-copy-file]').forEach(b=>b.onclick=e=>{{e.preventDefault();e.stopPropagation();const f=b.closest('.file');copy(f.querySelector('code').textContent,b)}});
document.getElementById('copyAll').onclick=e=>copy(bundle(),e.target);
document.getElementById('dlBundle').onclick=()=>{{const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([bundle()],{{type:'text/markdown'}}));a.download='RODRU_bundle.md';a.click();setTimeout(()=>URL.revokeObjectURL(a.href),2000)}};
document.getElementById('expand').onclick=()=>document.querySelectorAll('.file').forEach(f=>f.open=true);
document.getElementById('collapse').onclick=()=>document.querySelectorAll('.file').forEach(f=>f.open=false);
document.querySelectorAll('.toc a').forEach(a=>a.onclick=()=>{{const t=document.querySelector(a.getAttribute('href'));if(t)t.open=true}});
</script></body></html>"""
open(out, "w", encoding="utf-8").write(page)
print(out)

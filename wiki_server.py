#!/usr/bin/env python3
"""Power Kernel 本地 wiki 预览服务器。

用法:
    python wiki_server.py            # 默认 http://127.0.0.1:8000
    python wiki_server.py 9000       # 指定端口

把 wiki/ 目录下的 .md 渲染成网页，支持 [[Page Name]] wiki 链接和侧边栏。
"""
import os
import re
import sys
import webbrowser
from http.server import HTTPServer, BaseHTTPRequestHandler

import markdown

ROOT = os.path.dirname(os.path.abspath(__file__))
WIKI_DIR = os.path.join(ROOT, 'wiki')
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8000

# [[Page Name]] -> 链接。页面标题里的空格对应文件名里的连字符。
WIKI_LINK = re.compile(r'\[\[([^\]]+)\]\]')

CSS = """
:root { color-scheme: light dark; }
* { box-sizing: border-box; }
body { margin: 0; font-family: -apple-system, "Segoe UI", "Microsoft YaHei",
       "PingFang SC", sans-serif; line-height: 1.6; color: #1f2328;
       background: #fff; }
.layout { display: flex; max-width: 1100px; margin: 0 auto; }
.sidebar { width: 240px; padding: 24px 16px; border-right: 1px solid #d0d7de;
           background: #f6f8fa; min-height: 100vh; flex-shrink: 0; }
.sidebar h1 { font-size: 15px; margin: 0 0 12px; }
.sidebar ul { list-style: none; margin: 0; padding: 0; }
.sidebar li { margin: 4px 0; }
.sidebar a { color: #0969da; text-decoration: none; display: block;
             padding: 4px 8px; border-radius: 6px; }
.sidebar a:hover { background: #eaeef2; }
.content { flex: 1; padding: 24px 32px; max-width: 760px; }
h1, h2, h3 { border-bottom: 1px solid #d8dee4; padding-bottom: .3em; }
h1 { font-size: 2em; } h2 { font-size: 1.5em; } h3 { font-size: 1.25em; }
code { background: #eff1f3; padding: 2px 5px; border-radius: 6px;
       font-family: ui-monospace, Consolas, monospace; font-size: 90%; }
pre { background: #f6f8fa; padding: 16px; border-radius: 6px; overflow-x: auto; }
pre code { background: none; padding: 0; }
table { border-collapse: collapse; margin: 16px 0; }
th, td { border: 1px solid #d0d7de; padding: 6px 13px; text-align: left; }
th { background: #f6f8fa; }
a { color: #0969da; }
blockquote { border-left: 4px solid #d0d7de; margin: 0; padding: 0 16px;
             color: #57606a; }
@media (prefers-color-scheme: dark) {
  body { background: #0d1117; color: #c9d1d9; }
  .sidebar { background: #161b22; border-color: #30363d; }
  .sidebar a:hover { background: #21262d; }
  code, pre, th { background: #161b22; }
  h1, h2, h3, th, td { border-color: #30363d; }
  blockquote { color: #8b949e; }
}
"""


def to_md(text):
    """把 [[Page Name]] 转成 markdown 链接。"""
    def repl(m):
        name = m.group(1).strip()
        return '[%s](/%s)' % (name, name.replace(' ', '-'))
    return WIKI_LINK.sub(repl, text)


def render(name):
    """返回 (html, 404标志)。"""
    path = os.path.join(WIKI_DIR, name + '.md')
    if not os.path.isfile(path):
        return None
    with open(path, encoding='utf-8') as f:
        body = markdown.markdown(
            to_md(f.read()), extensions=['tables', 'fenced_code'])

    sidebar = ''
    sb = os.path.join(WIKI_DIR, '_Sidebar.md')
    if os.path.isfile(sb):
        with open(sb, encoding='utf-8') as f:
            sidebar = markdown.markdown(to_md(f.read()))

    title = name.replace('-', ' ')
    return f"""<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} · Power Kernel Wiki</title>
<style>{CSS}</style></head>
<body><div class="layout">
<nav class="sidebar">{sidebar}</nav>
<main class="content">{body}</main>
</div></body></html>"""


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        name = self.path.lstrip('/').strip()
        if name == '':
            self.send_response(302)
            self.send_header('Location', '/Home')
            self.end_headers()
            return
        if name == 'favicon.ico':
            self.send_response(204)
            self.end_headers()
            return
        html = render(name)
        if html is None:
            self.send_response(404)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.end_headers()
            self.wfile.write(b'<h1>404</h1><p>page not found</p>')
            return
        data = html.encode('utf-8')
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, fmt, *args):
        sys.stderr.write('[%s] %s\n' % (self.log_date_time_string(), fmt % args))


def main():
    server = HTTPServer(('127.0.0.1', PORT), Handler)
    url = 'http://127.0.0.1:%d/Home' % PORT
    print('Power Kernel wiki: %s' % url)
    print('按 Ctrl+C 停止')
    try:
        webbrowser.open(url)
    except Exception:
        pass
    server.serve_forever()


if __name__ == '__main__':
    main()

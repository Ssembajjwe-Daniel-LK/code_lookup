"""
Small MCP server for the Code Lookup app.

Tools:
  search_knowledge_base(query)  - keyword search over a documents folder (.docx, .pdf, .txt, .md)
  lookup_code(code)             - only if a Code_Index.csv exists (optional)

Setup:
  python -m venv .venv
  .venv\\Scripts\\activate
  pip install -r requirements.txt

Run:
  python server.py --cors                                 # demo data in this folder
  python server.py --cors --docs "D:\\MyDocuments"        # your own documents, knowledge base only
  -> http://127.0.0.1:8010/mcp   (localhost only)

Flutter app:
  flutter run -d windows --dart-define=MCP_URL=http://127.0.0.1:8010/mcp
"""
import argparse
import csv
import json
import re
from collections import defaultdict
from pathlib import Path

from docx import Document
from docx.oxml.ns import qn

BASE = Path(__file__).resolve().parent

# Fictional code families (regex) for the demo data, like code_patterns.xlsx in the real pipeline.
PATTERNS = {
    "DMX": r"\bDMX-\d{4}\b",            # Steuermodule, e.g. DMX-2001
    "TRMA": r"\bTRMA-\d{5}\b",          # RMA cases, e.g. TRMA-26014
    "KBX": r"\bKBX-\d{3}[A-Z]\b",       # Kabelsätze, e.g. KBX-104A
    "FWV": r"\bFWV \d+\.\d{2}\b",       # Firmware, e.g. FWV 3.14
}

SUFFIXES = {".docx", ".pdf", ".txt", ".md"}


def docx_pages(path: Path):
    """Yield (page_num, text) for a .docx. Pages are split at manual page breaks.
    Paragraphs and tables are read in document order."""
    doc = Document(path)
    page, parts = 1, []
    for el in doc.element.body.iterchildren():
        if el.tag == qn("w:p"):
            text = "".join(t.text or "" for t in el.iter(qn("w:t")))
            if text:
                parts.append(text)
            if any(br.get(qn("w:type")) == "page" for br in el.iter(qn("w:br"))):
                yield page, "\n".join(parts)
                page, parts = page + 1, []
        elif el.tag == qn("w:tbl"):
            for row in el.iter(qn("w:tr")):
                cells = ["".join(t.text or "" for t in tc.iter(qn("w:t"))) for tc in row.iter(qn("w:tc"))]
                parts.append(" | ".join(cells))
    if parts:
        yield page, "\n".join(parts)


def pdf_pages(path: Path):
    import pymupdf  # only needed when PDFs are present
    with pymupdf.open(path) as doc:
        for i, page in enumerate(doc, start=1):
            text = page.get_text()
            if text.strip():  # scanned pages without text layer are skipped (no OCR here)
                yield i, text


def file_pages(path: Path):
    suffix = path.suffix.lower()
    if suffix == ".docx":
        yield from docx_pages(path)
    elif suffix == ".pdf":
        yield from pdf_pages(path)
    else:
        yield 1, path.read_text(encoding="utf-8", errors="replace")


def load_pages(docs_dir: Path):
    pages, failed = [], []
    for f in sorted(docs_dir.rglob("*")):
        if f.suffix.lower() not in SUFFIXES or f.name.startswith(("~$", "._")):
            continue
        try:
            pages += [{"source": str(f), "page": p, "text": t} for p, t in file_pages(f)]
        except Exception as e:  # one broken file must not stop the server
            failed.append(f"{f.name}: {e}")
    return pages, failed


def _norm(code: str) -> str:
    return re.sub(r"\s+", " ", code.strip()).upper()


def load_index(csv_path: Path, base: Path):
    index = defaultdict(list)
    with open(csv_path, encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            index[_norm(row["code"])].append({
                "filepath": str(base / row["filepath"]),
                "page_num": int(row["page_num"]),
                "quelle": row["quelle"],
                "archiv": row["archiv"].lower() == "true",
            })
    return index


if __name__ == "__main__":
    from mcp.server.fastmcp import FastMCP

    ap = argparse.ArgumentParser()
    ap.add_argument("--docs", type=Path, default=BASE / "Dokumente", help="documents folder")
    ap.add_argument("--index", type=Path, default=None,
                    help="Code_Index.csv (default: only used with the demo data)")
    ap.add_argument("--port", type=int, default=8010)
    ap.add_argument("--cors", action="store_true", help="allow Flutter web (Chrome) on localhost")
    args = ap.parse_args()

    docs_dir = args.docs.resolve()
    index_path = args.index or (BASE / "Code_Index.csv" if docs_dir == (BASE / "Dokumente") else None)

    PAGES, FAILED = load_pages(docs_dir)
    mcp = FastMCP("code-lookup-demo", host="127.0.0.1", port=args.port)

    @mcp.tool()
    def search_knowledge_base(query: str, top_k: int = 5) -> str:
        """Keyword search over the documents (page level). Returns source + page + text."""
        terms = [t.lower() for t in re.findall(r"\w[\w.-]*", query) if len(t) > 1]
        scored = []
        for p in PAGES:
            low = p["text"].lower()
            score = sum(low.count(t) for t in terms)
            if score:
                scored.append({**p, "text": p["text"][:2000], "score": score})
        scored.sort(key=lambda x: -x["score"])
        return json.dumps({"query": query, "treffer": scored[:top_k]}, ensure_ascii=False)

    if index_path and index_path.exists():
        INDEX = load_index(index_path, index_path.parent)

        @mcp.tool()
        def lookup_code(code: str) -> str:
            """Look up an exact code, e.g. DMX-2001, TRMA-26014, KBX-104A, FWV 3.14.
            A family name alone (e.g. "KBX") returns aehnliche_codes."""
            key = _norm(code)
            if key in INDEX:
                hits = sorted(INDEX[key], key=lambda h: (h["archiv"], h["filepath"], h["page_num"]))
                return json.dumps({"code": key, "anzahl": len(hits), "treffer": hits}, ensure_ascii=False)
            similar = sorted(c for c in INDEX if c.startswith(key))
            return json.dumps({"code": key, "anzahl": 0, "treffer": [], "aehnliche_codes": similar},
                              ensure_ascii=False)

        print(f"lookup_code: {len(INDEX)} codes from {index_path}")
    else:
        print("lookup_code: off (no Code_Index.csv) - knowledge base only")

    print(f"search_knowledge_base: {len(PAGES)} pages from {docs_dir}")
    for msg in FAILED:
        print("  skipped", msg)
    print(f"MCP server: http://127.0.0.1:{args.port}/mcp")

    if args.cors:
        # Flutter web (Chrome): the browser only lets the app read the answer if the
        # server allows the app's origin. Only localhost origins are allowed.
        import uvicorn
        from starlette.middleware.cors import CORSMiddleware

        app = CORSMiddleware(
            mcp.streamable_http_app(),
            allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
            allow_methods=["GET", "POST", "DELETE", "OPTIONS"],
            allow_headers=["*"],
            expose_headers=["Mcp-Session-Id"],  # the app must be able to read the session ID
        )
        print("CORS on (for flutter run -d chrome)")
        uvicorn.run(app, host="127.0.0.1", port=args.port, log_level="warning")
    else:
        mcp.run(transport="streamable-http")

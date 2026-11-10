# Code Lookup

A small Flutter app that searches documents through an MCP server (Model Context Protocol).
Includes a minimal Python MCP server that indexes a folder of `.docx`, `.pdf`, `.txt` and `.md` files.

```
Flutter app (Chrome)  ->  HTTP (MCP)  ->  server.py  ->  documents folder
```

## Requirements

- [Flutter SDK](https://docs.flutter.dev/install) (3.47.8 or newer), with `flutter\bin` on your PATH
- Chrome
- Python 3.10+
- Optional: Visual Studio 2022 with "Desktop development with C++" to build a Windows app

## Setup

**1. Server**

```
cd server
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python server.py --cors
```

Uses the demo documents in `server/Dokumente`. For your own folder:

```
python server.py --cors --docs "C:\path\to\documents"
```

The server listens on `http://127.0.0.1:8010/mcp` (localhost only).

**2. App** (second terminal, in the project root)

```
flutter pub get
flutter run -d chrome --dart-define=MCP_URL=http://127.0.0.1:8010/mcp
```

Search for a word from your documents, e.g. `Display flackert` for the demo data.

## Tests

```
flutter test
```

## Notes

- The demo documents and codes are fictional.
- `--cors` is needed for Chrome and only allows `localhost` origins.
- Scanned PDFs without a text layer are skipped (no OCR).
- Code lookup (`lookup_code`) is only available with the demo data: run without `--docs` and start the app with `--dart-define=TOOL=lookup_code`.

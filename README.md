# Code Lookup

A small Flutter app that searches documents through an MCP server (Model Context Protocol).
Includes a Python MCP server that indexes a folder of `.docx`, `.pdf`, `.txt` and `.md` files.

```
Flutter app (Chrome)  ->  HTTP (MCP)  ->  server.py  ->  documents folder
```

## Features

- Full-text search over a documents folder, results as cards with file, page and preview
- Search words highlighted in results and on the detail page
- Detail page with full text and a copy-path button
- Search history (last 10, saved in the browser)
- Settings: dark mode and server URL, both saved
- MCP client in Dart (`lib/services/mcp_client.dart`)

## Project structure

```
lib/
  main.dart        app start, themes, settings
  config.dart      constants
  models/          SearchHit
  services/        MCP client
  screens/         search, detail, settings
  widgets/         HitCard
  utils/           highlighting
server/            Python MCP server + demo data
test/              unit and widget tests
```

## Requirements

- [Flutter SDK](https://docs.flutter.dev/install) (3.47.8 or newer), with `flutter\bin` on your PATH
- Chrome
- Python 3.10+


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

- The documents and codes are fictional.
- `--cors` is needed for Chrome and allows `localhost` origins.
- Scanned PDFs without a text layer are skipped because OCR isn't part.

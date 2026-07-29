#!/usr/bin/env bash
# Serve the sample web fixture on :8765 (for Playwright evidence-capture dogfooding).
cd "$(dirname "$0")" && exec python3 -m http.server 8765

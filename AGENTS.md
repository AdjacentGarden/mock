# CloudPath Mock

- This repository is the standalone mock client for AdjacentGarden/LLM_Study_App.
- Keep all app flows local in Debug and Release. Do not connect to a real backend, OCR service, model provider, or API key.
- Keep presets, delays, and simulated processing in frontend/Mock and bundled resources. Preserve the frontend service boundary for later integration.
- PDF originals stay on the device. Upload/preparation/generation progress is simulated; do not parse a PDF to generate teaching content.
- After adding Swift files, run `python3 frontend/scripts/generate-project.py`.
- The generated test targets intentionally include Mock*.swift only. Production protocol tests are retained for reference and are not acceptance tests for this mock app.
- Run mock integration/UI tests on an explicitly selected, isolated simulator. Do not contact deployment hosts or reuse production credentials.

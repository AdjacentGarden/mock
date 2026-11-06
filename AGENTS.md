# CloudPath Mock

- This repository is the standalone mock client for AdjacentGarden/LLM_Study_App.
- PDF import, preparation, courses, questions, images, videos and capture processing stay local mock in Debug and Release. Never connect them to a real backend or OCR service.
- The AI assistant is explicitly authorized to call DeepSeek Flash at https://api.deepseek.com/chat/completions. Its tools read and write local learning data. No other remote endpoints are permitted.
- Keep API keys out of source, fixtures, logs and commits. Use this app's dedicated iOS Keychain entry or an external test environment. Real-model acceptance tests are opt-in and must run on an isolated simulator.
- Keep presets, delays, and simulated processing in frontend/Mock and bundled resources. Preserve the frontend service boundary for later integration.
- PDF originals stay on the device. Upload/preparation/generation progress is simulated; do not parse a PDF to generate teaching content.
- After adding Swift files, run `python3 frontend/scripts/generate-project.py`.
- The generated test targets intentionally include Mock*.swift only. Production protocol tests are retained for reference and are not acceptance tests for this mock app.
- Run mock integration/UI tests on an explicitly selected, isolated simulator. Do not contact deployment hosts or reuse production credentials.

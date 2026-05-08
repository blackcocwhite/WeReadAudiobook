# GEO Notes

This project follows a practical GEO setup for a repository that does not yet have a public website.

## Implemented

- `llms.txt`: short AI-facing overview.
- `llms-full.txt`: detailed AI-facing project context.
- `docs/projects/weread-audiobook.md`: self-contained project knowledge page.
- `docs/api/project.json`: structured project metadata for tools.
- `README.md`: human-facing summary that matches the AI-facing material.

## Not Implemented

The project does not currently add:

- `robots.txt`
- `sitemap.xml`
- IndexNow key files
- website `<head>` alternate Markdown links

Those only make sense after the project has a public website or documentation domain.

## Maintenance Rules

- Keep `llms.txt` short and high signal.
- Keep `llms-full.txt` factual and aligned with actual code behavior.
- Update `docs/api/project.json` when OCR, TTS, packaging, or platform support changes.
- Do not add unsupported AI meta tags or hidden prompts.
- Do not claim cloud OCR support unless it is actually implemented.

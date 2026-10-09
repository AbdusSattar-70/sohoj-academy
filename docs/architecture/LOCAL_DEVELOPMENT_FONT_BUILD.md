# Local development font build

`pnpm dev` uses the webpack engine, matching `pnpm build`. This avoids the Next 16.3.5 Turbopack Google-font import-map failure while retaining Montserrat and Noto Sans Bengali typography.

Stop the running development server, then run `pnpm dev` after pulling. If stale generated files remain, remove `.next` with the server stopped and restart. Do not remove database data or migration history. Google font downloading still requires network access during compilation; this is an engine workaround, not offline font bundling.

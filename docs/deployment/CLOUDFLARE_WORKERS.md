# Sohoj Academy — Cloudflare Workers deployment runbook

Status: **prepared / not deployed**. Source branch: `feature/cloudflare_deployment`. Domain: `sohojac.com`.

This is a deployment of the **existing** Next.js 16 application (public website and `/dashboard` ERP) with the **existing Supabase PostgreSQL and Supabase Auth**. Do not recreate the application, reset the database, change the public/ERP routing, or migrate to D1. Never commit credentials or point untested versions at the live domain.

## Verified baseline

The original Next.js/webpack project passed `pnpm check` except for ESLint warnings reported on 25 October 2026; targeted warning cleanups have since been committed to this branch. Local verification against the cleanup commits is still required. The standard Next.js scripts remain available.

## 1. Sync and verify locally

```bash
git fetch origin
git switch feature/cloudflare_deployment
git pull --ff-only origin feature/cloudflare_deployment
pnpm install --frozen-lockfile
pnpm check
```

The `lint` script uses `--max-warnings 0`. Stop if any check fails. Keep changes on this branch only.

## 2. Use the current official vinext initializer

Cloudflare recommends vinext for existing Next.js 16 Workers applications. Vinext runs alongside Next.js instead of rewriting the application. The current initializer generates the required Vite and typed Cloudflare configuration; **do not hand-write a guessed Wrangler/vinext config**.

```bash
pnpm dlx vinext check
pnpm dlx vinext init --platform=cloudflare
```

Review all compatibility findings and generated file changes before going further. For the initial smoke test, favor the simplest supported cache configuration; avoid unnecessary paid R2/KV/Response Store resources until needed.

```bash
pnpm dev:vinext
pnpm build:vinext
```

The initializer should create/update `vite.config.ts`, `cloudflare.config.ts`, scripts and dependencies. If it directs you to include `.cloudflare/types` in `tsconfig.json`, follow the generated guidance and use `pnpm exec cf workers types` before standalone type checking. Do not manually run `next build` as a substitute for the Workers/Vite build.

### Critical smoke tests

- Public: homepage, Bangla/English toggle, programme cards, FAQ, interest and admission request.
- Supabase: public catalogue RPCs; validated form submission; authorization boundaries.
- ERP: sign-in, recovery link, `/dashboard` authentication and role permissions; admissions; students; payment/receipt workflows.
- File/print routes, including `/api/finance/documents`, and the existing `proxy.ts` logic.
- Security: anonymous users cannot access student, guardian, staff, invoice or accounting data.
- Runtime: test Workers runtime and limits; a successful conventional Next.js/webpack build does not prove Workers compatibility.

## 3. Use a temporary Cloudflare Worker first

Sign in using the CLI installed by the initializer:

```bash
pnpm exec cf auth login
```

Set the Cloudflare account ID as directed by the generated `cloudflare.config.ts`, or via a local `CLOUDFLARE_ACCOUNT_ID` environment variable. Do not commit account tokens.

Configure production/build variables and secrets for the new Worker, using the same Supabase project as in the existing local environment:

- `NEXT_PUBLIC_SUPABASE_URL` — publishable project URL
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` — publishable key
- `NEXT_PUBLIC_SITE_URL` — **actual** test Worker URL during testing; change to `https://sohojac.com` only for the custom-domain build
- `SUPABASE_SECRET_KEY` — **secret** (or documented legacy `SUPABASE_SERVICE_ROLE_KEY`, not both unless needed)

Never put privileged Supabase keys in `NEXT_PUBLIC_*` variables, public git files, or example values that may be real. Review generated Vite env conventions: public variables may need to exist at **build time** as well as Workers runtime. Do not rely on a local `.env.local` being transferred automatically.

Deploy initially to the temporary Worker / test URL (not the custom domain):

```bash
pnpm dlx @vinext/cloudflare deploy
```

If the initializer provides a `deploy:vinext` script, it may be used instead. Do not deploy until `pnpm build:vinext` passes. Production deploy requires your Cloudflare authentication/permissions and cannot be completed by editing GitHub alone.

## 4. Auth and domain cutover

During testing add the exact Worker URL to **Supabase Auth** permitted redirect URLs. Verify secure cookies, invite/forgot-password callbacks and staff authentication. Do not loosen authorization or disable server-side permission checks to make the test pass.

Once every critical flow works:
1. Update `NEXT_PUBLIC_SITE_URL` to `https://sohojac.com` for the production build, and configure Supabase site URL and exact redirect allowlist.
2. In Cloudflare, bind `sohojac.com` to the tested Worker. Optionally redirect `www.sohojac.com` to the apex.
3. Confirm DNS, HTTPS, application routes, authentication and forms.
4. Avoid changing the domain's MX, SPF, DKIM, DMARC or Email Routing records unintentionally.

If something breaks, return the domain route to the previous safe configuration; no database reset should be required.

## 5. GitHub integration — after initializer succeeds

Commit the **generated non-secret** Cloudflare/Vite config files, lockfile and scripts:

```bash
git status
git diff --check
git add package.json pnpm-lock.yaml vite.config.ts cloudflare.config.ts tsconfig.json .gitignore
# Adjust the list to include only generated files that actually exist.
git commit -m "build: initialize Cloudflare Workers deployment with vinext"
git push origin feature/cloudflare_deployment
```

Configure Workers Builds/GitHub CI for this branch, using the script **actually generated** by your vinext version. Cloudflare's tooling is evolving; avoid assuming an older Wrangler `wrangler.jsonc` workflow when the generated project uses `cloudflare.config.ts` and `cf`. Build-time values and runtime secrets have separate settings.

## 6. Operational readiness

Use distinct test/live configuration when possible. Never insert fake student records into live production. Keep independent Supabase backups. Workers Free tier may be insufficient for CPU-heavy SSR and PDF processing; test realistic workloads before declaring production ready. Hosting/registrar do not themselves provide transactional SMS or mailbox hosting.

References:
- https://developers.cloudflare.com/workers/framework-guides/web-apps/nextjs/
- https://vinext.dev/docs/getting-started/migrating
- https://vinext.dev/docs/deploying/cloudflare
- https://developers.cloudflare.com/workers/ci-cd/builds/configuration/

## Troubleshooting: vinext init completed, but dev/build says ERR_UNKNOWN_FILE_EXTENSION

If `vite dev` or `vite build` reports `Unknown file extension ".ts" for cloudflare.config.ts`, first check `node --version`. The new Cloudflare `cf` programmatic config requires Node.js 22.18+. Our deployment branch includes an `.nvmrc` requesting Node 24 LTS. Run `nvm install` and `nvm use` if nvm is installed.

Vite's native config loader and Node's module resolution also require an explicit extension on the generated import. In `vite.config.ts`, replace an existing `./cloudflare.config` import with `./cloudflare.config.ts`. Do not change the generated config's worker definitions blindly. `tsconfig.json` enables `allowImportingTsExtensions` and includes `.cloudflare/types` on this branch.

If pnpm warns about blocked build scripts for `workerd`, review and approve trusted Cloudflare package scripts with `pnpm approve-builds`, followed by `pnpm install`. npm registry `ECONNRESET` errors are network/registry errors, not application compilation errors; retry failed installs after connectivity recovers.

Then run `pnpm dev:vinext` and `pnpm build:vinext` again. Verify all workflows before deployment.

### Initial low-cost setup advice

The first initialization may have enabled Workers Response Store (requires a second Worker, R2 and a SQLite Durable Object), Cloudflare Images, prerendering and cache warming. These are optional; `vinext` supports no persistent cache and can run without an image optimizer. Consider simplifying the generated config after reviewing it, rather than paying for extra services or assuming the generator's choices are required.

Sources: https://developers.cloudflare.com/cf/projects/cloudflare-config/ and https://vinext.dev/docs/guides/caching

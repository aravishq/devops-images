# devops-images

Public container images for the CI pipelines of Aravis projects. GitHub Actions
builds them and publishes them to the GitHub Container Registry.

## Images

### `ghcr.io/aravishq/devops/php`

Lean PHP CLI image for CI jobs (tests, code style, `composer install`), based on
the official `php:<version>-cli` image (Debian).

| Contents   |                                                                               |
| ---------- | ----------------------------------------------------------------------------- |
| Extensions | bcmath, gd, intl, pcntl, pdo_mysql, pdo_pgsql, redis, soap, sockets, xsl, zip |
| Tools      | composer, curl, git, tar, unzip, xz                                           |
| Versions   | 8.1, 8.3, 8.4, 8.5                                                            |
| Platforms  | linux/amd64, linux/arm64 (Docker picks the right one)                         |

Tags per version, for example for 8.4:

| Tag      | Meaning                                                                         |
| -------- | ------------------------------------------------------------------------------- |
| `8.4`    | Latest weekly build of PHP 8.4; use this in pipelines                           |
| `8.4.27` | Latest build of that exact PHP release; deleted six months after its last build |

A patch tag keeps receiving the weekly Debian updates as long as it is the
current release of its version.

Usage in `.gitlab-ci.yml`:

```yaml
tests:
  image: ghcr.io/aravishq/devops/php:8.4
```

### Variant with Node.js: `8.4-node`

The same image plus Node.js (current LTS) with npm and npx, for jobs that need
both, such as a Vite build that runs `php artisan` (Laravel Wayfinder). Built
for PHP 8.4 only; more versions are one line in `NODE_PHP` in the workflow.

| Tag          | Meaning                                                                                                   |
| ------------ | --------------------------------------------------------------------------------------------------------- |
| `8.4-node`   | Always the current Node.js LTS (now 26); moves to the next LTS in October, when Node.js promotes it      |
| `8.4-node26` | Node.js 26; deleted six months after its last build, so six months after the next LTS takes over         |

Node is copied from the official `node:lts-trixie-slim` image (same Debian as
the PHP image), so the weekly build also picks up Node patches. A job that
breaks on a new Node major can pin to the `-node<major>` tag for a while.

Usage in `.gitlab-ci.yml`:

```yaml
frontend:
  image: ghcr.io/aravishq/devops/php:8.4-node
```

PHP 8.1 is end-of-life: its official base image is no longer rebuilt, so the
weekly build only picks up Debian updates (`apt-get upgrade`), no PHP fixes.

## How it builds

`.github/workflows/php.yml` runs:

- on every pull request: build and test, and a dry run of the cleanup (the log
  shows what it would delete);
- on every push to `main`, every Monday at 03:17 UTC and on demand
  (Actions, "Run workflow"): build, test, publish and clean up.

| Job       | What it does                                                                                                                                           |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `build`   | Builds and tests every version on a native amd64 and a native arm64 runner, then pushes each image without a tag (by digest).                         |
| `publish` | Combines both architectures of a version into the tags above. A version is only published when both its builds succeeded; the others go ahead anyway. |
| `cleanup` | Deletes images nothing points to any more (previous weekly builds), and patch and `-node<major>` tags six months after their last build. Skipped when a publish failed. |

The cleanup uses
[dataaxiom/ghcr-cleanup-action](https://github.com/dataaxiom/ghcr-cleanup-action),
which understands multi-arch images: it never deletes the platform images of a
tagged image. Untagged platform entries can still show up in the package list
on GitHub; that is expected. Deleted versions can be restored for 30 days via
the GitHub API; the cleanup log lists their IDs.

Each build starts from a freshly pulled base image without cache, so PHP and
Debian security updates are included. `php/test.sh` fails the build when a
tool or extension is missing; `php/test-node.sh` also checks node, npm and npx. Dependabot keeps the GitHub Actions and the
`php-extension-installer` pin up to date.

GitHub disables scheduled workflows in a public repository after 60 days
without activity (it e-mails a warning first). Merging a Dependabot pull
request or re-enabling the workflow under Actions resets that.

## Adding an extension or version

- Extension: add it to the `install-php-extensions` line in `php/Dockerfile`
  and to the list in `php/test.sh`.
- PHP version: add it to both `matrix.php` lists in `.github/workflows/php.yml`
  (jobs `build` and `publish`) and to the table above. Remove a version the same
  way; its minor tag (for example `8.1`) then stays until you delete it under
  the package on GitHub.

Test locally:

```sh
docker build --target php --build-arg PHP_VERSION=8.4 -t php-test:8.4 php
php/test.sh php-test:8.4

docker build --target php-node --build-arg PHP_VERSION=8.4 -t php-node-test:8.4 php
php/test-node.sh php-node-test:8.4
```

Always pass `--target`: without it Docker builds the last stage, `php-node`.

To unpack an archive in a CI job, use `tar` (`tar -xzf`, `tar -xJf`). Do not
use PHP's `PharData`: it turns symlinks into empty executable files, so for
example `npm` from a Node tarball then exits 0 without doing anything.

Never put secrets or customer-specific files in these images: they are public.

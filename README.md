# devops-images

Public container images for the CI pipelines of Aravis projects. GitHub Actions
builds them and publishes them to the GitHub Container Registry.

## Images

### `ghcr.io/aravishq/devops/php`

Lean PHP CLI image for CI jobs (tests, code style, `composer install`), based on
the official `php:<version>-cli` image (Debian).

| Contents   |                                                                   |
| ---------- | ----------------------------------------------------------------- |
| Extensions | bcmath, gd, intl, pcntl, pdo_mysql, pdo_pgsql, redis, zip         |
| Tools      | composer, git, unzip                                              |
| Versions   | 8.1, 8.3, 8.4, 8.5                                                |

Tags per version, for example for 8.4:

| Tag              | Meaning                                                    |
| ---------------- | ---------------------------------------------------------- |
| `8.4`            | Latest weekly build of PHP 8.4; use this in pipelines      |
| `8.4.27`         | Latest build of that exact PHP release                     |
| `8.4-20261123`   | Build of that date; never overwritten, for pinning         |

Usage in `.gitlab-ci.yml`:

```yaml
tests:
  image: ghcr.io/aravishq/devops/php:8.4
```

PHP 8.1 is end-of-life: its official base image is no longer rebuilt, so the
weekly build only picks up Debian updates (`apt-get upgrade`), no PHP fixes.

## How it builds

`.github/workflows/php.yml` runs:

- on every pull request: build and test, no push;
- on every push to `main`, every Monday at 03:17 UTC and on demand
  (Actions, "Run workflow"): build, test and push.

Each build starts from a freshly pulled base image without cache, so PHP and
Debian security updates are included. `php/test.sh` fails the build when a
tool or extension is missing. Dependabot keeps the GitHub Actions and the
`php-extension-installer` pin up to date.

GitHub disables scheduled workflows in a public repository after 60 days
without activity (it e-mails a warning first). Merging a Dependabot pull
request or re-enabling the workflow under Actions resets that.

## Adding an extension or version

- Extension: add it to the `install-php-extensions` line in `php/Dockerfile`
  and to the list in `php/test.sh`.
- PHP version: add it to `matrix.php` in `.github/workflows/php.yml` and to the
  table above.

Test locally:

```sh
docker build --build-arg PHP_VERSION=8.4 -t php-test:8.4 php
php/test.sh php-test:8.4
```

Never put secrets or customer-specific files in these images: they are public.

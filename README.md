# devops-images

PHP CLI images for the GitLab CI jobs of Aravis projects.

- Use `ghcr.io/aravishq/devops/php:8.4` for a PHP 8.4 job.
- Use `ghcr.io/aravishq/devops/php:8.4-node` when the same job also needs
  Node.js.

The images are public: no login is needed to pull them. They are rebuilt
every week, so new PHP, Debian and Node.js patches arrive without anyone
changing a pipeline.

## Using the images

### PHP image

Based on the official `php:<version>-cli-trixie` image (Debian 13).

| Contents   |                                                                               |
| ---------- | ----------------------------------------------------------------------------- |
| Extensions | bcmath, gd, intl, pcntl, pdo_mysql, pdo_pgsql, redis, soap, sockets, xsl, zip |
| Tools      | composer, curl, git, tar, unzip, xz; gcc, g++ and make from the base image    |
| Versions   | 8.1, 8.3, 8.4, 8.5                                                            |
| Platforms  | linux/amd64 and linux/arm64; Docker picks the right one                       |

`COMPOSER_ALLOW_SUPERUSER=1` is set, so Composer runs as root without a
warning.

Tags, for PHP 8.4 as an example:

| Tag      | Meaning                                                                  |
| -------- | ------------------------------------------------------------------------ |
| `8.4`    | The latest build of PHP 8.4. Use this in pipelines.                      |
| `8.4.28` | PHP 8.4.28 exactly. Other packages in the image can change when rebuilt. |

Each build updates both tags. When PHP 8.4.29 comes out, `8.4` moves to it and
`8.4.28` stops changing. Old patch tags are deleted after a while (see
[Cleanup](#cleanup)).

PHP 8.1 is end-of-life and gets no PHP fixes any more. Rebuilds still update
the Debian packages, Composer and the redis extension.

Example:

```yaml
tests:
  image: ghcr.io/aravishq/devops/php:8.4
  script:
    - composer install --no-interaction
    - vendor/bin/phpunit
```

### PHP with Node.js: `8.4-node`, `8.5-node`

The PHP image plus Node.js, npm, npx and python3. Use it when one job needs
PHP and Node.js together. For example, a Vite build with Laravel Wayfinder runs
`php artisan` during the build.

| Tag          | Meaning                                                                         |
| ------------ | ------------------------------------------------------------------------------- |
| `8.4-node`   | PHP 8.4 with the current Node.js LTS release, now 26. Use this in pipelines.    |
| `8.4-node26` | PHP 8.4 with Node.js 26. Gets the same updates as `8.4-node` while 26 is the LTS. |

Node.js names a new LTS release every October. The build then picks it up, and
`8.4-node` moves to it with the next successful build. If your build breaks on
the new Node.js version, switch to `8.4-node26` for a short while. Do not stay
on it: once 26 is no longer the LTS, `8.4-node26` gets no more updates, and it
is deleted after about six months (see [Cleanup](#cleanup)). A pipeline that
still uses it then fails.

Example for a project with `composer.json`, `package-lock.json` and an npm
`build` script:

```yaml
frontend:
  image: ghcr.io/aravishq/devops/php:8.4-node
  script:
    - composer install --no-interaction
    - npm ci
    - npm run build
```

### Native npm modules

Some npm packages contain C or C++ code. Most of them ship a ready-made binary.
When there is none for the platform, npm compiles the code with node-gyp. That
needs python3, a compiler and the Node.js headers, and all of them are in the
image.

node-gyp normally downloads the headers from nodejs.org. In this image they are
already in its cache (`/root/.cache/node-gyp`), so the compile also works
without network access. Two exceptions: the cache is only used when the job
runs as root (the default in GitLab CI), and only by the node-gyp version that
comes with npm. Other cases download the headers as usual. A package can also
need system libraries that the image does not have.

### Unpacking archives

Use `tar`, for example `tar -xzf tools.tar.gz` or `tar -xJf tools.tar.xz`. Do
not use PHP's `PharData`: it turns symbolic links into empty files. In a
Node.js archive, `bin/npm` is such a link. After `PharData`, `npm` exits without
an error but does nothing.

## Maintaining the images

### When the workflow runs

`.github/workflows/php.yml` builds, tests and publishes the images.

- **On `main`**: after a push, every Monday at 03:17 UTC, or with "Run
  workflow". It builds, tests, publishes, cleans up and verifies.
- **On a pull request, or "Run workflow" on another branch**: it builds and
  tests, but pushes nothing. The cleanup runs as a dry run: its log shows what
  it would delete. A plain push to another branch does not start the workflow.

Two runs on `main` never run at the same time. A newer run does not cancel a
run that has started. GitHub keeps at most one waiting run: when a second one
is queued, it replaces the first waiting run. On pull requests and other
branches, a newer run cancels the older one.

### Jobs

- **`setup`**: reads the PHP versions from `PHP_VERSIONS`. Stops the run if
  `NODE_PHP` has a version that is not in `PHP_VERSIONS`.
- **`build`**: builds each PHP version on an amd64 and an arm64 runner. The
  PHP image always starts from freshly pulled base images and an empty cache.
  The Node.js image pulls the latest Node.js image and reuses the PHP part that
  was just built. On `main`, each image is pushed without a tag first, and then
  exactly that image is tested.
- **`publish`**: gives the tested amd64 and arm64 images their tags. Each
  image is published only when its amd64 and arm64 builds both passed their
  tests and contain the same PHP version (and, for the Node.js image, the same
  Node.js version). One failure does not block the rest: if the `8.4-node`
  build fails, `8.4` and the 8.5 images are still published. The run is then
  marked as failed.
- **`cleanup`**: deletes images that are no longer needed. See
  [Cleanup](#cleanup).
- **`verify`**: checks that every minor tag exists (`8.4`, `8.4-node` and so
  on), and that every tag has a readable linux/amd64 and linux/arm64 image. It
  does not check that this run updated the tag; an older image also passes.

### Tests

`php/test.sh` checks the PHP version, the extensions, the tools and the CA
certificates. It checks what each tool prints, not only that it exits without
an error. That catches an empty executable file, which exits without an error
but does nothing.

`php/test-node.sh` runs those checks too. It also checks node, npm, npx and
python3, and compiles the small module in `php/test-fixtures/native-addon`
without network access, then loads it.

### Cleanup

The `cleanup` job uses
[dataaxiom/ghcr-cleanup-action](https://github.com/dataaxiom/ghcr-cleanup-action)
version 1.2.2. It deletes:

- **Untagged images older than one day.** These come from earlier builds and
  from builds whose tests failed. The day protects the images of a run that is
  still publishing. Untagged amd64 and arm64 images that belong to a tagged
  image are kept.
- **Images with a patch tag or Node.js major tag** (`8.4.27`, `8.4-node26`),
  six months after GHCR last changed them.

An image that also has a minor tag (`8.4`, `8.4-node`) is never deleted. The
rules only delete whole images. They never remove one tag from an image that
keeps another tag, because version 1.2.2 of the action can then delete the
whole image. That bug is fixed in the action's source code (November 2026),
but not yet in a release.

The action checks its own result, but only warns when something is wrong. The
`verify` job is there to make the run fail in that case.

The cleanup also runs when publishing failed or was skipped. Otherwise one
broken version would stop the cleanup every week. The one-day rule keeps this
safe.

On the package page, untagged entries are normal: most are the amd64 and
arm64 parts of a tagged image, the rest are left over from failed builds.

GitHub does not allow deleting a public package version with more than 5,000
downloads. If the cleanup fails for that reason, exclude that version or ask
GitHub Support.

A deleted version can be restored with the GitHub API within 30 days, by an
organization admin. The cleanup log lists the IDs of deleted versions.

### Settings on GitHub

These are not in the repository, so check them when something stops working:

- The package `devops/php` is **Public** (package settings). The workflow does
  not set this.
- Under the package settings, **Manage Actions access** gives this repository
  the **Admin** role. The cleanup needs this to delete versions.
- GitHub turns off the weekly schedule of a public repository after 60 days
  without activity. Merging a Dependabot pull request counts as activity. To
  turn it on again: **Actions**, select **php**, then **Enable workflow**.

Dependabot checks every month for new versions of the GitHub Actions (pinned to
commit hashes in the workflow) and of `mlocati/php-extension-installer`
(pinned to version 2.13.2 in the Dockerfile).

### Adding or removing a PHP version or extension

- **Add an extension:** add it to the `install-php-extensions` line in
  `php/Dockerfile` and to the list in `php/test.sh`.
- **Add a PHP version:** add it to `PHP_VERSIONS` in
  `.github/workflows/php.yml`. Add it to `NODE_PHP` too if it needs the Node.js
  image. Update the version list in this README.
- **Remove a PHP version:** remove it from `PHP_VERSIONS` and `NODE_PHP`. The
  cleanup never deletes minor tags, so delete the old images (`8.1`,
  `8.1-node`) by hand on the package page.
- **PHP 8.6:** released on 19 November 2026, but not built yet. On 20 November
  2026 the latest redis extension (phpredis 6.3.0) did not compile against it.
  Try again when a newer phpredis is released.

The PHP and Node.js base images must use the same Debian release: the Node.js
binary is copied into the PHP image and uses its system libraries. Both follow
the `DEBIAN` build argument in the Dockerfile (now `trixie`).

### Testing locally

Run from the repository root. This tests the architecture of your own machine.

```sh
docker build --pull --no-cache --target php --build-arg PHP_VERSION=8.4 -t php-test:8.4 php
php/test.sh php-test:8.4

docker build --pull --target php-node --build-arg PHP_VERSION=8.4 -t php-node-test:8.4 php
php/test-node.sh php-node-test:8.4
```

Always pass `--target`. Without it Docker builds the last stage, `php-node`.

Never put secrets or customer-specific files in these images. They are public.

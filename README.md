# Shunter

Public distribution of Shunt binaries, installers and the install-and-run
GitHub Action. The Flow application's source repository remains private.

Release packages contain the runner, HTML report resources, Python worker and
a pinned, relocatable CPython runtime with its upstream license notices. Consumers
do not install Qt, a compiler, pip packages or a separate Python interpreter.
Project-specific build tools and third-party Python modules remain project
dependencies.

## GitHub Actions

Choose an exact published four-part runner version from Releases and set the
repository variable `SHUNT_RUNNER_VERSION` to a compatible release. The action
version and runner version are independent; runner versions never resolve to
`latest` implicitly.

```yaml
name: Build
on: [push, pull_request, workflow_dispatch]
permissions:
  contents: read
jobs:
  build:
    runs-on: ubuntu-22.04 # or windows-latest
    steps:
      - uses: actions/checkout@v4
      # Install your project's build tools here, if needed.
      # Pin the published action and an exact compatible runner release.
      - uses: jlindrud/flow-runner@v2
        with:
          version: ${{ vars.SHUNT_RUNNER_VERSION || '0.1.0.18' }}
          repository: jlindrud/flow-runner
          file: build.flowbook
          flow: Build
```

The action downloads and verifies the selected package (or reuses its cache),
runs the Flow, uploads the HTML report without a ZIP wrapper, and links it from
the native job summary. A failed Flow still uploads/publishes its report and
keeps the step failed. GitHub controls the final artifact viewing/download UI;
the action does not host private logs on a public website.

Optional inputs: `variables` (one `name=value` per line), `report` (default
`.flow/report.html`), and `artifact-name` (an optional friendly filename;
otherwise a unique name is generated). Use distinct report paths and explicit
artifact names for multiple Flows/matrix jobs in one run. The action copies only
the generated HTML to a non-hidden upload path: it does not expose the rest of
the `.flow` directory. Unarchived artifacts use that file's basename as their name.
The `report-url` output contains the uploaded HTML artifact URL.

GitHub's cache stores the complete installed package by exact version, OS and
architecture. Fresh hosted machines restore it from GitHub's cache service;
self-hosted runners may also retain their local cache. A cache miss downloads
the package again. No credentials are needed to download these public releases.
GitHub Windows runners need Git Bash (included on hosted runners); unsupported
OS/architectures are not silently redirected to another binary.

## Other CI platforms and local installation

Shunt's `--ci-setup` command generates the bootstrap and platform collection
configuration. These installers are the same ones used by the GitHub Action:
set `SHUNT_RUNNER_VERSION` to an exact published release that supports this
Flowbook format (`export SHUNT_RUNNER_VERSION=<version>` in a POSIX shell or
`$env:SHUNT_RUNNER_VERSION = '<version>'` in PowerShell).

```sh
curl --fail --location https://raw.githubusercontent.com/jlindrud/flow-runner/main/install.sh -o install-shunt.sh
export SHUNTER_REPOSITORY=jlindrud/flow-runner
runner=$(sh install-shunt.sh "$SHUNT_RUNNER_VERSION")
"$runner" build.flowbook --flow Build
```

```powershell
Invoke-WebRequest https://raw.githubusercontent.com/jlindrud/flow-runner/main/install.ps1 -OutFile install-shunt.ps1
$env:SHUNTER_REPOSITORY = 'jlindrud/flow-runner'
$runner = & ./install-shunt.ps1 -Version $env:SHUNT_RUNNER_VERSION
& $runner build.flowbook --flow Build
exit $LASTEXITCODE
```

`run`, `validate`, `ci-setup`, and `publish-summary` are subcommands. Passing the
Flowbook file as the first argument still runs it.

Linux needs a normal glibc-based x64 agent with `/bin/sh`, `curl`, `tar`, and
`sha256sum`. Windows needs
x64 Windows with PowerShell 5.1+ (or pwsh) and HTTPS access. Release validation
targets Windows Server 2022 and Ubuntu 22.04/24.04; Alpine/musl, ARM and macOS
packages are not provided. HTTP proxies, outbound access and platform agent
permissions remain installation-level requirements.

Set `SHUNTER_CACHE` to choose the cache directory (Linux defaults to the user
cache, Windows to LocalAppData). Set the required `repository` action input to
the `owner/repository` that publishes the release assets. Install scripts also
require `SHUNTER_REPOSITORY` when called directly. The action source requires
the matching `repository` input and passes it through to the installer. Downloads use HTTPS
and SHA256 sidecars from that repository; checksums detect corruption, not a
compromised publisher. Installs use a staging directory and refuse to replace
an incomplete or pre-existing installation. Public release assets are treated as
immutable. No automatic upgrades occur.

Shunter uses the bundled interpreter for Python tasks and conditions.
`SHUNTER_PYTHON` can explicitly choose another interpreter, and
`SHUNTER_PYTHON_WORKER` can choose another worker script. `SHUNTER_RUNTIME_PYTHON`
is set by the installer for the action's own runtime. These overrides are not necessary for normal use.
They do not install project dependencies or put a `python` command on the project
shell's PATH.

## Validation

Release `0.1.0.1` passed the
[clean consumer matrix](https://github.com/jlindrud/flow-runner/actions/runs/38716589586)
on Windows Server 2022 and Ubuntu 22.04/24.04. These tests include successful and
deliberately failed Flows, Python tasks/conditions, HTML artifact URLs and a
second cached installation, with no access to the private Flow source repository.

The manually dispatched `Clean consumer validation` workflow exercises a selected
public release on fresh Windows/Linux hosted agents, including a deliberate
failure, report upload, report URL handoff and a second cached installation.
It uses only this public distribution repository, not the private source tree.
Bamboo/Jenkins/GitLab/Azure server-side validation remains pending access to those
installations; generated integration is not a claim of live server testing.
## Prepared action v1.1: project artifacts

New runners emit `flow_artifacts` when a Publish Artifact task stages project
files. This action forwards that native output and uploads the complete root as
one `Shunter-Artifacts-<run number>-<attempt>` artifact, separately from the HTML
report. The root is fixed beside the run report. These distribution changes
require a new runner/action release; this source change does not publish one.

JUnit results declared with a task's `Artifacts` property are included as
sanitized `flow-auto-*/results.xml` files in that artifact. The action publishes
them as a GitHub test check using the pinned
[dorny/test-reporter action](https://github.com/dorny/test-reporter/tree/a43b3a5f7366b97d083190328d2c652e1a8b6aa2).
Generated workflows grant `actions: read` and `checks: write` for this step.
Fork pull requests keep the downloadable XML and Flow summary; the test check
is skipped because GitHub gives those workflows a read-only token.

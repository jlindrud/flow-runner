"""GitHub Action wrapper: argument arrays only; preserve the native runner exit code."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import uuid


def arguments(env):
    runner = Path(env["FLOW_RUNNER_HOME"]) / "bin" / ("FlowRunner.exe" if os.name == "nt" else "FlowRunner")
    result = [str(runner), env["FLOW_FILE"], "--html-log", env["FLOW_HTML_REPORT"], "--ci", "github", "--ci-defer-summary"]
    if env.get("FLOW_WORKFLOW"):
        result += ["--workflow", env["FLOW_WORKFLOW"]]
    for line in env.get("FLOW_VARIABLES", "").splitlines():
        if line.strip():
            if "=" not in line or not line.split("=", 1)[0].strip():
                raise ValueError("Flow variables must contain one name=value pair per line")
            result += ["--var", line]
    return result


def artifact_name(env):
    name = env.get("FLOW_ARTIFACT_NAME") or "Flow-" + env.get("GITHUB_JOB", "report") + "-" + uuid.uuid4().hex[:8]
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,119}", name):
        raise ValueError("Artifact names must be a simple filename using letters, digits, dots, underscores or hyphens")
    return name if name.endswith(".html") else name + ".html"


def run_action(env):
    args = arguments(env)
    name = artifact_name(env)
    # Isolate native outputs so stale report files cannot be uploaded after a
    # pre-execution error. Forward only outputs produced by this invocation.
    staging = Path(tempfile.mkdtemp(prefix="flow-artifact-", dir=env["RUNNER_TEMP"]))
    outputs = staging / "native-outputs.txt"
    result = subprocess.run(args, env=dict(env, GITHUB_OUTPUT=str(outputs)))
    native = outputs.read_text(encoding="utf-8") if outputs.exists() else ""
    for line in native.splitlines():
        if line.startswith("flow_html="):
            report = Path(line.split("=", 1)[1])
            if report.is_file():
                upload = staging / name
                shutil.copyfile(report, upload)
                native += "flow_upload=" + str(upload) + "\n"
            break
    with open(env["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
        output.write(native)
    return result.returncode


if __name__ == "__main__":
    try:
        sys.exit(run_action(os.environ))
    except (OSError, ValueError, KeyError) as error:
        print("Flow action: " + str(error), file=sys.stderr)
        sys.exit(1)

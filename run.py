"""GitHub Action wrapper: argument arrays only; preserve the native runner exit code."""
import os
from pathlib import Path
import subprocess
import sys


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


if __name__ == "__main__":
    try:
        sys.exit(subprocess.run(arguments(os.environ)).returncode)
    except (OSError, ValueError, KeyError) as error:
        print("Flow action: " + str(error), file=sys.stderr)
        sys.exit(1)

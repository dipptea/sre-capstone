#!/usr/bin/env python3
"""
PreToolUse hook: enforce spec-first rule.

Blocks Write/Edit to infra/app code unless a spec under specs/phase-*.md
has status: approved or status: in-progress.

Doc/framework files are always allowed (specs/, .claude/, README.md, etc.).

If this hook misfires, comment out the entry in .claude/settings.json.
"""
import json
import sys
import os
import re
import glob

# --- 1. Read tool-call context from stdin ---
try:
    data = json.load(sys.stdin)
except Exception:
    # If we can't parse, fail open (allow). Don't break tooling on hook bugs.
    sys.exit(0)

tool_name = data.get("tool_name", "")
tool_input = data.get("tool_input", {}) or {}
file_path = tool_input.get("file_path", "") or ""

# --- 2. Only check Write/Edit ---
if tool_name not in ("Write", "Edit"):
    sys.exit(0)

if not file_path:
    sys.exit(0)

# --- 3. Always allow doc/framework edits ---
ALWAYS_ALLOW_BASENAMES = {
    "README.md",
    "CLAUDE.md",
    "ROADMAP.md",
    "ARCHITECTURE.md",
    "DECISIONS.md",
    "runbook.md",
    "lessons.md",
    "PHASE-01.md",
    ".gitignore",
}
ALWAYS_ALLOW_PATH_FRAGMENTS = (
    "/specs/",
    "/.claude/",
    "/docs/",
)

basename = os.path.basename(file_path)
norm_path = "/" + file_path.lstrip("/")

if basename in ALWAYS_ALLOW_BASENAMES:
    sys.exit(0)

if any(frag in norm_path for frag in ALWAYS_ALLOW_PATH_FRAGMENTS):
    sys.exit(0)

# --- 4. Determine if this looks like infra/app code we should gate ---
INFRA_EXTS = {
    ".tf", ".tfvars", ".hcl",
    ".yaml", ".yml",
    ".py", ".js", ".ts", ".tsx", ".jsx",
    ".go", ".rb", ".java", ".rs",
    ".sh", ".bash",
    ".json",  # only when not in always-allow paths
    ".toml",
}
INFRA_BASENAMES = {
    "Dockerfile", "Chart.yaml", "values.yaml", "Makefile",
}

ext = os.path.splitext(file_path)[1].lower()
should_check = ext in INFRA_EXTS or basename in INFRA_BASENAMES

if not should_check:
    sys.exit(0)

# --- 5. Find the project root and scan specs ---
project_dir = (
    os.environ.get("CLAUDE_PROJECT_DIR")
    or data.get("cwd")
    or os.getcwd()
)
spec_glob = os.path.join(project_dir, "specs", "phase-*.md")
spec_files = glob.glob(spec_glob)

active_specs = []
for spec_path in spec_files:
    try:
        with open(spec_path, "r", encoding="utf-8") as f:
            content = f.read()
    except OSError:
        continue
    m = re.search(r"^status:\s*(\S+)", content, re.MULTILINE)
    if m and m.group(1).lower() in ("approved", "in-progress"):
        active_specs.append(os.path.basename(spec_path))

# --- 6. Decide ---
if active_specs:
    sys.exit(0)

msg = (
    "BLOCKED by spec-first rule (CLAUDE.md).\n"
    f"\n"
    f"  File: {file_path}\n"
    f"  Reason: this looks like infra/app code, but no spec under specs/ is\n"
    f"          currently 'approved' or 'in-progress'.\n"
    f"\n"
    f"What to do:\n"
    f"  1. Run /spec-new <NN> to draft a spec for the current phase.\n"
    f"  2. Walk through the sections, then say 'approved' to lock it.\n"
    f"  3. Re-run this edit — the hook will allow it.\n"
    f"\n"
    f"If this is a doc/framework edit and the hook is over-blocking,\n"
    f"either rename the file to a doc location (specs/, .claude/, docs/)\n"
    f"or temporarily comment out the hook in .claude/settings.json.\n"
)
print(msg, file=sys.stderr)
sys.exit(2)

"""pytest configuration — adds this dir to sys.path so tests can import `app.*`.

Phase 03 minimum-viable setup. Cleaner alternatives (pytest.ini, pyproject.toml)
are reasonable later but would bring in tooling concepts not load-bearing here.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

"""pytest configuration — adds this dir to sys.path so tests can import `app.*`.

Mirrors services/payment/conftest.py. Phase 03b minimum-viable setup.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

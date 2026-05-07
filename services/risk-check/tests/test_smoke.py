"""Phase 03b smoke test — placeholder. Mirrors services/payment/tests/test_smoke.py.

A passing test here proves: Python env set up, requirements.txt installable,
app module importable, FastAPI instantiation doesn't crash.
"""


def test_app_imports_cleanly():
    from app.main import app
    assert app is not None

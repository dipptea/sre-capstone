"""Phase 03 smoke test — placeholder per resolved Open question #3.

Real test coverage is a separate ongoing effort beyond Phase 03 scope.
This exists so the pipeline's pytest gate runs something real (not a no-op).
A passing test here proves: Python env set up, requirements.txt installable,
app module importable, FastAPI instantiation doesn't crash.
"""


def test_app_imports_cleanly():
    from app.main import app
    assert app is not None

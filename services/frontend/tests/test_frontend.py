"""Basic frontend tests - validate static files serve correctly."""

from pathlib import Path

STATIC_DIR = Path(__file__).parent.parent / "static"


def test_index_html_exists():
    assert (STATIC_DIR / "index.html").exists()


def test_style_css_exists():
    assert (STATIC_DIR / "style.css").exists()


def test_app_js_exists():
    assert (STATIC_DIR / "app.js").exists()


def test_index_html_contains_title():
    content = (STATIC_DIR / "index.html").read_text()
    assert "CloudMart" in content


def test_app_js_contains_api_base():
    content = (STATIC_DIR / "app.js").read_text()
    assert "API_BASE" in content

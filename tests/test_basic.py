"""Minimal smoke tests."""

from api.interface import Memory


def test_observe_and_recall():
    m = Memory(dim=64)
    m.observe("the staging server uses PostgreSQL 15")
    m.observe("PostgreSQL listens on port 5432")
    m.observe("nginx is the reverse proxy")
    results = m.recall("what database runs on staging")
    assert len(results) > 0
    assert any("PostgreSQL" in r[0] for r in results)


def test_persistence(tmp_path):
    path = tmp_path / "field.json"
    m1 = Memory(dim=32, store_path=path)
    m1.observe("test fact one")
    m1.save()
    m2 = Memory(dim=32, store_path=path)
    assert m2.field.collapse_count >= 1

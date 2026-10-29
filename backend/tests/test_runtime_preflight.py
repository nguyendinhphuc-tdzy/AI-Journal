import pytest

from scripts.runtime_preflight import require_current_schema


def test_current_source_head_accepts_live_revision():
    require_current_schema(["20261028_15"], ("20261028_15",))


@pytest.mark.parametrize("source,database", [
    (["20261028_15"], ("20261028_09",)),
    (["20261028_15"], ()),
    (["a", "b"], ("a", "b")),
    (["20261028_15"], ("20261028_15", "other")),
])
def test_unknown_or_divergent_schema_is_rejected(source, database):
    with pytest.raises(RuntimeError, match="no migration was run"):
        require_current_schema(source, database)

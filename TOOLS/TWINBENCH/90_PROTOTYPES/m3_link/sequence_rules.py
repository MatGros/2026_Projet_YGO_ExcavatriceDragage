"""Règles communes de progression UDINT pour les flux UDP T409."""

UDINT_MASK = 0xFFFFFFFF
HALF_RANGE = 0x80000000


def is_strictly_newer(previous: int, current: int) -> bool:
    """Accepte la progression normale et FFFFFFFF vers 0, jamais un doublon."""
    delta = (int(current) - int(previous)) & UDINT_MASK
    return 0 < delta < HALF_RANGE


def is_acceptable(previous: int | None, current: int, stale: bool) -> bool:
    """Après stale, un nouveau producteur peut légitimement repartir à zéro."""
    return previous is None or stale or is_strictly_newer(previous, current)

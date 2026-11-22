from decimal import Decimal

import pytest

from app.services.pricing import commission_for, route_price, with_commission

# A -> B -> C -> D, whole route 1000, boarding at least 150.
PAIRS = {(0, 1): 300, (1, 2): 400, (2, 3): 500, (1, 3): 600}


def _price(a: int, b: int) -> int:
    return route_price(a, b, stops_count=4, full_price=1000, min_price=150, pair_prices=PAIRS)


def test_commission_example_from_design() -> None:
    price = with_commission(1000)

    assert (price.driver, price.commission, price.passenger) == (1000, 100, 1100)


@pytest.mark.parametrize(("amount", "expected"), [(5, 1), (4, 0), (15, 2), (0, 0)])
def test_commission_rounds_half_up(amount: int, expected: int) -> None:
    assert commission_for(amount, Decimal("10")) == expected


def test_whole_route_uses_full_price() -> None:
    assert _price(0, 3) == 1000


def test_explicit_pair_wins_over_sum() -> None:
    assert _price(1, 3) == 600


def test_missing_pair_sums_consecutive_segments() -> None:
    assert _price(0, 2) == 700


def test_sum_is_capped_by_full_route() -> None:
    pairs = {(0, 1): 600, (1, 2): 600, (2, 3): 100}

    assert route_price(0, 2, stops_count=4, full_price=1000, min_price=0, pair_prices=pairs) == 1000


def test_boarding_minimum_applies() -> None:
    pairs = {(0, 1): 50, (1, 2): 400, (2, 3): 500}

    price = route_price(0, 1, stops_count=4, full_price=1000, min_price=150, pair_prices=pairs)

    assert price == 150


@pytest.mark.parametrize(("a", "b"), [(2, 1), (1, 1), (-1, 2), (0, 4)])
def test_invalid_positions(a: int, b: int) -> None:
    with pytest.raises(ValueError):
        _price(a, b)

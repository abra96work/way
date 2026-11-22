"""Trip pricing. All amounts are whole rubles.

The driver sets: the whole-route price, a price for each consecutive pair of stops,
optional prices for any other pair of stops, and a minimal "boarding" price.
The service commission is added on top of the driver's price (1000 -> 1100 at 10 %).
"""

from collections.abc import Mapping
from dataclasses import dataclass
from decimal import ROUND_HALF_UP, Decimal

from app.core.config import get_settings


@dataclass(frozen=True)
class Price:
    driver: int
    commission: int

    @property
    def passenger(self) -> int:
        return self.driver + self.commission


def commission_for(driver_price: int, percent: Decimal | None = None) -> int:
    rate = get_settings().commission_percent if percent is None else percent
    amount = Decimal(driver_price) * rate / Decimal(100)
    return int(amount.quantize(Decimal(1), rounding=ROUND_HALF_UP))


def with_commission(driver_price: int) -> Price:
    return Price(driver=driver_price, commission=commission_for(driver_price))


def route_price(
    from_position: int,
    to_position: int,
    *,
    stops_count: int,
    full_price: int,
    min_price: int,
    pair_prices: Mapping[tuple[int, int], int],
) -> int:
    """Driver's price for riding from one stop to another.

    An explicit pair price wins; otherwise consecutive segments are summed. A part of
    the route never costs more than the whole route nor less than the boarding price.
    """
    last = stops_count - 1
    if not 0 <= from_position < to_position <= last:
        raise ValueError("invalid stop positions")
    if (from_position, to_position) == (0, last):
        price = full_price
    elif (from_position, to_position) in pair_prices:
        price = pair_prices[(from_position, to_position)]
    else:
        price = sum(pair_prices[(i, i + 1)] for i in range(from_position, to_position))
    return max(min(price, full_price), min_price)

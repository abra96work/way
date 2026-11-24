/// Service commission added on top of the driver's price.
///
/// Mirrors the backend (`PUT_COMMISSION_PERCENT`, `services/pricing.py`):
/// 10 %, rounded half up to whole rubles. 1000 → 100 → passenger pays 1100.
const commissionPercent = 10;

int commissionFor(int driverPrice) =>
    (driverPrice * commissionPercent + 50) ~/ 100;

int passengerPriceFor(int driverPrice) =>
    driverPrice + commissionFor(driverPrice);

from decimal import Decimal
from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

BACKEND_DIR = Path(__file__).resolve().parents[2]
DEV_JWT_SECRET = "dev-insecure-secret-change-me-0123456789"


class Settings(BaseSettings):
    app_name: str = "Путь API"
    environment: str = "development"
    database_url: str = "sqlite+aiosqlite:///./put.db"
    cors_origins: list[str] = ["http://localhost:3000", "http://localhost:5173"]

    # Auth. SMS is not connected in the test assignment: the code is always fixed.
    auth_fixed_code: str = "111111"
    auth_code_ttl_seconds: int = 600
    auth_code_max_attempts: int = 5
    jwt_secret: str = DEV_JWT_SECRET
    jwt_algorithm: str = "HS256"
    access_token_ttl_seconds: int = 15 * 60
    refresh_token_ttl_days: int = 30

    # Media uploads (avatars, car photos).
    media_dir: Path = BACKEND_DIR / "media"
    media_url_prefix: str = "/media"
    max_upload_bytes: int = 5 * 1024 * 1024

    # Business rules.
    local_timezone: str = "Asia/Yekaterinburg"  # "a day" for publishing limits
    commission_percent: Decimal = Decimal("10")
    trip_publish_days_ahead: int = 7  # a week, as the date picker in Figma offers
    trip_max_stops: int = 10
    # Published trips per calendar week (Mon–Sun, local), as "На неделе 3 / 10" in Figma.
    trip_week_limit: int = 10
    # Arrival times are not collected, so a trip counts as finished this long after departure.
    trip_complete_after_hours: int = 6
    # Drivers need an admin-approved face photo. Off until the admin panel exists (stage 8).
    require_driver_face_approval: bool = False
    # The test build has no UI for leaving reviews; the API exists behind this flag.
    reviews_enabled: bool = False
    cancellations_to_block: int = 2
    cancellation_window_days: int = 30
    block_duration_days: int = 30

    model_config = SettingsConfigDict(
        env_file=".env",
        env_prefix="PUT_",
        extra="ignore",
    )

    @property
    def is_production(self) -> bool:
        return self.environment == "production"


@lru_cache
def get_settings() -> Settings:
    settings = Settings()
    if settings.is_production and settings.jwt_secret == DEV_JWT_SECRET:
        raise RuntimeError("PUT_JWT_SECRET must be set in production")
    return settings

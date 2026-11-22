import re
from typing import Annotated

from pydantic import AfterValidator, BaseModel, Field

from app.schemas.user import MeRead

_PHONE_JUNK = re.compile(r"[\s\-()]")
_E164 = re.compile(r"^\+[1-9]\d{9,14}$")


def normalize_phone(value: str) -> str:
    """Normalize to E.164. Russian local formats 8XXXXXXXXXX / 7XXXXXXXXXX become +7..."""
    phone = _PHONE_JUNK.sub("", value)
    if len(phone) == 11 and phone[0] in "78" and phone.isdigit():
        phone = "+7" + phone[1:]
    elif len(phone) == 10 and phone.startswith("9") and phone.isdigit():
        phone = "+7" + phone
    if not _E164.match(phone):
        raise ValueError("Некорректный номер телефона")
    return phone


Phone = Annotated[str, AfterValidator(normalize_phone), Field(examples=["+79001234567"])]


class CodeRequest(BaseModel):
    phone: Phone


class CodeRequestResult(BaseModel):
    phone: str
    expires_in: int
    resend_in: int = 60


class CodeVerify(BaseModel):
    phone: Phone
    code: str = Field(pattern=r"^\d{6}$", examples=["111111"])


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=10)


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class AuthResult(TokenPair):
    is_new_user: bool
    user: MeRead

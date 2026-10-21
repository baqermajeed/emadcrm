from pydantic import Field

from app.schemas.common import ORMModel
from app.schemas.user import UserOut


class LoginRequest(ORMModel):
    username: str = Field(min_length=3, max_length=64)
    password: str = Field(min_length=4, max_length=128)


class TokenResponse(ORMModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut

from pydantic import BaseModel, ConfigDict


class CityRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    region: str
    lat: float
    lng: float

from pydantic import BaseModel
from typing import Optional

class MenuUpdate(BaseModel):
    foto_id: Optional[str] = None
    nama: Optional[str] = None

data1 = MenuUpdate.parse_raw('{"nama": "Coffee"}')
print('Omitted foto_id:', data1.dict(exclude_unset=True))
data2 = MenuUpdate.parse_raw('{"nama": "Coffee", "foto_id": null}')
print('Explicit null:', data2.dict(exclude_unset=True))

from dataclasses import dataclass
from datetime import datetime
from typing import Optional

@dataclass
class ParkingSession:
    user_id: str
    slot_id: str
    vehicle_id: Optional[str]
    start_time: datetime
    is_active: bool

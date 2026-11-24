"""Live delivery over WebSockets.

Each logged-in client keeps one socket open (`/api/v1/chats/ws`); the server pushes chat
events to every socket of the recipient. Connections live in process memory, so the API
must run as a single process (one uvicorn worker), which is how the Docker image runs it.
Scaling out would need a shared pub/sub (e.g. Redis) in place of this hub.
"""

import logging
from collections import defaultdict
from typing import Any
from uuid import UUID

from fastapi import WebSocket

logger = logging.getLogger(__name__)


class ConnectionHub:
    def __init__(self) -> None:
        self._sockets: dict[UUID, set[WebSocket]] = defaultdict(set)

    def connect(self, user_id: UUID, websocket: WebSocket) -> None:
        self._sockets[user_id].add(websocket)

    def disconnect(self, user_id: UUID, websocket: WebSocket) -> None:
        sockets = self._sockets.get(user_id)
        if sockets is None:
            return
        sockets.discard(websocket)
        if not sockets:
            del self._sockets[user_id]

    def is_online(self, user_id: UUID) -> bool:
        return bool(self._sockets.get(user_id))

    async def send(self, user_id: UUID, payload: dict[str, Any]) -> None:
        for websocket in list(self._sockets.get(user_id, ())):
            try:
                await websocket.send_json(payload)
            except Exception:  # noqa: BLE001 - a dead socket must not break the sender
                logger.info("dropping dead websocket of %s", user_id)
                self.disconnect(user_id, websocket)


hub = ConnectionHub()

# API Conventions

## Base URL

```text
/api
```

## Authentication

```http
Authorization: Bearer <accessToken>
```

JWT payload should include:

```json
{
  "sub": "user-id",
  "role": "USER",
  "email": "user@kaist.ac.kr"
}
```

## Response Envelope

Use direct JSON resources for successful responses. Use this shape for errors:

```json
{
  "code": "LOBBY_ALREADY_LOCKED",
  "message": "Cart locked lobbies cannot be joined."
}
```

## WebSocket

```text
/ws
```

Suggested STOMP destinations:

```text
/app/lobbies/{lobbyId}/messages
/topic/lobbies/{lobbyId}/chat
/topic/lobbies/{lobbyId}/cart
/topic/lobbies/{lobbyId}/payment
/topic/lobbies/{lobbyId}/status
```


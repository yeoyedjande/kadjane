"""Enveloppe standard des réponses de l'API."""

from __future__ import annotations

from typing import Any

from fastapi.responses import JSONResponse


def success(data: Any = None, meta: dict[str, Any] | None = None) -> dict[str, Any]:
    """`{"success": true, "data": ..., "meta": ...}`."""
    payload: dict[str, Any] = {"success": True, "data": data}
    if meta is not None:
        payload["meta"] = meta
    return payload


def error_payload(
    code: str,
    message: str,
    details: dict[str, Any] | None = None,
) -> dict[str, Any]:
    return {
        "success": False,
        "error": {"code": code, "message": message, "details": details},
    }


def error_response(
    status_code: int,
    code: str,
    message: str,
    details: dict[str, Any] | None = None,
) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content=error_payload(code, message, details),
    )

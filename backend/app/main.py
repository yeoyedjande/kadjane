"""Point d'entrée de l'API Kadjane."""

from __future__ import annotations

import logging
from pathlib import Path
from typing import Any

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.api.health import router as health_router
from app.api.v1.router import api_router
from app.core.config import settings
from app.core.errors import AppError
from app.core.responses import error_response

logger = logging.getLogger("kadjane")

DESCRIPTION = """
API de Kadjane — gestion de tontines et d'associations.

**Format des réponses**

* succès : `{"success": true, "data": ..., "meta": ...}`
* erreur : `{"success": false, "error": {"code", "message", "details"}}`

**Authentification** : `Authorization: Bearer <accessToken>`.
Obtenez un jeton via `POST /api/v1/auth/login`, puis cliquez sur *Authorize*.
"""


def create_app() -> FastAPI:
    app = FastAPI(
        title=settings.app_name,
        version="0.1.0",
        description=DESCRIPTION,
        docs_url="/docs",
        redoc_url="/redoc",
        openapi_url="/openapi.json",
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_origin_regex=settings.cors_origin_regex,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
        expose_headers=["Content-Disposition"],
    )

    _mount_files(app)
    app.include_router(health_router)
    app.include_router(api_router, prefix=settings.api_v1_prefix)

    _register_exception_handlers(app)

    @app.get("/", include_in_schema=False)
    def root() -> dict[str, Any]:
        return {
            "name": settings.app_name,
            "environment": settings.environment,
            "docs": "/docs",
            "health": "/health",
            "api": settings.api_v1_prefix,
        }

    return app


def _mount_files(app: FastAPI) -> None:
    """Sert les justificatifs téléversés.

    TODO(storage): remplacer par des URL pré-signées quand le stockage objet
    sera en place — le montage disparaîtra alors.
    """
    directory = Path(settings.upload_dir)
    directory.mkdir(parents=True, exist_ok=True)
    app.mount(
        settings.files_url_prefix,
        StaticFiles(directory=directory),
        name="files",
    )


def _register_exception_handlers(app: FastAPI) -> None:
    """Toutes les erreurs sortent dans l'enveloppe standard."""

    @app.exception_handler(AppError)
    async def _app_error(_: Request, error: AppError) -> JSONResponse:
        return error_response(
            error.status_code, error.code, error.message, error.details
        )

    @app.exception_handler(RequestValidationError)
    async def _validation_error(
        _: Request, error: RequestValidationError
    ) -> JSONResponse:
        fields: dict[str, str] = {}
        for item in error.errors():
            location = [str(part) for part in item["loc"] if part not in ("body", "query")]
            fields[".".join(location) or "body"] = item["msg"]
        return error_response(
            422,
            "validation_error",
            "Certaines données envoyées sont invalides.",
            {"errors": fields},
        )

    @app.exception_handler(StarletteHTTPException)
    async def _http_error(_: Request, error: StarletteHTTPException) -> JSONResponse:
        codes = {401: "unauthenticated", 403: "forbidden", 404: "not_found"}
        return error_response(
            error.status_code,
            codes.get(error.status_code, f"http_{error.status_code}"),
            str(error.detail),
        )

    @app.exception_handler(Exception)
    async def _unexpected(_: Request, error: Exception) -> JSONResponse:
        logger.exception("Erreur inattendue", exc_info=error)
        return error_response(
            500, "internal_error", "Une erreur interne est survenue."
        )


app = create_app()

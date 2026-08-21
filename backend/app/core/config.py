"""Configuration de l'application, lue depuis l'environnement."""

from __future__ import annotations

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(".env",),
        env_file_encoding="utf-8",
        extra="ignore",
        populate_by_name=True,
    )

    # --- Application ---
    app_name: str = "Kadjane API"
    environment: str = "development"
    api_v1_prefix: str = "/api/v1"
    debug: bool = True

    # --- Base de données ---
    database_url: str = "postgresql+psycopg://kadjane:kadjane@localhost:5432/kadjane"

    # --- Sécurité ---
    jwt_secret: str = "dev-secret-change-me"
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 30
    jwt_refresh_token_expire_days: int = 30

    # Coût bcrypt. 12 en production ; abaissé dans les tests, où seule la
    # vérification du mécanisme compte.
    bcrypt_rounds: int = 12

    # Chaîne brute (`A,B,C`) : pydantic-settings tenterait de décoder du JSON
    # sur un champ typé `list`.
    cors_origins_raw: str = Field(
        default="http://localhost:4200,http://localhost:8080,http://localhost:3000",
        alias="CORS_ORIGINS",
    )

    # Origines acceptées par expression régulière, en complément de la liste.
    # Indispensable en développement : `flutter run -d chrome` sert l'application
    # sur un port tiré au hasard, impossible à énumérer à l'avance. Vide (donc
    # inactif) hors développement — voir `cors_origin_regex`.
    cors_origin_regex_raw: str = Field(default="", alias="CORS_ORIGIN_REGEX")

    # --- Fichiers ---
    upload_dir: str = "uploads"
    files_url_prefix: str = "/files"

    # --- Seed de développement ---
    seed_password: str = "kadjane"

    @property
    def cors_origins(self) -> list[str]:
        """Origines autorisées, séparées par des virgules."""
        return [
            origin.strip()
            for origin in self.cors_origins_raw.split(",")
            if origin.strip()
        ]

    @property
    def cors_origin_regex(self) -> str | None:
        """Motif d'origines autorisées, ou `None` si aucun.

        En développement, on accepte par défaut n'importe quel port de
        `localhost` / `127.0.0.1` : le serveur de développement Flutter Web en
        choisit un au hasard à chaque lancement. Ce repli ne s'applique jamais
        hors développement, où seules les origines listées sont admises.
        """
        if self.cors_origin_regex_raw.strip():
            return self.cors_origin_regex_raw.strip()
        if self.environment == "development":
            return r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"
        return None

    @property
    def is_production(self) -> bool:
        return self.environment == "production"


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()

"""Base des schémas Pydantic.

Le contrat client (`docs/api-contract.md`) est en camelCase : la conversion
est automatique, le code Python reste en snake_case.
"""

from __future__ import annotations

from typing import Any

from pydantic import BaseModel, ConfigDict
from pydantic.alias_generators import to_camel


class CamelModel(BaseModel):
    model_config = ConfigDict(
        alias_generator=to_camel,
        populate_by_name=True,
        from_attributes=True,
    )


def dump(model: BaseModel) -> dict[str, Any]:
    """Sérialise en JSON camelCase (dates ISO 8601, UUID en chaînes)."""
    return model.model_dump(by_alias=True, mode="json")


def dump_all(models: list[Any]) -> list[dict[str, Any]]:
    return [dump(model) for model in models]

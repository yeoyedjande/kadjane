"""jour de tirage

Le tirage s'ouvre à une date convenue de la période, et non dès que les
cotisations sont réglées. `draw_day` porte ce jour ; `NULL` retombe sur le jour
d'échéance, ce qui laisse les tontines existantes inchangées.

Revision ID: b4c8e2f10a37
Revises: a7c1e5d94b30
Create Date: 2026-09-05 19:40:00.000000
"""
from __future__ import annotations

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'b4c8e2f10a37'
down_revision: Union[str, None] = 'a7c1e5d94b30'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('tontines', sa.Column('draw_day', sa.Integer(), nullable=True))


def downgrade() -> None:
    op.drop_column('tontines', 'draw_day')

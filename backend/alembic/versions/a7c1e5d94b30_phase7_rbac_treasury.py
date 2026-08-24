"""RBAC persisté, caisses et campagnes de cotisation

Revision ID: a7c1e5d94b30
Revises: 1217380b7bd7
Create Date: 2026-08-24 15:10:00.000000

Aucune donnée n'est perdue :

* `organization_members.role` est conservée telle quelle — elle reste
  l'étiquette du membre. La nouvelle colonne `role_id` naît nulle, et la
  résolution des droits retombe alors sur le rôle système de même code.
* Les `cash_transactions` existantes sont rattachées à une « Caisse
  principale » créée pour chaque organisation qui en possède, avec un solde
  d'ouverture nul : le solde reconstitué est donc identique à l'ancien total.
* Le catalogue des permissions et les six rôles système sont semés ici, de
  façon idempotente.

`roles.created_by` et `organization_members.role_id` se référencent en boucle :
la contrainte est posée après coup par `ALTER`, faute de quoi aucune des deux
tables ne pourrait être créée en premier.
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "a7c1e5d94b30"
down_revision: Union[str, None] = "1217380b7bd7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # --- Catalogue des permissions -----------------------------------------
    op.create_table(
        "permissions",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("code", sa.String(length=64), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("category", sa.String(length=32), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_permissions")),
        sa.UniqueConstraint("code", name=op.f("uq_permissions_code")),
    )
    op.create_index(op.f("ix_permissions_category"), "permissions", ["category"])

    # --- Rôles --------------------------------------------------------------
    op.create_table(
        "roles",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("organization_id", sa.Uuid(), nullable=True),
        sa.Column("code", sa.String(length=64), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("is_system", sa.Boolean(), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("created_by", sa.Uuid(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(
            ["organization_id"],
            ["organizations.id"],
            name=op.f("fk_roles_organization_id_organizations"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_roles")),
        sa.UniqueConstraint("organization_id", "code", name="uq_roles_organization_id"),
    )
    op.create_index(op.f("ix_roles_organization_id"), "roles", ["organization_id"])
    op.create_index("ix_roles_org_status", "roles", ["organization_id", "status"])

    op.create_table(
        "role_permissions",
        sa.Column("role_id", sa.Uuid(), nullable=False),
        sa.Column("permission_id", sa.Uuid(), nullable=False),
        sa.ForeignKeyConstraint(
            ["permission_id"],
            ["permissions.id"],
            name=op.f("fk_role_permissions_permission_id_permissions"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["role_id"],
            ["roles.id"],
            name=op.f("fk_role_permissions_role_id_roles"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("role_id", "permission_id", name=op.f("pk_role_permissions")),
    )

    # Le membre porte désormais un rôle explicite. Nul pour tout l'existant.
    op.add_column("organization_members", sa.Column("role_id", sa.Uuid(), nullable=True))
    op.create_index(
        op.f("ix_organization_members_role_id"), "organization_members", ["role_id"]
    )
    op.create_foreign_key(
        op.f("fk_organization_members_role_id_roles"),
        "organization_members",
        "roles",
        ["role_id"],
        ["id"],
        ondelete="SET NULL",
    )
    # Boucle refermée après coup : voir l'en-tête du module.
    op.create_foreign_key(
        "fk_roles_created_by_organization_members",
        "roles",
        "organization_members",
        ["created_by"],
        ["id"],
        ondelete="SET NULL",
    )

    # --- Caisses ------------------------------------------------------------
    op.create_table(
        "cashboxes",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("organization_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("currency", sa.String(length=8), nullable=False),
        sa.Column("opening_balance", sa.Numeric(precision=14, scale=2), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("is_default", sa.Boolean(), nullable=False),
        sa.Column("created_by", sa.Uuid(), nullable=True),
        sa.Column("closed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(
            ["created_by"],
            ["organization_members.id"],
            name=op.f("fk_cashboxes_created_by_organization_members"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["organization_id"],
            ["organizations.id"],
            name=op.f("fk_cashboxes_organization_id_organizations"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_cashboxes")),
        sa.UniqueConstraint("organization_id", "name", name="uq_cashboxes_organization_id"),
    )
    op.create_index(op.f("ix_cashboxes_organization_id"), "cashboxes", ["organization_id"])
    op.create_index("ix_cashboxes_org_status", "cashboxes", ["organization_id", "status"])

    # --- Mouvements de caisse : caisse, statut, référence, annulation -------
    op.add_column("cash_transactions", sa.Column("cashbox_id", sa.Uuid(), nullable=True))
    op.add_column(
        "cash_transactions",
        sa.Column("status", sa.String(length=20), nullable=False, server_default="confirmed"),
    )
    op.add_column("cash_transactions", sa.Column("reference", sa.String(length=120), nullable=True))
    op.add_column("cash_transactions", sa.Column("cancelled_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("cash_transactions", sa.Column("cancel_reason", sa.Text(), nullable=True))
    op.create_index(op.f("ix_cash_transactions_cashbox_id"), "cash_transactions", ["cashbox_id"])
    op.create_index(
        "ix_cash_transactions_box_status", "cash_transactions", ["cashbox_id", "status"]
    )
    op.create_foreign_key(
        op.f("fk_cash_transactions_cashbox_id_cashboxes"),
        "cash_transactions",
        "cashboxes",
        ["cashbox_id"],
        ["id"],
        ondelete="RESTRICT",
    )

    # --- Campagnes de cotisation -------------------------------------------
    op.create_table(
        "contribution_campaigns",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("organization_id", sa.Uuid(), nullable=False),
        sa.Column("tontine_id", sa.Uuid(), nullable=True),
        sa.Column("cashbox_id", sa.Uuid(), nullable=True),
        sa.Column("title", sa.String(length=180), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("contribution_type", sa.String(length=20), nullable=False),
        sa.Column("amount", sa.Numeric(precision=14, scale=2), nullable=False),
        sa.Column("amount_mode", sa.String(length=10), nullable=False),
        sa.Column("currency", sa.String(length=8), nullable=False),
        sa.Column("start_date", sa.DateTime(timezone=True), nullable=True),
        sa.Column("due_date", sa.DateTime(timezone=True), nullable=True),
        sa.Column("mandatory", sa.Boolean(), nullable=False),
        sa.Column("penalty_enabled", sa.Boolean(), nullable=False),
        sa.Column("penalty_amount", sa.Numeric(precision=14, scale=2), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("created_by", sa.Uuid(), nullable=True),
        sa.Column("closed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(
            ["cashbox_id"], ["cashboxes.id"],
            name=op.f("fk_contribution_campaigns_cashbox_id_cashboxes"), ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["created_by"], ["organization_members.id"],
            name=op.f("fk_contribution_campaigns_created_by_organization_members"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["organization_id"], ["organizations.id"],
            name=op.f("fk_contribution_campaigns_organization_id_organizations"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["tontine_id"], ["tontines.id"],
            name=op.f("fk_contribution_campaigns_tontine_id_tontines"), ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_contribution_campaigns")),
    )
    op.create_index(
        op.f("ix_contribution_campaigns_organization_id"),
        "contribution_campaigns",
        ["organization_id"],
    )
    op.create_index(
        op.f("ix_contribution_campaigns_cashbox_id"), "contribution_campaigns", ["cashbox_id"]
    )
    op.create_index(
        "ix_contribution_campaigns_org_status",
        "contribution_campaigns",
        ["organization_id", "status"],
    )
    op.create_index(
        "ix_contribution_campaigns_org_type",
        "contribution_campaigns",
        ["organization_id", "contribution_type"],
    )

    op.create_table(
        "campaign_entries",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("organization_id", sa.Uuid(), nullable=False),
        sa.Column("campaign_id", sa.Uuid(), nullable=False),
        sa.Column("member_id", sa.Uuid(), nullable=False),
        sa.Column("expected_amount", sa.Numeric(precision=14, scale=2), nullable=False),
        sa.Column("paid_amount", sa.Numeric(precision=14, scale=2), nullable=False),
        sa.Column("due_date", sa.DateTime(timezone=True), nullable=True),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("last_payment_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("exemption_reason", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(
            ["campaign_id"], ["contribution_campaigns.id"],
            name=op.f("fk_campaign_entries_campaign_id_contribution_campaigns"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["member_id"], ["organization_members.id"],
            name=op.f("fk_campaign_entries_member_id_organization_members"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["organization_id"], ["organizations.id"],
            name=op.f("fk_campaign_entries_organization_id_organizations"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_campaign_entries")),
        sa.UniqueConstraint("campaign_id", "member_id", name="uq_campaign_entries_campaign_id"),
    )
    op.create_index(op.f("ix_campaign_entries_organization_id"), "campaign_entries", ["organization_id"])
    op.create_index(op.f("ix_campaign_entries_campaign_id"), "campaign_entries", ["campaign_id"])
    op.create_index(op.f("ix_campaign_entries_member_id"), "campaign_entries", ["member_id"])
    op.create_index(
        "ix_campaign_entries_campaign_status", "campaign_entries", ["campaign_id", "status"]
    )

    op.create_table(
        "campaign_payments",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("organization_id", sa.Uuid(), nullable=False),
        sa.Column("entry_id", sa.Uuid(), nullable=False),
        sa.Column("cash_transaction_id", sa.Uuid(), nullable=True),
        sa.Column("amount", sa.Numeric(precision=14, scale=2), nullable=False),
        sa.Column("payment_method", sa.String(length=24), nullable=False),
        sa.Column("reference", sa.String(length=120), nullable=True),
        sa.Column("comment", sa.Text(), nullable=True),
        sa.Column("proof_url", sa.String(length=512), nullable=True),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("recorded_by", sa.Uuid(), nullable=True),
        sa.Column("paid_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("confirmed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("cancelled_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("cancel_reason", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(
            ["cash_transaction_id"], ["cash_transactions.id"],
            name=op.f("fk_campaign_payments_cash_transaction_id_cash_transactions"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["entry_id"], ["campaign_entries.id"],
            name=op.f("fk_campaign_payments_entry_id_campaign_entries"), ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["organization_id"], ["organizations.id"],
            name=op.f("fk_campaign_payments_organization_id_organizations"), ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["recorded_by"], ["organization_members.id"],
            name=op.f("fk_campaign_payments_recorded_by_organization_members"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_campaign_payments")),
    )
    op.create_index(op.f("ix_campaign_payments_organization_id"), "campaign_payments", ["organization_id"])
    op.create_index(op.f("ix_campaign_payments_entry_id"), "campaign_payments", ["entry_id"])
    op.create_index(
        "ix_campaign_payments_entry_status", "campaign_payments", ["entry_id", "status"]
    )

    # En mode hors ligne (`alembic upgrade --sql`), il n'y a pas de connexion :
    # seul le DDL est rendu, et les étapes de données sont à rejouer avec
    # `python -m app.rbac.seed` après application du script.
    if not op.get_context().as_sql:
        _seed_rbac()
        _backfill_cashboxes()


def _seed_rbac() -> None:
    """Catalogue et rôles système, via le même code qu'au démarrage."""
    from sqlalchemy.orm import Session

    from app.rbac.seed import sync_system_roles

    session = Session(bind=op.get_bind())
    sync_system_roles(session)
    session.flush()


def _backfill_cashboxes() -> None:
    """Rattache les mouvements existants à une « Caisse principale ».

    Une caisse par organisation **qui possède déjà des mouvements** : inutile
    d'en ouvrir une pour une association qui n'a rien saisi, elle naîtra à son
    premier encaissement. Le solde d'ouverture est nul, donc le solde
    reconstitué égale exactement l'ancien total.
    """
    import uuid

    connection = op.get_bind()
    organizations = connection.execute(
        sa.text(
            "SELECT DISTINCT organization_id FROM cash_transactions "
            "WHERE cashbox_id IS NULL"
        )
    ).scalars()

    for organization_id in list(organizations):
        cashbox_id = uuid.uuid4()
        connection.execute(
            sa.text(
                "INSERT INTO cashboxes "
                "(id, organization_id, name, description, currency, "
                " opening_balance, status, is_default, created_at, updated_at) "
                "VALUES (:id, :org, :name, :description, 'XOF', 0, 'open', true, "
                " CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
            ),
            {
                "id": cashbox_id,
                "org": organization_id,
                "name": "Caisse principale",
                "description": "Caisse créée lors de la reprise des mouvements existants.",
            },
        )
        connection.execute(
            sa.text(
                "UPDATE cash_transactions SET cashbox_id = :box "
                "WHERE organization_id = :org AND cashbox_id IS NULL"
            ),
            {"box": cashbox_id, "org": organization_id},
        )


def downgrade() -> None:
    op.drop_table("campaign_payments")
    op.drop_table("campaign_entries")
    op.drop_table("contribution_campaigns")

    op.drop_constraint(
        op.f("fk_cash_transactions_cashbox_id_cashboxes"),
        "cash_transactions",
        type_="foreignkey",
    )
    op.drop_index("ix_cash_transactions_box_status", table_name="cash_transactions")
    op.drop_index(op.f("ix_cash_transactions_cashbox_id"), table_name="cash_transactions")
    for column in ("cancel_reason", "cancelled_at", "reference", "status", "cashbox_id"):
        op.drop_column("cash_transactions", column)

    op.drop_table("cashboxes")

    op.drop_constraint(
        "fk_roles_created_by_organization_members", "roles", type_="foreignkey"
    )
    op.drop_constraint(
        op.f("fk_organization_members_role_id_roles"),
        "organization_members",
        type_="foreignkey",
    )
    op.drop_index(op.f("ix_organization_members_role_id"), table_name="organization_members")
    op.drop_column("organization_members", "role_id")

    op.drop_table("role_permissions")
    op.drop_table("roles")
    op.drop_table("permissions")

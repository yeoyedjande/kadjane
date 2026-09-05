"""Cycle de vie d'une tontine : création, activation, cycles, cotisations.

L'activation est l'opération structurante : elle fige le nombre de cycles
(un par participant), calcule la cagnotte de chaque cycle et crée toutes les
lignes de cotisation attendues. Elle est transactionnelle.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.orm import Session, joinedload

from app.core.errors import ConflictError, NotFoundError, ValidationError
from app.models.contribution import Contribution
from app.models.enums import (
    AllocationMode,
    AuditAction,
    ContributionStatus,
    CycleStatus,
    TontineFrequency,
    TontineStatus,
)
from app.models.membership import OrganizationMember
from app.models.organization import Organization
from app.models.tontine import Tontine, TontineCycle, TontineParticipant
from app.services.audit_service import AuditService
from app.services.period_service import build_periods, compute_draw_opening

# Transitions autorisées : aucune tontine ne saute d'un état à l'autre.
ALLOWED_TRANSITIONS: dict[TontineStatus, set[TontineStatus]] = {
    TontineStatus.DRAFT: {
        TontineStatus.PENDING,
        TontineStatus.ACTIVE,
        TontineStatus.CANCELLED,
    },
    TontineStatus.PENDING: {
        TontineStatus.ACTIVE,
        TontineStatus.DRAFT,
        TontineStatus.CANCELLED,
    },
    TontineStatus.ACTIVE: {
        TontineStatus.SUSPENDED,
        TontineStatus.COMPLETED,
        TontineStatus.CANCELLED,
    },
    TontineStatus.SUSPENDED: {TontineStatus.ACTIVE, TontineStatus.CANCELLED},
    TontineStatus.COMPLETED: set(),
    TontineStatus.CANCELLED: set(),
}


class TontineService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.audit = AuditService(db)

    # --- Lecture -------------------------------------------------------------

    def get(self, tontine_id: uuid.UUID, organization_id: uuid.UUID) -> Tontine:
        """Charge la tontine **et** vérifie son rattachement à l'organisation."""
        tontine = self.db.get(Tontine, tontine_id)
        if tontine is None or tontine.organization_id != organization_id:
            raise NotFoundError("Tontine introuvable.", code="tontine_not_found")
        return tontine

    def list_for_organization(
        self,
        organization_id: uuid.UUID,
        *,
        status: TontineStatus | None = None,
        member_id: uuid.UUID | None = None,
    ) -> list[Tontine]:
        statement = select(Tontine).where(Tontine.organization_id == organization_id)
        if status is not None:
            statement = statement.where(Tontine.status == status.value)
        if member_id is not None:
            statement = statement.join(
                TontineParticipant, TontineParticipant.tontine_id == Tontine.id
            ).where(TontineParticipant.organization_member_id == member_id)
        statement = statement.order_by(Tontine.created_at.desc())
        return list(self.db.scalars(statement).unique())

    def participants(self, tontine_id: uuid.UUID) -> list[TontineParticipant]:
        statement = (
            select(TontineParticipant)
            .options(
                joinedload(TontineParticipant.member).joinedload(
                    OrganizationMember.user
                )
            )
            .where(TontineParticipant.tontine_id == tontine_id)
            .order_by(
                TontineParticipant.draw_position.asc().nulls_last(),
                TontineParticipant.joined_at.asc(),
            )
        )
        return list(self.db.scalars(statement).unique())

    def active_participants(self, tontine_id: uuid.UUID) -> list[TontineParticipant]:
        return [p for p in self.participants(tontine_id) if p.is_active]

    def cycles(self, tontine_id: uuid.UUID) -> list[TontineCycle]:
        statement = (
            select(TontineCycle)
            .where(TontineCycle.tontine_id == tontine_id)
            .order_by(TontineCycle.sequence_number)
        )
        return list(self.db.scalars(statement))

    def cycle(self, cycle_id: uuid.UUID, organization_id: uuid.UUID) -> TontineCycle:
        cycle = self.db.get(TontineCycle, cycle_id)
        if cycle is None:
            raise NotFoundError("Cycle introuvable.", code="cycle_not_found")
        # Le cycle hérite du cloisonnement de sa tontine.
        self.get(cycle.tontine_id, organization_id)
        return cycle

    def current_cycle(self, tontine_id: uuid.UUID) -> TontineCycle | None:
        """Cycle en cours, sinon le premier cycle encore ouvert."""
        now = datetime.now(timezone.utc)
        cycles = self.cycles(tontine_id)
        open_statuses = {
            CycleStatus.UPCOMING.value,
            CycleStatus.COLLECTING.value,
            CycleStatus.READY_FOR_DRAW.value,
        }
        for cycle in cycles:
            if _aware(cycle.start_date) <= now <= _aware(cycle.end_date):
                return cycle
        for cycle in cycles:
            if cycle.status in open_statuses:
                return cycle
        return cycles[-1] if cycles else None

    def beneficiary_names(self, tontine_id: uuid.UUID) -> dict[uuid.UUID, str]:
        """Nom du bénéficiaire par cycle, pour les vues agrégées."""
        from app.models.payout import Beneficiary

        statement = (
            select(Beneficiary)
            .options(
                joinedload(Beneficiary.participant)
                .joinedload(TontineParticipant.member)
                .joinedload(OrganizationMember.user)
            )
            .where(
                Beneficiary.tontine_id == tontine_id,
                Beneficiary.status != "cancelled",
            )
        )
        return {
            beneficiary.cycle_id: beneficiary.participant.display_name
            for beneficiary in self.db.scalars(statement).unique()
        }

    # --- Écriture ------------------------------------------------------------

    def create(
        self,
        *,
        organization: Organization,
        actor: OrganizationMember,
        name: str,
        contribution_amount: Decimal,
        currency: str,
        frequency: TontineFrequency,
        attribution_mode: AllocationMode,
        start_date,
        due_day: int,
        member_ids: list[uuid.UUID],
        draw_day: int | None = None,
        description: str | None = None,
        custom_period_days: int | None = None,
        require_all_contributions_before_draw: bool | None = None,
        allow_draw_override: bool | None = None,
        manual_order: list[uuid.UUID] | None = None,
        activate: bool = True,
    ) -> Tontine:
        """Crée la tontine, inscrit ses participants et l'active par défaut.

        Les deux règles de tirage non précisées sont héritées des réglages de
        l'organisation : sans cet héritage, le réglage « exiger le paiement
        complet avant le tirage » n'avait aucun effet, chaque tontine repartant
        sur un `True` en dur.
        """
        members = self._validate_members(organization.id, member_ids)
        settings = organization.settings or {}
        if require_all_contributions_before_draw is None:
            require_all_contributions_before_draw = bool(
                settings.get("requireFullPaymentBeforeDraw", True)
            )
        if allow_draw_override is None:
            allow_draw_override = bool(settings.get("allowDrawOverride", True))

        tontine = Tontine(
            organization_id=organization.id,
            name=name.strip(),
            description=description,
            contribution_amount=contribution_amount,
            currency=currency.upper(),
            frequency=frequency.value,
            start_date=start_date,
            due_day=due_day,
            draw_day=draw_day,
            custom_period_days=custom_period_days,
            attribution_mode=attribution_mode.value,
            status=TontineStatus.DRAFT.value,
            require_all_contributions_before_draw=require_all_contributions_before_draw,
            allow_draw_override=allow_draw_override,
            created_by=actor.id,
        )
        self.db.add(tontine)
        self.db.flush()

        participants = {
            member.id: TontineParticipant(
                tontine_id=tontine.id,
                organization_member_id=member.id,
                is_active=True,
                is_draw_eligible=True,
                has_received_payout=False,
                joined_at=datetime.now(timezone.utc),
            )
            for member in members
        }
        for participant in participants.values():
            self.db.add(participant)
        self.db.flush()

        if attribution_mode is AllocationMode.MANUAL_ORDER:
            self._apply_manual_order(
                tontine, participants, manual_order or [], actor, commit=False
            )

        self.audit.record(
            organization_id=organization.id,
            action=AuditAction.TONTINE_CREATED,
            description=f"Tontine « {tontine.name} » créée.",
            actor=actor,
            target_type="tontine",
            target_id=tontine.id,
            tontine_id=tontine.id,
            amount=tontine.contribution_amount,
            metadata={
                "participants": len(participants),
                "mode": attribution_mode.value,
            },
        )

        if activate:
            self.activate(tontine, actor, commit=False)

        self.db.commit()
        self.db.refresh(tontine)
        return tontine

    def activate(
        self, tontine: Tontine, actor: OrganizationMember, *, commit: bool = True
    ) -> Tontine:
        """Passe la tontine en `active` : génère cycles et cotisations."""
        participants = self.active_participants(tontine.id)
        if len(participants) < 2:
            raise ValidationError(
                "Une tontine demande au moins deux participants.",
                code="min_two_participants",
            )

        if not self.cycles(tontine.id):
            self._generate_cycles(tontine, participants)

        if tontine.mode is AllocationMode.FULL_ORDER_DRAW and all(
            p.draw_position is None for p in participants
        ):
            # L'ordre complet est tiré au démarrage, côté serveur.
            from app.services.draw_service import DrawService

            DrawService(self.db).generate_full_order(
                tontine=tontine, actor=actor, commit=False
            )

        tontine.status = TontineStatus.ACTIVE.value
        tontine.activated_at = datetime.now(timezone.utc)

        self.audit.record(
            organization_id=tontine.organization_id,
            action=AuditAction.TONTINE_STATUS_CHANGED,
            description=f"Tontine « {tontine.name} » activée.",
            actor=actor,
            target_type="tontine",
            target_id=tontine.id,
            tontine_id=tontine.id,
            metadata={"status": TontineStatus.ACTIVE.value},
        )

        if commit:
            self.db.commit()
            self.db.refresh(tontine)
        return tontine

    def change_status(
        self, tontine: Tontine, status: TontineStatus, actor: OrganizationMember
    ) -> Tontine:
        current = tontine.status_enum
        if status is current:
            return tontine
        if status not in ALLOWED_TRANSITIONS[current]:
            raise ConflictError(
                f"Passage de « {current.value} » à « {status.value} » impossible.",
                code="invalid_status_transition",
                details={"from": current.value, "to": status.value},
            )

        if status is TontineStatus.ACTIVE:
            return self.activate(tontine, actor)

        tontine.status = status.value
        if status in {TontineStatus.COMPLETED, TontineStatus.CANCELLED}:
            tontine.closed_at = datetime.now(timezone.utc)

        self.audit.record(
            organization_id=tontine.organization_id,
            action=AuditAction.TONTINE_STATUS_CHANGED,
            description=f"Tontine « {tontine.name} » : statut {status.value}.",
            actor=actor,
            target_type="tontine",
            target_id=tontine.id,
            tontine_id=tontine.id,
            metadata={"from": current.value, "to": status.value},
        )
        self.db.commit()
        self.db.refresh(tontine)
        return tontine

    def update(
        self, tontine: Tontine, data: dict, actor: OrganizationMember
    ) -> Tontine:
        """Mise à jour des champs descriptifs et des règles de tirage.

        Le montant et la fréquence ne sont modifiables qu'avant activation :
        les cycles et cotisations déjà générés en dépendent.
        """
        locked = {"contribution_amount", "frequency", "start_date", "custom_period_days"}
        if tontine.status_enum is not TontineStatus.DRAFT:
            blocked = locked & {key for key, value in data.items() if value is not None}
            if blocked:
                raise ConflictError(
                    "Ces réglages ne sont plus modifiables après activation.",
                    code="tontine_locked",
                    details={"fields": sorted(blocked)},
                )

        for field, value in data.items():
            if value is None:
                continue
            setattr(tontine, field, getattr(value, "value", value))

        # Déplacer le jour de tirage doit déplacer les tirages à venir, sinon
        # le réglage affiché et la date qui fait foi divergeraient.
        if "draw_day" in data or "due_day" in data:
            self._resync_draw_dates(tontine)

        self.audit.record(
            organization_id=tontine.organization_id,
            action=AuditAction.TONTINE_UPDATED,
            description=f"Tontine « {tontine.name} » mise à jour.",
            actor=actor,
            target_type="tontine",
            target_id=tontine.id,
            tontine_id=tontine.id,
            metadata={"fields": sorted(data)},
        )
        self.db.commit()
        self.db.refresh(tontine)
        return tontine

    def _resync_draw_dates(self, tontine: Tontine) -> None:
        """Réaligne la date d'ouverture des cycles non encore tirés.

        Les cycles déjà attribués gardent la leur : on ne réécrit pas l'histoire
        d'un tirage qui a eu lieu.
        """
        cycles = list(
            self.db.scalars(
                select(TontineCycle)
                .where(TontineCycle.tontine_id == tontine.id)
                .order_by(TontineCycle.sequence_number)
            )
        )
        settled = {CycleStatus.DRAWN.value, CycleStatus.PAID_OUT.value}
        for cycle in cycles:
            if cycle.status in settled:
                continue
            cycle.draw_scheduled_at = compute_draw_opening(
                period_start=cycle.start_date,
                period_end=cycle.end_date,
                draw_day=tontine.effective_draw_day,
            )

    def set_manual_order(
        self,
        tontine: Tontine,
        participant_ids: list[uuid.UUID],
        actor: OrganizationMember,
    ) -> list[TontineParticipant]:
        participants = {p.id: p for p in self.participants(tontine.id)}
        self._apply_manual_order(tontine, participants, participant_ids, actor)
        self.db.commit()
        return self.participants(tontine.id)

    # --- Interne -------------------------------------------------------------

    def _validate_members(
        self, organization_id: uuid.UUID, member_ids: list[uuid.UUID]
    ) -> list[OrganizationMember]:
        unique_ids = list(dict.fromkeys(member_ids))
        if len(unique_ids) != len(member_ids):
            raise ValidationError(
                "Un membre ne peut être ajouté qu'une fois.",
                code="duplicate_participant",
            )
        if len(unique_ids) < 2:
            raise ValidationError(
                "Une tontine demande au moins deux participants.",
                code="min_two_participants",
            )

        statement = (
            select(OrganizationMember)
            .options(joinedload(OrganizationMember.user))
            .where(
                OrganizationMember.id.in_(unique_ids),
                OrganizationMember.organization_id == organization_id,
            )
        )
        found = {member.id: member for member in self.db.scalars(statement).unique()}
        missing = [str(member_id) for member_id in unique_ids if member_id not in found]
        if missing:
            # Un identifiant d'une autre organisation est traité comme inconnu.
            raise ValidationError(
                "Certains membres n'appartiennent pas à cette organisation.",
                code="unknown_participant",
                details={"memberIds": missing},
            )
        return [found[member_id] for member_id in unique_ids]

    def _generate_cycles(
        self, tontine: Tontine, participants: list[TontineParticipant]
    ) -> list[TontineCycle]:
        """Un cycle par participant : chacun reçoit la cagnotte une fois."""
        expected = tontine.pot_for(len(participants))
        periods = build_periods(
            start_date=tontine.start_date,
            frequency=tontine.frequency_enum,
            count=len(participants),
            due_day=tontine.due_day,
            custom_period_days=tontine.custom_period_days,
            draw_day=tontine.effective_draw_day,
        )

        now = datetime.now(timezone.utc)
        cycles: list[TontineCycle] = []
        for period in periods:
            cycle = TontineCycle(
                tontine_id=tontine.id,
                sequence_number=period.sequence_number,
                period_label=period.label,
                start_date=period.start,
                end_date=period.end,
                due_date=period.due,
                draw_scheduled_at=period.draw,
                expected_amount=expected,
                collected_amount=Decimal("0"),
                status=(
                    CycleStatus.COLLECTING.value
                    if period.start <= now <= period.end
                    else CycleStatus.UPCOMING.value
                ),
            )
            self.db.add(cycle)
            cycles.append(cycle)
        self.db.flush()

        # Une ligne de cotisation par participant et par cycle — y compris pour
        # les cycles postérieurs à la réception de la cagnotte.
        for cycle in cycles:
            for participant in participants:
                self.db.add(
                    Contribution(
                        organization_id=tontine.organization_id,
                        tontine_id=tontine.id,
                        cycle_id=cycle.id,
                        participant_id=participant.id,
                        expected_amount=tontine.contribution_amount,
                        paid_amount=Decimal("0"),
                        status=ContributionStatus.PENDING.value,
                        due_date=cycle.due_date,
                    )
                )
        self.db.flush()
        return cycles

    def _apply_manual_order(
        self,
        tontine: Tontine,
        participants: dict[uuid.UUID, TontineParticipant],
        ordered_ids: list[uuid.UUID],
        actor: OrganizationMember,
        *,
        commit: bool = True,
    ) -> None:
        if not ordered_ids:
            raise ValidationError(
                "L'ordre de passage est obligatoire dans ce mode.",
                code="order_required",
            )
        if len(set(ordered_ids)) != len(ordered_ids):
            raise ValidationError(
                "Un participant ne peut apparaître qu'une fois dans l'ordre.",
                code="duplicate_order_entry",
            )
        known = set(participants)
        submitted = set(ordered_ids)
        if submitted - known:
            raise ValidationError(
                "L'ordre contient un participant étranger à la tontine.",
                code="unknown_order_entry",
            )
        if known - submitted:
            raise ValidationError(
                "L'ordre doit contenir tous les participants.",
                code="incomplete_order",
                details={"missing": len(known - submitted)},
            )

        # Positions libérées avant réattribution : la contrainte d'unicité
        # (tontine, position) interdit tout doublon transitoire.
        for participant in participants.values():
            participant.draw_position = None
        self.db.flush()
        for position, participant_id in enumerate(ordered_ids, start=1):
            participants[participant_id].draw_position = position
        self.db.flush()

        self.audit.record(
            organization_id=tontine.organization_id,
            action=AuditAction.ORDER_GENERATED,
            description=f"Ordre de passage défini manuellement ({len(ordered_ids)} participants).",
            actor=actor,
            target_type="tontine",
            target_id=tontine.id,
            tontine_id=tontine.id,
            metadata={
                "mode": tontine.attribution_mode,
                "order": [str(pid) for pid in ordered_ids],
            },
        )
        if commit:
            self.db.commit()

    def collected_for_cycle(self, cycle_id: uuid.UUID) -> Decimal:
        total = self.db.scalar(
            select(func.coalesce(func.sum(Contribution.paid_amount), 0)).where(
                Contribution.cycle_id == cycle_id
            )
        )
        return Decimal(str(total or 0))


def _aware(value: datetime) -> datetime:
    return value if value.tzinfo else value.replace(tzinfo=timezone.utc)

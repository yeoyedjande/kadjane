from __future__ import annotations

from datetime import datetime

from pydantic import computed_field

from app.schemas.base import CamelModel
from app.schemas.organization import OrganizationRead


class UpcomingDeadline(CamelModel):
    tontine_id: str
    tontine_name: str
    cycle_id: str
    period_start: datetime
    due_date: datetime
    amount: float
    is_paid: bool = False


class TrendPoint(CamelModel):
    period_start: datetime
    collected: float
    expected: float


class DashboardRead(CamelModel):
    """`dashboardSnapshot` du contrat d'API.

    Les agrégats liés aux tontines valent 0 tant que le métier tontine n'est
    pas migré : ils sont calculés côté serveur, jamais inventés côté client.
    TODO(tontines): brancher sur les cycles et cotisations réels.
    """

    organization: OrganizationRead
    members_count: int = 0
    active_tontines: int = 0
    expected_this_period: float = 0
    collected_this_period: float = 0
    late_contributions: int = 0
    my_contribution_due: float = 0
    my_contribution_paid: float = 0
    deadlines: list[UpcomingDeadline] = []
    recent_activity: list[dict] = []
    trend: list[TrendPoint] = []
    next_draw: None = None
    current_beneficiary: None = None

    # --- Alias explicites du cahier des charges backend ---------------------
    @computed_field(alias="members_count")
    @property
    def members_count_alias(self) -> int:
        return self.members_count

    @computed_field(alias="active_tontines_count")
    @property
    def active_tontines_count(self) -> int:
        return self.active_tontines

    @computed_field(alias="expected_this_month")
    @property
    def expected_this_month(self) -> float:
        return self.expected_this_period

    @computed_field(alias="collected_this_month")
    @property
    def collected_this_month(self) -> float:
        return self.collected_this_period

    @computed_field(alias="remaining_this_month")
    @property
    def remaining_this_month(self) -> float:
        return max(0.0, self.expected_this_period - self.collected_this_period)

    @computed_field(alias="collection_rate")
    @property
    def collection_rate(self) -> float:
        if self.expected_this_period <= 0:
            return 0.0
        return round(self.collected_this_period / self.expected_this_period, 4)

    @computed_field(alias="late_contributions_count")
    @property
    def late_contributions_count(self) -> int:
        return self.late_contributions

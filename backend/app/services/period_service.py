"""Découpage d'une tontine en périodes de collecte.

Une tontine mensuelle de douze participants produit douze cycles : chacun
reçoit la cagnotte une fois. Les autres fréquences suivent la même logique,
seule la durée de la période change.
"""

from __future__ import annotations

import calendar
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta, timezone

from app.models.enums import TontineFrequency

MONTHS_FR: tuple[str, ...] = (
    "Janvier",
    "Février",
    "Mars",
    "Avril",
    "Mai",
    "Juin",
    "Juillet",
    "Août",
    "Septembre",
    "Octobre",
    "Novembre",
    "Décembre",
)


@dataclass(frozen=True, slots=True)
class Period:
    sequence_number: int
    label: str
    start: datetime
    end: datetime
    due: datetime


def _at(value: date, moment: time) -> datetime:
    return datetime.combine(value, moment, tzinfo=timezone.utc)


def _start_of_day(value: date) -> datetime:
    return _at(value, time.min)


def _end_of_day(value: date) -> datetime:
    return _at(value, time(23, 59, 59))


def add_months(value: date, months: int) -> date:
    """Ajoute des mois en restant dans le mois cible (31 janvier + 1 = 28/29 fév.)."""
    total = value.month - 1 + months
    year = value.year + total // 12
    month = total % 12 + 1
    day = min(value.day, calendar.monthrange(year, month)[1])
    return date(year, month, day)


def month_label(value: date) -> str:
    """`Août 2026`."""
    return f"{MONTHS_FR[value.month - 1]} {value.year}"


def build_periods(
    *,
    start_date: date,
    frequency: TontineFrequency,
    count: int,
    due_day: int = 5,
    custom_period_days: int | None = None,
) -> list[Period]:
    """Construit `count` périodes consécutives à partir de `start_date`."""
    if count <= 0:
        return []

    if frequency is TontineFrequency.MONTHLY:
        return _monthly_periods(start_date, count, due_day)

    length = _period_length(frequency, custom_period_days)
    periods: list[Period] = []
    for index in range(count):
        first = start_date + timedelta(days=length * index)
        last = first + timedelta(days=length - 1)
        due_offset = min(max(due_day, 1), length) - 1
        periods.append(
            Period(
                sequence_number=index + 1,
                label=f"Période du {first.day:02d}/{first.month:02d}/{first.year}",
                start=_start_of_day(first),
                end=_end_of_day(last),
                due=_end_of_day(first + timedelta(days=due_offset)),
            )
        )
    return periods


def _period_length(frequency: TontineFrequency, custom_period_days: int | None) -> int:
    if frequency is TontineFrequency.WEEKLY:
        return 7
    if frequency is TontineFrequency.BIWEEKLY:
        return 14
    # CUSTOM : la durée est portée par la tontine, 30 jours par défaut.
    return max(1, custom_period_days or 30)


def _monthly_periods(start_date: date, count: int, due_day: int) -> list[Period]:
    first_month = date(start_date.year, start_date.month, 1)
    periods: list[Period] = []
    for index in range(count):
        month_start = add_months(first_month, index)
        days_in_month = calendar.monthrange(month_start.year, month_start.month)[1]
        month_end = date(month_start.year, month_start.month, days_in_month)
        due = date(
            month_start.year,
            month_start.month,
            min(max(due_day, 1), days_in_month),
        )
        periods.append(
            Period(
                sequence_number=index + 1,
                label=month_label(month_start),
                start=_start_of_day(month_start),
                end=_end_of_day(month_end),
                due=_end_of_day(due),
            )
        )
    return periods

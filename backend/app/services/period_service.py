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

    # Début du jour où le tirage s'ouvre. `due` marque la fin d'un délai,
    # `draw` l'ouverture d'un droit : d'où le début de journée et non la fin.
    draw: datetime


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
    draw_day: int | None = None,
) -> list[Period]:
    """Construit `count` périodes consécutives à partir de `start_date`.

    `draw_day` omis, le tirage s'ouvre le jour de l'échéance : on tire quand
    tout le monde était censé avoir cotisé.
    """
    if count <= 0:
        return []

    draw_day = draw_day or due_day

    if frequency is TontineFrequency.MONTHLY:
        return _monthly_periods(start_date, count, due_day, draw_day)

    length = _period_length(frequency, custom_period_days)
    periods: list[Period] = []
    for index in range(count):
        first = start_date + timedelta(days=length * index)
        last = first + timedelta(days=length - 1)
        due_offset = min(max(due_day, 1), length) - 1
        draw_offset = min(max(draw_day, 1), length) - 1
        periods.append(
            Period(
                sequence_number=index + 1,
                label=f"Période du {first.day:02d}/{first.month:02d}/{first.year}",
                start=_start_of_day(first),
                end=_end_of_day(last),
                due=_end_of_day(first + timedelta(days=due_offset)),
                draw=_start_of_day(first + timedelta(days=draw_offset)),
            )
        )
    return periods


def compute_draw_opening(
    *, period_start: datetime, period_end: datetime, draw_day: int
) -> datetime:
    """Ouverture du tirage à l'intérieur d'une période déjà découpée.

    Sert aux cycles engendrés avant que la date d'ouverture ne soit stockée :
    la même arithmétique que [build_periods], appliquée après coup. Un jour
    au-delà de la période retombe sur son dernier jour.
    """
    first = period_start.date()
    length = (period_end.date() - first).days + 1
    offset = min(max(draw_day, 1), max(length, 1)) - 1
    return _start_of_day(first + timedelta(days=offset))


def _period_length(frequency: TontineFrequency, custom_period_days: int | None) -> int:
    if frequency is TontineFrequency.WEEKLY:
        return 7
    if frequency is TontineFrequency.BIWEEKLY:
        return 14
    # CUSTOM : la durée est portée par la tontine, 30 jours par défaut.
    return max(1, custom_period_days or 30)


def _monthly_periods(
    start_date: date, count: int, due_day: int, draw_day: int
) -> list[Period]:
    first_month = date(start_date.year, start_date.month, 1)
    periods: list[Period] = []
    for index in range(count):
        month_start = add_months(first_month, index)
        days_in_month = calendar.monthrange(month_start.year, month_start.month)[1]
        month_end = date(month_start.year, month_start.month, days_in_month)
        # Un 31 dans un mois de 30 jours retombe sur le dernier jour.
        due = date(
            month_start.year,
            month_start.month,
            min(max(due_day, 1), days_in_month),
        )
        draw = date(
            month_start.year,
            month_start.month,
            min(max(draw_day, 1), days_in_month),
        )
        periods.append(
            Period(
                sequence_number=index + 1,
                label=month_label(month_start),
                start=_start_of_day(month_start),
                end=_end_of_day(month_end),
                due=_end_of_day(due),
                draw=_start_of_day(draw),
            )
        )
    return periods

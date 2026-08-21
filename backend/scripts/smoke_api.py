"""Vérification de bout en bout de l'API, contre un serveur qui tourne.

Parcourt le chemin critique de la Beta — connexion, organisation, membres,
tontines, cycle courant, notifications, rafraîchissement de session — et sort
en erreur au premier appel qui ne répond pas comme attendu.

    python backend/scripts/smoke_api.py
    python backend/scripts/smoke_api.py --base-url http://192.168.1.10:8000/api/v1

Les requêtes portent une en-tête `Origin` : le script valide donc aussi la
configuration CORS, à l'origine de la panne « impossible de charger les
données » corrigée dans `app/core/config.py`.
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request

DEFAULT_BASE_URL = "http://127.0.0.1:8000/api/v1"

# Port arbitraire : le serveur de développement Flutter Web en choisit un au
# hasard, et c'est précisément ce cas que la configuration CORS doit accepter.
DEFAULT_ORIGIN = "http://localhost:50392"


class Client:
    def __init__(self, base_url: str, origin: str) -> None:
        self.base_url = base_url.rstrip("/")
        self.origin = origin
        self.token: str | None = None
        self.passed = 0
        self.failed = 0

    def call(self, method: str, path: str, body: dict | None = None, expect: int = 200) -> dict:
        data = json.dumps(body).encode() if body is not None else None
        request = urllib.request.Request(self.base_url + path, data=data, method=method)
        request.add_header("Origin", self.origin)
        if data is not None:
            request.add_header("Content-Type", "application/json")
        if self.token:
            request.add_header("Authorization", f"Bearer {self.token}")

        try:
            with urllib.request.urlopen(request, timeout=15) as response:
                status, raw = response.status, response.read()
        except urllib.error.HTTPError as error:
            status, raw = error.code, error.read()
        except urllib.error.URLError as error:
            print(f"KO  {method:6} {path}\n      serveur injoignable : {error.reason}")
            self.failed += 1
            return {}

        try:
            payload = json.loads(raw)
        except ValueError:
            payload = {"raw": raw[:200].decode(errors="replace")}

        if status == expect:
            self.passed += 1
            print(f"OK  {method:6} {path}")
        else:
            self.failed += 1
            print(f"KO  {method:6} {path}  (attendu {expect}, reçu {status})")
            print("      " + json.dumps(payload, ensure_ascii=False)[:300])
        return payload


def rows(payload: dict) -> list:
    """Les collections paginées arrivent sous `data.items`, les autres sous `data`."""
    data = payload.get("data")
    if isinstance(data, dict) and "items" in data:
        return data["items"]
    return data if isinstance(data, list) else []


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL)
    parser.add_argument("--origin", default=DEFAULT_ORIGIN)
    parser.add_argument("--identifier", default="+225 07 00 00 00 01")
    parser.add_argument("--password", default="kadjane")
    args = parser.parse_args()

    api = Client(args.base_url, args.origin)

    print("=== Authentification ===")
    login = api.call(
        "POST", "/auth/login",
        {"identifier": args.identifier, "password": args.password},
    )
    if not login.get("success"):
        print("\nConnexion impossible : le reste du parcours est sans objet.")
        return 1
    api.token = login["data"]["tokens"]["accessToken"]
    refresh_token = login["data"]["tokens"]["refreshToken"]
    api.call("GET", "/auth/me")
    api.call("GET", "/me")

    print("\n=== Organisation ===")
    organizations = api.call("GET", "/organizations")
    if not rows(organizations):
        print("\nAucune organisation : lancer le seed de développement.")
        return 1
    org = rows(organizations)[0]["id"]
    for suffix in (
        "", "/dashboard", "/membership", "/officers", "/roles",
        "/reports", "/treasury", "/audit-logs", "/reminder-campaigns",
    ):
        api.call("GET", f"/organizations/{org}{suffix}")

    print("\n=== Membres ===")
    members = api.call("GET", f"/organizations/{org}/members")
    if rows(members):
        member = rows(members)[0]["id"]
        for suffix in ("", "/contributions", "/payouts/total", "/reminders"):
            api.call("GET", f"/organizations/{org}/members/{member}{suffix}")
        api.call("GET", f"/members/{member}/stats")

    print("\n=== Tontines ===")
    tontines = api.call("GET", f"/organizations/{org}/tontines")
    if rows(tontines):
        # La liste renvoie des résumés : la tontine est imbriquée sous `tontine`.
        summary = rows(tontines)[0]
        tontine = summary.get("tontine", summary)["id"]
        for suffix in (
            "", "/summary", "/participants", "/cycles",
            "/beneficiaries", "/payouts", "/draws", "/contributions",
        ):
            api.call("GET", f"/tontines/{tontine}{suffix}")

        print("\n=== Cycle courant ===")
        current = api.call("GET", f"/tontines/{tontine}/cycles/current")
        cycle = (current.get("data") or {}).get("id")
        if cycle:
            api.call("GET", f"/cycles/{cycle}")
            api.call("GET", f"/cycles/{cycle}/contributions")
            api.call("GET", f"/cycles/{cycle}/contribution-slots")
            api.call("GET", f"/tontines/{tontine}/cycles/{cycle}/contributions")
            api.call("GET", f"/tontines/{tontine}/cycles/{cycle}/draw/eligibility")
            api.call("GET", f"/tontines/{tontine}/cycles/{cycle}/reminder-targets")

    print("\n=== Notifications ===")
    api.call("GET", "/notifications")
    api.call("GET", "/notifications/unread-count")

    print("\n=== Session ===")
    api.call("POST", "/auth/refresh", {"refreshToken": refresh_token})

    print(f"\n===== {api.passed} OK, {api.failed} KO =====")
    return 1 if api.failed else 0


if __name__ == "__main__":
    sys.exit(main())

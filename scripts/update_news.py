import json
import os
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

API_URL = "https://api.sifting.io/v1/fnd/economic-calendar"

now = datetime.now(timezone.utc)
end = now + timedelta(days=365)

params = urllib.parse.urlencode({
    "from": now.strftime("%Y-%m-%dT00:00:00Z"),
    "to": end.strftime("%Y-%m-%dT23:59:59Z"),
    "country": "US",
    "impact": "high",
    "limit": 500,
})

request = urllib.request.Request(
    f"{API_URL}?{params}",
    headers={
        "X-API-Key": os.environ["SIFTING_API_KEY"],
        "Accept": "application/json",
    },
)

with urllib.request.urlopen(request, timeout=30) as response:
    payload = json.load(response)

events = []
for event in payload.get("events", []):
    scheduled = event.get("scheduled_at")
    if not scheduled:
        continue

    dt = datetime.fromisoformat(scheduled.replace("Z", "+00:00"))
    events.append({
        "date": dt.strftime("%Y-%m-%d"),
        "time_utc": dt.strftime("%H:%M"),
        "event_id": event.get("event_id"),
        "name": event.get("name"),
        "currency": event.get("currency", "USD"),
        "impact": event.get("impact", "high"),
        "agency": event.get("agency"),
        "scheduled_at": scheduled,
    })

events.sort(key=lambda x: x["scheduled_at"])

# Your standing rule: every Thursday is a Weekly No Trade Day.
weekly_no_trade = []
day = now.date()
last_day = end.date()
while day <= last_day:
    if day.weekday() == 3:  # Thursday
        weekly_no_trade.append(day.isoformat())
    day += timedelta(days=1)

output = {
    "updated_at": now.isoformat(),
    "source": "SiftingIO",
    "rules": {
        "high_impact_usd": True,
        "weekly_no_trade_day": "Thursday",
    },
    "events": events,
    "weekly_no_trade_days": weekly_no_trade,
}

with open("news.json", "w", encoding="utf-8") as f:
    json.dump(output, f, indent=2, ensure_ascii=False)

print(f"Wrote {len(events)} high-impact USD events and {len(weekly_no_trade)} Thursday no-trade days.")

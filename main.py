import os
import sys
import logging
from urllib.parse import quote
from dotenv import load_dotenv
import requests

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

load_dotenv()

API_KEY = os.getenv("CR_API_KEY")

# Allow overriding the player tag via environment variable; default keeps previous example
PLAYER_TAG = os.getenv("CR_TAG")
PLAYER_TAG_ENC = quote(PLAYER_TAG, safe="")

url = f"https://api.clashroyale.com/v1/players/{PLAYER_TAG_ENC}"
print("URL: " + url)

headers = {
    "Accept": "application/json",
    "Authorization": f"Bearer {API_KEY}",
}

try:
    response = requests.get(url, headers=headers, timeout=10)
    response.raise_for_status()
except requests.RequestException as exc:
    logging.error("Request failed: %s", exc)
    sys.exit(1)

try:
    data = response.json()
except ValueError as exc:
    logging.error("Failed to decode JSON response: %s", exc)
    sys.exit(1)

print("Name:", data.get("name", "<unknown>"))
print("Trophies:", data.get("trophies", "N/A"))
print("Current Deck:")
for card in data.get("currentDeck", []):
    print(" -", card.get("name", "<unknown>"), f"(Lvl {card.get('level', '?')})")

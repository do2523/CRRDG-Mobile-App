import os
import sys
import logging
from urllib.parse import quote
from dotenv import load_dotenv
import requests
import psycopg2
import os


logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

# Load environment variables from .env
load_dotenv()

# Fetch variables
USER = os.getenv("user")
PASSWORD = os.getenv("password")
HOST = os.getenv("host")
PORT = os.getenv("port")
DBNAME = os.getenv("dbname")

# Connect to the database
try:
    connection = psycopg2.connect(
        user=USER,
        password=PASSWORD,
        host=HOST,
        port=PORT,
        dbname=DBNAME,
        sslmode="require" # important for supabase
    )
    print("Connection successful!")
    
    # Create a cursor to execute SQL queries
    cursor = connection.cursor()
    


except Exception as e:
    print(f"Failed to connect: {e}")

# DATABASE_URL="postgresql://postgres:[PASSWORD]@db.dmwtqxrnszsghdxygmuh.supabase.co:5432/postgres"



API_KEY = os.getenv("CR_API_KEY")

# Allow overriding the player tag via environment variable; default keeps previous example
PLAYER_TAG = os.getenv("CR_TAG")

url = f"https://api.clashroyale.com/v1/players/{PLAYER_TAG}"
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



#retrieve existing data
player_name = data.get("name")
trophies = data.get("trophies")
deck = data.get("currentDeck", [])
print("Name:", player_name)
print("Trophies:", trophies)


cursor.execute("""
    INSERT INTO players (tag, name, trophies)
    VALUES (%s, %s, %s)
    ON CONFLICT (tag)
    DO UPDATE SET
        name = EXCLUDED.name,
        trophies = EXCLUDED.trophies,
        last_updated = NOW();
""", (PLAYER_TAG, player_name, trophies))

## insert card in deck
for card in deck:
    card_name = card["name"]
    level = card["level"]

    # Insert card if not exists
    cursor.execute("""
        INSERT INTO cards (name)
        VALUES (%s)
        ON CONFLICT (name) DO NOTHING
        RETURNING id;
    """, (card_name,))

    row = cursor.fetchone()

    # If conflict, fetch card id
    if row is None:
        cursor.execute("SELECT id FROM cards WHERE name=%s", (card_name,))
        row = cursor.fetchone()

    card_id = row[0]

    # Upsert deck entry
    cursor.execute("""
        INSERT INTO player_deck (player_tag, card_id, level)
        VALUES (%s, %s, %s)
        ON CONFLICT (player_tag, card_id)
        DO UPDATE SET
            level = EXCLUDED.level;
    """, (PLAYER_TAG, card_id, level))

# Commit all DB writes
connection.commit()
print("Player + deck saved to Supabase!")

# ===========================================
# 6. Close connection
# ===========================================
cursor.close()
connection.close()
print("Database connection closed.")


print("Name:", data.get("name", "<unknown>"))
print("Trophies:", data.get("trophies", "N/A"))
print("Current Deck:")
for card in data.get("currentDeck", []):
    print(" -", card.get("name", "<unknown>"), f"(Lvl {card.get('level', '?')})")

---
name: db-clone
description: Clone a database (schema + data) into a new database, with verification. Supports SQLite and PostgreSQL. Use when the user wants to copy, clone, duplicate, or snapshot a database into a new file or a new db name. Never overwrites an existing target.
---

# db-clone

Clone an existing database into a **new** one and verify the clone is identical to
the source. The skill never overwrites an existing target — cloning only ever
creates something new.

Currently supported engines (one adapter each, same contract):

| Engine     | Source              | Target                        | Adapter                 |
|------------|---------------------|-------------------------------|-------------------------|
| SQLite     | path to a `.db` file| path to a new file            | `adapters/sqlite.sh`    |
| PostgreSQL | connection URI      | connection URI (new db name)  | `adapters/postgres.sh`  |

## Procedure

Run these steps in order. Ask only for what you don't already have.

### 1. Determine the engine
If the user hasn't said, **ask which database engine** they're cloning: SQLite or
PostgreSQL. Smart hints (confirm, don't assume):
- A `.db` / `.sqlite` / `.sqlite3` path, or a file whose first 16 bytes are
  `SQLite format 3` → **SQLite**.
- A `postgres://` / `postgresql://` URI → **PostgreSQL**.

### 2. Gather source + target
**SQLite:**
- `SOURCE` — path to the existing database file.
- `TARGET` — path for the new clone. If the user gives only a directory or a new
  name, help them form a full path. Default to the source's directory with a
  `-clone` suffix if they don't specify (e.g. `app.db` → `app-clone.db`).

**PostgreSQL:**
- `SOURCE_URL` — full URI to the existing db, e.g.
  `postgresql://user@host:5432/app`.
- `TARGET_URL` — full URI whose **database name does not exist yet**, e.g.
  `postgresql://user@host:5432/app_clone`. Same server is fine; a different
  host/server is also fine (it's a `pg_dump | psql` clone). The user supplies
  credentials via the URI or the standard `PG*` env vars / `.pgpass`.

### 3. Confirm
Restate the plan back to the user before doing anything:
> "Clone **<source>** → **<target>** using the **<engine>** adapter. This creates
> a new database and will not touch anything that already exists. Proceed?"

Wait for a yes.

### 4. Run the adapter
From the skill directory, run the matching adapter with the two arguments:

```bash
# SQLite
bash adapters/sqlite.sh "<SOURCE>" "<TARGET>"

# PostgreSQL
bash adapters/postgres.sh "<SOURCE_URL>" "<TARGET_URL>"
```

The adapter performs: preflight tool check → guards (source exists, target does
NOT) → clone → verification. It exits non-zero if anything fails.

### 5. Report
Relay the adapter's verification block to the user verbatim-in-spirit: whether the
clone passed every check (integrity / schema / constraints / row counts) and where
the new database lives. If it failed, show the failing check — do not claim success.

## Guarantees & limits
- **Never overwrites.** If the target file/db already exists, the skill stops.
- **Verified.** Every clone is checked against the source, not assumed good.
- **Postgres scope:** clones schema + data. Object ownership and GRANT/privileges
  are intentionally not copied, so the clone is portable across servers/roles.
- **Adding engines:** drop a new `adapters/<engine>.sh` honoring the same
  `clone → verify → never-overwrite` contract, then add a branch in step 1–4.

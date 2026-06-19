# Installing the `db-clone` skill in Claude Code

This is a Claude Code **skill**: a folder named `db-clone/` containing a `SKILL.md`
and a few scripts. "Installing" it just means putting this whole folder where
Claude Code looks for skills. The folder name becomes the command — `db-clone/`
gives you `/db-clone`.

---

## If you're letting Claude Code install it for you

Point Claude Code at this folder and tell it: **"Read INSTALL.md and install this
skill."** It should do the following. (These instructions are written to work no
matter what directory Claude is run from.)

> **For the agent:** This `INSTALL.md` lives inside the `db-clone/` folder — the
> same folder that contains `SKILL.md` and an `adapters/` directory. Copy that
> entire `db-clone/` folder into the user's personal skills directory so the result
> is `~/.claude/skills/db-clone/SKILL.md`. Then make the adapter scripts executable.
> Do not rename the folder — the folder name *is* the command name.

---

## Manual install (recommended: global / personal)

A **personal** install makes `/db-clone` available in **every project** — no need to
copy it into each repo. This is the recommended setup.

Run this **from inside the `db-clone/` folder** (the one containing `SKILL.md`):

```bash
mkdir -p ~/.claude/skills
rm -rf ~/.claude/skills/db-clone          # clean any previous copy
cp -R "$PWD" ~/.claude/skills/db-clone
chmod +x ~/.claude/skills/db-clone/adapters/*.sh
```

Verify it landed correctly:

```bash
ls ~/.claude/skills/db-clone/SKILL.md && echo "installed ✅"
```

### Alternative: project-only install
If you ever want it scoped to a single repo instead of global, copy the folder to
that repo's `.claude/skills/` instead of `~/.claude/skills/`. Same folder, same
result — just narrower scope. (You don't need both; global covers everything.)

---

## Does it work immediately, or do I restart?

- If `~/.claude/skills/` **already existed** when you started Claude Code, the new
  skill is picked up **live — no restart needed.** Just type `/db-clone`.
- If `~/.claude/skills/` **did not exist** before this session (you created it just
  now), **restart Claude Code once** so it starts watching that directory. After
  that first restart it's permanent.

---

## Prerequisites (only for the engine you use)

- **SQLite:** the `sqlite3` CLI on your PATH.
- **PostgreSQL:** the client tools `psql` and `pg_dump` on your PATH
  (e.g. `brew install postgresql@16`, or install `libpq`).

The skill checks for these and tells you if one is missing — it won't fail silently.

---

## Using it

In Claude Code, run:

```
/db-clone
```

Claude asks which engine (SQLite or PostgreSQL), then for the source and a **new**
target, restates the plan, clones, and verifies. **It never overwrites an existing
database** — cloning only ever creates something new.

Examples of what you can say:
- "Clone `./app.db` to `./app-backup.db`" — SQLite
- "Clone my Postgres `app` database to `app_staging`"
  → source `postgresql://me@localhost:5432/app`,
     target `postgresql://me@localhost:5432/app_staging`

---

## What's in the folder

```
db-clone/
├── SKILL.md              # what Claude reads: the dispatcher (engine routing only)
├── adapters/
│   ├── sqlite.sh         # SQLite clone + verify + guard
│   └── postgres.sh       # PostgreSQL clone + verify + guard
├── lib/common.sh         # shared verify/report helpers
└── INSTALL.md            # this file
```

Adding another engine later (MySQL, Mongo, …) is a drop-in: add
`adapters/<engine>.sh` that follows the same **clone → verify → never-overwrite**
contract, and add a branch to `SKILL.md`.

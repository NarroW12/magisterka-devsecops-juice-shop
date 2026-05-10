"""Minimal Flask REST API used as test harness for the DevSecOps experiment.

Baseline (clean) version — no intentional vulnerabilities. Scenarios A/B/C
introduce specific defects on dedicated feature branches.
"""

from __future__ import annotations

import os
import sqlite3

from flask import Flask, jsonify, request


def get_db() -> sqlite3.Connection:
    if not hasattr(get_db, "_conn"):
        conn = sqlite3.connect(
            "file::memory:?cache=shared",
            uri=True,
            check_same_thread=False,
        )
        conn.row_factory = sqlite3.Row
        get_db._conn = conn  # type: ignore[attr-defined]
    return get_db._conn  # type: ignore[attr-defined]


def init_db() -> None:
    conn = get_db()
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY,
            username TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS products (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            price REAL NOT NULL
        );
        """
    )
    conn.execute(
        "INSERT OR IGNORE INTO users (id, username, password) VALUES (?, ?, ?)",
        (1, "demo", "demo-only-not-real-credential"),
    )
    conn.execute(
        "INSERT OR IGNORE INTO products (id, name, price) VALUES (?, ?, ?)",
        (1, "Apple Juice", 4.99),
    )
    conn.execute(
        "INSERT OR IGNORE INTO products (id, name, price) VALUES (?, ?, ?)",
        (2, "Orange Juice", 3.49),
    )
    conn.commit()


def create_app() -> Flask:
    app = Flask(__name__)
    app.config["JSON_SORT_KEYS"] = False
    init_db()

    @app.get("/health")
    def health():
        return jsonify(status="ok"), 200

    @app.post("/login")
    def login():
        data = request.get_json(silent=True) or {}
        username = data.get("username", "")
        password = data.get("password", "")

        row = get_db().execute(
            "SELECT id, username FROM users WHERE username = ? AND password = ?",
            (username, password),
        ).fetchone()
        if row is None:
            return jsonify(error="invalid_credentials"), 401
        return jsonify(id=row["id"], username=row["username"]), 200

    @app.get("/products")
    def products():
        rows = get_db().execute(
            "SELECT id, name, price FROM products"
        ).fetchall()
        return jsonify([dict(r) for r in rows]), 200

    return app


app = create_app()


if __name__ == "__main__":
    app.run(
        host=os.environ.get("HOST", "127.0.0.1"),
        port=int(os.environ.get("PORT", "5000")),
    )

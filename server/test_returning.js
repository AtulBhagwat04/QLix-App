import sqlite3 from 'sqlite3';

const db = new sqlite3.Database(':memory:');

db.serialize(() => {
  db.run("CREATE TABLE questions (id TEXT PRIMARY KEY, text TEXT, is_pinned INTEGER DEFAULT 0)");

  // Test db.all with RETURNING
  db.all("INSERT INTO questions (id, text) VALUES (?, ?) RETURNING *", ["1", "Test Question"], (err, rows) => {
    if (err) {
      console.error("db.all with RETURNING failed:", err);
    } else {
      console.log("db.all with RETURNING returned rows:", rows);
    }
    db.close();
  });
});

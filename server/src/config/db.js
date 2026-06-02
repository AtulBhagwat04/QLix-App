import sqlite3 from 'sqlite3';
import mongoose from 'mongoose';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';

dotenv.config();

const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/qlix_db';

// Tables in the application
const TABLES = [
  'users',
  'sessions',
  'participants',
  'polls',
  'poll_options',
  'votes',
  'questions',
  'question_upvotes',
  'quiz_scores',
  'announcements',
  'templates'
];

// Initialize dynamic MongoDB Model Caching
const mongoModels = {};
function getMongoModel(tableName) {
  if (!mongoModels[tableName]) {
    // Dynamic schema-less mongoose schema with id virtual disabled
    const schema = new mongoose.Schema({}, { strict: false, versionKey: false, id: false });
    mongoModels[tableName] = mongoose.model(tableName, schema, tableName);
  }
  return mongoModels[tableName];
}

// Function to translate PostgreSQL schema definitions to SQLite compatible syntax
function translatePgToSqlite(pgSql) {
  let sql = pgSql;
  
  // Remove PostgreSQL extensions
  sql = sql.replace(/CREATE EXTENSION[\s\S]*?;/g, '');
  
  // Remove DROP TYPE and CREATE TYPE enums
  sql = sql.replace(/DROP TYPE[\s\S]*?;/g, '');
  sql = sql.replace(/CREATE TYPE[\s\S]*?AS ENUM\s*\([\s\S]*?\);/g, '');
  
  // Replace ::uuid cast
  sql = sql.replace(/::uuid/gi, '');
  
  // Replace UUID with TEXT
  sql = sql.replace(/\bUUID\b/gi, 'TEXT');
  
  // Replace JSONB with TEXT
  sql = sql.replace(/\bJSONB\b/gi, 'TEXT');
  
  // Replace TIMESTAMP WITH TIME ZONE or TIMESTAMP with TEXT
  sql = sql.replace(/\bTIMESTAMP WITH TIME ZONE\b/gi, 'TEXT');
  sql = sql.replace(/\bTIMESTAMP\b/gi, 'TEXT');
  
  // Replace uuid_generate_v4() with hex(randomblob) UUID v4 generator
  const uuidGenerator = `(lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || substr(lower(hex(randomblob(2))),2) || '-' || substr('89ab',abs(random()) % 4 + 1, 1) || substr(lower(hex(randomblob(2))),2) || '-' || lower(hex(randomblob(6))))`;
  sql = sql.replace(/uuid_generate_v4\(\)/g, uuidGenerator);
  
  // Replace CURRENT_TIMESTAMP with strftime ISO-8601 string
  sql = sql.replace(/DEFAULT CURRENT_TIMESTAMP/gi, `DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))`);
  sql = sql.replace(/CURRENT_TIMESTAMP/gi, `(strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))`);

  // Remove CASCADE from DROP TABLE
  sql = sql.replace(/DROP TABLE IF EXISTS (\w+) CASCADE/gi, 'DROP TABLE IF EXISTS $1');
  
  return sql;
}

// Initialize SQLite in-memory database
const db = new sqlite3.Database(':memory:');

const runSql = (sql, params = []) => new Promise((resolve, reject) => {
  db.run(sql, params, function(err) {
    if (err) reject(err);
    else resolve(this);
  });
});

const allSql = (sql, params = []) => new Promise((resolve, reject) => {
  db.all(sql, params, (err, rows) => {
    if (err) reject(err);
    else resolve(rows || []);
  });
});

const execSql = (sql) => new Promise((resolve, reject) => {
  db.exec(sql, (err) => {
    if (err) reject(err);
    else resolve();
  });
});

// Dynamic SQL query table extractor
function extractTables(sql) {
  const tables = new Set();
  
  // Matches "insert into table_name"
  const insertRegex = /insert\s+into\s+([a-zA-Z0-9_]+)/gi;
  let match;
  while ((match = insertRegex.exec(sql)) !== null) {
    tables.add(match[1].toLowerCase());
  }
  
  // Matches "update table_name"
  const updateRegex = /update\s+([a-zA-Z0-9_]+)/gi;
  while ((match = updateRegex.exec(sql)) !== null) {
    tables.add(match[1].toLowerCase());
  }
  
  // Matches "delete from table_name"
  const deleteRegex = /delete\s+from\s+([a-zA-Z0-9_]+)/gi;
  while ((match = deleteRegex.exec(sql)) !== null) {
    tables.add(match[1].toLowerCase());
  }
  
  return Array.from(tables);
}

// Sync function: Writes SQLite table state back to MongoDB
async function syncTableToMongo(tableName) {
  try {
    const rows = await allSql(`SELECT * FROM ${tableName}`);
    console.log(`MongoDB Bridge [sync]: Syncing table "${tableName}" with SQLite row count: ${rows.length}`);
    const Model = getMongoModel(tableName);
    
    // Completely overwrite the MongoDB collection with updated SQLite state
    const deleteRes = await Model.deleteMany({});
    console.log(`MongoDB Bridge [sync]: Deleted old docs from "${tableName}":`, deleteRes);
    
    if (rows.length > 0) {
      const docs = rows.map(row => {
        const doc = { ...row };
        // Parse settings/structure strings into JSON objects for MongoDB storage
        for (const key of ['settings', 'structure']) {
          if (doc[key] && typeof doc[key] === 'string') {
            try {
              doc[key] = JSON.parse(doc[key]);
            } catch (e) {
              // keep as string
            }
          }
        }
        return doc;
      });
      const insertRes = await Model.insertMany(docs);
      console.log(`MongoDB Bridge [sync]: Inserted ${docs.length} docs into "${tableName}":`, insertRes.length || insertRes);
    }
  } catch (err) {
    console.error(`Failed to sync SQLite table "${tableName}" to MongoDB:`, err);
  }
}

// Format returned rows: parsing datetimes, JSON configurations, & booleans
function formatRows(rows) {
  if (!rows) return [];
  return rows.map(row => {
    const formatted = { ...row };
    for (const key of Object.keys(formatted)) {
      const val = formatted[key];
      
      // Convert SQLite integer booleans (0 or 1) back to JS booleans for fields starting with is/has
      const lowerKey = key.toLowerCase();
      if (lowerKey.startsWith('is_') || lowerKey.startsWith('has_') || lowerKey.startsWith('is') || lowerKey.startsWith('has')) {
        if (val === 0) {
          formatted[key] = false;
          continue;
        } else if (val === 1) {
          formatted[key] = true;
          continue;
        }
      }

      if (typeof val === 'string') {
        if (key.endsWith('_at')) {
          formatted[key] = new Date(val);
        } else if (key === 'settings' || key === 'structure') {
          try {
            formatted[key] = JSON.parse(val);
          } catch (e) {
            // Keep as string
          }
        }
      }
    }
    return formatted;
  });
}

// Translate and Execute SQL
async function executeSQL(pgSql, pgParams = [], clientState = null) {
  // 1. Intercept SELECT NOW()
  if (pgSql.trim().toLowerCase() === 'select now()') {
    return { rows: [{ now: new Date() }], rowCount: 1 };
  }

  // 2. Syntax Translation
  let sql = pgSql;
  sql = sql.replace(/::uuid/gi, '');
  sql = sql.replace(/\bILIKE\b/gi, 'LIKE');
  
  // 3. Postgres style placeholders $1, $2 mapping to SQLite ?
  let params = pgParams;
  const hasPostgresParams = /\$\d+/.test(sql);
  if (hasPostgresParams && pgParams && pgParams.length > 0) {
    const mappedParams = [];
    sql = sql.replace(/\$(\d+)/g, (match, num) => {
      const idx = parseInt(num, 10) - 1;
      mappedParams.push(pgParams[idx]);
      return '?';
    });
    params = mappedParams;
  }

  const sqlLower = sql.toLowerCase();
  
  // Track transaction state
  if (sqlLower.includes('begin')) {
    if (clientState) {
      clientState.transactionActive = true;
      clientState.modifiedTables.clear();
    }
  }

  const isQueryQuery = /^\s*(select|with)/i.test(sql) || /returning/i.test(sql);
  let result;
  
  if (isQueryQuery) {
    const rows = await allSql(sql, params);
    result = { rows: formatRows(rows), rowCount: rows.length };
  } else {
    const runResult = await runSql(sql, params);
    result = { rows: [], rowCount: runResult.changes || 0 };
  }

  // Identify affected tables
  const affected = extractTables(sql);

  if (clientState && clientState.transactionActive) {
    for (const t of affected) {
      clientState.modifiedTables.add(t);
    }
  } else {
    for (const t of affected) {
      await syncTableToMongo(t);
    }
  }

  // Track transaction ending boundaries
  if (sqlLower.includes('commit')) {
    if (clientState) {
      clientState.transactionActive = false;
      for (const t of clientState.modifiedTables) {
        await syncTableToMongo(t);
      }
      clientState.modifiedTables.clear();
    }
  } else if (sqlLower.includes('rollback')) {
    if (clientState) {
      clientState.transactionActive = false;
      clientState.modifiedTables.clear();
    }
  }

  return result;
}

// Database module initialization
async function initialize() {
  console.log('MongoDB Bridge: Connecting to MongoDB...');
  await mongoose.connect(mongoUri);
  console.log('MongoDB Bridge: Connected successfully to MongoDB.');

  console.log('MongoDB Bridge: Initializing SQLite schema...');
  const __dirname = path.dirname(fileURLToPath(import.meta.url));
  const schemaPath = path.resolve(__dirname, '../../schema.sql');
  const pgSql = fs.readFileSync(schemaPath, 'utf8');
  const sqliteSql = translatePgToSqlite(pgSql);
  await execSql(sqliteSql);
  console.log('MongoDB Bridge: SQLite schema initialized.');

  console.log('MongoDB Bridge: Loading startup data from MongoDB...');
  await runSql("PRAGMA foreign_keys = OFF;");
  
  for (const table of TABLES) {
    const Model = getMongoModel(table);
    const docs = await Model.find({}).lean();
    console.log(`MongoDB Bridge: Table "${table}" has ${docs.length} documents in MongoDB.`);
    
    for (const doc of docs) {
      const keys = Object.keys(doc).filter(k => k !== '_id' && k !== '__v');
      if (keys.length === 0) continue;
      
      const placeholders = keys.map(() => '?').join(', ');
      const values = keys.map(k => {
        let val = doc[k];
        if (val && typeof val === 'object') {
          if (val instanceof Date) {
            val = val.toISOString();
          } else {
            val = JSON.stringify(val);
          }
        }
        return val;
      });
      
      const insertSql = `INSERT INTO ${table} (${keys.join(', ')}) VALUES (${placeholders})`;
      try {
        await runSql(insertSql, values);
      } catch (err) {
        console.error(`MongoDB Bridge: Error loading row into table "${table}":`, err.message);
      }
    }
  }
  
  await runSql("PRAGMA foreign_keys = ON;");
  console.log('MongoDB Bridge: Database initialization completed.');
}

// Run startup initialization
await initialize();

// Exported interfaces matching pg Pool
const pool = {
  query: (text, params) => executeSQL(text, params, null),
  connect: async () => {
    const clientState = {
      transactionActive: false,
      modifiedTables: new Set()
    };
    return {
      query: (text, params) => executeSQL(text, params, clientState),
      release: () => {}
    };
  },
  end: async () => {
    await new Promise((resolve) => db.close(() => resolve()));
    await mongoose.disconnect();
    console.log('MongoDB Bridge: All database connections closed.');
  },
  on: (event, handler) => {
    // console.log(`MongoDB Bridge: Registered pool event: ${event}`);
  }
};

export default {
  query: (text, params) => pool.query(text, params),
  pool,
};

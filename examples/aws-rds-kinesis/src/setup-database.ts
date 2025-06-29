import { Pool } from 'pg';
import 'dotenv/config';

// Database configuration constants
const DB_HOST = process.env.DB_HOST!;
const DB_PORT = parseInt(process.env.DB_PORT!);
const DB_USER = process.env.DB_USER!;
const DB_PASSWORD = process.env.DB_PASSWORD!;
const DB_NAME = process.env.DB_NAME!;

console.log('=== Database Configuration ===');
console.log(`Host: ${DB_HOST}`);
console.log(`Port: ${DB_PORT}`);
console.log(`User: ${DB_USER}`);
console.log(`Database: ${DB_NAME}`);
console.log('===============================');

// First connect to postgres database to create our target database
const adminPool = new Pool({
  user: DB_USER,
  host: DB_HOST,
  database: 'postgres', // Connect to default postgres database first
  password: DB_PASSWORD,
  port: DB_PORT,
  ssl: { rejectUnauthorized: false },
});

// Then connect to our target database for table creation
const pool = new Pool({
  user: DB_USER,
  host: DB_HOST,
  database: DB_NAME,
  password: DB_PASSWORD,
  port: DB_PORT,
  ssl: { rejectUnauthorized: false },
});

async function setupDatabase() {

  // First create the database if it doesn't exist
  const adminClient = await adminPool.connect();
  
  try {
    console.log(`Attempting to create database: "${DB_NAME}"`);
    await adminClient.query(`CREATE DATABASE "${DB_NAME}"`);
    console.log(`Database "${DB_NAME}" created successfully!`);
  } catch (error: any) {
    if (error.code === '42P04') {
      console.log(`Database "${DB_NAME}" already exists, continuing...`);
    } else {
      console.error('Error creating database:', error);
      throw error;
    }
  } finally {
    adminClient.release();
    await adminPool.end();
  }

  // Now connect to the target database and create tables
  const client = await pool.connect();
  
  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS people (
        id SERIAL PRIMARY KEY,
        first_name VARCHAR(100) NOT NULL,
        last_name VARCHAR(100) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);

    await client.query(`
      CREATE TABLE IF NOT EXISTS outbox (
        id SERIAL PRIMARY KEY,
        message JSONB NOT NULL,
        status VARCHAR(20) DEFAULT 'pending',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        processed_at TIMESTAMP NULL
      );
    `);

    console.log(`Database setup completed successfully on ${DB_HOST}:${DB_PORT}!`);
    console.log(`Connected to database: ${DB_NAME}`);
    console.log('Tables created: people, outbox');
    console.log('NOTE: AWS DMS will be configured to stream outbox table changes to Kinesis');
  } catch (error) {
    console.error('Error setting up database:', error);
  } finally {
    client.release();
    await pool.end();
  }
}

setupDatabase();
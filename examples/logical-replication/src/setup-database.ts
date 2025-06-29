import { Pool } from 'pg';

const pool = new Pool({
  user: process.env.DB_USER || 'postgres',
  host: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || 'outbox_demo',
  password: process.env.DB_PASSWORD || 'postgres',
  port: parseInt(process.env.DB_PORT || '5432'),
});

async function setupDatabase() {
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

    await client.query(`ALTER SYSTEM SET wal_level = logical;`);
    
    await client.query(`
      SELECT pg_create_logical_replication_slot('outbox_slot', 'wal2json')
      WHERE NOT EXISTS (
        SELECT 1 FROM pg_replication_slots WHERE slot_name = 'outbox_slot'
      );
    `);

    await client.query(`
      CREATE PUBLICATION outbox_publication FOR TABLE outbox;
    `);


    console.log('Database setup completed successfully!');
    console.log('Tables created: people, outbox');
    console.log('Logical replication slot created: outbox_slot');
    console.log('Publication created: outbox_publication');
    console.log('NOTE: PostgreSQL restart may be required for wal_level change');
  } catch (error) {
    console.error('Error setting up database:', error);
  } finally {
    client.release();
    await pool.end();
  }
}

setupDatabase();
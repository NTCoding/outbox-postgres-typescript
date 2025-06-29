import { Pool } from 'pg';

export interface Person {
  id?: number;
  first_name: string;
  last_name: string;
  created_at?: Date;
}

export interface OutboxMessage {
  id?: number;
  message: any;
  status: string;
  created_at?: Date;
  processed_at?: Date;
}

export const pool = new Pool({
  user: process.env.DB_USER!,
  host: process.env.DB_HOST!,
  database: process.env.DB_NAME!,
  password: process.env.DB_PASSWORD!,
  port: parseInt(process.env.DB_PORT!),
});

export class Database {
  async addPerson(firstName: string, lastName: string): Promise<Person> {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      
      const personResult = await client.query(
        'INSERT INTO people (first_name, last_name) VALUES ($1, $2) RETURNING *',
        [firstName, lastName]
      );
      const person = personResult.rows[0];
      
      const outboxMessage = {
        event_type: 'INSERT',
        table_name: 'people',
        data: person,
        timestamp: Math.floor(Date.now() / 1000)
      };
      
      await client.query(
        'INSERT INTO outbox (message) VALUES ($1)',
        [JSON.stringify(outboxMessage)]
      );
      
      await client.query('COMMIT');
      return person;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async getAllPeople(): Promise<Person[]> {
    const client = await pool.connect();
    try {
      const result = await client.query('SELECT * FROM people ORDER BY created_at DESC');
      return result.rows;
    } finally {
      client.release();
    }
  }

  async getOutboxMessages(): Promise<OutboxMessage[]> {
    const client = await pool.connect();
    try {
      const result = await client.query('SELECT * FROM outbox ORDER BY created_at DESC LIMIT 50');
      return result.rows;
    } finally {
      client.release();
    }
  }
}
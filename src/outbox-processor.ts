import { writeFileSync, existsSync } from 'fs';
import { Database } from './database';
import { Client } from 'pg';
// @ts-ignore - no types available for pg-logical-replication
import { LogicalReplicationService, Wal2JsonPlugin } from 'pg-logical-replication';

class OutboxProcessor {
  private db = new Database();
  private logFile = 'outbox-processed.log';
  private errorLogFile = 'outbox-errors.log';
  private slotName = 'outbox_slot';
  private publication = 'outbox_publication';
  private replicationService: LogicalReplicationService | undefined;

  constructor() {
    if (!existsSync(this.logFile)) {
      writeFileSync(this.logFile, '');
    }
    if (!existsSync(this.errorLogFile)) {
      writeFileSync(this.errorLogFile, '');
    }
  }

  async start() {
    console.log('Starting outbox processor...');
    await this.setupReplication();
    await this.setupSubscriptions();
    console.log('Outbox processor started successfully');
  }

  private async setupReplication() {
    const setupClient = new Client({
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432'),
      user: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD || 'postgres',
      database: process.env.DB_NAME || 'outbox_demo'
    });

    await setupClient.connect();
    
    try {
      await setupClient.query(`SELECT pg_create_logical_replication_slot('${this.slotName}', 'wal2json')`);
    } catch (error: any) {
      if (error.code !== '42710') { // 42710 = replication slot already exists
        throw error;
      }
    }
    await setupClient.end();
  }

  private async setupSubscriptions() {
    const config = {
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432'),
      user: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD || 'postgres',
      database: process.env.DB_NAME || 'outbox_demo'
    };

    this.replicationService = new LogicalReplicationService(config, {
      acknowledge: {
        auto: true,
        timeoutSeconds: 10
      }
    });

    this.replicationService.subscribe(new Wal2JsonPlugin(), this.slotName);

    this.replicationService.on('data', (_lsn: any, log: any) => {
      if (log && log.change) {
        for (const change of log.change) {
          if (change.kind === 'insert' && change.table === 'outbox') {
            const messageData = {
              id: change.columnvalues[0],
              message: JSON.parse(change.columnvalues[1]), // message is a JSONB column
              status: change.columnvalues[2],
              created_at: change.columnvalues[3]
            };
            this.processMessage(messageData).catch(error => {
              this.logError('Error processing message', error);
            });
          }
        }
      }
    });

    this.replicationService.on('error', (error: any) => {
      this.logError('Replication service error', error);
      throw new Error(error.message);
    });
  }


  private async processMessage(message: any) {
    try {
      const logEntry = {
        timestamp: new Date().toISOString(),
        messageId: message.id,
        eventType: message.message.event_type,
        tableName: message.message.table_name,
        data: message.message.data,
        originalTimestamp: new Date(message.message.timestamp * 1000).toISOString()
      };

      const logLine = JSON.stringify(logEntry) + '\n';
      writeFileSync(this.logFile, logLine, { flag: 'a' });

      await this.db.markOutboxMessageProcessed(message.id);
    } catch (error) {
      this.logError(`Error processing message ${message.id}`, error);
    }
  }

  private logError(context: string, error: any) {
    const errorEntry = {
      timestamp: new Date().toISOString(),
      context,
      error: error.message || error,
      stack: error.stack || null
    };

    const errorLine = JSON.stringify(errorEntry) + '\n';
    writeFileSync(this.errorLogFile, errorLine, {flag: 'a'});
  }

}

export default OutboxProcessor;
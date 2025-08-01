import express from 'express';
import { existsSync, readFileSync } from 'fs';
import { Database } from './database';
import OutboxProcessor from './outbox-processor';

const app = express();
const db = new Database();
const outboxProcessor = new OutboxProcessor();

outboxProcessor.start();

app.use(express.json());
app.use(express.static('public'));


app.post('/api/people', async (req, res) => {
  try {
    const { firstName, lastName } = req.body;
    const person = await db.addPerson(firstName, lastName);
    res.json(person);
  } catch (error) {
    console.error('Error adding person:', error);
    res.status(500).json({ error: 'Failed to add person' });
  }
});

app.get('/api/people', async (req, res) => {
  try {
    const people = await db.getAllPeople();
    res.json(people);
  } catch (error) {
    console.error('Error getting people:', error);
    res.status(500).json({ error: 'Failed to get people' });
  }
});

app.get('/api/outbox', async (req, res) => {
  try {
    const messages = await db.getOutboxMessages();
    res.json(messages);
  } catch (error) {
    console.error('Error getting outbox messages:', error);
    res.status(500).json({ error: 'Failed to get outbox messages' });
  }
});

function getProcessedMessages(): any[] {
  try {
    const logFile = 'outbox-processed.log';
    if (!existsSync(logFile)) {
      return [];
    }
    
    const content = readFileSync(logFile, 'utf8');
    const lines = content.trim().split('\n').filter(line => line.length > 0);
    return lines.map(line => JSON.parse(line)).reverse().slice(0, 50);
  } catch (error) {
    console.error('Error reading processed messages:', error);
    return [];
  }
}

app.get('/api/processed', async (req, res) => {
  try {
    const processed = getProcessedMessages();
    res.json(processed);
  } catch (error) {
    console.error('Error getting processed messages:', error);
    res.status(500).json({ error: 'Failed to get processed messages' });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});
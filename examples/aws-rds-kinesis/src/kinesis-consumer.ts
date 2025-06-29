import AWS from 'aws-sdk';
import { writeFileSync, appendFileSync } from 'fs';

const kinesis = new AWS.Kinesis({
  region: process.env.AWS_REGION || 'us-east-1'
});

const STREAM_NAME = process.env.KINESIS_STREAM_NAME || 'outbox-stream';

export class KinesisConsumer {
  private shardIterator: string | null = null;

  async startConsuming() {
    console.log(`Starting to consume from Kinesis stream: ${STREAM_NAME}`);
    
    try {
      const streams = await kinesis.listStreams().promise();
      console.log('Available streams:', streams.StreamNames);

      const streamDesc = await kinesis.describeStream({ StreamName: STREAM_NAME }).promise();
      const shardId = streamDesc.StreamDescription.Shards[0].ShardId;

      const iteratorResponse = await kinesis.getShardIterator({
        StreamName: STREAM_NAME,
        ShardId: shardId,
        ShardIteratorType: 'LATEST'
      }).promise();

      this.shardIterator = iteratorResponse.ShardIterator!;
      await this.pollRecords();
    } catch (error) {
      console.error('Error starting Kinesis consumer:', error);
    }
  }

  private async pollRecords() {
    if (!this.shardIterator) return;

    try {
      const response = await kinesis.getRecords({
        ShardIterator: this.shardIterator
      }).promise();

      if (response.Records && response.Records.length > 0) {
        for (const record of response.Records) {
          const data = JSON.parse(record.Data.toString());
          console.log('Received outbox change from DMS:', JSON.stringify(data, null, 2));
          this.processOutboxMessage(data);
        }
      }

      this.shardIterator = response.NextShardIterator!;
      setTimeout(() => this.pollRecords(), 1000);
    } catch (error) {
      console.error('Error polling Kinesis records:', error);
      setTimeout(() => this.pollRecords(), 5000);
    }
  }

  private processOutboxMessage(dmsRecord: any) {
    if (dmsRecord.eventName === 'INSERT' && dmsRecord.dynamodb) {
      const outboxData = dmsRecord.dynamodb.NewImage;
      console.log('Processing outbox message:', outboxData);
      
      const processedMessage = {
        messageId: outboxData.id?.S || 'unknown',
        eventType: 'INSERT',
        tableName: 'outbox',
        data: outboxData,
        timestamp: new Date().toISOString()
      };
      
      try {
        appendFileSync('outbox-processed.log', JSON.stringify(processedMessage) + '\n');
      } catch (error) {
        console.error('Error logging processed message:', error);
      }
    }
  }
}
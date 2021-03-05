#!/usr/bin/env python
import boto3
import logging
import json
import os
import sys
import time


PROCESSING_TIME_SECONDS = 3


def work(queue):
    while True:
        logging.info('Waiting for messages from the queue...')
        messages = queue.receive_messages(WaitTimeSeconds=20)

        if not len(messages):
            logging.info('No messages were returned after last poll')
            continue

        for msg in messages:
            logging.info('Processing message (ID: %s, body: %s)' % (msg.message_id, json.dumps(msg.body)))
            time.sleep(PROCESSING_TIME_SECONDS)
            msg.delete()
            logging.info('Message processed')


if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)

    if 'WORKER_SQS_QUEUE_URL' not in os.environ:
        logging.error('SQS queue URL not specified in env var WORKER_SQS_QUEUE_URL')
        sys.exit(1)

    endpoint_url = None
    if 'WORKER_SQS_ENDPOINT_URL' in os.environ:
        endpoint_url = os.environ['WORKER_SQS_ENDPOINT_URL']

    sqs = boto3.resource('sqs', endpoint_url=endpoint_url)
    queue = sqs.Queue(os.environ['WORKER_SQS_QUEUE_URL'])

    work(queue)

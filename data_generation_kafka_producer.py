import json
import os
import random
import time
from datetime import datetime

from kafka import KafkaProducer
from kafka.sasl.oauth import AbstractTokenProvider
from aws_msk_iam_sasl_signer import MSKAuthTokenProvider

TOPIC_NAME = 'realtimeridedata'
AWS_REGION = os.environ.get('AWS_REGION', 'us-east-2')
BROKERS = os.environ.get('ho', '').split(',')


class MSKTokenProvider(AbstractTokenProvider):
    def generate_token(self):
        token, _ = MSKAuthTokenProvider.generate_auth_token(AWS_REGION)
        return token


tp = MSKTokenProvider()

producer = KafkaProducer(
    bootstrap_servers=BROKERS,
    retry_backoff_ms=500,
    request_timeout_ms=20000,
    security_protocol='SASL_SSL',
    sasl_mechanism='OAUTHBEARER',
    sasl_oauth_token_provider=tp,
    value_serializer=lambda v: json.dumps(v).encode('utf-8'),
)


city = ['Manhattan', 'Brooklyn', 'Queens', 'Bronx', 'Staten Island']
payment_types = ['Credit card', 'Cash', 'No charge', 'Dispute', 'Unknown']
rate_codes = ['Standard', 'JFK', 'Newark', 'Nassau/Westchester', 'Negotiated', 'Group ride']
trip_types = ['Street-hail', 'Dispatch']

def generate_ride_event():
    return {
        'ride_id': random.randint(1, 100000),
        'rider_id': random.randint(1, 5000),
        'driver_id': random.randint(1, 2000),
        'fare': round(random.uniform(5, 75), 2),
        'distance_km': round(random.uniform(0.5, 40), 2),
        
        'pick_up_city': random.choice([city]),
        'rate_code': random.choice([rate_codes]),
        'trip_types': random.choice([trip_types]),
        'payment_type': random.choice([payment_types]),
        'event_time': datetime.utcnow().isoformat(),
    }


if __name__ == '__main__':
    if not any(BROKERS):
        raise SystemExit('KAFKA_BOOTSTRAP_SERVERS env var is not set')
    if not any(AWS_REGION):
        raise SystemExit('AWS_REGION env var is not set')


    try:
        while True:
            event = generate_ride_event()
            producer.send(TOPIC_NAME, value=event)
            print(f'Sent: {event}')
            time.sleep(1)
    except KeyboardInterrupt:
        print('Stopping producer...')
    finally:
        producer.flush()
        producer.close()

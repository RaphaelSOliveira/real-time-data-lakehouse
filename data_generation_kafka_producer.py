import json
import os
import random
import time
from datetime import datetime

from kafka import KafkaProducer
from kafka.sasl.oauth import AbstractTokenProvider
from aws_msk_iam_sasl_signer import MSKAuthTokenProvider

TOPIC_NAME = 'realtimeriskopsdata'
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


transaction_types = ['Wire transfer', 'ACH', 'Card payment', 'ATM withdrawal', 'Loan disbursement']
channels = ['Online banking', 'Mobile app', 'Branch', 'ATM', 'Call center']
currencies = ['USD', 'EUR', 'GBP', 'BRL', 'JPY']
countries = ['US', 'GB', 'DE', 'BR', 'JP', 'NG', 'RU', 'CN']
risk_categories = ['Credit', 'Market', 'Operational', 'Liquidity', 'Compliance']
account_types = ['Checking', 'Savings', 'Credit', 'Investment', 'Corporate']

high_risk_countries = {'NG', 'RU', 'CN'}

def is_flagged(amount, risk_score, origin_country, destination_country):
    return (
        risk_score > 80
        or amount > 200000
        or origin_country in high_risk_countries
        or destination_country in high_risk_countries
    )

def generate_riskops_event():
    amount = round(random.uniform(10, 250000), 2)
    risk_score = round(random.uniform(0, 100), 2)
    origin_country = random.choice(countries)
    destination_country = random.choice(countries)
    return {
        'transaction_id': random.randint(1, 1000000),
        'account_id': random.randint(1, 50000),
        'customer_id': random.randint(1, 20000),
        'amount': amount,
        'currency': random.choice(currencies),
        'transaction_type': random.choice(transaction_types),
        'channel': random.choice(channels),
        'account_type': random.choice(account_types),
        'origin_country': origin_country,
        'destination_country': destination_country,
        'risk_category': random.choice(risk_categories),
        'risk_score': risk_score,
        'is_flagged': is_flagged(amount, risk_score, origin_country, destination_country),
        'event_time': datetime.utcnow().isoformat(),
    }


if __name__ == '__main__':
    if not any(BROKERS):
        raise SystemExit('KAFKA_BOOTSTRAP_SERVERS env var is not set')
    if not any(AWS_REGION):
        raise SystemExit('AWS_REGION env var is not set')


    try:
        while True:
            event = generate_riskops_event()
            producer.send(TOPIC_NAME, value=event)
            print(f'Sent: {event}')
            time.sleep(1)
    except KeyboardInterrupt:
        print('Stopping producer...')
    finally:
        producer.flush()
        producer.close()

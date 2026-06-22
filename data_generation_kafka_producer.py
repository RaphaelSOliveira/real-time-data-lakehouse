import json
import logging
import os
import random
import sys
import time
from datetime import datetime, timezone

from kafka import KafkaProducer
from kafka.errors import KafkaError, KafkaTimeoutError
from kafka.sasl.oauth import AbstractTokenProvider
from aws_msk_iam_sasl_signer import MSKAuthTokenProvider

logging.basicConfig(
    level=os.environ.get('LOG_LEVEL', 'INFO'),
    format='%(asctime)s %(levelname)s %(name)s %(message)s',
)
logger = logging.getLogger('riskops-producer')

TOPIC_NAME = os.environ.get('TOPIC_NAME')
AWS_REGION = os.environ.get('AWS_REGION')
BROKERS = [b for b in os.environ.get('KAFKA_BOOTSTRAP_SERVERS', '').split(',') if b]

# Seconds to wait before retrying after the producer cannot be (re)built.
RECONNECT_BACKOFF_SECONDS = int(os.environ.get('RECONNECT_BACKOFF_SECONDS', '5'))
# Seconds between generated events.
SEND_INTERVAL_SECONDS = float(os.environ.get('SEND_INTERVAL_SECONDS', '1'))


class MSKTokenProvider(AbstractTokenProvider):
    def generate_token(self):
        token, _ = MSKAuthTokenProvider.generate_auth_token(AWS_REGION)
        return token


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
        'event_time': datetime.now(timezone.utc).isoformat(),
    }


def validate_config():
    missing = []
    if not BROKERS:
        missing.append('KAFKA_BOOTSTRAP_SERVERS')
    if not AWS_REGION:
        missing.append('AWS_REGION')
    if not TOPIC_NAME:
        missing.append('TOPIC_NAME')
    if missing:
        raise SystemExit(f'Missing required environment variable(s): {", ".join(missing)}')


def build_producer():
    return KafkaProducer(
        bootstrap_servers=BROKERS,
        retry_backoff_ms=500,
        request_timeout_ms=20000,
        retries=5,
        acks='all',
        security_protocol='SASL_SSL',
        sasl_mechanism='OAUTHBEARER',
        sasl_oauth_token_provider=MSKTokenProvider(),
        value_serializer=lambda v: json.dumps(v).encode('utf-8'),
    )


def on_send_error(event, exc):
    # Async delivery failure: alert but keep the producer alive.
    logger.error('ALERT: failed to deliver event transaction_id=%s: %s',
                 event.get('transaction_id'), exc, exc_info=exc)


def run():
    validate_config()

    producer = None
    try:
        while True:
            # (Re)build the producer if we don't currently have a healthy one.
            if producer is None:
                try:
                    producer = build_producer()
                    logger.info('Kafka producer connected to %s', BROKERS)
                except KafkaError as exc:
                    logger.error('ALERT: could not create Kafka producer: %s. '
                                 'Retrying in %ss', exc, RECONNECT_BACKOFF_SECONDS)
                    time.sleep(RECONNECT_BACKOFF_SECONDS)
                    continue

            event = generate_riskops_event()
            try:
                future = producer.send(TOPIC_NAME, value=event)
                future.add_errback(lambda exc, e=event: on_send_error(e, exc))
                logger.info('Sent: %s', event)
            except KafkaTimeoutError as exc:
                # Buffer full / metadata timeout — transient, keep running.
                logger.error('ALERT: send timed out for transaction_id=%s: %s',
                             event.get('transaction_id'), exc)
            except KafkaError as exc:
                # Producer-level failure — alert, drop this producer and rebuild.
                logger.error('ALERT: producer error for transaction_id=%s: %s. '
                             'Rebuilding producer.', event.get('transaction_id'), exc,
                             exc_info=exc)
                _safe_close(producer)
                producer = None
                continue
            except Exception as e:
                # Never let an unexpected error kill the loop.
                logger.exception(f'ALERT: unexpected error while sending event; continuing. Error {e}')

            time.sleep(SEND_INTERVAL_SECONDS)
    except KeyboardInterrupt:
        logger.info('Stopping producer (received interrupt)...')
    finally:
        if producer is not None:
            _safe_close(producer)


def _safe_close(producer):
    try:
        producer.flush(timeout=10)
        producer.close(timeout=10)
    except Exception:
        logger.exception('Error while closing producer')


if __name__ == '__main__':
    run()

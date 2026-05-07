import logging
import uuid

import httpx
from fastapi import FastAPI
from pythonjsonlogger import jsonlogger

app = FastAPI(title="payment-service", version="0.1.0")

logger = logging.getLogger()
logHandler = logging.StreamHandler()
formatter = jsonlogger.JsonFormatter()
logHandler.setFormatter(formatter)
logger.addHandler(logHandler)
logger.setLevel(logging.INFO)

# Phase 03b — synchronous call to risk-check-service via cluster DNS.
# timeout=2.0 prevents indefinite hang if risk-check is unreachable.
# Per resolved Open Q #2: hard-fail with HTTP 500 on timeout/error;
# graceful degradation is Phase 06 work.
RISK_CHECK_URL = "http://risk-check-service.risk-check.svc.cluster.local/check"
RISK_CHECK_TIMEOUT = 2.0


@app.get("/health")
def health_check():
    return {"status": "ok"}


@app.post("/pay")
def process_payment():
    payment_id = str(uuid.uuid4())

    # dd-trace auto-injects W3C Trace Context headers (traceparent, tracestate)
    # into this httpx.post() — no manual code needed for parent-child span.
    response = httpx.post(
        RISK_CHECK_URL,
        json={"payment_id": payment_id},
        timeout=RISK_CHECK_TIMEOUT,
    )
    response.raise_for_status()
    risk = response.json()["risk"]

    logger.info(
        "payment processed",
        extra={"payment_id": payment_id, "risk": risk},
    )
    return {"payment_id": payment_id, "status": "approved", "risk": risk}

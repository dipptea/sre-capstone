import logging
import uuid
from fastapi import FastAPI
from pythonjsonlogger import jsonlogger

app = FastAPI(title="payment-service", version="0.1.0")

logger = logging.getLogger()
logHandler = logging.StreamHandler()
formatter = jsonlogger.JsonFormatter()
logHandler.setFormatter(formatter)
logger.addHandler(logHandler)
logger.setLevel(logging.INFO)


@app.get("/health")
def health_check():
    # Phase 03 M7 — deliberately broken to validate Helm --atomic auto-rollback.
    # Kubernetes readiness probe hits this endpoint; getting 500 will mark the
    # new pod NotReady, helm upgrade --atomic times out at 5min, rolls back.
    # REVERT after observing the rollback.
    raise Exception("phase 03 m7 negative test — intentional break")


@app.post("/pay")
def process_payment():
    payment_id = str(uuid.uuid4())
    logger.info("payment processed", extra={"payment_id": payment_id})
    return {"payment_id": payment_id, "status": "approved"}

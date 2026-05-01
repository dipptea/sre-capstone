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
    return {"status": "ok"}


@app.post("/pay")
def process_payment():
    payment_id = str(uuid.uuid4())
    logger.info("payment processed", extra={"payment_id": payment_id})
    return {"payment_id": payment_id, "status": "approved"}

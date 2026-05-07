import logging

from fastapi import FastAPI
from pydantic import BaseModel
from pythonjsonlogger import jsonlogger

app = FastAPI(title="risk-check-service", version="0.1.0")

logger = logging.getLogger()
logHandler = logging.StreamHandler()
formatter = jsonlogger.JsonFormatter()
logHandler.setFormatter(formatter)
logger.addHandler(logHandler)
logger.setLevel(logging.INFO)


class CheckRequest(BaseModel):
    payment_id: str


@app.get("/health")
def health_check():
    return {"status": "ok"}


@app.post("/check")
def check_risk(req: CheckRequest):
    # Phase 03b synthetic decision (resolved Open Q #1: always "low").
    # The cross-service trace is the deliverable, not the risk math.
    logger.info(
        "risk check evaluated",
        extra={"payment_id": req.payment_id, "risk": "low"},
    )
    return {"risk": "low", "reason": "synthetic"}

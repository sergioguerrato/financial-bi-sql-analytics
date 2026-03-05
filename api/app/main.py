from fastapi import FastAPI
import redis
import os

app = FastAPI()

redis_host = os.getenv("REDIS_HOST", "localhost")
r = redis.Redis(host=redis_host, port=6379, decode_responses=True)

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/metrics/example")
def example_metric():
    return {"revenue": 100000}


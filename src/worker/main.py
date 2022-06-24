from flask import Flask, request
import logging
import os
import time


SLEEP_SECONDS = 3

logging.basicConfig(level=logging.INFO)
app = Flask(__name__)


@app.route('/pubsub/push', methods=['POST'])
def index():
    envelope = request.get_json()
    if not envelope:
        msg = "no Pub/Sub message received"
        logging.error(f"error: {msg}")
        return (f"Bad request: {msg}", 400)
    
    if not isinstance(envelope, dict) or "message" not in envelope:
        msg = "invalid Pub/Sub message format"
        logging.error(f"error: {msg}")
        return (f"Bad Request: {msg}", 400)
    
    time.sleep(SLEEP_SECONDS)
    logging.getLogger().info("Processed message: %s" % envelope["message"])
    
    return ("", 204)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))

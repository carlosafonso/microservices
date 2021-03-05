FROM python:3.7-alpine

RUN mkdir -p /srv/worker

COPY requirements.txt /srv/worker

WORKDIR /srv/worker

RUN pip install -r requirements.txt

COPY worker.py /srv/worker

ENTRYPOINT ["/srv/worker/worker.py"]

FROM tiangolo/uwsgi-nginx-flask:python3.6-alpine3.8

COPY requirements.txt /app

WORKDIR /app

RUN pip install -r requirements.txt

COPY . /app

FROM python:3.10-slim

RUN pip install --no-cache-dir \
    flask==3.1.0 \
    plotly==5.24.1 \
    requests==2.32.3 \
    oauthenticator==17.4.0 \
    python-dotenv==1.0.1

WORKDIR /app

COPY app.py /app/app.py
COPY routes.py /app/routes.py
COPY models.py /app/models.py
COPY templates/ /app/templates/
COPY static/ /app/static/

RUN mkdir -p /app/logs

EXPOSE 5000

CMD ["python", "app.py"]

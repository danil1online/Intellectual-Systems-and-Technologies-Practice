FROM python:3.10-slim

RUN pip install --no-cache-dir \
    flask==3.1.0 \
    plotly==5.24.1 \
    requests==2.32.3 \
    oauthenticator==24.1.0 \
    python-dotenv==1.0.1

WORKDIR /app

COPY dashboard/app.py /app/app.py
COPY dashboard/routes.py /app/routes.py
COPY dashboard/models.py /app/models.py
COPY dashboard/templates/ /app/templates/
COPY dashboard/static/ /app/static/

RUN mkdir -p /app/logs

EXPOSE 5000

CMD ["python", "app.py"]

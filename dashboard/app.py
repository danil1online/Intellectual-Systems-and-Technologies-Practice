"""
Admin Dashboard — панель преподавателя для мониторинга логов общения
студентов с ИИ-ментором.
"""

import os
import sys
from flask import Flask
from routes import create_api_blueprint

app = Flask(__name__)
app.secret_key = os.environ.get("FLASK_SECRET_KEY", os.urandom(32).hex())

# Регистрация API роутов
api_bp = create_api_blueprint()
app.register_blueprint(api_bp)

if __name__ == "__main__":
    port = int(os.environ.get("DASHBOARD_PORT", "5000"))
    app.run(host="0.0.0.0", port=port, debug=False)

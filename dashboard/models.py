"""
Models для Admin Dashboard.
Простая модель для кэширования логов в памяти.
"""

import threading
from datetime import datetime


class LogEntry:
    """Одна запись лога."""

    def __init__(self, data: dict):
        self.timestamp = data.get("timestamp", "")
        self.student = data.get("student", "unknown")
        self.prompt = data.get("prompt", "")
        self.category = data.get("category", "UNKNOWN")
        self.penalty = data.get("penalty", False)
        self.reason = data.get("reason", "")

    def to_dict(self):
        return {
            "timestamp": self.timestamp,
            "student": self.student,
            "prompt": self.prompt,
            "category": self.category,
            "penalty": self.penalty,
            "reason": self.reason,
        }


class DashboardCache:
    """Кэш логов с автообновлением."""

    def __init__(self):
        self._logs = []
        self._lock = threading.Lock()
        self._last_modified = ""

    def load(self, log_file: str):
        """Загрузить логи из файла."""
        import os
        try:
            mtime = os.path.getmtime(log_file) if os.path.exists(log_file) else ""
            if mtime == self._last_modified:
                return  # Файл не менялся

            logs = []
            with open(log_file, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if line:
                        try:
                            data = json.loads(line)
                            logs.append(LogEntry(data))
                        except json.JSONDecodeError:
                            pass

            with self._lock:
                self._logs = logs
                self._last_modified = mtime

        except FileNotFoundError:
            pass

    def get_logs(self):
        with self._lock:
            return [e.to_dict() for e in self._logs]

    def get_stats(self):
        import glob
        self._logs = []
        log_files = glob.glob("/home/*/.logs/grading_log.json")
        for log_file in sorted(log_files):
            if not os.path.exists(log_file):
                continue
            try:
                with open(log_file, "r", encoding="utf-8") as f:
                    for line in f:
                        line = line.strip()
                        if line:
                            try:
                                data = json.loads(line)
                                self._logs.append(LogEntry(data))
                            except json.JSONDecodeError:
                                pass
            except FileNotFoundError:
                pass
        with self._lock:
            stats = {}
            for entry in self._logs:
                student = entry.student
                if student not in stats:
                    stats[student] = {"total": 0, "lazy": 0, "smart": 0, "penalty": 0}
                stats[student]["total"] += 1
                if entry.category == "LAZY":
                    stats[student]["lazy"] += 1
                elif entry.category == "SMART":
                    stats[student]["smart"] += 1
                if entry.penalty:
                    stats[student]["penalty"] += 1
            return stats

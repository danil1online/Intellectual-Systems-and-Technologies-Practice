# Langflow 1.12.6 + кастомный компонент Neo4j Cypher (бандл ISTP)
FROM langflowai/langflow:1.12.6

# Драйвер Neo4j для кастомного компонента
RUN /app/.venv/bin/pip install --no-cache-dir "neo4j==5.26.*"

# Кастомные компоненты: каждый подкаталог = отдельный бандл (inline bundle)
COPY custom_components/ /app/custom_components/

ENV LANGFLOW_COMPONENTS_PATH=/app/custom_components \
    LANGFLOW_ALLOW_CUSTOM_COMPONENTS=true \
    # Однонаёмный учебный контур: разрешаем локальные sqlite-файлы
    # (students.db монтируется read-only в /app/data).
    LANGFLOW_RESTRICT_LOCAL_FILE_ACCESS=false

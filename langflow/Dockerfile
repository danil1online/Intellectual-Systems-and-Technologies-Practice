# Langflow 1.12.6 (учебный контур ISTP)
FROM langflowai/langflow:1.12.6

# Writable-каталог данных Langflow (БД, логи, кэш, knowledge bases).
# Должен существовать в образе с владельцем `user` (uid 1000): пустой named volume
# при первом монтировании наследует права из образа, иначе langflow не сможет писать.
# /app принадлежит root, а сборка идёт под user — переключаем USER на время RUN.
USER root
RUN mkdir -p /app/.langflow/knowledge_bases && chown -R 1000:0 /app/.langflow
USER user

ENV LANGFLOW_RESTRICT_LOCAL_FILE_ACCESS=false \
    # В образе HOME=/app/data — а /app/data смонтирован read-only.
    # Все $HOME-пути (кэш, .gunicorn, knowledge bases) переносим в writable-том
    # /app/.langflow; LANGFLOW_* заданы явно, не полагаясь на дефолты platformdirs.
    HOME=/app/.langflow \
    LANGFLOW_CONFIG_DIR=/app/.langflow \
    LANGFLOW_KNOWLEDGE_BASES_DIR=/app/.langflow/knowledge_bases

FROM python:3.12-slim
WORKDIR /app
RUN pip install --no-cache-dir langgraph langchain-core langchain-openai opentelemetry-sdk "wrapt<2" microsoft-agents-a365-observability-core microsoft-agents-a365-observability-extensions-langchain
COPY identity.py app.py ./
USER 10001
CMD ["python", "app.py"]

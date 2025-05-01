FROM python:3.10-slim
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1
COPY . /app
RUN pip install --no-cache-dir pytest web3
CMD ["pytest"]
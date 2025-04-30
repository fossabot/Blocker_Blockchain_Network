# 플랫폼 지정 및 Python 3.9-slim 이미지 사용
FROM --platform=linux/amd64 python:3.9-slim

# 기본 패키지 설치
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    libgmp-dev \
    libssl-dev \
    wget \
    cmake \
    && rm -rf /var/lib/apt/lists/*

# 작업 디렉토리 설정
WORKDIR /app

# 요구사항 파일 복사 및 설치
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install wheel && \
    pip install --no-cache-dir -r requirements.txt

# solc 설치
RUN pip install py-solc-x
RUN python -c "import solcx; solcx.install_solc('0.8.17'); solcx.set_solc_version('0.8.17')"

# 프로젝트 파일 복사
COPY . .

# 기본 명령어
CMD ["python", "deploy/deploy_contract.py"]

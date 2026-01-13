#!/bin/bash
set -e

# Harbor 설정
HARBOR_URL="10.255.48.244"
HARBOR_USER="admin"
HARBOR_PASS="Harbor12345!"
PROJECT_DEV="smartlivetech-dev"
PROJECT_PROD="smartlivetech-prod"
IMAGE_NAME="landing"

# 환경 선택 (dev 또는 prod)
ENV=${1:-dev}

if [ "$ENV" == "dev" ]; then
    IMAGE_TAG="dev"
    PROJECT=$PROJECT_DEV
elif [ "$ENV" == "prod" ]; then
    IMAGE_TAG="latest"
    PROJECT=$PROJECT_PROD
else
    echo "Usage: $0 [dev|prod]"
    exit 1
fi

FULL_IMAGE_NAME="${HARBOR_URL}/${PROJECT}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "=== SmartLive Tech Landing 이미지 빌드 및 푸시 ==="
echo "환경: $ENV"
echo "이미지: $FULL_IMAGE_NAME"

# Docker 이미지 빌드
echo "1. Docker 이미지 빌드 중..."
docker build -t $FULL_IMAGE_NAME .

# Harbor 로그인
echo "2. Harbor 로그인 중..."
echo $HARBOR_PASS | docker login $HARBOR_URL -u $HARBOR_USER --password-stdin

# 이미지 푸시
echo "3. 이미지 푸시 중..."
docker push $FULL_IMAGE_NAME

echo "✅ 빌드 및 푸시 완료!"
echo "이미지: $FULL_IMAGE_NAME"

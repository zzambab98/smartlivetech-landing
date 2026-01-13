#!/bin/bash
# GitHub 레파지토리 자동 생성 스크립트

set -e

echo "=== SmartLive Tech Landing GitHub 레파지토리 생성 ==="
echo ""

read -p "GitHub 사용자명을 입력하세요: " GITHUB_USER
read -p "Personal Access Token을 입력하세요 (repo 권한 필요): " GITHUB_TOKEN

REPO_NAME="smartlivetech-landing"
REPO_DESCRIPTION="SmartLive Tech Landing Page"

echo ""
echo "GitHub 레파지토리 생성 중..."

# GitHub API를 사용하여 레파지토리 생성
HTTP_CODE=$(curl -s -o /tmp/github-response.json -w "%{http_code}" \
  -X POST \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  https://api.github.com/user/repos \
  -d "{\"name\":\"${REPO_NAME}\",\"description\":\"${REPO_DESCRIPTION}\",\"private\":false}")

if [ "$HTTP_CODE" == "201" ]; then
    echo "✅ GitHub 레파지토리 생성 완료!"
    REPO_URL="https://${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${REPO_NAME}.git"
    echo "레파지토리 URL: https://github.com/${GITHUB_USER}/${REPO_NAME}"
    echo ""
    
    # 원격 레파지토리 추가 및 푸시
    echo "원격 레파지토리 설정 중..."
    git remote add origin $REPO_URL 2>/dev/null || git remote set-url origin $REPO_URL
    
    echo "코드 푸시 중..."
    git push -u origin main
    
    echo ""
    echo "✅ 모든 작업 완료!"
    echo "레파지토리: https://github.com/${GITHUB_USER}/${REPO_NAME}"
else
    echo "❌ GitHub 레파지토리 생성 실패!"
    echo "HTTP 코드: $HTTP_CODE"
    cat /tmp/github-response.json | grep -o '"message":"[^"]*"' || cat /tmp/github-response.json
    echo ""
    echo "레파지토리가 이미 존재하는 경우, 다음 명령어로 푸시할 수 있습니다:"
    echo "  git remote add origin https://${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${REPO_NAME}.git"
    echo "  git push -u origin main"
    exit 1
fi

rm -f /tmp/github-response.json

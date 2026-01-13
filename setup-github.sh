#!/bin/bash
# GitHub 레파지토리 설정 스크립트

echo "=== SmartLive Tech Landing GitHub 레파지토리 설정 ==="
echo ""
echo "이 스크립트는 GitHub 레파지토리를 설정하고 코드를 푸시합니다."
echo ""
read -p "GitHub 사용자명을 입력하세요: " GITHUB_USER
read -p "Personal Access Token이 있나요? (y/n): " HAS_TOKEN

if [ "$HAS_TOKEN" == "y" ]; then
    read -p "Personal Access Token을 입력하세요: " GITHUB_TOKEN
    REPO_URL="https://${GITHUB_TOKEN}@github.com/${GITHUB_USER}/smartlivetech-landing.git"
else
    REPO_URL="https://github.com/${GITHUB_USER}/smartlivetech-landing.git"
fi

echo ""
echo "원격 레파지토리 추가 중..."
git remote add origin $REPO_URL 2>/dev/null || git remote set-url origin $REPO_URL

echo "코드 푸시 중..."
git push -u origin main

echo ""
echo "✅ GitHub 레파지토리 설정 완료!"
echo "레파지토리 URL: $REPO_URL"

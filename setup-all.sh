#!/bin/bash
# 전체 설정 자동화 스크립트

set -e

echo "=========================================="
echo "SmartLive Tech Landing 전체 설정 자동화"
echo "=========================================="
echo ""

# GitHub 정보 입력
read -p "GitHub 사용자명을 입력하세요: " GITHUB_USER
read -p "GitHub Personal Access Token을 입력하세요 (repo 권한 필요): " GITHUB_TOKEN

REPO_NAME="smartlivetech-landing"
REPO_URL="https://${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${REPO_NAME}.git"

echo ""
echo "=== 1단계: GitHub 레파지토리 생성 ==="
HTTP_CODE=$(curl -s -o /tmp/github-response.json -w "%{http_code}" \
  -X POST \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  https://api.github.com/user/repos \
  -d "{\"name\":\"${REPO_NAME}\",\"description\":\"SmartLive Tech Landing Page\",\"private\":false}")

if [ "$HTTP_CODE" == "201" ]; then
    echo "✅ GitHub 레파지토리 생성 완료!"
elif [ "$HTTP_CODE" == "422" ]; then
    echo "⚠️  레파지토리가 이미 존재합니다. 계속 진행합니다..."
else
    echo "❌ GitHub 레파지토리 생성 실패! (HTTP: $HTTP_CODE)"
    cat /tmp/github-response.json | grep -o '"message":"[^"]*"' || cat /tmp/github-response.json
    exit 1
fi

echo ""
echo "=== 2단계: 코드 푸시 ==="
cd /home/ubuntu/smartlivetech-landing
git remote add origin $REPO_URL 2>/dev/null || git remote set-url origin $REPO_URL
git push -u origin main || echo "⚠️  푸시 실패 (이미 푸시되었을 수 있음)"

echo ""
echo "=== 3단계: Harbor 프로젝트 확인 ==="
echo "Harbor 웹 UI (http://10.255.48.244)에서 'smartlivetech-prod' 프로젝트를 생성해주세요."
echo "프로젝트 생성 후 Enter를 눌러주세요..."
read

echo ""
echo "=== 4단계: Jenkins Job 생성 ==="
JENKINS_URL="http://10.255.48.245:8080"
JENKINS_USER="admin"
JENKINS_PASS="admin123!"
JOB_NAME="smartlivetech-landing-build-prod"

# Jenkins Job XML 생성
cat > /tmp/jenkins-job-temp.xml <<EOF
<?xml version='1.1' encoding='UTF-8'?>
<project>
  <description>SmartLive Tech Landing 페이지 빌드 및 Harbor 푸시 (Prod 환경)</description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <scm class="hudson.plugins.git.GitSCM" plugin="git@5.0.0">
    <configVersion>2</configVersion>
    <userRemoteConfigs>
      <hudson.plugins.git.UserRemoteConfig>
        <url>${REPO_URL}</url>
      </hudson.plugins.git.UserRemoteConfig>
    </userRemoteConfigs>
    <branches>
      <hudson.plugins.git.BranchSpec>
        <name>*/main</name>
      </hudson.plugins.git.BranchSpec>
    </branches>
    <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
    <submoduleCfg class="list"/>
    <extensions/>
  </scm>
  <canRoam>true</canRoam>
  <disabled>false</disabled>
  <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
  <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
  <triggers/>
  <concurrentBuild>false</concurrentBuild>
  <builders>
    <hudson.tasks.Shell>
      <command>#!/bin/bash
set -e

echo "=== Kaniko를 사용한 Prod 환경 Landing 이미지 빌드 시작 ==="

export PATH="/var/jenkins_home/bin:$PATH"

IMAGE_NAME="10.255.48.244/smartlivetech-prod/landing:latest"
BUILD_ID=$(date +%s)
POD_NAME="kaniko-landing-build-prod-\${BUILD_ID}"

kubectl create secret generic harbor-registry-secret-jenkins \\
  --from-literal=.dockerconfigjson="{\\"auths\\":{\\"10.255.48.244\\":{\\"username\\":\\"admin\\",\\"password\\":\\"Harbor12345!\\",\\"auth\\":\\"\$(echo -n 'admin:Harbor12345!' | base64)\\"}}}" \\
  --dry-run=client -o yaml | kubectl apply -n jenkins -f -

cat &lt;&lt;EOF2 | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: \${POD_NAME}
  namespace: jenkins
spec:
  restartPolicy: Never
  initContainers:
  - name: git-clone
    image: alpine/git:latest
    command:
    - sh
    - -c
    - |
      git clone -b main ${REPO_URL} /workspace
    volumeMounts:
    - name: workspace
      mountPath: /workspace
  containers:
  - name: kaniko
    image: gcr.io/kaniko-project/executor:latest
    args:
    - --context=/workspace
    - --dockerfile=/workspace/Dockerfile
    - --destination=\${IMAGE_NAME}
    - --insecure
    - --skip-tls-verify
    volumeMounts:
    - name: kaniko-secret
      mountPath: /kaniko/.docker
    - name: workspace
      mountPath: /workspace
  volumes:
  - name: kaniko-secret
    secret:
      secretName: harbor-registry-secret-jenkins
      items:
      - key: .dockerconfigjson
        path: config.json
  - name: workspace
    emptyDir: {}
EOF2

sleep 5

for i in {1..120}; do
  POD_STATUS=\$(kubectl get pod \${POD_NAME} -n jenkins -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
  if [ "\$POD_STATUS" == "Succeeded" ] || [ "\$POD_STATUS" == "Failed" ]; then
    break
  fi
  sleep 5
done

kubectl logs -n jenkins \${POD_NAME} || echo "로그를 가져올 수 없습니다"
POD_STATUS=\$(kubectl get pod \${POD_NAME} -n jenkins -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
kubectl delete pod \${POD_NAME} -n jenkins --ignore-not-found=true
kubectl delete secret harbor-registry-secret-jenkins -n jenkins --ignore-not-found=true

if [ "\${POD_STATUS}" == "Succeeded" ]; then
  echo "✅ 빌드 성공!"
  exit 0
else
  echo "❌ 빌드 실패!"
  exit 1
fi</command>
    </hudson.tasks.Shell>
  </builders>
  <publishers/>
  <buildWrappers/>
</project>
EOF

CRUMB=$(curl -s -u ${JENKINS_USER}:${JENKINS_PASS} \
  "${JENKINS_URL}/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)")

HTTP_CODE=$(curl -s -o /tmp/jenkins-response.txt -w "%{http_code}" \
  -X POST \
  -u ${JENKINS_USER}:${JENKINS_PASS} \
  -H "$CRUMB" \
  -H "Content-Type: application/xml" \
  --data-binary @/tmp/jenkins-job-temp.xml \
  "${JENKINS_URL}/createItem?name=${JOB_NAME}")

if [ "$HTTP_CODE" == "200" ] || [ "$HTTP_CODE" == "201" ]; then
    echo "✅ Jenkins Job 생성 완료!"
    echo "Job URL: ${JENKINS_URL}/job/${JOB_NAME}"
else
    echo "⚠️  Jenkins Job 생성 실패 또는 이미 존재함 (HTTP: $HTTP_CODE)"
fi

rm -f /tmp/github-response.json /tmp/jenkins-job-temp.xml /tmp/jenkins-response.txt

echo ""
echo "=========================================="
echo "✅ 전체 설정 완료!"
echo "=========================================="
echo ""
echo "다음 단계:"
echo "1. Harbor에서 이미지 빌드: Jenkins에서 '${JOB_NAME}' Job 실행"
echo "2. DNS 설정: smartlive.co.kr, www.smartlive.co.kr → 기존 공인 IP"
echo "3. 배포 확인: kubectl get pods -n k8s-care-bridge-prod -l app=landing"
echo ""

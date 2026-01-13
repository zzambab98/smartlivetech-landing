#!/bin/bash
# Jenkins Job 생성 스크립트

set -e

echo "=== SmartLive Tech Landing Jenkins Job 생성 ==="
echo ""

# Jenkins 설정
JENKINS_URL="http://10.255.48.245:8080"
JENKINS_USER="admin"
JENKINS_PASS="admin123!"
JOB_NAME="smartlivetech-landing-build-prod"

# GitHub 레파지토리 URL 확인
read -p "GitHub 사용자명을 입력하세요: " GITHUB_USER
read -p "Personal Access Token이 있나요? (y/n): " HAS_TOKEN

if [ "$HAS_TOKEN" == "y" ]; then
    read -p "Personal Access Token을 입력하세요: " GITHUB_TOKEN
    REPO_URL="https://${GITHUB_TOKEN}@github.com/${GITHUB_USER}/smartlivetech-landing.git"
else
    REPO_URL="https://github.com/${GITHUB_USER}/smartlivetech-landing.git"
fi

echo ""
echo "Jenkins Job XML 파일 생성 중..."

# Jenkins Job XML 파일 생성
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

echo "CSRF Crumb 가져오는 중..."
CRUMB=$(curl -s -u ${JENKINS_USER}:${JENKINS_PASS} \
  "${JENKINS_URL}/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)")

echo "Jenkins Job 생성 중..."
HTTP_CODE=$(curl -s -o /tmp/jenkins-response.txt -w "%{http_code}" \
  -X POST \
  -u ${JENKINS_USER}:${JENKINS_PASS} \
  -H "$CRUMB" \
  -H "Content-Type: application/xml" \
  --data-binary @/tmp/jenkins-job-temp.xml \
  "${JENKINS_URL}/createItem?name=${JOB_NAME}")

if [ "$HTTP_CODE" == "200" ] || [ "$HTTP_CODE" == "201" ]; then
    echo "✅ Jenkins Job 생성 완료!"
    echo "Job 이름: ${JOB_NAME}"
    echo "Jenkins URL: ${JENKINS_URL}/job/${JOB_NAME}"
else
    echo "❌ Jenkins Job 생성 실패!"
    echo "HTTP 코드: $HTTP_CODE"
    cat /tmp/jenkins-response.txt
    exit 1
fi

# 임시 파일 정리
rm -f /tmp/jenkins-job-temp.xml /tmp/jenkins-response.txt

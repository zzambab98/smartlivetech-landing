# SmartLive Tech Landing Page

SmartLive Tech 랜딩 페이지 프로젝트입니다.

## 빌드 및 실행

### Docker 빌드
```bash
docker build -t smartlivetech-landing:latest .
```

### Docker 실행
```bash
docker run -p 8080:80 smartlivetech-landing:latest
```

## 배포

이 프로젝트는 Kubernetes를 통해 배포되며, ArgoCD를 통해 자동 동기화됩니다.

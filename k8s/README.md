# Kubernetes Workloads (K8s)

이 디렉토리는 홈랩의 K3s 클러스터 내에 배포되는 모든 애플리케이션 및 인프라 매니페스트를 관리합니다.
현재 대부분의 워크로드는 **ArgoCD**를 통해 선언적으로(GitOps) 관리되고 있습니다.

## 주요 디렉토리 구조

- `argocd/`: ArgoCD에서 감시할 각 애플리케이션 리소스 정의 (App of Apps 구조)
- `cert-manager/`: Let's Encrypt 및 Cloudflare DNS-01 챌린지를 통한 TLS 인증서 설정
- `gateway/`: Envoy Gateway 기반의 인그레스 라우팅 및 `HTTPRoute` 전역 설정
- `observability/`: Prometheus, Loki, Tempo, Grafana 등 모니터링 스택 (Helm 기반)
- `sealed-secrets/`: Bitnami Sealed Secrets Controller 매니페스트 (클러스터 내부 암복호화 담당)
- 기타 (`database`, `gitea`, `gateway` 등): 개별 애플리케이션 및 인프라 리소스 모음

## 시크릿(Secrets) 관리 가이드 (Sealed Secrets 체제)

보안상 민감한 시크릿(비밀번호, 토큰 등)은 평문으로 리포지토리에 저장하지 않고, **Bitnami Sealed Secrets**를 사용하여 암호화된 `SealedSecret` CRD 형식으로 관리합니다.

1. **시크릿 생성**: 로컬에서 `kubectl create secret generic ... --dry-run=client -o yaml` 로 평문 시크릿 백업 템플릿을 만듭니다.
2. **시크릿 암호화**: `kubeseal --format=yaml < plaintext-secret.yaml > sealed-secret.yaml` 명령을 사용하여 시크릿을 암호화합니다.
3. **코드 커밋**: 생성된 `sealed-secret.yaml`을 해당 앱 경로에 저장하고 푸시합니다.
4. **GitOps 배포**: ArgoCD가 `SealedSecret`을 배포하면, 클러스터의 Controller가 자동으로 이를 복호화해 Native `Secret` 객체를 생성합니다.

*(※ 로컬의 `.env` 환경변수들과 `scripts/apply-secrets.sh`를 활용하던 이전 방식은 Deprecated 되어 삭제되었습니다.)*

## 노출 및 네트워킹

- **External Gateway**: OPNsense 의 NAT 포트포워딩을 거치는 외부 퍼블릭 접근용 게이트웨이 (`.4.80`)
- **Internal Gateway**: 홈랩 로컬 네트워크(LAN)에서만 참조 가능한 내부 서비스용 게이트웨이 (`.4.84`)

모든 앱 노출은 `HTTPRoute` 리소스를 정의하여 외부/내부 Gateway 객체에 바인딩함으로써 이루어집니다. 외부망인지 내부망인지에 따라 `parentRefs` 설정을 명확하게 분리해야 합니다.

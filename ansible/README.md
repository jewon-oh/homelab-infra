# Configuration Management (Ansible)

이 디렉토리는 프로비저닝된 인스턴스에 K3s 클러스터를 자동화하여 배포하고, 네트워크(Cilium), 스토리지(Longhorn), 배포 도구(ArgoCD) 등 플랫폼 필수 애드온을 일관되게 구성하는 역할을 담당합니다.

## 실행 요구사항

- 로컬 환경(Windows WSL2 권장)에 Ansible 설치
- `~/.ssh/config` 와 `~/.ssh/id_rsa` 가 구성되어 있어야 하며, `inventory.yml` 에 선언된 서버 리스트에 암호 프롬프트 없이 SSH 접속이 가능한 상태여야 함
- 프로비저닝 대상 노드에 Python3 및 패스워드 없는 Sudo 권한(`NOPASSWD`)이 준비되어 있어야 함

## 주요 플레이북 (`site.yml`)

`site.yml` 파일 내에 정의된 롤(Role) 들은 태그(Tag)별로 실행 분리가 가능합니다. 초기 퍼블리싱이나 일부 변경 시, 혹은 인프라 장애 후 복원 작업 시 전체를 다시 적용할 필요 없이 사용할 수 있습니다.

```bash
# 전체 클러스터 설치 및 동기화
ansible-playbook -i inventory.yml site.yml --tags k3s

# 특정 애드온만 배포할 때 (예: Longhorn, ArgoCD)
ansible-playbook -i inventory.yml site.yml --tags longhorn
ansible-playbook -i inventory.yml site.yml --tags argocd
```

## 신규 노드 추가 워크플로우

1. 홈랩 인프라에 새로운 VM이나 Bare-metal(SBC 등)이 추가되면 `inventory.yml`에 노드명과 IP 정보를 기입
2. 해당 노드의 역할(서버/워커)에 맞게 그룹 리스트에 할당
3. `ansible-playbook -i inventory.yml site.yml --tags k3s-worker` 등 역할에 맞는 태그로 롤(Role)을 실행시켜 기존 K3s 클러스터에 조인 (Join)

# Infrastructure as Code (Terraform)

이 디렉터리는 홈랩의 기반 인프라인 가상머신(VM)을 Proxmox에 동적으로 프로비저닝하기 위해 관리됩니다.

## 디렉터리별 목적

- `k3s-cluster/`: K3s Control Plane, Worker 노드 등 홈랩 메인 클러스터의 VM 인스턴스를 배포

## 사용 방법 (k3s-cluster 예시)

1. 초기 `terraform.tfvars` 설정 (Proxmox API 토큰, 패스워드, 스토리지 타겟 등 포함)
   ```bash
   cd terraform/k3s-cluster
   cp terraform.tfvars.example terraform.tfvars
   # tfvars 내용을 현재 환경 및 인증정보에 맞게 편집
   ```
2. 프로비저닝 초기화 및 실행
   ```bash
   terraform init
   terraform plan  # 실제 환경 변동 전에 변경되는 리소스 목록 확인
   terraform apply # 실제 VM 배포 및 서버에 적용
   ```

## 상태(State) 파일 및 확장 유의사항

- 현재 로컬에 저장되는 `.tfstate` 파일은 Proxmox 상의 배포된 VM 상태와 밀접하게 바인딩되어 있으므로 임의로 삭제해서는 안 되며, 삭제 시 Terraform 제어권을 잃어버리게 됩니다.
- 인프라 스펙(CPU/Memory/Disk 용량)을 확장(Scale-up)하거나 줄일 때에는, 해당 테라폼 코드를 수정한 뒤 반드시 `terraform plan` 과정을 통해 In-place 변경(삭제 후 재생성이 아닌 재부팅/업데이트 처리)이 정상적으로 이루어지는지 체크한 후에만 `apply`를 수행하십시오.

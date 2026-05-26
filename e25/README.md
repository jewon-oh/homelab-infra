# E25 — Radxa E25 서비스 호스팅 구성

## 역할

클러스터 외부에서 독립적으로 운영되는 네트워크 서비스 노드.
k3s 클러스터가 다운되어도 DNS, 모니터링, 보안이 살아있음.

## 서비스 구성

| 서비스       | 포트                | 역할                 |
| ------------ | ------------------- | -------------------- |
| AdGuard Home | :53 (DNS), :80 (UI) | DNS 광고 차단        |
| Uptime Kuma  | :3001               | 서비스 가동 모니터링 |

> CrowdSec LAPI는 OPNsense(192.168.1.1:8080)에서 운영하고, Envoy bouncer는 k3s 내부에 그대로 둠.

## 네트워크 연결

```text
keepLiNK Port 1
  └── 언매니지드 2.5G 스위치
        ├── OPNsense (기존)
        └── E25 eth0  →  LAN (192.168.1.x)
E25 eth1  →  미사용 (향후 서브라우터 용도)
```

## 실행

```bash
# 1. E25에 SSH 접속 후
git clone <homelab-infra> && cd e25

# 2. AdGuard + Uptime Kuma 실행
docker compose up -d adguard uptime-kuma

# 3. PC DNS 또는 OPNsense DNS upstream을 E25 IP(192.168.1.196)로 변경
```

## 기존 k8s 서비스 제거 순서

1. PC DNS 전환 확인 후 adguard ArgoCD app 삭제
2. uptime-kuma ArgoCD app 삭제 (데이터는 rsync로 먼저 이전)

## Uptime Kuma 데이터 이전

```bash
# 기존 k3s PVC에서 데이터 추출
kubectl exec -n uptime-kuma deploy/uptime-kuma -- tar czf - /app/data \
  | ssh user@<E25-IP> "tar xzf - -C ~/e25/data/uptime-kuma --strip-components=2"
```

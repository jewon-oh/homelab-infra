 
 # ─── K3s HA 클러스터 인프라 (Terraform = VM 생성만) ───
# Techno Tim k3s-ansible로 소프트웨어 설치
# 구성: server 3 (embedded etcd HA) + worker (SVC VLAN40 + LAN VLAN1)
#
# 사전 조건:
#   1. 각 Proxmox 노드에 Cloud-Init 템플릿 VM이 존재해야 함
#   2. SVC VLAN40용 bridge (vnetsvc)가 양쪽 노드에 존재해야 함
#   3. LAN VLAN1용 bridge (vmbr0)가 해당 노드에 존재해야 함

# =========================================================
# [사전 작업] Proxmox 쉘에서 Cloud-Init 템플릿 VM 생성
# 각 노드(um880, wtr-pro)에서 실행 필요
# =========================================================
# wget https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2 -O /tmp/debian-12-cloud.qcow2
# qm create 9000 --name debian-12-cloud-template --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
# qm importdisk 9000 /tmp/debian-12-cloud.qcow2 app-1
# qm set 9000 --scsihw virtio-scsi-pci --scsi0 app-1:vm-9000-disk-0
# qm set 9000 --ide2 app-1:cloudinit
# qm set 9000 --boot c --bootdisk scsi0
# qm set 9000 --serial0 socket --vga serial0
# qm set 9000 --agent enabled=1
# qm template 9000
# rm /tmp/debian-12-cloud.qcow2

terraform {
  required_version = ">= 1.5"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.78"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = var.proxmox_api_token
  insecure  = true
}

# =========================================================
# K3s Server VMs — HA control plane (embedded etcd, 3 nodes)
# server 노드는 반드시 같은 VLAN(SVC)에 배치
# =========================================================
resource "proxmox_virtual_environment_vm" "k3s_server" {
  for_each = var.servers

  node_name = each.value.proxmox_node
  vm_id     = each.value.vm_id
  name      = each.key

  description         = "K3s Server Node (HA) - Terraform managed"
  tags                = ["terraform", "k3s", "server"]
  started             = true
  on_boot             = true
  stop_on_destroy     = true
  reboot_after_update = false

  # 디스크 I/O 성능·안정성 튜닝 (디스크당 독립 iothread)
  scsi_hardware = "virtio-scsi-single"

  clone {
    vm_id = each.value.template_vm_id
  }

  agent {
    enabled = true
    timeout = "30s"
  }

  cpu {
    cores = each.value.cpu_cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
    # floating = dedicated → ballooning(동적 메모리 재분배) 비활성화.
    # 홈랩은 호스트 RAM 여유가 충분해 VM이 할당된 메모리를 고정으로 쓰도록 함.
    floating = each.value.memory
  }

  disk {
    datastore_id = each.value.storage
    interface    = "scsi0"
    size         = each.value.disk_size
    discard      = "on"
    ssd          = true
    aio          = "threads"
    cache        = "none"
    iothread     = true
  }

  # 추가 데이터 디스크 (Longhorn 등) — extra_disks list 로 지정.
  # scsi1 부터 순서대로 attach.
  dynamic "disk" {
    for_each = each.value.extra_disks
    iterator = d
    content {
      datastore_id = d.value.storage
      interface    = "scsi${d.key + 1}"
      size         = d.value.size
      discard      = "on"
      ssd          = true
      aio          = "threads"
      cache        = "none"
      iothread     = true
    }
  }

  network_device {
    bridge   = each.value.bridge
    model    = "virtio"
    firewall = true
    mtu      = 9000
  }

  initialization {
    datastore_id = each.value.storage
    ip_config {
      ipv4 {
        address = each.value.ip
        gateway = each.value.gateway
      }
    }

    dns {
      servers = var.dns_servers
    }

    user_account {
      username = var.vm_user
      keys     = var.ssh_public_keys
      password = var.vm_password
    }
  }
}

# =========================================================
# K3s Worker VMs — workload nodes (SVC VLAN40 or LAN VLAN1)
# =========================================================
resource "proxmox_virtual_environment_vm" "k3s_worker" {
  for_each = var.workers

  node_name = each.value.proxmox_node
  vm_id     = each.value.vm_id
  name      = each.key

  description         = "K3s Worker Node - Terraform managed"
  tags                = concat(["terraform", "k3s", "worker"], each.value.extra_tags)
  machine             = each.value.gpu_mapping != null ? "q35" : null
  bios                = each.value.gpu_mapping != null ? "ovmf" : "seabios"
  started             = true
  on_boot             = true
  stop_on_destroy     = true
  reboot_after_update = false

  # 디스크 I/O 성능·안정성 튜닝 (server와 동일)
  scsi_hardware = "virtio-scsi-single"

  # GPU 워커는 vga: std (iGPU 패스스루 호환), 일반 워커는 기본값
  dynamic "vga" {
    for_each = each.value.gpu_mapping != null ? [1] : []
    content {
      type = "std"
    }
  }

  dynamic "efi_disk" {
    for_each = each.value.gpu_mapping != null ? [1] : []
    content {
      datastore_id      = each.value.storage
      file_format       = "raw"
      type              = "4m"
      pre_enrolled_keys = false
    }
  }

  clone {
    vm_id = each.value.template_vm_id
  }

  agent {
    enabled = true
    timeout = "30s"
  }

  cpu {
    cores = each.value.cpu_cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
    # floating = dedicated → ballooning(동적 메모리 재분배) 비활성화 (server와 동일).
    floating = each.value.memory
  }

  disk {
    datastore_id = each.value.storage
    interface    = "scsi0"
    size         = each.value.disk_size
    discard      = "on"
    ssd          = true
    aio          = "threads"
    cache        = "none"
    iothread     = true
  }

  # 추가 데이터 디스크 (Longhorn 등) — extra_disks list 로 지정.
  # scsi1 부터 순서대로 attach.
  dynamic "disk" {
    for_each = each.value.extra_disks
    iterator = d
    content {
      datastore_id = d.value.storage
      interface    = "scsi${d.key + 1}"
      size         = d.value.size
      discard      = "on"
      ssd          = true
      aio          = "threads"
      cache        = "none"
      iothread     = true
    }
  }

  network_device {
    bridge   = each.value.bridge
    model    = "virtio"
    firewall = true
    mtu      = 9000
  }

  initialization {
    datastore_id = each.value.storage
    ip_config {
      ipv4 {
        address = each.value.ip
        gateway = each.value.gateway
      }
    }

    dns {
      servers = var.dns_servers
    }

    user_account {
      username = var.vm_user
      keys     = var.ssh_public_keys
      password = var.vm_password
    }
  }

  # GPU 패스스루 설정은 수동 관리 — Terraform이 건드리지 않도록 ignore
  lifecycle {
    ignore_changes = [
      bios,
      machine,
      efi_disk,
      hostpci,
      cpu,
      vga,
    ]
  }

  # AMD GPU passthrough — Terraform은 VM만 생성, hostpci는 수동 관리
  # lifecycle.ignore_changes로 수동 설정 보호
  # worker-1 (UM880): Phoenix3 1002:1900 — vbios_8845hs.bin
  # worker-5 (WTR-Pro): Barcelo 1002:15e7 — vbios_5825U.bin + AMDGopDriver-5825U.rom
  # 호스트 필수: kvm.conf(ignore_msrs=1), vfio.conf(disable_idle_d3=1), blacklist amdgpu
  dynamic "hostpci" {
    for_each = each.value.gpu_mapping != null ? [each.value.gpu_mapping] : []
    content {
      device   = "hostpci0"
      mapping  = hostpci.value
      pcie     = true
      rombar   = true
      xvga     = true
      rom_file = "vbios_8845hs.bin"
    }
  }
}

# =========================================================
# Outputs
# =========================================================
output "server_ips" {
  description = "K3s server node IPs"
  value = {
    for name, vm in proxmox_virtual_environment_vm.k3s_server :
    name => split("/", vm.initialization[0].ip_config[0].ipv4[0].address)[0]
  }
}

output "worker_ips" {
  description = "K3s worker node IPs"
  value = {
    for name, vm in proxmox_virtual_environment_vm.k3s_worker :
    name => split("/", vm.initialization[0].ip_config[0].ipv4[0].address)[0]
  }
}

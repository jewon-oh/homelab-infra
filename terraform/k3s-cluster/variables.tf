# ─── Proxmox 연결 ───
variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API 토큰"
  type        = string
  sensitive   = true
}

# ─── SSH 인증 ───
variable "ssh_public_keys" {
  description = "SSH 공개키 목록 (Cloud-Init에 주입)"
  type        = list(string)
  default     = []
}

# ─── VM 사용자 계정 ───
variable "vm_user" {
  description = "VM 사용자명"
  type        = string
  default     = "jw"
}

variable "vm_password" {
  description = "VM 사용자 비밀번호"
  type        = string
  sensitive   = true
}

# ─── DNS ───
variable "dns_servers" {
  description = "DNS 서버 목록"
  type        = list(string)
  default     = ["192.168.1.1"]
}

# ─── Server 노드 정의 (HA: 3대) ───
variable "servers" {
  description = "K3s server nodes (control plane + etcd)"
  type = map(object({
    vm_id          = number
    proxmox_node   = string
    template_vm_id = number
    bridge         = string
    storage        = string
    ip             = string
    gateway        = string
    cpu_cores      = number
    memory         = number
    disk_size      = number
    # 추가 데이터 디스크 (Longhorn 등). 미명시 시 빈 list.
    # scsi1 부터 순서대로 attach. 각 entry: { storage = "<pool>", size = <GB> }
    extra_disks = optional(list(object({
      storage = string
      size    = number
    })), [])
  }))
}

# ─── Worker 노드 정의 (SVC + LAN) ───
variable "workers" {
  description = "K3s worker nodes (multi-VLAN)"
  type = map(object({
    vm_id          = number
    proxmox_node   = string
    template_vm_id = number
    bridge         = string
    storage        = string
    ip             = string
    gateway        = string
    cpu_cores      = number
    memory         = number
    disk_size      = number
    extra_tags     = list(string)
    # GPU passthrough mapping name (null = no GPU)
    gpu_mapping    = optional(string, null)
    # 추가 데이터 디스크 (Longhorn 등). 미명시 시 빈 list.
    extra_disks = optional(list(object({
      storage = string
      size    = number
    })), [])
  }))
}

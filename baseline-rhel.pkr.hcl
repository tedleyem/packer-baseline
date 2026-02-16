packer {
  required_version = ">= 1.7.0"
  required_plugins {
    qemu = {
      version = ">= 1.1.4"
      source  = "github.com/hashicorp/qemu"
    }
    ansible = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

variable "ssh_username" {
  type    = string
  default = "admin"
}

variable "ssh_password" {
  type    = string
  default = "wohbae6euchahj4eiL9aghi6"
}

variable "destination_path" {
  type    = string
  default = "./output-iso/rhel/nine"
}

variable "rhsm_org" {
  type    = string
  default = "ORGID123"
}

variable "rhsm_key" {
  type    = string
  default = "SuperLongKey"
}

/*
variable "iso_url" {
  type    = string
  default = "https://gitlab.com/tedleyem/repo.meralus.dev/-/package_files/258387539/download"
}

variable "iso_checksum" {
  type    = string
  default = "file:https://gitlab.com/tedleyem/repo.meralus.dev/-/raw/master/checksums/rhel/SHA256SUMS?ref_type=heads&inline=false"
}
*/
variable "iso_url" {
  type    = string
  default = "build-isos/rhel-9.5-x86_64-dvd.iso"
}

variable "iso_checksum" {
  type    = string
  default = "0bb7600c3187e89cebecfcfc73947eb48b539252ece8aab3fe04d010e8644ea9"
}

source "qemu" "rhel" {
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum
  communicator = "ssh"
  ssh_username     = "root"
  ssh_password     = var.ssh_password
  ssh_timeout      = "30m"
  net_device       = "virtio-net"
  boot_wait      = "15s"
  disk_size      = 50000    # 50GB disk size
  memory         = 4096     # 4GB Memory
  cpus           = 2        # 2 CPUs
  cpu_model      = "host"
  accelerator    = "kvm" #switch to hvf on mac
  output_directory = "/tmp/rhel-build-output"
  #headless         = true
  http_content = {
    "/ks.cfg" = templatefile("${path.root}/scripts/rhel/ks.packer.hcl", {
      ssh_password = var.ssh_password
      rhsm_org     = var.rhsm_org
      rhsm_key     = var.rhsm_key
      })
      }
  boot_command = [
    "<tab><wait>",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg ip=dhcp nameserver=8.8.8.8 console=ttyS0 console=tty0",
    "<enter>"
  ]
}

build {
  sources = ["source.qemu.rhel"]

  // Provision: No additional OS setup since we're generating ISO
  provisioner "shell" {
    inline = ["echo 'Preparing ISO Creation Based on QEMU Artifacts'"]
  }
  
  // Apply CIS Benchmarks
  provisioner "ansible" {
    playbook_file   = "./ansible/setup-rhel.yml"
    extra_arguments = ["--extra-vars", "ansible_sudo_pass=${var.ssh_password}"]
  }
  // Apply CIS Hardening
  provisioner "ansible" {
    playbook_file   = "./ansible/cis-hardening.yml"
    extra_arguments = ["--extra-vars", "ansible_sudo_pass=${var.ssh_password}"]
  }

}
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

variable "ssh_password" {
  type    = string
  default = "ubuntu"
}

variable "destination_path" {
  type    = string
  default = "./output-iso/ubuntu/2404"
}

variable "iso_url" {
  type    = string
  default = "https://releases.ubuntu.com/24.04/ubuntu-24.04.3-live-server-amd64.iso"
}

variable "iso_checksum" {
  type    = string
  default = "file:https://releases.ubuntu.com/24.04/SHA256SUMS"
}

source "qemu" "ubuntu-24-04" {
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum
  output_directory = "output-ubuntu-2404"
  shutdown_command = "echo '${var.ssh_password}' | sudo -S shutdown -P now"
  ssh_username     = "ubuntu"
  ssh_password     = var.ssh_password
  ssh_timeout      = "30m"
  cpus             = 2
  memory           = 2048
  disk_size        = "20000"
  accelerator      = "kvm"
  format           = "qcow2"
  net_device       = "virtio-net"
  disk_interface   = "virtio"
  http_directory = "scripts/ubuntu"
  #headless         = true
  boot_wait = "10s"
  boot_command = [
    "c<wait>",
    "set gfxpayload=keep<enter>",
    "linux /casper/vmlinuz autoinstall \"ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/\"<enter>",
    "initrd /casper/initrd<enter>",
    "boot<enter>"
  ]

  # Ensures QEMU handles the keyboard input correctly
  qemuargs = [
    ["-display", "gtk,zoom-to-fit=on"],
    ["-device", "virtio-gpu-pci"]
  ]
}

build {
  sources = ["source.qemu.ubuntu-24-04"]

  provisioner "ansible" {
    playbook_file   = "./ansible/setup-ubuntu.yml"
    extra_arguments = ["--extra-vars", "ansible_sudo_pass=${var.ssh_password}"]
  }

  provisioner "ansible" {
    playbook_file   = "./ansible/cisa-ubuntu-benchmark.yml"
    extra_arguments = ["--extra-vars", "ansible_sudo_pass=${var.ssh_password}"]
  }

  post-processor "shell-local" {
    inline = [
      "export ISO_NAME=ubuntu-24-04-custom.iso",
      "export ROOT_OUT='./output-iso'",
      "export STAGING_DIR='./output-iso/staging'",
      "mkdir -p \"$ROOT_OUT\"",
      "rm -rf \"$STAGING_DIR\"",
      "mkdir -p \"$STAGING_DIR\"",
      "ISO_PATH=$(find packer_cache -name '*.iso' | head -n 1)",
      "if [ -z \"$ISO_PATH\" ]; then echo 'Base ISO not found in packer_cache'; exit 1; fi",
      "xorriso -osirrox on -indev \"$ISO_PATH\" -extract / \"$STAGING_DIR\"",
      "cp -r scripts/ubuntu/* \"$STAGING_DIR/\"",
      "chmod -R +w \"$STAGING_DIR\"",
      "xorriso -as mkisofs -r -V 'UBUNTU_CUSTOM' -o \"$ROOT_OUT/$ISO_NAME\" -J -joliet-long -l -b boot/grub/i386-pc/eltorito_alt1.boot -c boot.catalog -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot -isohybrid-gpt-basdat \"$STAGING_DIR\"",
      "rm -rf \"$STAGING_DIR\""
    ]
  }
}
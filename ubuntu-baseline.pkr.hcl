packer {
  required_version = ">= 1.7.0"
  required_plugins {
    virtualbox = {
      version = ">= 0.0.1"
      source  = "github.com/hashicorp/virtualbox"
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
  default = "/mnt/iso/ubuntu2404"
}

variable "iso_url" {
  type    = string
  default = "https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso"
}

variable "iso_checksum" {
  type    = string
  default = "file:https://releases.ubuntu.com/24.04/SHA256SUMS"
}

source "virtualbox-iso" "ubuntu-24-04" {
  boot_command = [
    "c<wait>",
    "set gfxpayload=keep",
    "linux /casper/vmlinuz --- autoinstall ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/",
    "<enter><wait>",
    "initrd /casper/initrd",
    "<enter><wait>",
    "boot<enter>"
  ]
  boot_wait      = "5s"
  cpus           = 2
  memory         = 2048
  disk_size      = 20000
  guest_os_type  = "Ubuntu_64"
  http_directory = "scripts/ubuntu" # Ensure your user-data and meta-data files are here

  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  output_directory = "output-build"

  shutdown_command = "echo '${var.ssh_password}' | sudo -S shutdown -P now"
  ssh_username     = "ubuntu"
  ssh_password     = var.ssh_password
  ssh_timeout      = "20m"
}

build {
  sources = ["source.virtualbox-iso.ubuntu-24-04"]

  // Apply CIS Benchmarks
  provisioner "ansible" {
    playbook_file   = "./ansible/setup-ubuntu.yml"
    extra_arguments = ["--extra-vars", "ansible_sudo_pass=${var.ssh_password}"]
  }

  provisioner "ansible" {
    playbook_file   = "./ansible/network-setup.yml"
    extra_arguments = ["--extra-vars", "ansible_sudo_pass=${var.ssh_password}"]
  }

  provisioner "ansible" {
    playbook_file   = "./ansible/cis-hardening.yml"
    extra_arguments = ["--extra-vars", "ansible_sudo_pass=${var.ssh_password}"]
  }

  // Standardize and Cleanup
  provisioner "shell" {
    inline = [
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo truncate -s 0 /etc/machine-id"
    ]
  }

  // Move the final artifact to the destination directory
  post-processor "shell-local" {
    inline = [
      "echo 'Moving image to ${var.destination_path}'",
      "sudo mkdir -p ${var.destination_path}",
      "sudo mv output-build/*.ova ${var.destination_path}/ubuntu-2404-baseline-{{timestamp}}.ova",
      "sudo chown -R $USER:$USER ${var.destination_path}",
      "echo 'Build complete. File is located at ${var.destination_path}'"
    ]
  }
}
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
  default = "your_iscrypted_password_here"
}

variable "destination_path" {
  type    = string
  default = "/Users/meralust/projects/hs-linux/configuration/mnt/iso/rhel9"
}

variable "iso_url" {
  type    = string
  default = "https://repo.meralus.dev/iso/rhel-baseos-9.0-x86_64-dvd-ks.iso"
}

variable "iso_checksum" {
  type    = string
  default = "none"
}

source "virtualbox-iso" "rhel9" {
  boot_command = [
    "<tab><wait>",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg",
    "<enter>"
  ]
  boot_wait      = "10s"
  cpus           = 2
  memory         = 4096
  disk_size      = 50000
  guest_os_type  = "RedHat_64"
  http_directory = "scripts/rhel"

  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  output_directory = "output-rhel-build"
  shutdown_command = "echo '${var.ssh_password}' | sudo -S shutdown -P now"
  ssh_username     = "root"
  ssh_password     = var.ssh_password
  ssh_timeout      = "30m"
}

build {
  sources = ["source.virtualbox-iso.rhel9"]

  // Apply CIS Benchmarks
  provisioner "ansible" {
    playbook_file   = "./ansible/setup-rhel.yml"
    extra_arguments = ["--extra-vars", "ansible_sudo_pass=${var.ssh_password}"]
  }
  // setup networking
  provisioner "ansible" {
    playbook_file   = "./ansible/network-setup.yml"
    extra_arguments = ["--extra-vars", "ansible_sudo_pass=${var.ssh_password}"]
  }
  // Apply CIS Hardening
  provisioner "ansible" {
    playbook_file   = "./ansible/cis-hardening.yml"
    extra_arguments = ["--extra-vars", "ansible_sudo_pass=${var.ssh_password}"]
  }

  // System Prep
  provisioner "shell" {
    inline = [
      "mkdir -p /splunkdata/{hot_data,cold_data,datamodel_data}",
      "dnf clean all",
      "rm -rf /etc/udev/rules.d/70-persistent-net.rules",
      "truncate -s 0 /etc/machine-id"
    ]
  }

  // Final Artifact Handling
  post-processor "shell-local" {
    inline = [
      "sudo mkdir -p ${var.destination_path}",
      "sudo mv output-rhel-build/*.ova ${var.destination_path}/rhel9-baseline-{{timestamp}}.ova",
      "sudo chown -R $USER:$USER ${var.destination_path}"
    ]
  }
}
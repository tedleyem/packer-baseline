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

# SSH credentials for the system
variable "ssh_password" {
  type    = string
  default = "ubuntu"
}

# Path to store the final .ova artifact
variable "destination_path" {
  type    = string
  default = "./output-iso/ubuntu/2404"
}

# URL and checksum of the Ubuntu 24.04 ISO
variable "iso_url" {
  type    = string
  default = "https://releases.ubuntu.com/24.04/ubuntu-24.04.3-live-server-amd64.iso"
}

variable "iso_checksum" {
  type    = string
  default = "file:https://releases.ubuntu.com/24.04/SHA256SUMS"
}

# QEMU Builder
source "qemu" "ubuntu-24-04" {
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum
  communicator = "ssh"
  boot_command = [
    "c<wait>",
    "set gfxpayload=keep<enter>",
    "linux /casper/vmlinuz autoinstall ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/<enter>",
    "initrd /casper/initrd<enter>",
    "boot<enter>"
  ]

  http_directory = "scripts/ubuntu"
  boot_wait      = "5s"              
  disk_size      = 20000            # 20GB disk size
  memory         = 2048             # 2GB Memory
  cpus           = 2                # 2 CPUs
  output_directory = "/tmp/ubuntu-build-output" # Temporary output folder
  shutdown_command = "echo '${var.ssh_password}' | sudo -S shutdown -P now"
  ssh_username     = "ubuntu"
  ssh_password     = var.ssh_password
  ssh_timeout      = "20m"
  format           = "qcow2"       # Use QCOW2 format for QEMU
  accelerator      = "kvm"
  headless         = "true"
#  accelerator      = "hvf" # Use Hypervisor.framework since this is macOS
}

# Build steps
build {
  sources = ["source.qemu.ubuntu-24-04"]

  # Provisioning with Ansible
  provisioner "ansible" {
    playbook_file   = "./ansible/setup-ubuntu.yml"
    extra_arguments = ["--extra-vars", "ansible_sudo_pass=${var.ssh_password}"]
  }

  provisioner "ansible" {
    playbook_file   = "./ansible/cis-hardening.yml"
    extra_arguments = ["--extra-vars", "ansible_sudo_pass=${var.ssh_password}"]
  }

  # Cleanup and standardization
  provisioner "shell" {
    inline = [
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo truncate -s 0 /etc/machine-id"
    ]
  }

  # Post-Processing to create .ova and move artifact
  post-processor "shell-local" {
    inline = [
      # Create staging area for the new ISO
      "mkdir -p /tmp/ubuntu-iso-staging && cd /tmp/ubuntu-iso-staging",

      # Mount base Ubuntu ISO to extract the contents
      "mkdir -p /mnt/ubuntu-iso",
      "sudo mount -o loop ${var.iso_url} /mnt/ubuntu-iso",
      "cp -r /mnt/ubuntu-iso/* .",
      "sudo umount /mnt/ubuntu-iso",

      # Inject autoinstall (cloud-init) Copies user-data/meta-data to the staging area
      "cp -r scripts/ubuntu/* .", 

      # Inject any additional files/configurations here, if necessary
      "echo 'Customizing ISO build...'",

      # Rebuild the ISO with mkisofs/xorriso
      "mkisofs -U -A Ubuntu_Custom -V 'UBUNTU_CUSTOM' -volset 'UBUNTU_CUSTOM' -R -J + -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 + -boot-info-table -o ${var.destination_path}/ubuntu-24-04-custom.iso .",

      # Clean up temporary files
      "rm -rf /tmp/ubuntu-build-output /tmp/ubuntu-iso-staging"
    ]
  }
}
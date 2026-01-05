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
  default = "wohbae6euchahj4eiL9aghi6"
}

variable "destination_path" {
  type    = string
  default = "./output-iso/rhel9"
}

variable "iso_url" {
  type    = string
  default = "https://repo.meralus.dev/iso/rhel-9.4-x86_64-boot.iso"
}

variable "iso_checksum" {
  type    = string
  default = "sha256:17b013f605e6b85affd37431b533b6904541f8b889179ae3f99e1e480dd4ae38"
}

source "qemu" "rhel9" {
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum
  communicator = "none" # No clean OS with SSH ensures we only stage the ISO
  boot_command = [
    "<tab><wait>",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg",
    "<enter>"
  ]
  boot_wait      = "5s"
  disk_size      = 50000    # 20GB disk size
  memory         = 2048     # 2GB Memory
  cpus           = 2        # 2 CPUs
  output_directory = "/tmp/rhel9-build-output" # Temporary build artifacts
}

build {
  sources = ["source.qemu.rhel9"]

  // Provision: No additional OS setup since we're generating ISO
  provisioner "shell" {
    inline = ["echo 'Preparing ISO Creation Based on QEMU Artifacts'"]
  }
  
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


  // Final Custom Bootable ISO - Post-Processing
  post-processor "shell-local" {
    inline = [
      # Create stage directory to extract base ISO and inject custom files
      "mkdir -p /tmp/rhel9-iso-stage && cd /tmp/rhel9-iso-stage",
      "cp -r $(mktemp -d)/* /tmp/rhel9-iso-stage",

      # Mount base ISO and copy contents into stage directory
      "mkdir -p /mnt/rhel9-iso",
      "sudo mount -o loop ${var.iso_url} /mnt/rhel9-iso",
      "cp -r /mnt/rhel9-iso/* .",
      "sudo umount /mnt/rhel9-iso",

      # Inject Kickstart configuration
      "cp ${var.destination_path}/scripts/rhel/ks.cfg isolinux/ks.cfg",

      # Rebuild custom ISO
      "mkisofs -U -A rhel9-custom-iso -V 'RHEL9_CUSTOM' -volset 'RHEL9_CUSTOM' -J -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ${var.destination_path}/rhel9-custom.iso .",

      # Clean up temporary directories
      "rm -rf /tmp/rhel9-build-output",
      "rm -rf /tmp/rhel9-iso-stage"
    ]
  }
}
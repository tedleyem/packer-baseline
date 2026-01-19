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
  default = "./output-iso/rhel"
}

variable "iso_url" {
  type    = string
  default = "https://gitlab.com/tedleyem/repo.meralus.dev/-/package_files/258387539/download"
}

variable "iso_checksum" {
  type    = string
  default = "file:https://gitlab.com/tedleyem/repo.meralus.dev/-/raw/master/checksums/rhel/SHA256SUMS?ref_type=heads&inline=false"
}

source "qemu" "rhel" {
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
  output_directory = "/tmp/rhel-build-output" # Temporary build artifacts
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


  // Final Custom Bootable ISO - Post-Processing
  post-processor "shell-local" {
    inline = [
      "mkdir -p /tmp/rhel-iso-stage",
      "mkdir -p /mnt/rhel-iso",
      "sudo mount -o loop ${var.iso_url} /mnt/rhel-iso",
      "cp -r /mnt/rhel-iso/* /tmp/rhel-iso-stage",
      "sudo umount /mnt/rhel-iso",
      "cp ${var.destination_path}/scripts/rhel/ks.cfg /tmp/rhel-iso-stage/isolinux/ks.cfg",
      "xorriso -as mkisofs -o ${var.destination_path}/rhel-custom.iso -J -R -V 'rhel_CUSTOM' -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table /tmp/rhel-iso-stage",
      "rm -rf /tmp/rhel-build-output /tmp/rhel-iso-stage"
    ]
  }
}
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
  default = "dsl" #default username for dsl linux
}

variable "ssh_password" {
  type    = string
  default = "wowitworks"
}

variable "destination_path" {
  type    = string
  default = "./output-iso/dsl-test"
}

variable "iso_url" {
  type    = string
  default = "https://repo.meralus.dev/isos/dsl-2024.rc7.iso"
}

variable "iso_checksum" {
  type    = string
  default = "cd8afa1de6e60af50605a1a4af21da64"
}

source "qemu" "dsl-test" {
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum
  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_wait_timeout = "3m"
  communicator = "ssh" # needed for shell/ansible provisioning
  host_port_min = 2222 # QEMU needs to forward the port for SSH
  host_port_max = 2222 # QEMU needs to forward the port for SSH
  disk_size      = 50000 # 50GB disk size
  memory         = 2048  # 2GB Memory
  cpus           = 2     # 2 CPUs
  output_directory = "/tmp/dsl-test-build-output" # Temporary build artifacts
  headless         = false # set to true to disable GUI
  boot_wait      = "5s"
  boot_command = [
    # 1. Wait for the boot menu to appear, then hit Tab to edit
    "<wait10><tab>",
    
    # 2. Clear any default 'desktop' boot arguments (safety measure)
    "<control>a<backspace>", 
    
    # 3. Type the explicit boot command
    # '2' forces runlevel 2 (Console), 'nosplash' hides the logo
    "vmlinuz initrd=initrd.gz 2 nosplash vga=normal<enter>",
    
    # 4. Long wait for the console prompt to appear
    "<wait40>", 
    
    # 5. Set the password
    "sudo passwd ${var.ssh_username}<enter>",
    "<wait2>",
    "${var.ssh_password}<enter>",
    "<wait2>",
    "${var.ssh_password}<enter>",
    "<wait2>",
    
    # 6. Install and start SSH
    "sudo apt-get update && sudo apt-get install -y openssh-server<enter>",
    "<wait60>", # Heavy wait for installation
    "sudo service ssh start<enter>"
  ]
}

build {
  sources = ["source.qemu.dsl-test"]

  // Provision
  provisioner "shell" {
    inline = ["echo 'Preparing ISO Creation Based on QEMU Artifacts'"]
  }
  
  // Apply CIS Hardening
  provisioner "ansible" {
    playbook_file   = "./ansible/cis-hardening.yml"
    extra_arguments = ["--extra-vars", "ansible_sudo_pass=${var.ssh_password}"]
  }

  // Final Custom Bootable ISO - Post-Processing
  post-processor "shell-local" {
    inline = [
      "mkdir -p ${var.destination_path}",
      "mkdir -p /tmp/dsl-iso-stage",
      "xorriso -osirrox on -indev ${var.iso_url} -extract / /tmp/dsl-iso-stage",
      "echo 'Hardened by Packer' > /tmp/dsl-iso-stage/version.txt",
      
      # Using a single string with no '+' operators to avoid the math error
      "xorriso -as mkisofs -R -J -V 'DSL_HARDENED' -b boot/isolinux/isolinux.bin -c boot/isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ${var.destination_path}/dsl-custom.iso /tmp/dsl-iso-stage",
      "rm -rf /tmp/dsl-iso-stage"
    ]
  }
}
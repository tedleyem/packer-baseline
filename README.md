# Creating Ubuntu 24.04 baseline and image 

### Ubuntu and RedHat Image Builder
Instead of manually clicking through an installer, we use Hashicorps Packer method to utilize to ensure every image we build are identical and meets our repeatable.

**Note:** This currently uses virtualbox as the source to build the images and can be done locally. Future changes will use a different provider so that this can be used within an AAP workflow

###  Project Goals (Key Results)
* Security (KR 1.1 & 1.2): Automated CIS hardening via Ansible to ensure zero critical audit findings.
* Efficiency (KR 2.1): 30% faster deployments by "pre-baking" the OS instead of configuring it after boot.
* Consistency (KR 2.2): 95% config consistency—every server starts from the exact same bit-level foundation.

### How It’s Built
The build process follows a four-step "Assembly Line" process:
* The Source: Packer downloads the official Ubuntu 24.04 Live Server ISO.
* The Install (Autoinstall): Packer boots the ISO and "types" instructions into the bootloader. The installer reads the user-data file to handle disk partitioning (LVM), user creation, and network setup automatically.
* The Hardening (Ansible): Once the OS is installed, Packer logs in via SSH and runs the Ansible playbook. This applies any security controls, installs Splunk directories as needed, and sets up local repositories.
* The Export: Packer shuts down the VM a moves the final image to a specified location like /mnt/iso/ubuntu2404/.

### File Structure
```
'.
├── README.md
├── ansible             
│   ├── cis-hardening.yml   #  Security enhancements
│   ├── network-setup.yml   #  Setup network mounts
│   ├── setup-rhel.yml      #  setup rhel specific package mirrors 
│   └── setup-ubuntu.yml    #  setup ubuntu specific package mirrors
├── build-images.yml        #  playbook to build both images
├── build-redhat.yml        #  playbook to build rhel image
├── build-ubuntu.yml        #  playbook to build ubuntu image
├── iso                     #  local iso images  
├── redhat                  #  redhat configuration files 
│   └── ks.cfg              #  redhat kickstart configs
├── rhel-baseline.pkr.hcl   #  PACKER build steps for redhat 
├── scripts                 #  scripts for packer builds  
    └── ubuntu/             #  ubuntu specific user-data scripts
        ├── userdata.yml    # Ubuntu Autoinstall
        └── meta-data       #  Keep this empty file here
└── ubuntu-baseline.pkr.hcl #  PACKER build steps for ubuntu 
 ```

###  Running the Build
Prerequisites
Ensure you have the following installed on your build machine:
* Packer (v1.10+)
* VirtualBox 

Prepare the Packer environment and download necessary plugins:
```
packer init .
```
 
 
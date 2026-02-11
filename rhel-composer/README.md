# RHEL Image Builder on Debian (Containerized)

This setup allows you to run Red Hat’s `composer-cli` and `osbuild-composer` on Debian 13 using Docker. Because Im using Debian 13 on my compute rand didnt want to install Fedora or Redhat. These steps can be followed on a rhel system if needed as well. 

---

## 1. Prerequisites

* **Docker & Docker Compose** installed.
* **Privileged Mode:** Required for the backend to mount filesystems.
* **RHEL Subscription:** If using official Red Hat repositories, your host must be registered via `subscription-manager`, or you must provide valid `baseurl` paths in the repository config.

---

## 2. File Structure

Ensure your directory looks like this:

```text
.
├── Dockerfile.composer    # Fedora-based image with composer tools
├── docker-compose.yml     # Orchestrates server and client
├── rhel-9.json           # RHEL repository definitions
├── rhel-baseline.toml     # Your image blueprint
└── build-image.sh         # Automation script

```

---

## 3. Core Components

### Repository Configuration (`rhel-9.json`)

Defines where the builder fetches RHEL packages. Use `"rhsm": true` if your host has an active Red Hat subscription mounted into the container.

### The Blueprint (`rhel-baseline.toml`)

A simple TOML file naming the image and listing packages (e.g., `rsync`, `openssh-server`).

### The Docker Environment

* **Server:** Runs `osbuild-composer` in `--privileged` mode.
* **Client:** Runs `composer-cli` commands against the server's socket.
* **Output:** Images are exported to the `./output` directory on your host.

---

## 4. Usage

1. **Prepare Directories:**
```bash
mkdir output
chmod 777 output

```


2. **Build and Start:**
Run the provided bash script to automate the process:
```bash
chmod +x build-image.sh
./build-image.sh

```


3. **Monitor:**
The script will poll the status. Once it reaches `FINISHED`, your `.qcow2` file will be in `./output`.

---

## 5. Troubleshooting

* **Build Fails:** Run `docker-compose logs composer-server` to see low-level errors.
* **Missing Packages:** Verify that your `rhel-9.json` URLs are accessible from within the container.
* **Permission Denied:** Ensure the container is running with `privileged: true` in your `docker-compose.yml`.

[How to use RHEL Image Builder](https://www.youtube.com/watch?v=MjF_5kFN3KE)

This tutorial provides a visual walkthrough of using the Image Builder (Composer) interface and CLI to generate RHEL images, which helps clarify the workflow described in this README.
FROM fedora:latest

RUN dnf install -y osbuild-composer weldr-client composer-cli && dnf clean all

# Create the override directory
RUN mkdir -p /etc/osbuild-composer/repositories

# Copy the RHEL 9 repository definition
COPY rhel-9.json /etc/osbuild-composer/repositories/rhel-9.json

# Ensure the socket directory exists for the service
RUN mkdir -p /run/osbuild-composer

# Set the working directory for blueprint operations
WORKDIR /blueprints

CMD ["/usr/libexec/osbuild-composer/osbuild-composer"]
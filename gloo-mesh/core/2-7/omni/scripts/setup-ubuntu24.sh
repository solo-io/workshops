#!/bin/bash


# Terminal color codes.
REDB="\033[1;31m"
WHITEB="\033[1;37m"
GREENB="\033[1;32m"
CLR="\033[0m"


# Downloads an archive, checks its SHA256 hash, and installs it in /usr/local/bin/.
download_and_install() {
    url=$1
    expected_sha256_hash=$2
    uncompressed_executable_relative_path=$3

    # Create a safe working directory and make it our current directory.
    temp_dir=$(mktemp -d)
    pushd ${temp_dir} > /dev/null

    # Get the latest working version of Helm for this application.
    wget -O tool.tar.gz ${url}

    # Check its sha256 hash.
    actual_sha256_hash=$(sha256sum tool.tar.gz | cut -f1 -d" ")
    if [[ $actual_sha256_hash != $expected_sha256_hash ]]; then
        echo -e "${REDB}Error: sha256sum is ${actual_sha256_hash} instead of ${expected_sha256_hash}!${CLR}"
        exit -1
    fi

    # Uncompress the archive and install it into /usr/local/bin.
    tar xvzf tool.tar.gz
    install -m 0755 -o root -g root ${uncompressed_executable_relative_path} /usr/local/bin

    # Restore our original working directory.
    popd > /dev/null

    # Remove the working directory.
    rm -rf ${temp_dir}
}


# If the NO_COLOR environment variable exists, disable console colors.
if [[ ! -z "${NO_COLOR}" ]]; then
    echo "Disabling console colors because the NO_COLOR environment variable is set."
    REDB=""
    WHITEB=""
    GREENB=""
    CLR=""
fi

# Ensure that the host platform is Ubuntu 24.04.
if ! grep "PRETTY_NAME=\"Ubuntu 24\." /etc/os-release > /dev/null; then
    echo -e "${REDB}ERROR: this script is designed to work on Ubuntu 24.04 only.${CLR}"
    exit -1
fi

# Ensure that we are running as root.
if [[ $(whoami) != "root" ]]; then
    echo -e "${REDB}ERROR: this script must be run as root.${CLR}"
    exit -1
fi

# Fully update the host system.
echo -e "${WHITEB}Updating system...${CLR}\n"
apt update
apt dist-upgrade -y

# Install Docker and the go command.
echo -e "\n\n${WHITEB}Installing Docker and the go command...${CLR}\n"
apt install docker.io golang-go -y

# Remove setup packages.
apt clean

# Install kind.
echo -e "\n\n${WHITEB}Installing latest version of kind...${CLR}\n"
go install sigs.k8s.io/kind@latest

# Copy the kind command to /usr/local/bin.
cp /root/go/bin/kind /usr/local/bin/kind

# Install kubectl.
echo -e "\n\n${WHITEB}Installing kubectl and gcloud...${CLR}\n"
snap install kubectl google-cloud-cli --classic

# Install helm.  We can't install the latest version, because of this issue: https://github.com/solo-io/workshops/issues/283
echo -e "\n\n${WHITEB}Installing helm...${CLR}\n"

download_and_install "https://get.helm.sh/helm-v3.17.2-linux-amd64.tar.gz" "90c28792a1eb5fb0b50028e39ebf826531ebfcf73f599050dbd79bab2f277241" "linux-amd64/helm"

# Install the smallstep cli tool.
echo -e "\n\n${WHITEB}Installing the smallstep cli tool...${CLR}\n"

download_and_install "https://dl.smallstep.com/gh-release/cli/gh-release-header/v0.27.2/step_linux_0.27.2_amd64.tar.gz" "10648c4222b111a429adfc5a1d00b857b8e506e641facd83b246d6dd4ee4577a" "step_0.27.2/bin/step"

echo -e "\n\n${GREENB}Done!${CLR}\n"
exit 0

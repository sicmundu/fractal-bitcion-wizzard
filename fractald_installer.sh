#!/bin/bash

# Colors for styling
COLOR_RED="\e[31m"
COLOR_GREEN="\e[32m"
COLOR_YELLOW="\e[33m"
COLOR_BLUE="\e[34m"
COLOR_CYAN="\e[36m"
COLOR_RESET="\e[0m"

# Logging function with emoji support
log() {
    echo -e "${COLOR_CYAN}$1${COLOR_RESET}"
}

# Error handling with emoji support
handle_error() {
    echo -e "${COLOR_RED}❌ Error: $1${COLOR_RESET}"
    exit 1
}

# Function to check if a file exists
check_file_exists() {
    if [ -f "$1" ]; then
        log "${COLOR_YELLOW}⚠️  File $1 already exists. Skipping download.${COLOR_RESET}"
        return 1
    fi
    return 0
}

# Function to check if a directory exists
check_directory_exists() {
    if [ -d "$1" ]; then
        log "${COLOR_GREEN}📁 Directory $1 already exists.${COLOR_RESET}"
    else
        log "${COLOR_YELLOW}📂 Creating directory $1...${COLOR_RESET}"
        mkdir -p "$1" || handle_error "Failed to create directory $1."
    fi
}

# Function to check and install a package if not already installed
check_and_install_package() {
    if ! dpkg -l | grep -qw "$1"; then
        log "${COLOR_YELLOW}📦 Installing $1...${COLOR_RESET}"
        sudo apt-get install -y "$1" || handle_error "Failed to install $1."
    else
        log "${COLOR_GREEN}✔️  $1 is already installed!${COLOR_RESET}"
    fi
}

# Prepare the server by updating and installing necessary packages
prepare_server() {
    log "${COLOR_BLUE}🔄 Updating the server and installing required packages...${COLOR_RESET}"
    sudo apt-get update -y && sudo apt-get upgrade -y || handle_error "Failed to update the server."

    local packages=("make" "build-essential" "pkg-config" "libssl-dev" "unzip" "tar" "lz4" "gcc" "git" "jq")
    for package in "${packages[@]}"; do
        check_and_install_package "$package"
    done
}

# Download and extract the Fractal Node repository
download_and_extract() {
    local url="https://github.com/fractal-bitcoin/fractald-release/releases/download/v0.1.7/fractald-0.1.7-x86_64-linux-gnu.tar.gz"
    local filename="fractald-0.1.7-x86_64-linux-gnu.tar.gz"
    local dirname="fractald-0.1.7-x86_64-linux-gnu"

    check_file_exists "$filename"
    if [ $? -eq 0 ]; then
        log "${COLOR_BLUE}⬇️  Downloading Fractal Node...${COLOR_RESET}"
        wget -q "$url" -O "$filename" || handle_error "Failed to download $filename."
    fi

    log "${COLOR_BLUE}🗜️  Extracting $filename...${COLOR_RESET}"
    tar -zxvf "$filename" || handle_error "Failed to extract $filename."

    check_directory_exists "$dirname/data"
    cp "$dirname/bitcoin.conf" "$dirname/data" || handle_error "Failed to copy bitcoin.conf to $dirname/data."
}

# Check if the wallet already exists
check_wallet_exists() {
    if [ -f "/root/.bitcoin/wallets/wallet/wallet.dat" ]; then
        log "${COLOR_GREEN}💰 Wallet already exists. Skipping wallet creation.${COLOR_RESET}"
        return 1
    fi
    return 0
}

# Create a new wallet
create_wallet() {
    log "${COLOR_BLUE}🔍 Checking if wallet exists...${COLOR_RESET}"
    check_wallet_exists
    if [ $? -eq 1 ]; then
        log "${COLOR_GREEN}✅ Wallet already exists. No need to create a new one.${COLOR_RESET}"
        return
    fi

    log "${COLOR_BLUE}💼 Creating a new wallet...${COLOR_RESET}"

    cd fractald-0.1.7-x86_64-linux-gnu/bin || handle_error "Failed to change to directory bin."
    ./bitcoin-wallet -wallet=wallet -legacy create || handle_error "Failed to create wallet."

    log "${COLOR_BLUE}🔑 Exporting the wallet private key...${COLOR_RESET}"
    ./bitcoin-wallet -wallet=/root/.bitcoin/wallets/wallet/wallet.dat -dumpfile=/root/.bitcoin/wallets/wallet/MyPK.dat dump || handle_error "Failed to export wallet private key."

    PRIVATE_KEY=$(awk -F 'checksum,' '/checksum/ {print "Wallet Private Key:" $2}' /root/.bitcoin/wallets/wallet/MyPK.dat)
    log "${COLOR_RED}$PRIVATE_KEY${COLOR_RESET}"
    log "${COLOR_YELLOW}⚠️  Don't forget to write down your private key!${COLOR_RESET}"
}

# Create a systemd service file for Fractal Node
create_service_file() {
    log "${COLOR_BLUE}🛠️  Creating system service for Fractal Node...${COLOR_RESET}"

    if [ -f "/etc/systemd/system/fractald.service" ]; then
        log "${COLOR_YELLOW}⚠️  Service file already exists. Skipping creation.${COLOR_RESET}"
    else
        sudo tee /etc/systemd/system/fractald.service > /dev/null << EOF
[Unit]
Description=Fractal Node
After=network-online.target
[Service]
User=$USER
ExecStart=/root/fractald-0.1.7-x86_64-linux-gnu/bin/bitcoind -datadir=/root/fractald-0.1.7-x86_64-linux-gnu/data/ -maxtipage=504576000
Restart=always
RestartSec=5
LimitNOFILE=infinity
[Install]
WantedBy=multi-user.target
EOF

        sudo systemctl daemon-reload || handle_error "Failed to execute daemon-reload."
        sudo systemctl enable fractald || handle_error "Failed to enable fractald service."
    fi
}

# Start the Fractal Node service
start_node() {
    log "${COLOR_BLUE}🚀 Starting the Fractal Node...${COLOR_RESET}"
    sudo systemctl start fractald || handle_error "Failed to start fractald service."
    log "${COLOR_GREEN}🎉 Fractal Node is up and running!${COLOR_RESET}"
    log "${COLOR_CYAN}📝 To check the node logs, run: ${COLOR_BLUE}sudo journalctl -u fractald -f --no-hostname -o cat${COLOR_RESET}"
}

# Main function to control the flow of the script
main() {
    prepare_server
    download_and_extract
    create_service_file
    create_wallet
    start_node
}

# Start the main process
main

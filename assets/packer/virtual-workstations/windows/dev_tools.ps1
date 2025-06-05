# # Use this file to write PowerShell that installs dev tools:
# # Once done, link this file in `userdata.ps1` so it will be used during Packer AMI creation.

# # Install Chocolatey (this is already done in base_setup_*.ps1 scripts I believe. Double check this)
# Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'))

# # Install Git
# choco install git -y

# # Install Node.js
# choco install nodejs -y

# # Install Python
# choco install python -y

# # Install VS Code
# choco install vscode -y

# # Install Docker
# choco install docker-desktop -y

# # Install Terraform
# choco install terraform -y

# # Install tfenv using choco or homebrew
# choco install tfenv -y

# # Install VS Code Extensions
# code --install-extension ms-vscode-remote.vscode-remote-extensionpack
# code --install-extension ms-vscode-remote.remote-containers
# code --install-extension ms-vscode-remote.remote-ssh
# code --install-extension ms-vscode-remote.remote-ssh-edit
# code --install-extension ms-vscode-remote.remote-wsl
# code --install-extension ms-vscode-remote.remote-wsl-edit
# code --install-extension ms-vscode-remote.remote-ssh-explorer
# code --install-extension ms-vscode-remote.remote-ssh-extension-pack
# code --install-extension ms-vscode-remote.remote-ssh-explorer
# code --install-extension ms-vscode-remote.remote-ssh-explorer

function Write($message) {
    Write-Output $message
}

try {
    # Create Jenkins user and add to administrative group
    Write "Creating Jenkins User"
    New-LocalUser -Name "jenkins" -AccountNeverExpires -Description "jenkins" -NoPassword
    Add-LocalGroupMember -Group "Administrators" -Member "jenkins"
}
catch {
    Write "Failed to create jenkins user"
}

try {
    # Java Runtime for Jenkins
    Write "Installing Java for Jenkins agents"
    choco install -y  --no-progress openjdk
}
catch {
    Write "Failed to install java sdk"
}

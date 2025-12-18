function Write($message) {
    Write-Output $message
}

try {
    # Downloads Debugging Tools for Windows
    # This is required for the PDBCOPY.exe which is not available through vs_installer
    # Ref: https://forums.unrealengine.com/t/installed-build-fails-trying-to-run-pdbcopy-exe/88759/19
    Write "Installing Debugging Tools for Windows..."

    $WDK_DOWNLOAD_LINK = "https://go.microsoft.com/fwlink/?linkid=2249371"
    $WDK_DESTINATION = "C:\\Users\\Administrator\\Downloads\\wdksetup.exe"

    Invoke-WebRequest -Uri $WDK_DOWNLOAD_LINK -OutFile $WDK_DESTINATION
    Start-Process -FilePath $WDK_DESTINATION -ArgumentList "/q" -Wait -PassThru

    Write "Windows Development Kit Installed successfully."
}
catch {
    Write "Debugging Tools for Windows installation failed."
}
finally {
    Remove-Item -Path $WDK_DESTINATION
}

try {
    Write "Installing Visual Studio 2022 Build Tools"
    choco install -y --no-progress visualstudio2022buildtools --package-parameters " --passive --locale en-US --add Microsoft.VisualStudio.Workload.VCTools;includeRecommended --add Microsoft.VisualStudio.Workload.ManagedDesktopBuildTools;includeRecommended --add Microsoft.VisualStudio.Component.VC.14.38.17.8.x86.x64 --add Microsoft.Net.Component.4.6.2.TargetingPack"

}
catch {
    Write "Failed to install Visual Studio 2022 Build Tools"
}

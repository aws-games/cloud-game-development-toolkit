function Write($message) {
    Write-Output $message
}

# Fail loud: any unhandled cmdlet error is terminating so a broken bake stops
# at THIS provisioner instead of limping onward to validate_image.
$ErrorActionPreference = 'Stop'

try {
    # Downloads Debugging Tools for Windows
    # This is required for the PDBCOPY.exe which is not available through vs_installer
    # Ref: https://forums.unrealengine.com/t/installed-build-fails-trying-to-run-pdbcopy-exe/88759/19
    Write "Installing Debugging Tools for Windows..."

    $WDK_DOWNLOAD_LINK = "https://go.microsoft.com/fwlink/?linkid=2249371"
    $WDK_DESTINATION = "C:\\Users\\Administrator\\Downloads\\wdksetup.exe"

    Invoke-WebRequest -Uri $WDK_DOWNLOAD_LINK -OutFile $WDK_DESTINATION
    $wdkProc = Start-Process -FilePath $WDK_DESTINATION -ArgumentList "/q" -Wait -PassThru
    if ($wdkProc.ExitCode -ne 0) {
        throw "install_vs_tools: Debugging Tools for Windows (WDK) installer failed with exit code $($wdkProc.ExitCode)"
    }

    Write "Windows Development Kit Installed successfully."
}
catch {
    # FAIL LOUD: re-throw so the provisioner fails here instead of continuing
    # without PDBCOPY.exe and surfacing a confusing error later.
    Write "Debugging Tools for Windows installation failed: $($_.Exception.Message)"
    throw
}
finally {
    if ($WDK_DESTINATION -and (Test-Path $WDK_DESTINATION)) {
        Remove-Item -Path $WDK_DESTINATION -ErrorAction SilentlyContinue
    }
}

Write "Installing Visual Studio 2022 Build Tools"
choco install -y --no-progress visualstudio2022buildtools --package-parameters " --passive --locale en-US --add Microsoft.VisualStudio.Workload.VCTools;includeRecommended --add Microsoft.VisualStudio.Workload.ManagedDesktopBuildTools;includeRecommended --add Microsoft.VisualStudio.Component.VC.14.38.17.8.x86.x64 --add Microsoft.Net.Component.4.6.2.TargetingPack"
if ($LASTEXITCODE -ne 0) {
    throw "install_vs_tools: choco install 'visualstudio2022buildtools' failed with exit code $LASTEXITCODE"
}

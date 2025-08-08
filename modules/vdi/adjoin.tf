# AD Domain Joining Configuration
# Note: Local variables are defined in locals.tf

# SSM Document for domain joining using PowerShell (more reliable than aws:domainJoin)
resource "aws_ssm_document" "ssm_document_my_ad" {
  count         = local.enable_domain_join ? 1 : 0
  name          = "${local.ssm_document_name}-v2"
  document_type = "Command"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Join an instance to a domain using PowerShell"
    parameters = {
      DomainName = {
        type        = "String"
        description = "Domain name to join"
        default     = var.directory_name
      }
      AdminPassword = {
        type        = "String"
        description = "Domain administrator password"
        default     = local.effective_password
      }
      DirectoryOU = {
        type        = "String"
        description = "Organizational Unit (optional)"
        default     = var.directory_ou != null ? var.directory_ou : ""
      }
    }
    mainSteps = [
      {
        action = "aws:runPowerShellScript"
        name   = "JoinDomain"
        inputs = {
          runCommand = [
            "# PowerShell script for reliable domain joining",
            "Start-Transcript -Path 'C:\\Windows\\Temp\\domain-join.log' -Append",
            "Write-Host '=== Domain Join Process Starting ==='",
            "",
            "# Get parameters",
            "$domainName = '${var.directory_name}'",
            "$adminPassword = '${local.effective_password}'",
            "$directoryOU = '${var.directory_ou != null ? var.directory_ou : ""}'",
            "$adminUser = \"$domainName\\Administrator\"",
            "",
            "Write-Host \"Domain: $domainName\"",
            "Write-Host \"Admin User: $adminUser\"",
            "Write-Host \"Directory OU: $directoryOU\"",
            "",
            "try {",
            "    # Test network connectivity first",
            "    Write-Host 'Testing network connectivity...'",
            "    $dnsServers = @(${join(", ", [for ip in var.dns_ip_addresses : "'${ip}'"])})",
            "    foreach ($dns in $dnsServers) {",
            "        Write-Host \"Testing DNS server: $dns\"",
            "        $testResult = Test-NetConnection -ComputerName $dns -Port 53 -WarningAction SilentlyContinue",
            "        if ($testResult.TcpTestSucceeded) {",
            "            Write-Host \"DNS server $dns is reachable\"",
            "        } else {",
            "            Write-Host \"Warning: DNS server $dns is not reachable\"",
            "        }",
            "    }",
            "",
            "    # Test domain controller connectivity",
            "    Write-Host 'Testing domain controller connectivity...'",
            "    $dcTest = Test-NetConnection -ComputerName $domainName -Port 389 -WarningAction SilentlyContinue",
            "    if ($dcTest.TcpTestSucceeded) {",
            "        Write-Host 'Domain controller is reachable on LDAP port'",
            "    } else {",
            "        Write-Host 'Warning: Domain controller not reachable on LDAP port'",
            "    }",
            "",
            "    # Create credential object",
            "    Write-Host 'Creating domain credentials...'",
            "    $securePassword = ConvertTo-SecureString $adminPassword -AsPlainText -Force",
            "    $credential = New-Object System.Management.Automation.PSCredential($adminUser, $securePassword)",
            "",
            "    # Check if already domain joined",
            "    $currentDomain = (Get-WmiObject -Class Win32_ComputerSystem).Domain",
            "    Write-Host \"Current domain: $currentDomain\"",
            "",
            "    if ($currentDomain -eq $domainName) {",
            "        Write-Host 'Computer is already joined to the target domain'",
            "        # Test domain trust relationship",
            "        Write-Host 'Testing domain trust relationship...'",
            "        $trustTest = Test-ComputerSecureChannel -Verbose",
            "        if ($trustTest) {",
            "            Write-Host 'Domain trust relationship is healthy'",
            "            exit 0",
            "        } else {",
            "            Write-Host 'Domain trust relationship is broken, attempting to repair...'",
            "            Test-ComputerSecureChannel -Repair -Credential $credential",
            "        }",
            "    } else {",
            "        Write-Host 'Attempting to join domain...'",
            "        ",
            "        # Build Add-Computer parameters",
            "        $addComputerParams = @{",
            "            DomainName = $domainName",
            "            Credential = $credential",
            "            Force = $true",
            "            Verbose = $true",
            "        }",
            "        ",
            "        # Add OU if specified",
            "        if ($directoryOU -and $directoryOU -ne '') {",
            "            Write-Host \"Using Organizational Unit: $directoryOU\"",
            "            $addComputerParams.OUPath = $directoryOU",
            "        }",
            "        ",
            "        # Join the domain",
            "        Add-Computer @addComputerParams",
            "        Write-Host 'Domain join command completed successfully!'",
            "    }",
            "",
            "    # Verify domain join",
            "    Start-Sleep -Seconds 5",
            "    $newDomain = (Get-WmiObject -Class Win32_ComputerSystem).Domain",
            "    Write-Host \"New domain: $newDomain\"",
            "",
            "    if ($newDomain -eq $domainName) {",
            "        Write-Host 'Domain join verification successful!'",
            "        ",
            "        # Schedule restart",
            "        Write-Host 'Scheduling restart in 30 seconds...'",
            "        shutdown /r /t 30 /c 'Restarting after domain join'",
            "        ",
            "    } else {",
            "        Write-Host 'Domain join verification failed!'",
            "        throw 'Domain join completed but verification failed'",
            "    }",
            "",
            "} catch {",
            "    Write-Host \"Domain join failed: $_\"",
            "    Write-Host \"Exception Type: $($_.Exception.GetType().FullName)\"",
            "    Write-Host \"Exception Message: $($_.Exception.Message)\"",
            "    ",
            "    # Additional error details",
            "    if ($_.Exception.InnerException) {",
            "        Write-Host \"Inner Exception: $($_.Exception.InnerException.Message)\"",
            "    }",
            "    ",
            "    # Log current network configuration",
            "    Write-Host 'Current DNS configuration:'",
            "    Get-DnsClientServerAddress | Format-Table -AutoSize",
            "    ",
            "    Write-Host 'Current domain: '",
            "    (Get-WmiObject -Class Win32_ComputerSystem).Domain",
            "    ",
            "    exit 1",
            "}",
            "",
            "Write-Host '=== Domain Join Process Complete ==='",
            "Stop-Transcript"
          ]
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = local.ssm_document_name
  })

  # Force recreation when content changes since updates aren't allowed
  lifecycle {
    create_before_destroy = true
  }
}

# SSM Association to execute domain join on the instance
resource "aws_ssm_association" "domain_join" {
  count            = local.enable_domain_join && var.create_instance ? 1 : 0
  name             = aws_ssm_document.ssm_document_my_ad[0].name
  association_name = "${var.project_prefix}-${var.name}-domain-join-association"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.vdi_instance[0].id]
  }

  # Enhanced configuration for reliability
  max_concurrency = "1"
  max_errors      = "0"

  # Parameters for the PowerShell script
  parameters = {
    DomainName    = var.directory_name
    AdminPassword = local.effective_password
    DirectoryOU   = var.directory_ou != null ? var.directory_ou : ""
  }

  # Wait for the instance to be ready before attempting domain join
  depends_on = [
    aws_instance.vdi_instance
  ]

  tags = var.tags
}

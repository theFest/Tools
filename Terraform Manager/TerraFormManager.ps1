#requires -version 3.0

## v0.0.0.1

$Host.UI.RawUI.WindowTitle = "Terraform Manager by theFest"

$TimeBegin = Get-Date

## Checking and setting Executing policy settings
Write-Verbose -Message "Checking and setting Executing Policy..."
if ((Get-ExecutionPolicy -Scope CurrentUser) -ne "Unrestricted") {
    Write-Host "Setting Executing Policy to 'Unrestricted'" -ForegroundColor Yellow
    Set-ExecutionPolicy Unrestricted -Scope CurrentUser -Verbose
}

## Elevating if not runned under Admin permissions
Write-Verbose -Message "Elevating script as admin..."
$CurrentPrincipal = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
$AdminRole = [Security.Principal.WindowsBuiltInRole]::Administrator
if (-Not $CurrentPrincipal.IsInRole($AdminRole)) {
    Start-Process powershell.exe "-File `"$PSCommandPath`"" -Verb RunAs
    exit
}

## Checking or downloading/adding Terraform to environmental variables and making it permanent...
Write-Verbose -Message "Checking Terraform presence..."
if (!($env:Path -match "terraform")) {
    ## Check or download latest version of terraform.exe for Windows x64
    Write-Verbose -Message "Terraform is missing from environmental variables, setting it all up..."
    [uri]$tfURI = "https://releases.hashicorp.com/terraform"
    $tfIWR = Invoke-WebRequest -Uri $tfURI -Verbose
    $tfSel = ($tfIWR.Links | Select-Object -ExpandProperty "href")
    $tfSelU = $tfSel.Get("1") ; $tfSelA = $tfURI.Authority
    $tfSelC = [System.IO.Path]::Combine("$tfSelA$tfSelU")
    $tfURL = Invoke-WebRequest -Uri $tfSelC -Verbose
    $tfURLL = $tfURL.Links.Href | Select-String -SimpleMatch "windows_amd64" | Out-String
    $tfURLS = (Split-Path -Path $tfURLL -Leaf)
    $tfURLR = $tfURLS.Trim()
    if (-Not (Test-Path -Path "$env:TEMP\$tfURLR")) {
        Write-Host "Failed to find the $tfURLR, downloading..." -ForegroundColor DarkYellow
        try {
            Invoke-WebRequest -Uri $tfURLL -OutFile "$env:TEMP\$tfURLR" -Verbose
        }
        catch [System.Net.WebException] {
            Write-Warning "Exception caught: " ; $_
            $_.Exception.Response
        }
        finally {
            ## Verify downloaded content, in this case terraform.exe
            Write-Verbose -Message "Verifying downloaded content..."
            $tfFilePath = [System.IO.Path]::Combine($env:TEMP, $tfURLR)
            $tfLocPath = (Get-Item $tfFilePath).Length
            $tfRemPath = (Invoke-WebRequest -Uri $tfURLL -Method Head).Headers.'Content-Length'
            $tfLRCheck = [System.IO.File]::Exists("$env:TEMP\$tfURLR") -and $tfLocPath -match $tfRemPath
            if ($tfLRCheck) {
                Write-Host "Verification of downloaded content succesful: " -NoNewline -ForegroundColor Green ; $tfURLR
            }
            else {
                Write-Error -Message "Missmatch of downloaded content. Remote does not matches Local content!" -ErrorAction Stop
                $_
            }
            ## Expanding terraform.exe from .zip archive and moving it to C:\Windows\System32
            Write-Verbose -Message "Expanding Terraform and moving to C:\Windows\System32..."
            Expand-Archive -Path "$env:TEMP\$tfURLR" -DestinationPath $env:TEMP -Force -Verbose
            Copy-Item -Path "$env:TEMP\terraform.exe" -Destination "$env:SystemRoot\System32" -Force -Verbose
        }
    }
    else {
        Write-Host "Already present on system, continuing : " -NoNewline -ForegroundColor Green ; $tfURLR
    }
    Write-Verbose -Message "Terraform is being added to environmental variables..."
    $env:Path += ";$env:SystemRoot\System32\terraform.exe"
    [System.Environment]::SetEnvironmentVariable("Path", $env:Path, "Machine")
    ## Restarting ty prompting the user to restart the script
    $ResEnvR = Read-Host -Prompt "Do you want to restart the script (y/n)? "
    if ($ResEnvR -eq "y" -or $ResEnvR -eq "Y") {
        Start-Process $MyInvocation.ScriptName
        #powershell.exe start-process powershell | invoke-expression
    }
}

Write-Host "Time taken to check Terraform settings:" `
$((Get-Date).Subtract($TimeBegin).Duration() -replace ".{8}$") `
    -NoNewline -ForegroundColor Cyan

## Creating scriptblocks for menu, choices, etc.
Write-Verbose -Message "Preparing scriptblocks for menu, choices, etc. for loop..."
$Choices = {
    $Choice = $(Write-Host "Press(b) to go back into main menu" -ForegroundColor Cyan ; Read-Host)
    switch ($Choice) {
        { $Choice -eq 'b' } {
            Write-Host "Back to main menu"
        }
        default {
            throw "Exiting the script, unknown key!"
        }
    }
}
$Title = "Terraform IaC toolset"
$MenuData = @"
~> 1 [MAIN]TF - Init
~> 2 [MAIN]TF - Validate
~> 3 [MAIN]TF - Plan
~> 4 [MAIN]TF - Apply
~> 5 [MAIN]TF - Destroy
~> 06 [OTHER]TF - Console
~> 07 [OTHER]TF - Format
~> 08 [OTHER]TF - Unlock forcefully
~> 09 [OTHER]TF - Get modules
~> 10 [OTHER]TF - Graph
~> 11 [OTHER]TF - Import
~> 12 [OTHER]TF - Login
~> 13 [OTHER]TF - Logout
~> 14 [OTHER]TF - Output
~> 15 [OTHER]TF - Providers
~> 16 [OTHER]TF - Refresh
~> 17 [OTHER]TF - Show
~> 18 [OTHER]TF - State
~> 19 [OTHER]TF - Taint
~> 20 [OTHER]TF - Test
~> 21 [OTHER]TF - UnTaint
~> 22 [OTHER]TF - Workspace
~> s [INFO]TF - Switch to a different working directory before executing thegiven subcommand.
~> v [INFO]TF - Check installed version of Terraform
~> h [INFO]TF - Terraform Help (--help | /?)
* Pick a choice (0..9) or press (x) to Quit
"@
$MenuPicker = {
    Clear-Host ; $MenuPrompt = $Title ; $MenuPrompt += "`n" ; `
        $MenuPrompt += "-" * $Title.Length ; $MenuPrompt += "`n" ; `
        $MenuPrompt += $MenuData ; Read-Host -Prompt $MenuPrompt ; Clear-Host
}
Set-Alias -Name tf -Value "terraform" -Description "Execution of terraform.exe" -Force -Verbose
do {
    switch (Invoke-Command -ScriptBlock $MenuPicker) {
        "0" {
            tf "--help" ; Invoke-Command -ScriptBlock $Choices
        }
        "s" {
            $TFchdir = Read-Host -Prompt "Enter directory name" ; tf "-chdir=$TFchdir" ; Invoke-Command -ScriptBlock $Choices
        }
        "v" {
            tf --version json ; Invoke-Command -ScriptBlock $Choices
        }
        "h" {
            tf --help ; Invoke-Command -ScriptBlock $Choices # Invoke-Expression
        }
        "x" {
            Write-Host "Exiting, goodbye...." -ForegroundColor Cyan
            exit
        }
    }
}
while ($true)

## Cleaning up downloaded content
<#
    Write-Output "Time taken to instantiate Azure Resources: $Url $((Get-Date).Subtract($TimeDeploy).Duration() -replace ".{8}$")"
    Clear-Variable -Name DatabaseURL, DatabaseUser, DatabasePass -Force -Verbose
    Write-Host "Closing connecting with Azure..." -ForegroundColor DarkYellow
    az logout --verbose
    Clear-History -Verbose
    Stop-Transcript
#>

get-module -Name terraform -Verbose

# Get a list of all Terraform commands
$commands = "terraform.exe --help"

# Display a message to the user with the available options
Write-Host "Please select a command:"
$commands | ForEach-Object {
    Write-Host "$($_.Name) - $($_.Definition)"
}

# Prompt the user for input
$choice = Read-Host "Enter your command"






















<#
## TEMP

<# while ($true) {
    $Proc = Get-Process | Where-Object { $_.Path -eq "$env:USERPROFILE\Desktop\GitHub\Tools\Terraform manager\terraform_main.ps1" }
    # If the script is running, stop it
    if ($Proc) {
        Write-Host "Stopping script..."
        Stop-Process -Id $Proc.Id -Verbose
    }
    Write-Host "Restarting script..."
    Start-Process -FilePath "$env:USERPROFILE\Desktop\GitHub\Tools\Terraform manager\terraform_main.ps1"
    Write-Host "Exiting loop..."
    exit
} #>
#Start-Process -FilePath "$env:USERPROFILE\Desktop\test.ps1"
##
#Invoke-Expression "terraform -v"
#>

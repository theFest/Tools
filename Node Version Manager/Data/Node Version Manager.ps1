#requires -version 3.0
$Host.UI.RawUI.WindowTitle = "Node Version Manager by theFest"

Function Wait {
    $PauseJob = Start-Job -ScriptBlock { Start-Sleep -Seconds 3 }
    Write-Host "Starting Node Version Mamager, please wait..." -ForegroundColor DarkCyan
    while (($PauseJob.State -eq "Running") -and ($PauseJob.State -ne "NotStarted")) {
        Write-Host "." -NoNewline -ForegroundColor Cyan
        Start-Sleep -Seconds 1
    }
    Clear-Host
}

Function Timer {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [int]$Tleft = '3'
    )
    Write-Warning "Entering main menu in $Tleft seconds..."
    for ($Tleft = 3; $Tleft -gt 0; $Tleft--) {
        Write-Host "$Tleft seconds left" -ForegroundColor Cyan
        Start-Sleep -Seconds 1
    }
}

Function Choice {
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

Function InitialCheck {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [uri]$nmvUrl = "https://github.com/coreybutler/nvm-windows/releases/download/1.1.10/nvm-setup.zip"
    )
    Write-Host "Checking installed Node versions..."`n -ForegroundColor Yellow
    if (Get-Package -Name "NVM for Windows*" -Verbose -ErrorAction SilentlyContinue) {
        Write-Host "Found Node version(s)... `n$(nvm current)" -ForegroundColor Green
        Timer
    }
    else {
        Write-Host "`nNVM is not installed, do you want to download and install?"
        Write-Host "`t1.) 'Y' " -ForegroundColor Green
        Write-Host "`t2.) 'N' " -ForegroundColor Red
        $Choice = Read-Host "`nEnter Choice"
        switch ($Choice) {
            'Y' {
                Write-Host "`nDownloading and installing"
                Invoke-WebRequest -Uri $nmvUrl -UseBasicParsing -OutFile "$env:TEMP\nvm-setup.zip" -Verbose
                Expand-Archive -Path "$env:TEMP\nvm-setup.zip" -DestinationPath $env:TEMP -Force -Verbose
                Start-Process -FilePath "$env:TEMP\nvm-setup.exe" -ArgumentList "/silent" -WindowStyle Hidden -Wait
                if (Test-Path -Path "$env:USERPROFILE\AppData\Roaming\nvm\nvm.exe") {
                    Write-Host "Installed succesfully..." -ForegroundColor Green
                }
            }
            'N' {
                Write-Host "`exiting..." -ForegroundColor DarkGray
                exit
            } 
        }
    }
}

Wait
InitialCheck

Function ShowMenu {
    Param(
        [Parameter(Position = 0, Mandatory = $true, HelpMessage = "Enter your menu text")]
        [ValidateNotNullOrEmpty()]
        [string]$Menu,

        [Parameter(Position = 1, HelpMessage = "Define a title")]
        [ValidateNotNullOrEmpty()]
        [string]$Title,

        [switch]$ClearScreen
    )
    Clear-Host
    $MenuPrompt = $Title
    $MenuPrompt += "`n"
    $MenuPrompt += "-" * $Title.Length
    $MenuPrompt += "`n"
    $MenuPrompt += $Menu
    Read-Host -Prompt $MenuPrompt
    if ($ClearScreen) { 
        Clear-Host
    }    
} 

$MainMenu = @"
~> 0 NVM help /?
~> 1 Display currently active Node.JS version
~> 2 Show architecture information
~> 3 See list of available versions
~> 4 List the Node installations
~> 5 Install Node version
~> 6 Uninstall Node version
~> 7 Switch to use the specified Node version
~> 8 Enable Node version management
~> 9 Disable Node version management

* Pick a choice (0..9) or press (x) to Quit
"@

do {
    switch (ShowMenu -Menu $MainMenu -Title 'Node Version Manager Menu' -ClearScreen) {
        "0" {
            nvm "/?" ; Choice     
        } 
        "1" {
            Write-Host "Currently active Node.JS version: `n$(nvm current)" -ForegroundColor DarkYellow ; Choice
        } 
        "2" {
            nvm arch ; Write-Host "Installed NVM version: `n$(nvm --version)" -ForegroundColor DarkYellow ; Choice
        }
        "3" {
            Write-Host "List the Node.JS installations that are available and can be installed:" -ForegroundColor Cyan
            nvm list available ; Choice
        }
        "4" {
            Write-Output "Installed Node versions:" (nvm list) ; Choice
        }
        "5" {
            Write-Output "Copy Node version and paste it in input:" (nvm list available)
            Write-Host "Leave empty and press ENTER to return into main menu" -ForegroundColor DarkYellow
            $NvmInstallVer = Read-Host -Prompt "Enter version you would like to install"
            nvm install $NvmInstallVer
        }
        "6" {
            Write-Output "Copy Node version and paste it in input:" (nvm list)
            Write-Host "Leave empty and press ENTER to return into main menu" -ForegroundColor DarkYellow
            $NvmRemoveVer = Read-Host -Prompt "Enter version you would like to uninstall"
            nvm uninstall $NvmRemoveVer
        }
        "7" {
            Write-Output "Select(switch) to specific version:" (nvm list)
            $NvmUser = Read-Host -Prompt "Which version you would like to set as default"
            nvm use $NvmUser
        }
        "8" {
            Write-Host "Turn ON Node Version Manager:" -ForegroundColor DarkGreen
            nvm on ; InitialCheck
        }
        "9" {
            Write-Host "Turn OFF Node Version Manager:" -ForegroundColor Magenta
            nvm off ; InitialCheck
        }
        "x" {
            Write-Host "Exiting, goodbye...." -ForegroundColor Cyan
            exit
        }
    }
}
while ($true)

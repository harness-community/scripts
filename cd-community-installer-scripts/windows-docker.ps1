function Check-Resources {
    $cpus = Get-WmiObject -Class Win32_Processor | Measure-Object -Property NumberOfCores -Sum
    $memoryObject = Get-WmiObject -Class Win32_ComputerSystem 
    $totalMemory = [math]::Round($memoryObject.TotalPhysicalMemory / 1GB, 2) 
    if (!($totalMemory -lt 3 -and $cpus.Sum -lt 2)) {
        return $true
    }
    return $false
    
}

function Get-WSL {
    # Install WSL only if not enabled already
    # Write-Host "Run this script as administrator"
    if (!(Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux)) {
        # Enable WSL
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
        Write-Host "Windows Subsystem for Linux (WSL) has been enabled. Please restart your computer to complete the installation."
    }
    else {
        Write-Host "Windows Subsystem for Linux (WSL) is already enabled."
    }
}

function Get-Docker {
     # Check if Docker is already installed
     if (!(Get-Command "docker")) {
        # Download Docker for Windows installer
        Write-Host "Downloading Docker for Windows installer..."
        Write-Host "After installation restart the system and re-run the script to install Harness CD Community"
        $dockerInstaller = "$env:TEMP\Docker.exe"
        Invoke-WebRequest -Uri https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe -OutFile $dockerInstaller
        Start-Process -FilePath $dockerInstaller -Wait
        Write-Host "Docker for Windows has been installed. at '$destination'"
       
    }
    else {
        # if docker is installed - 
        if (!(Get-Command "docker")) {
            Write-Host "Docker not working properly"
        }
        else { Write-Host "Docker for Windows is already installed." }   
    }
}


function Get-Gitbash {
    # Check if Git Bash is already installed
    if (!(Test-Path "C:\Program Files (x86)\Git\git-bash.exe")) {
        # Download Git Bash installer
        Write-Host "Downloading Git Bash installer..."
        $gitInstaller = "$env:TEMP\GitBash.exe"
        Invoke-WebRequest "https://github.com/git-for-windows/git/releases/download/v2.30.2.windows.1/Git-2.30.2-32-bit.exe" -OutFile $gitInstaller
        # Install Git Bash
        Write-Host "Installing Git Bash..."
        Start-Process -FilePath $gitInstaller -ArgumentList "/SILENT" -Wait
        Write-Host "Git Bash has been installed."
    }
    else {
        Write-Host "Git Bash is already installed."
    }
}

function Clone-CDCommunity {
        $cloneDestination = Read-Host -Prompt "Enter the destination folder for cloning Harness CD Community Git Repo"
        $repoLink = "https://github.com/harness/harness-cd-community.git"
        Set-Location $cloneDestination
        git clone $repoLink
        Write-Host "$cloneDestination\harness-cd-community"
        if ((Test-Path "$cloneDestination\harness-cd-community")) {
            Write-Host "clonning completed"
            Write-Host "Setting Location to /docker-compose/harness"
            Set-Location harness-cd-community/docker-compose/harness
            docker-compose up -d
            docker compose ps 
            docker-compose run --rm proxy wait-for-it.sh ng-manager:7090 -t 180
            Start-Process "powershell.exe" -ArgumentList "start http://localhost/#/signup"
        }
        else {
            Write-Host "Some error occured IN harness CD Setup"
        }
        
    
}

if(Check-Resources){
    Get-WSL
    Get-Docker
    Get-Gitbash
    if ((Get-Command "docker") -and (Test-Path "C:\Program Files (x86)\Git\git-bash.exe")) {
    Clone-CDCommunity}
    else{
        Write-Host "Setup Failed!"
    }


}
else{
    Write-Host "Insufficient Resources! Harness CD Community requires a minimum of 3GB RAM and 2 CPU"
}





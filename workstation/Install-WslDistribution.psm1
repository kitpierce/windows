function Install-WSLDistribution {
    [CmdletBinding()]
    param (
        # Name Of Linux Distribution To Install
		[Parameter(Position=0)]
		[ValidateSet('Ubuntu-1804','Ubuntu-1804-Arm','Ubuntu-1604','Debian','Kali','OpenSUSE','SLES')]
        [String[]] $Name,

        # Destination/Installation Path For WSL Distributions
        [Parameter(Position=1)]
        [String] $Path = 'C:\WSL-Distros',

        # Do Not Install, Only Download File
        [Parameter(Position=2)]
        [Switch] $DownloadOnly,

        # Replace Any Existing Downloaded AppX Files
        [Parameter(Position=3)]
        [Switch] $ForceDownload
    )
    
    ## Reference: https://docs.microsoft.com/en-us/windows/wsl/install-manual

    $PrereqFeature = 'Microsoft-Windows-Subsystem-Linux'
    $ErrorNotElevated = 'The requested operation requires elevation'

    $DistroHash = [ORDERED]@{
        'Ubuntu-1804'		= 'https://aka.ms/wsl-ubuntu-1804';
        'Ubuntu-1804-Arm'	= 'https://aka.ms/wsl-ubuntu-1804-arm';
        'Ubuntu-1604'		= 'https://aka.ms/wsl-ubuntu-1604';
        'Debian'		= 'https://aka.ms/wsl-debian-gnulinux';
        'Kali'			= 'https://aka.ms/wsl-kali-linux';
        'OpenSUSE'		= 'https://aka.ms/wsl-opensuse-42';
        'SLES'			= 'https://aka.ms/wsl-sles-12';
    }
    
    # Test For Elevated Permissions & Valid Feature Object (via 'Online' query parameter)
    Try {
        $FeatureObject = Get-WindowsOptionalFeature -FeatureName $PrereqFeature -Online -ErrorAction Stop
        If ($FeatureObject.State -notlike "Enabled") {
            Write-Warning "Feature '$PrereqFeature' is not currently enabled"
        }
    }
    Catch {
        If ($_.Exception.Message -match $ErrorNotElevated) {
            Write-Warning "Installing Windows Optional Features requires elevated permissions."
            Return
        }
        Else {
            Write-Warning "Failed Windows Optional Feature online query '$Feature': $($_.Exception.Message)"
            Return
        }
    }

    Try {$IsEnabled = Get-WindowsOptionalFeature -FeatureName $PrereqFeature -ErrorAction Stop}
    Catch {
        Write-Host "Windowns Optional Feature not enabled: " -NoNewline
        Write-Host "'$PrereqFeature'" -ForegroundColor Cyan
        $IsEnabled = $false
    }

    If ($IsEnabled -eq $false) {
        Try {
            $InstallResults = Enable-WindowsOptionalFeature -FeatureName $PrereqFeature -Online -ErrorAction Stop
        }
        Catch {
            Write-Warning "Error installing feature '$PrereqFeature' - exception: $($_.Exception.Message)"
            Return
        }
    }

    Try {
        $InstallPath = Get-Item -Path $Path -ErrorAction Stop
    }
    Catch {
        Write-Host "Destination path does not exist: " -NoNewline
        Write-Host "'$Path'" -ForegroundColor Cyan
        $Response = Read-Host "Create destination path now? [Y/N]"

        If ($Response.ToCharArray()[0] -notlike 'Y') {
            Write-Warning "User declined to create destination path: '$Path'"
            Return
        }
        Else {
            Try {
                New-Item -Path $Path -ItemType Directory -ErrorAction Stop | Out-Null
                $InstallPath = Get-Item -Path $Path -ErrorAction Stop
            }
            Catch {
                Write-Warning "Error creating destination path: '$Path' - exception: $($_.Exception.Message)"
                Return
            }
        }
    }

    ForEach ($distro in $Name) {
        $DownloadAppXFile = $true
        $ReplaceAppXFile = $true
        $InstallAppXFile = $(-NOT $DownloadOnly)
        $DistroName = $Distro -replace '(\W)'
        $AppxName = $DistroName + '.appx'
        $AppXFullName = Join-Path $InstallPath.FullName $AppxName

        $FileExists = Test-Path -Path $AppXFullName -PathType Leaf
        
        If ($FileExists -AND ($ForceDownload -ne $true)) {
            Write-Host "AppX file already exists: " -NoNewline
            Write-Host $AppXFullName -ForegroundColor Yellow
            
            If ($(Read-Host "Force replace existing file? [Y/N]").ToCharArray()[0] -like 'Y') { $ReplaceAppXFile = $true }
            Else {
                Write-Verbose "User elected not to replace exiting file: '$AppXFullName'"
                $DownloadAppXFile = $false
            }
        }
        ElseIf ($FileExists -AND ($ForceDownload -eq $true -OR $ReplaceAppXFile -eq $true)) {
            Write-Host "Removing existing AppX file: " -NoNewline
            Write-Host $AppXFullName -ForegroundColor Yellow
            Try {
                Remove-Item -Path $AppXFullName -ErrorAction Stop | Out-Null
            }
            Catch {
                Write-Warning "Error removing existing file: '$AppXFullName'"
                $DownloadAppXFile = $false
                $InstallAppXFile = $false
            }
        }
        
        If ($DownloadAppXFile -ne $false) {
            $URL = $DistroHash[$distro]
            Write-Host "Downloading AppX file to path: " -NoNewline
            Write-Host $AppXFullName -ForegroundColor Cyan

            Try {
                Invoke-WebRequest -Uri $URL -OutFile $AppXFullName -UseBasicParsing
                Write-Verbose "Downloaded from '$URL' to AppX file: '$AppXFullName'"
            }
            Catch {
                Write-Warning "Error downloading from '$URL' - exception: $($_.Exception.Message)"
                $InstallAppXFile = $false
            }
        }
            
        If ($InstallAppXFile -ne $false) {
            Write-Verbose "Installing from AppX file: $($AppXFullName)"
            Try {
                $ZipFullName = $AppXFullName -replace '\.appx$','.zip'
                Copy-Item $AppXFullName $ZipFullName -ErrorAction Stop
                Start-Sleep 1
            }
            Catch {
                Write-Warning "Failed copying AppX to ZIP for file '$AppXFullName' - exception: $($_.Exception.Message)"
            }

            Try {
                $ExtractPath = Join-Path $InstallPath.FullName $DistroName
                Expand-Archive -Path $ZipFullName -DestinationPath $ExtractPath -ErrorAction Stop
            }
            Catch {
                Write-Warning "Failed extracting ZIP file '$ZipFullName' - exception: $($_.Exception.Message)"
            }
        }
    }
}

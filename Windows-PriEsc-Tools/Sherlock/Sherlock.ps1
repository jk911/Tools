<#

    File: Sherlock.ps1
    Author: @_RastaMouse
    License: GNU General Public License v3.0

#>

$Global:ExploitTable = $null

function Get-FileVersionInfo ($FilePath) {

    $VersionInfo = (Get-Item $FilePath).VersionInfo
    $FileVersion = ( "{0}.{1}.{2}.{3}" -f $VersionInfo.FileMajorPart, $VersionInfo.FileMinorPart, $VersionInfo.FileBuildPart, $VersionInfo.FilePrivatePart )
        
    return $FileVersion

}

function Get-InstalledSoftware($SoftwareName) {

    $SoftwareVersion = Get-WmiObject -Class Win32_Product | Where { $_.Name -eq $SoftwareName } | Select-Object Version
    $SoftwareVersion = $SoftwareVersion.Version  # I have no idea what I'm doing
    
    return $SoftwareVersion

}


function Get-Architecture {

    # This is the CPU architecture.  Returns "64-bit" or "32-bit".
    $CPUArchitecture = (Get-WmiObject Win32_OperatingSystem).OSArchitecture

    # This is the process architecture, e.g. are we an x86 process running on a 64-bit system.  Retuns "AMD64" or "x86".
    $ProcessArchitecture = $env:PROCESSOR_ARCHITECTURE

    return $CPUArchitecture, $ProcessArchitecture

}

function New-ExploitTable {

    # Create the table
    $Global:ExploitTable = New-Object System.Data.DataTable

    # Create the columns
    $Global:ExploitTable.Columns.Add("Title")
    $Global:ExploitTable.Columns.Add("MSBulletin")
    $Global:ExploitTable.Columns.Add("CVEID")
    $Global:ExploitTable.Columns.Add("Link")
    $Global:ExploitTable.Columns.Add("VulnStatus")

    # Add the exploits we are interested in.

    # MS10
    $Global:ExploitTable.Rows.Add("User Mode to Ring (KiTrap0D)","MS10-015","2010-0232","https://www.exploit-db.com/exploits/11199/")
    $Global:ExploitTable.Rows.Add("Task Scheduler .XML","MS10-092","2010-3338, 2010-3888","https://www.exploit-db.com/exploits/19930/")
    # MS13
    $Global:ExploitTable.Rows.Add("NTUserMessageCall Win32k Kernel Pool Overflow","MS13-053","2013-1300","https://www.exploit-db.com/exploits/33213/")
    $Global:ExploitTable.Rows.Add("TrackPopupMenuEx Win32k NULL Page","MS13-081","2013-3881","https://www.exploit-db.com/exploits/31576/")
    # MS14
    $Global:ExploitTable.Rows.Add("TrackPopupMenu Win32k Null Pointer Dereference","MS14-058","2014-4113","https://www.exploit-db.com/exploits/35101/")
    # MS15
    $Global:ExploitTable.Rows.Add("ClientCopyImage Win32k","MS15-051","2015-1701, 2015-2433","https://www.exploit-db.com/exploits/37367/")
    $Global:ExploitTable.Rows.Add("Font Driver Buffer Overflow","MS15-078","2015-2426, 2015-2433","https://www.exploit-db.com/exploits/38222/")
    # MS16
    $Global:ExploitTable.Rows.Add("'mrxdav.sys' WebDAV","MS16-016","2016-0051","https://www.exploit-db.com/exploits/40085/")
    $Global:ExploitTable.Rows.Add("Secondary Logon Handle","MS16-032","2016-0099","https://www.exploit-db.com/exploits/39719/")
    # Miscs that aren't MS
    $Global:ExploitTable.Rows.Add("Nessus Agent 6.6.2 - 6.10.3","N/A","2017-7199","https://aspe1337.blogspot.co.uk/2017/04/writeup-of-cve-2017-7199.html")

}

function Set-ExploitTable ($MSBulletin, $VulnStatus) {

    if ( $MSBulletin -like "MS*" ) {

        $Global:ExploitTable | Where { $_.MSBulletin -eq $MSBulletin

        } | ForEach-Object {

            $_.VulnStatus = $VulnStatus

        }

    } else {


    $Global:ExploitTable | Where { $_.CVEID -eq $MSBulletin

        } | ForEach-Object {

            $_.VulnStatus = $VulnStatus

        }

    }

}

function Get-Results {

    $Global:ExploitTable

}

function Find-AllVulns {

    if ( !$Global:ExploitTable ) {

        $null = New-ExploitTable
    
    }

        Find-MS10015
        Find-MS10092
        Find-MS13053
        Find-MS13081
        Find-MS14058
        Find-MS15051
        Find-MS15078
        Find-MS16016
        Find-MS16032
        Find-CVE20177199

        Get-Results

}

function Find-MS10015 {

    # Set the MS Bulletin
    $MSBulletin = "MS10-015"

    # Check the system architecture
    $Architecture = Get-Architecture

    # This exploit doesn't work against 64-bit systems
    if ( $Architecture[0] -eq "64-bit" ) {

        $VulnStatus = "Not supported on 64-bit systems"

    } Else {

        # Get the file version info for 'ntoskrnl.exe'
        $Path = $env:windir + "\system32\ntoskrnl.exe"
        $VersionInfo = Get-FileVersionInfo($Path)

        # Split the string into parts
        $VersionInfo = $VersionInfo.Split(".")

        # Get the Build and Revision
        $Build = $VersionInfo[2]
        $Revision = $VersionInfo[3].Split(" ")[0] # Drop the junk

        # Decide which versions are vulnerable
        switch ( $Build ) {

            7600 { $VulnStatus = @("Not Vulnerable","Appears Vulnerable")[ $Revision -le "20591" ] }
            default { $VulnStatus = "Not Vulnerable" }

        }

    }

    # Update the Exploit Table
    Set-ExploitTable $MSBulletin $VulnStatus

}

function Find-MS10092 {

    # Set the MS Bulletin
    $MSBulletin = "MS10-092"

    # Check the system architecture
    $Architecture = Get-Architecture

    # If running on 64-bit system, check the process architecture to ensure it's also 64-bit.
    if ( $Architecture[1] -eq "AMD64" -or $Architecture[0] -eq "32-bit" ) {

        # Get the file version info for 'schedsvc.dll'
        $Path = $env:windir + "\system32\schedsvc.dll"
        $VersionInfo = Get-FileVersionInfo($Path)

        # Split the string into parts
        $VersionInfo = $VersionInfo.Split(".")

        # Get the Build and Revision
        $Build = $VersionInfo[2]
        $Revision = $VersionInfo[3].Split(" ")[0] # Drop the junk

        # Decide which versions are vulnerable
        switch ( $Build ) {

            7600 { $VulnStatus = @("Not Vulnerable","Appears Vulnerable")[ $Revision -le "20830" ] }
            default { $VulnStatus = "Not Vulnerable" }

        }
        
    } ElseIf ( $Architecture[0] -eq "64-bit" -and $Architecture[1] -eq "x86" ) {

        $VulnStatus = "Migrate to a 64-bit process to avoid WOW64 Filesystem Redirection shenanigans"

    }

    # Update the Exploit Table
    Set-ExploitTable $MSBulletin $VulnStatus

}

function Find-MS13053 {

    # Set the MS Bulletin
    $MSBulletin = "MS13-053"

    # Check the system architecture
    $Architecture = Get-Architecture

    # This exploit doesn't work against 64-bit systems
    if ( $Architecture[0] -eq "64-bit" ) {

        $VulnStatus = "Not supported on 64-bit systems"

    } Else {

        # Get the file version info for 'win32k.sys'
        $Path = $env:windir + "\system32\win32k.sys"
        $VersionInfo = Get-FileVersionInfo($Path)

        # Split the string into parts
        $VersionInfo = $VersionInfo.Split(".")

        # Get the Build and Revision
        $Build = $VersionInfo[2]
        $Revision = $VersionInfo[3].Split(" ")[0] # Drop the junk

        # Decide which versions are vulnerable
        switch ( $Build ) {

            7600 { $VulnStatus = @("Not Vulnerable","Appears Vulnerable")[ $Revision -ge "17000" ] }
            7601 { $VulnStatus = @("Not Vulnerable","Appears Vulnerable")[ $Revision -le "22348" ] }
            9200 { $VulnStatus = @("Not Vulnerable","Appears Vulnerable")[ $Revision -le "20732" ] }
            default { $VulnStatus = "Not Vulnerable" }

        }

    }

    # Update the Exploit Table
    Set-ExploitTable $MSBulletin $VulnStatus

}

function Find-MS13081 {

    # Set the MS Bulletin
    $MSBulletin = "MS13-081"

    # Check the system architecture
    $Architecture = Get-Architecture

    # This exploit doesn't work against 64-bit systems
    if ( $Architecture[0] -eq "64-bit" ) {

        $VulnStatus = "Not supported on 64-bit systems"

    } Else {

        # Get the file version info for 'win32k.sys'
        $Path = $env:windir + "\system32\win32k.sys"
        $VersionInfo = Get-FileVersionInfo($Path)

        # Split the string into parts
        $VersionInfo = $VersionInfo.Split(".")

        # Get the Build and Revision
        $Build = $VersionInfo[2]
        $Revision = $VersionInfo[3].Split(" ")[0] # Drop the junk

        # Decide which versions are vulnerable
        switch ( $Build ) {

            7600 { $VulnStatus = @("Not Vulnerable","Appears Vulnerable")[ $Revision -ge "18000" ] }
            7601 { $VulnStatus = @("Not Vulnerable","Appears Vulnerable")[ $Revision -le "22435" ] }
            9200 { $VulnStatus = @("Not Vulnerable","Appears Vulnerable")[ $Revision -le "20807" ] }
            default { $VulnStatus = "Not Vulnerable" }

        }

    }

    # Update the Exploit Table
    Set-ExploitTable $MSBulletin $VulnStatus

}

function Find-MS14058 {

    # Set the MS Bulletin
    $MSBulletin = "MS14-058"

    # Check the system architecture
    $Architecture = Get-Architecture

    # If running on 64-bit system, check the process architecture to ensure it's also 64-bit.
    if ( $Architecture[1] -eq "AMD64" -or $Architecture[0] -eq "32-bit" ) {

        # Get the file version info for 'win32k.sys'
        $Path = $env:windir + "\system32\win32k.sys"
        $VersionInfo = Get-FileVersionInfo($Path)

        # Split the string into parts
        $VersionInfo = $VersionInfo.Split(".")

        # Get the Build and Revision
        $Build = $VersionInfo[2]
        $Revision = $VersionInfo[3].Split(" ")[0] # Drop the junk

        # Decide which versions are vulnerable
        switch ( $Build ) {

            7600 { $VulnStatus = @("Not Vulnerable","Appears Vulnerable")[ $Revision -ge "18000" ] }
            7601 { $VulnStatus = @("Not Vulnerable","Appears Vulnerable")[ $Revision -le "22823" ] }
            9200 { $VulnStatus = @("Not Vulnerable","Appears Vulnerable")[ $Revision -le "21247" ] }
            9600 { $VulnStatus = @("Not Vulnerable","Appears Vulnerable")[ $Revision -le "17353" ] }
            default { $VulnStatus = "Not Vulnerable" }

        }

        } ElseIf ( $Architecture[0] -eq "64-bit" -and $Architecture[1] -eq "x86" ) {

            $VulnStatus = "Migrate to a 64-bit process to avoid WOW64 Filesystem Redirection shenanigans"

        }

    # Update the Exploit Table
    Set-ExploitTable $MSBulletin $VulnStatus

}

function Find-MS15051 {

    # Set the MS Bulletin
    $MSBulletin = "MS15-051"

    # Check the system architecture
    $Architecture = Get-Architecture

    # If running on 64-bit system, check the process architecture to ensure it's also 64-bit.
    if ( $Architecture[1] -eq "AMD64" -or $Architecture[0] -eq "32-bit" ) {

        # Get the file version info for 'win32k.sys'
        $Path = $env:windir + "\system32\win32k.sys"
        $VersionInfo = Get-FileVersionInfo($Path)

        # Split the string into parts
        $VersionInfo = $VersionInfo.Split(".")

        # Get the Build and Revision
        $Build = $VersionInfo[2]
        $Revision = $VersionInfo[3].Split(" ")[0] # Drop the junk

        # Decide which versions are vulnerable
        switch ( $Build ) {

            7600 { $VulnStatus = @("Not Vulnerable","Appears Vulnerable")[ $Revision -ge "18000" ] }
            7601 { $VulnStatus = @("Not Vulnerable","Appears Vulnerable")[ $Revision -le "22823" ] }
            9200 { $VulnStatus = @("Not Vulnerable","Appears Vulnerable")[ $Revision -le "21247" ] }
            9600 { $VulnStatus = @("Not Vulnerable","Appears Vulnerable")[ $Revision -le "17353" ] }
            default { $VulnStatus = "Not Vulnerable" }

        }

    } ElseIf ( $Architecture[0] -eq "64-bit" -and $Architecture[1] -eq "x86" ) {

        $VulnStatus = "Migrate to a 64-bit process to avoid WOW64 Filesystem Redirection shenanigans"

    }

    # Update the Exploit Table
    Set-ExploitTable $MSBulletin $VulnStatus

}

function Find-MS15078 {

    # Set the MS Bulletin
    $MSBulletin = "MS15-078"

    # Get the file version info for 'atmfd.dll'
    $Path = $env:windir + "\system32\atmfd.dll"
    $VersionInfo = Get-FileVersionInfo($Path)

    # Split the string into parts
    $VersionInfo = $VersionInfo.Split(" ")

    # Get the Revision
    $Revision = $VersionInfo[2]

    # Decide which versions are vulnerable
    switch ( $Revision ) {

        243 { $VulnStatus = "Appears Vulnerable" }
        default { $VulnStatus = "Not Vulnerable" }

    }

    # Update the Exploit Table
    Set-ExploitTable $MSBulletin $VulnStatus

}

function Find-MS16016 {

    # Set the MS Bulletin
    $MSBulletin = "MS16-016"

    # Check the system architecture
    $Architecture = Get-Architecture

    # This exploit doesn't work against 64-bit systems
    if ( $Architecture[0] -eq "64-bit" ) {

        $VulnStatus = "Not supported on 64-bit systems"

    } Else {

        # Get the file version info for 'mrxdav.sys'
        $Path = $env:windir + "\system32\drivers\mrxdav.sys"
        $VersionInfo = Get-FileVersionInfo($Path)

        # Split the string into parts
        $VersionInfo = $VersionInfo.Split(".")

        # Get the Build and Revision
        $Build = $VersionInfo[2]
        $Revision = $VersionInfo[3].Split(" ")[0] # Drop the junk

        # Decide which versions are vulnerable
        switch ( $Build ) {

            7600 { $VulnStatus = @("Not Vulnerable","Appears Vulnerable")[ $Revision -ge "16000" ] }
            7601 { $VulnStatus = @("Not Vulnerable","Appears Vulnerable")[ $Revision -le "23317" ] }
            9200 { $VulnStatus = @("Not Vulnerable","Appears Vulnerable")[ $Revision -le "21738" ] }
            9600 { $VulnStatus = @("Not Vulnerable","Appears Vulnerable")[ $Revision -le "18189" ] }
            10240 { $VulnStatus = @("Not Vulnerable","Appears Vulnerable")[ $Revision -le "16683" ] }
            10586 { $VulnStatus = @("Not Vulnerable","Appears Vulnerable")[ $Revision -le "103" ] }
            default { $VulnStatus = "Not Vulnerable" }

        }

    }

    # Update the Exploit Table
    Set-ExploitTable $MSBulletin $VulnStatus

}

function Find-MS16032 {

    # Set the MS Bulletin
    $MSBulletin = "MS16-032"

    # Check the system architecture
    $Architecture = Get-Architecture

    # If running on 64-bit system, check the process architecture to ensure it's also 64-bit.
    if ( $Architecture[1] -eq "AMD64" -or $Architecture[0] -eq "32-bit" ) {

        # Get the file version info for 'seclogon.dll'
        $Path = $env:windir + "\system32\seclogon.dll"
        $VersionInfo = Get-FileVersionInfo($Path)

        # Split the string into parts
        $VersionInfo = $VersionInfo.Split(".")

        # Get the Build and Revision
        $Build = [int]$VersionInfo[2]
        $Revision = [int]$VersionInfo[3].Split(" ")[0] # Drop the junk
        # Decide which versions are vulnerable
        switch ( $Build ) {
            6002 { $VulnStatus = @("Not Vulnerable","Appears Vulnerable")[ $Revison -lt 19598 -Or ( $Revision -ge 23000 -And $Revision -le 23909 ) ] } # Confirmed for Windows 2008
            7600 { $VulnStatus = @("Not Vulnerable","Appears Vulnerable")[ $Revision -ge 16000 ] } # Not sure about 7 RTM
            7601 { $VulnStatus = @("Not Vulnerable","Appears Vulnerable")[ $Revision -lt 19148 -Or ( $Revision -ge 23000 -And $Revision -le 23347 ) ] } # Confirmed for Windows 7 and 2008R2
            9200 { $VulnStatus = @("Not Vulnerable","Appears Vulnerable")[ $Revison -lt 17649 -Or ( $Revision -ge 21000 -And $Revision -le 21767 ) ] } # Confirmed for Windows 2012
            9600 { $VulnStatus = @("Not Vulnerable","Appears Vulnerable")[ $Revison -lt 18230 ] } # Confirmed for Windows 8.1 and 2012R2
            10240 { $VulnStatus = @("Not Vulnerable","Appears Vulnerable")[ $Revision -lt 16724 ] } # Confirmed for Windows 10
            10586 { $VulnStatus = @("Not Vulnerable","Appears Vulnerable")[ $Revision -le 161 ] } # Confirmed for Windows 10 1151
            default { $VulnStatus = "Not Vulnerable" } # If no match

        }

    } ElseIf ( $Architecture[0] -eq "64-bit" -and $Architecture[1] -eq "x86" ) {

        $VulnStatus = "Migrate to a 64-bit process to avoid WOW64 Filesystem Redirection shenanigans"

    }

    # Update the Exploit Table
    Set-ExploitTable $MSBulletin $VulnStatus

}

function Find-CVE20177199 {

    # Set the CVE ID
    $CVEID = "2017-7199"

    # See if it's intalled and get the version
    $SoftwareVersion = Get-InstalledSoftware "Nessus Agent"
    
    if ( !$SoftwareVersion ) {

        $VulnStatus = "Not Vulnerable"

    } else {

        # Split
        $SoftwareVersion = $SoftwareVersion.Split(".")

        # Get the build parts
        $Major = [int]$SoftwareVersion[0]
        $Minor = [int]$SoftwareVersion[1]
        $Build = [int]$SoftwareVersion[2]

        # Decide which versions are vuln
        switch( $Major ) {

        6 { $VulnStatus = @("Not Vulnerable","Appears Vulnerable")[ $Minor -eq 10 -and $Build -le 3 -Or ( $Minor -eq 6 -and $Build -le 2 ) -Or ( $Minor -le 9 -and $Minor -ge 7 ) ] } # 6.6.2 - 6.10.3
        default { $VulnStatus = "Not Vulnerable" }

        }

    }

    # Update the Exploit Table
    Set-ExploitTable $CVEID $VulnStatus

}
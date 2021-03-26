function New-Project {
    <#
        .SYNOPSIS
            Powershell script to automate your work flow
        .EXAMPLE 
            New-Project -name "DevWorkSpace" -description "Powershell script to automate your work flow"
            Add each of the following to create a private repo, a repo without a wiki page, issues, downloads and to not Auto Initialize the repo
            -Private 
            -NoWiki
            -NoIssues
            -NoDownloads
            -AutoInit
        .NOTES
            File Name: devworkspace.psm1
            Author: Bradon Kelley (@bckelley)
            Requires: Powershell Version 5.1.18362.752
            
            The first time you run the script it will create an Environment Variable to save your GitHub Token
        .LINK
            https://github.com/bckelley/DevWorkSpace
    #>
    [cmdletbinding(SupportsShouldProcess)]    
    Param(
        [Parameter(Mandatory, HelpMessage = "Enter the new repository name")]
        [ValidateNotNullorEmpty()]
        [string]$Name,

        [Parameter(Mandatory, HelpMessage = "Enter the new repositories description")]
        [ValidateNotNullOrEmpty()]
        [string]$Description,
        
        [switch]$Private,
        [switch]$NoWiki,
        [switch]$NoIssues,
        [switch]$NoDownloads,
        [switch]$AutoInit,

        [Parameter(Mandatory, HelpMessage = "MIT, GPL-3.0 or AGPL-3.0")]
        [ValidateSet("MIT","GPL-3.0","AGPL-3.0")]
        [string]$License,
        
        [Parameter()]
        [string]$UserToken,

        [string]$path = "./$name",
        #write full native response to the pipeline
        [switch]$Raw
    )

    <#
     #
     # The follow if statment only runs once unless you delete the
     # ENV Variable.
     #
    #>
    if ( -not ( Test-Path Env:DevWorkSpaceTokenGitHub )) {
        $UserToken = Read-Host -Prompt "Enter your Github Personal Access Token: "
        Write-Host "Writing to ENV VARIABLE ..."
        [System.Environment]::SetEnvironmentVariable('DevWorkSpaceTokenGitHub', $UserToken, [System.EnvironmentVariableTarget]::User)
    }

    if ( ![System.IO.File]::Exists( $path ) ) {
        mkdir $path
    }

    Set-Location $path

    $readme = ".\readme.md"
    $gitignore = ".\.gitignore"
    $title = "Project: $Name`r`n"
    $desc = "$Description `r`n"
    $licenseDest = ".\License"

    <#
        This is for choosing license templates
    #>
    if ( $License -eq "MIT" ) {
        $LicenseTemplate = "..\templates\MIT"
    } elseif ( $License -eq "AGPL-3.0" ) {
        $LicenseTemplate = "..\templates\GNU AGPLv3"
    } elseif ( $License -eq "GPL-3.0" ) {
        $LicenseTemplate = "..\templates\GNU GPLv3"
    } else {
        Write-Warning "A License is required!"
    }

    $repo = "master"
    git init -b $repo
    
    Set-Content -Path $readme -value "$title`r`n$desc"
    $From = Get-Content -Path "..\templates\gitignore-wordpress"
    Add-Content -Path $gitignore -value $From
    Copy-Item -Path $LicenseTemplate -Destination $licenseDest

    git add $readme $gitignore $copied $licenseDest -A -f
    git commit -a -m "Initial Commit"

    Write-Verbose "[BEGIN  ] Starting: $($MyInvocation.Mycommand)"
    [string]$pb = ($PSBoundParameters | Format-Table -AutoSize | Out-String).TrimEnd()
    Write-Verbose "[BEGIN  ] PSBoundparameters: `n$($pb.split("`n").Foreach({"$("`t"*2)$_"}) | Out-String) `n"

    $Token = "$($env:DevWorkSpaceTokenGitHub)"
    $Base64Token = [System.Convert]::ToBase64String([char[]]$Token)

    $head = @{
        Authorization = 'Basic {0}' -f $Base64Token
    }

    $body = @{
        name = $Name
        description = $Description
        private = $Private -AS [boolean]
        has_wiki = (-Not $NoWiki)
        has_issues = (-Not $NoIssues)
        has_downloads = (-Not $NoDownloads)
    } | ConvertTo-Json

    Write-Verbose "[PROCESS] Sending json"
    Write-Verbose $body

    if ($PSCmdlet.ShouldProcess("$Name [$Description]")) {
        $r = Invoke-RestMethod -Headers $head -Uri https://api.github.com/user/repos -Body $body -Method Post
        
        if ($r.id -AND $Raw) {
            Write-Verbose "[PROCESS] Raw result"
            $r
        } elseif ($r.id) {
            Write-Verbose "[PROCESS} Formatted results"

            $r | Select-Object @{Name = "Name";Expression = {$_.name}},
            @{Name = "Description";Expression = {$_.description}},
            @{Name = "Private";Expression = {$_.private}},
            @{Name = "Issues";Expression = {$_.has_issues}},
            @{Name = "Wiki";Expression = {$_.has_wiki}},
            @{Name = "URL";Expression = {$_.html_url}},
            @{Name = "Clone";Expression = {$_.clone_url}}
        } else {
            Write-Warning "Something went wrong with this process"
        }

        if ($r.clone_url) {
            $msg = 
@"
            To push an existing local repository to Github run these commands:
            -> git remote add $repo $($r.clone_url)"
            -> git push -u $repo master
"@
            Write-Host $msg -ForegroundColor Green

            git remote add master $r.clone_url
            git push $repo master

        }
    }
    Write-Verbose "[END       ] Ending: $($MyInvocation.MyCommand)"

}
Export-ModuleMember -Function New-Project

<# 
 .SYNOPSIS
	Kickstart.ps1 is a Windows PowerShell script to install/configure IIS and Website Samples
.DESCRIPTION
	Version: 2.0.0
	Kickstart.ps1 is a Windows PowerShell script to install/configure IIS and Website Samples.
    It relies on bootstrap.ps1 to supply the requred 2 mandatory parmeters.
.DISCLAIMER
	THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF
	ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO
	THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
	PARTICULAR PURPOSE.
	Copyright (c) Microsoft Corporation. All rights reserved.
#> 

param
(    
    
    [Parameter(Mandatory=$true)]
    [string] $BootStrapFolder
)

Write-Host $BootStrapFolder
Write-host $AppProxyConnector


Function Create-WebSite
{
 param(
        [Parameter(Mandatory=$true)][string]$SiteName,
        [Parameter(Mandatory=$true)][string]$Port,
        [Parameter(Mandatory=$true)][string]$AppFolder
         )
         
        $portbind="*:" + "$port" + ":"
        $bindings=@{}
        $bindings.Add("protocol","http")
        $bindings.Add("bindingInformation","$portbind")
        

     
        New-Item -Path "IIS:\Sites" -Name $SiteName  -Type Site -Bindings $bindings
        Set-ItemProperty -Path "IIS:\Sites\$SiteName" -name "physicalPath" -value "$AppFolder"


    
    
}

Function Create-WebAppAndPool{
    param(
        [Parameter(Mandatory=$true)][string]$SiteName
        
         )

    [string]$HostName = "localhost"
    [string]$iisAppPoolDotNetVersion = "v4.0"
    [string]$iisAppPoolName = $SiteName
    [string]$IISSiteConfigPath = "IIS:\Sites\$SiteName"
    

    #navigate to the app pools root
    cd IIS:\AppPools\
    $appPool = New-Item $iisAppPoolName
    $appPool | Set-ItemProperty -Name "managedRuntimeVersion" -Value $iisAppPoolDotNetVersion

    #navigate to the sites root
    cd IIS:\Sites\

     Set-ItemProperty -Path $IISSiteConfigPath -Name "applicationpool" -Value $iisAppPoolName
    
           
}
Function Set-KerberosAuthForAppPool{
    param(
        [Parameter(Mandatory=$true)][string]$WebSiteName
        
         )

    [string]$IISAppConfigPath = "IIS:\Sites\$WebSiteName"
    
    #Setup Authentication to WindowsAuth
    
    Set-WebConfigurationProperty -filter /system.webServer/security/authentication/windowsAuthentication -name enabled -value true -PSPath IIS:\ -location $WebSiteName
    Set-WebConfigurationProperty -filter /system.webServer/security/authentication/anonymousAuthentication -name enabled -value False  -PSPath IIS:\ -location $WebSiteName
     
    
    
    cd $env:windir\system32\inetsrv
    #.\appcmd.exe set config $SiteName -section:system.webServer/security/authentication/windowsAuthentication /useKernelMode:"False"  /commit:apphost 
    .\appcmd.exe set config $SiteName -section:system.webServer/security/authentication/windowsAuthentication /useAppPoolCredentials:"True"  /commit:apphost
}
Function Set-AppPoolCredentials{
  param(
        [Parameter(Mandatory=$true)][string]$SiteName,
        [Parameter(Mandatory=$true)][string]$UserName,
        [Parameter(Mandatory=$true)][string]$Password,
        [Parameter(Mandatory=$true)][string]$Domain
        )

    
    [string]$iisAppPoolName = $SiteName
    [string]$iisAppDomainUser = $Domain+"\"+$UserName
    $applicationPools = Get-ChildItem IIS:\AppPools | where { $_.Name -eq $iisAppPoolName }
    foreach($applicationPool in $applicationPools)
        {
        $applicationPool.processModel.userName = $iisAppDomainUser
        $applicationPool.processModel.password = $Password
        $applicationPool.processModel.identityType = 3
        $applicationPool | Set-Item
        }

}
Function Add-SPN { 
    param(
    [Parameter(Mandatory=$true)][string]$UserName
    )

    [string]$ShortSPN="http/"+ $env:COMPUTERNAME
    [string]$LongSPN="http/" + $env:COMPUTERNAME+"."+$env:USERDNSDOMAIN
    $Result = Get-ADObject -LDAPFilter "(SamAccountname=$UserName)" 
    Set-ADObject -Identity $Result.DistinguishedName -add @{serviceprincipalname=$ShortSPN} 
    Set-ADObject -Identity $Result.DistinguishedName -add @{serviceprincipalname=$LongSPN} 

 
 }
Function Add-KCD { 
    param(
    [Parameter(Mandatory=$true)][string]$AppPoolUserName,
    [Parameter(Mandatory=$true)][string]$AppProxyConnetor
    )

 
    $dc=Get-ADDomainController -Discover -DomainName $env:USERDNSDOMAIN
    $AppProxyConnetorObj= Get-ADComputer -Identity $AppProxyConnetor -Server $dc.HostName[0]
    $AppPoolUserNameObj = Get-ADObject -LDAPFilter "(SamAccountname=$AppPoolUserName)" 
    
    Set-ADUser -Identity $AppPoolUserNameObj -PrincipalsAllowedToDelegateToAccount $AppProxyConnetorObj
    #Set-ADComputer -Identity jbadp1  -PrincipalsAllowedToDelegateToAccount  $AppPoolUserNameObj
    Get-ADUser -identity $AppPoolUserNameObj -Properties PrincipalsAllowedToDelegateToAccount
        
 }




#Install AD Tools
Write-Progress -PercentComplete 5 -id 1 -Activity "App Proxy Demo Installer " -Status "Installing Prerequistes" 
Write-Progress -PercentComplete 1 -id 2 -Activity "Installing Prerequisites" -Status "Remote Administration Tools" 

$addsTools = "RSAT-AD-Tools" 
Add-WindowsFeature $addsTools 

Write-Progress -PercentComplete 50 -id 2 -Activity "Installing Completed" -Status "Remote Administration Tools" 
Write-Progress -PercentComplete 20 -id 1 -Activity "App Proxy Demo Installer " -Status "Installing Prerequistes" 


#Install IIS
Write-Progress -PercentComplete 55 -id 2 -Activity "Installing Prerequisites" -Status "IIS" 
import-module servermanager
add-windowsfeature web-server -includeallsubfeature
Write-Progress -PercentComplete 99 -id 2 -Activity "Installing Completed" -Status "IIS" 


#Install 
Write-Progress -PercentComplete 100 -id 2 -Activity "Module Loaded" -Status "IIS" 
Write-Progress -PercentComplete 50 -id 1 -Activity "App Proxy Demo Installer " -Status "Starting Configuration" 
Import-Module WebAdministration
Write-Progress -PercentComplete 5 -id 2 -Activity "Initialize Install" -Status "Reading Configuration" 




Write-Progress -PercentComplete 100 -id 2 -Activity "Module Loaded" -Status "IIS" 
Write-Progress -PercentComplete 50 -id 1 -Activity "App Proxy Demo Installer " -Status "Starting Configuration" 
Import-Module WebAdministration
Write-Progress -PercentComplete 25 -id 2 -Activity "Initialize Install" -Status "Install WIA Website" 




[string] $AppPoolDomain = $env:USERDOMAIN



####################################################################
####################################################################
# Website 1
####################################################################
####################################################################
##Some variables
[string] $WebSiteName1 = "WIAApp"
[string] $WebSitePath1 = $BootStrapFolder +  "WIA"
[string] $WebSitePort1 = "8080"


## Create Domain Account / Password for App Pool
[string] $Randomizer = -join ((65..90) + (97..122) | Get-Random -Count 4 | % {[char]$_})
$Randomizer=$Randomizer.ToLower()
[string] $AppPoolUserName = "DemoAppPool" + "-" + "$Randomizer"
[Reflection.Assembly]::LoadWithPartialName("System.Web")
[string] $passrandom=[system.web.security.membership]::GeneratePassword(9,3)
[string] $AppPoolPassword = "MSFTDemo" + $passrandom
New-ADUser $AppPoolUserName -enable $true -AccountPassword (ConvertTo-SecureString -AsPlainText $AppPoolPassword -Force) -PassThru -Surname $AppPoolUserName -GivenName $AppPoolUserName  -Description "Test AppPool Account " -AccountExpirationDate $null
##


Create-WebSite -SiteName $WebSiteName1 -Port $WebSitePort1 -AppFolder $WebSitePath1
sleep(2)
Create-WebAppAndPool -SiteName $WebSiteName1 
sleep(1)
Set-AppPoolCredentials -SiteName $WebSiteName1 -UserName $AppPoolUserName -Password $AppPoolPassword -Domain $AppPoolDomain
sleep(1)
Set-KerberosAuthForAppPool -WebSiteName $WebSiteName1
sleep(1)
Add-SPN -UserName $AppPoolUserName 


Write-Progress -PercentComplete 50 -id 2 -Activity "Initialize Install" -Status "Install HeaderApp Website" 
####################################################################
####################################################################
# Website 2
####################################################################
####################################################################
##Some variables
[string] $WebSiteName2 = "HeaderApp"
[string] $WebSitePath2 = $BootStrapFolder +  "HeaderApp1"
[string] $WebSitePort2 = "8081"


## Create Domain Account / Password for App Pool
[string] $Randomizer = -join ((65..90) + (97..122) | Get-Random -Count 4 | % {[char]$_})
[string] $AppPoolUserName = "DemoAppPool" + "-" + "$Randomizer"
[Reflection.Assembly]::LoadWithPartialName("System.Web")
[string] $passrandom=[system.web.security.membership]::GeneratePassword(9,3)
[string] $AppPoolPassword = "MSFTDemo" + $passrandom
New-ADUser $AppPoolUserName -enable $true -AccountPassword (ConvertTo-SecureString -AsPlainText $AppPoolPassword -Force) -PassThru -Surname $AppPoolUserName -GivenName $AppPoolUserName  -Description "Test AppPool Account " -AccountExpirationDate $null

##

Create-WebSite -SiteName $WebSiteName2 -Port $WebSitePort2 -AppFolder $WebSitePath2
sleep(2)
Create-WebAppAndPool -SiteName $WebSiteName2 
sleep(1)
Set-AppPoolCredentials -SiteName $WebSiteName2 -UserName $AppPoolUserName -Password $AppPoolPassword -Domain $AppPoolDomain
sleep(1)


Write-Progress -PercentComplete 75 -id 2 -Activity "Initialize Install" -Status "Install Forms App Website" 
####################################################################
####################################################################
# Website 3
####################################################################
####################################################################
##Some variables
[string] $WebSiteName3 = "FormsApp"
[string] $WebSitePath3 = $BootStrapFolder + "Forms"
[string] $WebSitePort3 = "8082"


## Create Domain Account / Password for App Pool
[string] $Randomizer = -join ((65..90) + (97..122) | Get-Random -Count 4 | % {[char]$_})
[string] $AppPoolUserName = "DemoAppPool" + "-" + "$Randomizer"
[Reflection.Assembly]::LoadWithPartialName("System.Web")
[string] $passrandom=[system.web.security.membership]::GeneratePassword(9,3)
[string] $AppPoolPassword = "MSFTDemo" + $passrandom
New-ADUser $AppPoolUserName -enable $true -AccountPassword (ConvertTo-SecureString -AsPlainText $AppPoolPassword -Force) -PassThru -Surname $AppPoolUserName -GivenName $AppPoolUserName  -Description "Test AppPool Account " -AccountExpirationDate $null

##

Create-WebSite -SiteName $WebSiteName3 -Port $WebSitePort3 -AppFolder $WebSitePath3
sleep(2)
Create-WebAppAndPool -SiteName $WebSiteName3 
sleep(1)
Set-AppPoolCredentials -SiteName $WebSiteName3 -UserName $AppPoolUserName -Password $AppPoolPassword -Domain $AppPoolDomain
sleep(1)



Write-Progress -PercentComplete 75 -id 2 -Activity "Initialize Install" -Status "Install ASP.net Core hosting Package" 

$BootStrapFolder = "C:\AppDemov1\DemoSuite-master\Website"
$installFolder="$BootStrapFolder" + "\dotnetCore"
cd $installFolder
.\dotnet-hosting-3.1.3-win.exe /quiet 
    




Write-Progress -PercentComplete 100 -id 1 -Activity "App Proxy Demo Installer " -Status "Comppleting Configuration"  
Write-Progress -PercentComplete 100 -id 2 -Activity "Configuration Started" -Status "Confuguration  Completed!!" 





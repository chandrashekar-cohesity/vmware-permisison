## Top of the script

# Stop on any error
$ErrorActionPreference = "Stop"      

filter leftside{
    param(
            [Parameter(Position=0, Mandatory=$true,ValueFromPipeline = $true)]
            [ValidateNotNullOrEmpty()]
            [PSCustomObject]
            $obj
        )
    
        $obj | Where-Object{$_.sideindicator -eq '<='}
    
    }

filter rightside{
        param(
                [Parameter(Position=0, Mandatory=$true,ValueFromPipeline = $true)]
                [ValidateNotNullOrEmpty()]
                [PSCustomObject]
                $obj
            )
        
            $obj | Where-Object{$_.sideindicator -eq '=>'}
        
        }
function Manage-User-Roles {
    <#
    This function will create a user named "cohesity_backup_user" and a role named 
    "cohesity_data_protection_
role". If option 2 is selected, it will take a userName from user
    executing the script and apply the cohesity_data_protection_
role to the collected user
    #>
    param (
        [string]$Title = 'Role and User Management'
    )
    Write-Host "================ $Title ================"
    Write-Host "1: Press '1' to create a 'cohesity_backup_user' user and assign the 'cohesity_data_protection_role'"
    Write-Host "2: Press '2' to use an existing user and assign the 'cohesity_data_protection_ role'"
    Write-Host "Q: Press 'Q' to quit."
}

function Show-MainMenu {
    <#
    This displays the main menu. 
    Option 1: Applies all privileges to the user 
    Option 2: Provides more option
    #>
    param (
        [string]$Title = 'Give Cohesity vCenter User permission'
    )
    Write-Host "================ $Title ================"
            
    Write-Host "1: Press '1' for Silent Install (Storage Snapshot Integration + Datastore Adaptive Throttling + Encrypted VMs)"
    Write-Host "2: Press '2' for Interactive."
    Write-Host "Q: Press 'Q' to quit."
}
      

function Show-InteractiveMenu {
    <#
    This displays the interactive menu. 
    The options are pretty self explanatory
    #>
    param (
        [string]$Title = 'Select type of permission you want to assign'
    )
    write-host "`n"
    Write-Host "================ $Title ================"
            
    Write-Host "1: Press '1' VMware Snapshot only"
    Write-Host "2: Press '2' VMware Snapshot + Datastore Adaptive Throttling"
    Write-Host "2: Press '3' VMware Snapshot + Datastore Adaptive Throttling + Encrypted VMs"
    Write-Host "4: Press '4' Storage Snapshot Integration only"
    Write-Host "5: Press '5' Storage Snapshot Integration + Datastore Adaptive Throttling"
    Write-Host "6: Press '6' Storage Snapshot Integration + Datastore Adaptive Throttling + Encrypted VMs"
    Write-Host "Q: Press 'Q' to quit."
}

function RoleManagement($privilegeList) {
    <#
    This funtion creates or updates the cohesity_data_protection_role depending on $roleExits Flag 
    #>

    if($roleExists -ne $null){
        $existingPrivileges = Get-VIPrivilege -Role cohesity_data_protection_role | Select-Object -Property Id
        $existingStringPrivileges = $existingPrivileges | ForEach-Object{($_.Id)}                            
        $deletePrivilegesObj = Compare-Object -ReferenceObject $existingStringPrivileges -DifferenceObject $privilegeList | leftside
        $addPrivilegesObj = Compare-Object -ReferenceObject $existingStringPrivileges -DifferenceObject $privilegeList | rightside
        
        $deletePrivileges = $deletePrivilegesObj | ForEach-Object {$_.InputObject} 
        $addPrivileges = $addPrivilegesObj | ForEach-Object {$_.InputObject} 

        if(($addPrivileges.Length -eq 0) -and ($deletePrivileges.Length -eq 0 )){
            Write-Host "================ No updated needed to the privileges ================" -ForegroundColor Yellow
            Disconnect-VIServer -Server $vc -Confirm:$false
            exit
        }
        elseif(($addPrivileges.Length -eq 0) -and ($deletePrivileges.Length -ge 0 )){
            Write-Host "================ Removing the following privileges ================" -ForegroundColor Yellow
            $deletePrivileges
            Write-Host "===================================================================" -ForegroundColor Yellow
            Set-VIRole -Role (Get-VIRole -Name cohesity_data_protection_role) -RemovePrivilege (Get-VIPrivilege -id $deletePrivileges -Server $vc)
        }
        elseif(($addPrivileges.Length -ge 0) -and ($deletePrivileges.Length -eq 0 )){
            Write-Host "================ Adding the following privileges ================" -ForegroundColor Yellow
            $addPrivileges
            Write-Host "=================================================================" -ForegroundColor Yellow
            Set-VIRole -Role (Get-VIRole -Name cohesity_data_protection_role) -AddPrivilege (Get-VIPrivilege -id $addPrivileges -Server $vc) 
        }
        else{
            Write-Host "================ Adding the following privileges ==================" -ForegroundColor Yellow
            $addPrivileges
            Write-Host "===================================================================" -ForegroundColor Yellow
            Write-Host "================ Removing the following privileges ================" -ForegroundColor Yellow
            $deletePrivileges
            Write-Host "===================================================================" -ForegroundColor Yellow
            Set-VIRole -Role (Get-VIRole -Name cohesity_data_protection_role) -AddPrivilege (Get-VIPrivilege -id $addPrivileges -Server $vc) -RemovePrivilege (Get-VIPrivilege -id $deletePrivileges -Server $vc)
        }
        $rootFolder = Get-Folder -NoRecursion
        Set-VIPermission -Role $roleName -Permission (Get-VIPermission -Principal $userName)
        Write-Host "================ Updated $roleName. Check logs for more details ================" -ForegroundColor Green
        Disconnect-VIServer -Server $vc -Confirm:$false
        exit
    }
    else{
        New-VIRole -Name $roleName -Privilege (Get-VIPrivilege -id $privilegeList -Server $vc)
        $rootFolder = Get-Folder -NoRecursion
        New-VIPermission -Entity $rootFolder -Principal $userName -Role $roleName
        Write-Host "================ Assigning $roleName to $userName sucessful. Check logs for more details ================" -ForegroundColor Green
        Disconnect-VIServer -Server $vc -Confirm:$false
        exit
    }
    
}

# Variables that store privileges for different options
$VMwareSnapshot = @()
$VMwareSnapshotAptThrot = @()
$VMwareSnapshotAptThrotEncyptVM = @()
$StorageSnapshotIntegration = @()
$StorageSnapshotIntegrationAdptThrot = @()
$StorageSnapshotIntegrationAdptThrotEncryptVM = @()

$RootPath = $PSScriptRoot
$LogFile = Join-Path -Path $RootPath -ChildPath "privilege.log"
$privilegeJson = Join-Path -Path $RootPath -ChildPath "privilege.json"

# Read the privileges json file to populate the different privileges arrays
try{
    $json = Get-Content $privilegeJson | Out-String | ConvertFrom-Json
}
catch {
    Add-Content $LogFile  "Reading Json file failed."       
}
$VMwareSnapshot = $json.VMwareSnapshot
$VMwareSnapshotAptThrot = $VMwareSnapshot + $json.VMwareSnapshotAptThrot
$VMwareSnapshotAptThrotEncyptVM = $VMwareSnapshot + $json.VMwareSnapshotAptThrotEncyptVM
$StorageSnapshotIntegration = $VMwareSnapshot + $json.StorageSnapshotIntegration
$StorageSnapshotIntegrationAdptThrot = $VMwareSnapshot + $json.StorageSnapshotIntegrationAdptThrot
$StorageSnapshotIntegrationAdptThrotEncryptVM = $VMwareSnapshot + $json.StorageSnapshotIntegrationAdptThrotEncryptVM

Add-Content $LogFile  "$((Get-Date).ToString()): Starting script."

Set-PowerCLIConfiguration -InvalidCertificateAction ignore -confirm:$False
$vCenterServer = Read-Host " Enter the vCenter FQDN or IP here: "  
$vCenterUserName = Read-Host " Enter the vCenterUserName here: "  
$credentials= Get-Credential -UserName $vCenterUserName  -Message "Enter your vCenter password"

try{
    # Connecting to vCenter
    Clear-Host
    Write-Host "================ Connect to vCenter ================"
    $vc = Connect-VIServer -Server $vCenterServer -Credential $credentials
    

}
catch{
    Add-Content $LogFile  "Cannot connect to $vCenterServer. "    
}

try{
    # Check if role already exists
    $roleExists = Get-VIRole -Name "cohesity_data_protection_role"
    Write-Host ""
    Write-Host "Role already present Updating role 'cohesity_data_protection_role'" -ForegroundColor Yellow
}
catch{
    Write-Host ""
    Write-Host "Role not present already. Creating role 'cohesity_data_protection_role'" -ForegroundColor Yellow
}

#Default Role name
$roleName = "cohesity_data_protection_role"
Write-Host ""
$userName = Read-Host "Enter the user name here (DOMAIN\username) "  
write-host "`n"
  
#Main menu to collect user preference for applying role to the account user
do {
    
    Show-MainMenu
    $MainMenuSelection = Read-Host "Please make a selection"
    switch ($MainMenuSelection) {
        '1' {
            # Apply all roles to the user
            Write-Host "================ Assigning $roleName to $userName.  ================"
            try{
                RoleManagement($StorageSnapshotIntegrationAdptThrotEncryptVM)
            }
            catch{
                Add-Content $LogFile $_
                Write-Host $_ -ForegroundColor Red
            }
            
                
        } '2' {
            Show-InteractiveMenu
            $InteractiveMenuselection = Read-Host "Please make a selection"
            switch ($InteractiveMenuselection) {
                '1' {
                    # Apply VMwareSnapshot roles to the user
                    write-host "`n"
                    Write-Host "================ Assigning $roleName to $userName.  ================"
                    try{
                        RoleManagement($VMwareSnapshot)
                    }
                    catch{
                        Add-Content $LogFile $_
                        Write-Host $_ -ForegroundColor Red
                    }
                    
                    
                } '2' {
                    # Apply VMwareSnapshot + Datastore Adaptive throttling roles to the user
                    write-host "`n"
                    Write-Host "================ Assigning $roleName to $userName.  ================"
                    try{
                        RoleManagement($VMwareSnapshotAptThrot)
                    }
                    catch{
                        Write-Host $_ -ForegroundColor Red
                        Add-Content $LogFile $_
                    }
                    
                        
                } 
                '3' {
                    # Apply VMwareSnapshot + Datastore Adaptive throttling + Encryption roles to the user
                    write-host "`n"
                    Write-Host "================ Assigning $roleName to $userName.  ================"
                    try{
                        RoleManagement($VMwareSnapshotAptThrotEncyptVM)
                    }
                    catch{
                        Write-Host $_ -ForegroundColor Red
                        Add-Content $LogFile $_
                    }
                    
                    
                } '4' {
                    # Apply Storage Snapshot Integration roles to the user
                    write-host "`n"
                    Write-Host "================ Assigning $roleName to $userName.  ================"
                    try{
                        RoleManagement($StorageSnapshotIntegration)
                    }
                    catch{
                        Write-Host $_ -ForegroundColor Red
                        Add-Content $LogFile $_
                    }
                    
                        
                } 
                '5' {
                    # Apply Storage Snapshot Integration + Datastore Adaptive throttling roles to the user
                    write-host "`n"
                    Write-Host "================ Assigning $roleName to $userName.  ================"
                    try{
                        RoleManagement($StorageSnapshotIntegrationAdptThrot)
                    }
                    catch{
                        Write-Host $_ -ForegroundColor Red
                        Add-Content $LogFile $_
                    }
                    
                    
                } '6' {
                    # Apply Storage Snapshot Integration + Datastore Adaptive throttling + Encryption roles to the user
                    write-host "`n"
                    Write-Host "================ Assigning $roleName to $userName.  ================"
                    try{
                        RoleManagement($StorageSnapshotIntegrationAdptThrotEncryptVM)
                    }
                    catch{
                        Write-Host $_ -ForegroundColor Red
                        Add-Content $LogFile $_
                    }
                    
                        
                }'Q' {
                    Add-Content $LogFile  "$((Get-Date).ToString()): Exiting the script"    
                    exit
                } 'q' {
                    Add-Content $LogFile  "$((Get-Date).ToString()): Exiting the script"    
                    exit
                }
                default {
                    write-host "`n"
                    Write-Host "================ Incorrect Selection Please try again ================" -ForegroundColor Red
                    Show-InteractiveMenu
                }
            }

        } '3'{
            Write-Host "================ Reading privilege.json to get new privileges ================" 

        } 'Q' {
            Add-Content $LogFile  "$((Get-Date).ToString()): Exiting the script"    
            exit
        } 'q' {
            Add-Content $LogFile  "$((Get-Date).ToString()): Exiting the script"    
            exit
        }
        default {
            write-host "`n"
            Write-Host "================ Incorrect Selection Please try again ================" -ForegroundColor Red
            Show-MainMenu
        } 
    }
    
}
until ($MainMenuSelection -eq 'q')
#This script is used to migrate VMs from 1 cluster to another
#VMs are moved to destination datastore - "Test-VSAN"
#VMs are moved to destination hosts specified in the array $dest 
#Developer - kujalk
#Version - 2
#Date - 24/7/2018

cls

write-host "
This script is used to migrate VMs parallely to new cluster

Important things to Remember

	1. VM count should be greater than the parallel migrations specified
	2. VM list should be fed through text file
	3. Maximum of 8 VMs will be parallely migrated
	
	
"

$user_ans1=Read-Host "Are you ready to begin (y/n) ?"

if ($user_ans1 -ne "y")
{
exit
}

cls


#function for logging time
function timestamp ($message)
{
$date=Get-Date
"$date : <<Info>> : $message" >> $log
}
#############################

#To get the VM folder path of source location
function Get-VMFolderPath {  
  
   Begin {} #Begin  
   Process {  
     foreach ($vm in $Input) {  
       $DataCenter = $vm | Get-Datacenter  
       $DataCenterName = $DataCenter.Name  
       $VMname = $vm.Name  
       $VMParentName = $vm.Folder  
       if ($VMParentName.Name -eq "vm") {  
         $FolderStructure = "{0}\{1}" -f $DataCenterName, $VMname  
         $FolderStructure  
         Continue  
       }#if ($VMParentName.Name -eq "vm")  
       else {  
         $FolderStructure = "{0}\{1}" -f $VMParentName.Name, $VMname  
         $VMParentID = Get-Folder -Id $VMParentName.ParentId  
         do {  
           $ParentFolderName = $VMParentID.Name  
           if ($ParentFolderName -eq "vm") {  
             $FolderStructure = "$DataCenterName\$FolderStructure"  
             $FolderStructure  
             break  
           } #if ($ParentFolderName -eq "vm")  
           $FolderStructure = "$ParentFolderName\$FolderStructure"  
           $VMParentID = Get-Folder -Id $VMParentID.ParentId  
         } #do  
         until ($VMParentName.ParentId -eq $DataCenter.Id) #until  
       } #else ($VMParentName.Name -eq "vm")  
     } #foreach ($vm in $VMList)  
   } #Process  
   End {} #End  
 } 


#Move VM to correct folder path 
##############
function Move-VMtoFolderPath {  
   
   Foreach ($FolderPath in $Input) {  
     $list = $FolderPath -split "\\"  
     $VMName = $list[-1]
	 $list[0]="DC1"
     $count = $list.count - 2  
     0..$count | ForEach-Object {  
          $number = $_  
       if ($_ -eq 0 -and $count -gt 2) {  
               $Datacenter = Get-Datacenter $list[0]  
          } #if ($_ -eq 0)  
       elseif ($_ -eq 0 -and $count -eq 0) {  
               $Datacenter = Get-Datacenter $list[$_]  
               #VM already in Datacenter no need to move  
         Continue  
       } #elseif ($_ -eq 0 -and $count -eq 0)  
       elseif ($_ -eq 0 -and $count -eq 1) {  
         $Datacenter = Get-Datacenter $list[$_]  
       } #elseif ($_ -eq 0 -and $count -eq 1)  
       elseif ($_ -eq 0 -and $count -eq 2) {  
         $Datacenter = Get-Datacenter $list[$_]  
       } #elseif ($_ -eq 0 -and $count -eq 2)  
          elseif ($_ -eq 1) {  
               $Folder = $Datacenter | Get-folder $list[$_]  
          } #elseif ($_ -eq 1)  
          else {  
         $Folder = $Folder | Get-Folder $list[$_]  
          } #else  
     } #0..$count | foreach  
    Move-VM -VM $VMName -Destination $Folder  
   } #Foreach ($FolderPath in $VMFolderPathList)  
 }#function Set-FolderPath  
 

################
### Login Section start

$vCenter= Read-Host -Prompt "Please enter the Vcenter you want to connect `n" 


$vCenterUser= Read-Host -Prompt "Enter user name `n"

$vCenterUserPassword= Read-Host -Prompt "Password `n" -assecurestring

$credential = New-Object System.Management.Automation.PSCredential($vCenterUser,$vCenterUserPassword)

Connect-VIServer -Server $vCenter -Credential $credential

#To avoid timeout
Set-PowerCLIConfiguration -WebOperationTimeoutSeconds -1 -confirm:$false

### Login Section finished

$folder_loc= Read-Host "Provide the folder location to store files EG - C:\Test"

#Required Files
$not_found= "$folder_loc"+"\vm_not_found.txt"
$log="$folder_loc"+"\vm_log.txt"
$success="$folder_loc"+"\vm_success.txt"
$vm_info="$folder_loc"+"\vm_info.txt"
$failed_vm="$folder_loc"+"\vm_failed.txt"
$source = "$folder_loc"+"\vm_filter.txt"

#Get the location of VMs list file
$unfilter_VM = Read-Host "Provide the location of VM file [C:\Test\vm.txt]"

#Asking user, to input the no.of parallel migrations to be done
[int]$parallel = Read-Host "Input No.Of Parallel Migrations"


if($parallel -gt 8)
{
write-host "More than 8 migrations at a time is not allowed"
exit
}

$vm_where=Get-Content $unfilter_VM

write-host "VM Filtering is started ....."

foreach ($v in $vm_where)
{
Get-VM $v

if ($? -eq "True")
{
$v >> $source
}

else
{
$v >> $not_found
}

}

cls

write-host "VM Filtering done"

$list=Get-Content $source


#Total no.of VMs needs to be migrated
[int]$last=$list.count

if($parallel -ge $last)
{
$parallel=$last-1
}

$track=@{}

$offerings=@{}

$tasks=1..$parallel

[int]$num=$parallel

#Destination ESXI Servers
$dest=@("server1","server2","server3","server4","server5","server6","server7","server8")


#First mail - Information
$smtpServer = "mailserver1"

$msg = new-object Net.Mail.MailMessage

$smtp = new-object Net.Mail.SmtpClient($smtpServer)

#Change according to server where the script is executed
$msg.From = "Testserver1"

#Recepients
$msg.To.Add("sample.mail.address")


$msg.Subject = "Migration of VMS (Script Started)"
$dc=Get-Date
$msg.Body = "`n`nMigration script started.`nScript Initiator : $vCenterUser `nStart Time : $dc`nParallel Migrations : $parallel `nNo.of VMs to be migrated : $last `nVM Details : Refer Attachment"

$msg.Attachments.Add($source)
$msg.Attachments.Add($not_found)

$smtp.Send($msg)

####

#Function to set I/O high
function Reconfigure ($a)
{
#Reconfiguration tasks of VMS
#Getting the offerein level configured for each VM
$Resourceinfo = Get-VMResourceConfiguration $a
$off_vm=$Resourceinfo.DiskResourceConfiguration.DiskSharesLevel| Select-Object -first 1
$offerings.add($a,$off_vm)
timestamp "$a Storage Share is - $off_vm"
	
##First Reconfiguration
$DiskLimitIOPerSecond = -1

$vm = Get-VM -Name $a 
$spec = New-Object VMware.Vim.VirtualMachineConfigSpec
$vm.ExtensionData.Config.Hardware.Device |
where {$_ -is [VMware.Vim.VirtualDisk]} | %{
$dev = New-Object VMware.Vim.VirtualDeviceConfigSpec
$dev.Operation = "edit"
$dev.Device = $_
$dev.Device.StorageIOAllocation.Limit = $DiskLimitIOPerSecond
$dev.Device.storageIOAllocation.shares.level  = "High"
$spec.DeviceChange += $dev
}

$vm.ExtensionData.ReconfigVM_Task($spec)
timestamp "Setting IOPs limit to $a"

#VM information logging
$ss=Get-VM $a | Get-VMFolderPath

"`nVM Name : $a">>$vm_info
"VM folder location : $ss">>$vm_info
"VM storage shares level : $off_vm">>$vm_info
" ">>$vm_info

}

#Function to reset I/O

function Reset ($a)
{
$check_off=$offerings[$a]
timestamp "VM $a Storage shares will be changed from High to $check_off"
				if($check_off -eq "Low")
				{
				$x=400
				$pp="Low"
				}

				elseif($check_off -eq "Normal")
				{
				$x=600
				$pp="Normal"
				}

				elseif($check_off -eq "High")
				{
				$x=1200
				$pp="High"
				}

					##Second Reconfiguration
									$vm = Get-VM -Name $a 
									$spec = New-Object VMware.Vim.VirtualMachineConfigSpec
								    $vm.ExtensionData.Config.Hardware.Device |
									where {$_ -is [VMware.Vim.VirtualDisk]} | %{
										$dev = New-Object VMware.Vim.VirtualDeviceConfigSpec
										$dev.Operation = "edit"
										$dev.Device = $_
										$dev.Device.StorageIOAllocation.Limit = $x
										$dev.device.storageIOAllocation.shares.level  = $pp
										$spec.DeviceChange += $dev
										}

									$vm.ExtensionData.ReconfigVM_Task($spec)		
									timestamp "IOPs and Shares level in $a are set to original values - $pp"
									
									
}



#Take first eight VMs

for($i=0;$i -lt $parallel;$i++)
{
$track.add($i,$list[$i])
Reconfigure($list[$i])

$ori_path=Get-VM $list[$i] | Get-VMFolderPath
timestamp "Initial location of $($list[$i]) - $ori_path"
#Storing the location of VM before migration
[Array]$ans += $ori_path
			
			
			
			$networkAdapter = Get-NetworkAdapter -VM $list[$i]

			$VM_Network_Name = Get-NetworkAdapter -VM $list[$i] | select NetworkName -ExpandProperty NetworkName

			$pg = Get-VDPortgroup -VDSwitch "DSwitch1" -Name $VM_Network_Name
			
				#Move VM parallely
				write-host "$($list[$i]) is  moving"
				timestamp "$($list[$i]) migration started"
				$tasks[$i] =  get-vm $list[$i] | Move-VM -Datastore "Test-VSAN" -Destination $dest[$i] -NetworkAdapter $networkAdapter -PortGroup $pg -RunAsync
				timestamp "$($list[$i]) task state is $($tasks[$i].State)"
}


while(1)
{
Start-Sleep -seconds 3

	for ($i=0;$i -lt $parallel;$i++)
	{
	
	
	 #$status = Get-Task -Id $tasks[$i].State | select state -ExpandProperty state
	 $status = $tasks[$i].State
	 
		#Success
		if($status -eq "Success")
		{
		Reset($track[$i])
		timestamp "$($track[$i]) is moved to DC1"
		"$($track[$i])" >> $success
		
		$track[$i]=$list[$num]
		Reconfigure($list[$num])
		
		$ori_path=Get-VM $list[$num] | Get-VMFolderPath
		timestamp "Initial location of $($list[$num]) - $ori_path"
		#Storing the location of VM before migration
		[Array]$ans += $ori_path
		
		$networkAdapter = Get-NetworkAdapter -VM $list[$num]

			$VM_Network_Name = Get-NetworkAdapter -VM $list[$num] | select NetworkName -ExpandProperty NetworkName

			$pg = Get-VDPortgroup -VDSwitch "DSwitch1" -Name $VM_Network_Name
			
				#Move VM parallely
				write-host "$($list[$num]) =  moving"
				timestamp "$($list[$num]) migration started"
				$tasks[$i] =  get-vm $list[$num] | Move-VM -Datastore "Test-VSAN" -Destination $dest[$i] -NetworkAdapter $networkAdapter -PortGroup $pg -RunAsync
				
				$num++
		}
		
		#Failed
		elseif(($status -eq "Error") -or ($status -eq ""))
		{
		Reset($track[$i])
		timestamp "$($track[$i]) is failed to migrate"
		"$($track[$i])" >> $failed_vm
		
		$track[$i]=$list[$num]
		Reconfigure($list[$num])
		
		$ori_path=Get-VM $list[$num] | Get-VMFolderPath
		timestamp "Initial location of $($list[$num]) - $ori_path"
		#Storing the location of VM before migration
		[Array]$ans += $ori_path
		
		$networkAdapter = Get-NetworkAdapter -VM $list[$num]

			$VM_Network_Name = Get-NetworkAdapter -VM $list[$num] | select NetworkName -ExpandProperty NetworkName

			$pg = Get-VDPortgroup -VDSwitch "DSwitch1" -Name $VM_Network_Name
			
				#Move VM parallely
				write-host "$($list[$num]) =  moving"
				timestamp "$($list[$num]) migration started"
				$tasks[$i] =  get-vm $list[$num] | Move-VM -Datastore "Test-VSAN" -Destination $dest[$i] -NetworkAdapter $networkAdapter -PortGroup $pg -RunAsync
				
				$num++
		}
		
		
		if($num -eq $last)
		{
		break
		}
		
	}
	
		if($num -eq $last)
		{
		break
		}
	
}

$tasks | wait-task

for ($i=0;$i -lt $parallel;$i++)
{
Reset($track[$i])
timestamp "$($track[$i]) is moved to DC1"
"$($track[$i])" >> $success

}

#Moving the VM to correct location
$ans  | Move-VMtoFolderPath
timestamp "All VMs are moved to correct folder `n`n"
timestamp "Everything is finished"

#Final Mail

$smtpServer = "mailserver1"

$msg = new-object Net.Mail.MailMessage

$smtp = new-object Net.Mail.SmtpClient($smtpServer)

#Change according to server where the script is executed
$msg.From = "Testserver1"

$msg.To.Add("sample.mail")

$msg.Subject = "Migration of CMB VMS (Script Finished)"
$dd=Get-Date
$msg.Body = "`n`nScript Execution completed.`nScript Initiator : $vCenterUser`nScript Finished at :$dd`nExtra Information : Refer Attachments"

$msg.Attachments.Add($success)
$msg.Attachments.Add($vm_info)
$msg.Attachments.Add($failed_vm)

$smtp.Send($msg)

Write-host "Everything is finished!!!!!"


#Disconnecting from Vcenter	
Disconnect-VIServer -Server $vCenter -confirm:$false
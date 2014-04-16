
<#
.Synopsis
   This script gets the local groups of a set of servers in AD. By default, our max result size is limited to 100. 
.DESCRIPTION
    This script will get the local groups of a single server, current machine, or collection of ADComputers

    Running it without any parameters will get the Administrators group of the local machine

    To select a group of any machines by type, the ActiveDirectory Module is necessary.
    Otherwise, a single machine name can be selected, or a group of machines, please see the examples section. 

    This script requires Powershell v3 so that the -Append flag can work when outputting to CSV
.EXAMPLE
    Get-LocalGroups
.EXAMPLE
    Get-LocalGroups Server1
.EXAMPLE
    Get-LocalGroups Server1,Server2,Server3
.EXAMPLE
    Get-LocalGroups -type server
.EXAMPLE
    Get-LocalGroups -type server -resultsetsize 10 -outfile c:\servers.csv
.EXAMPLE
    Get-LocalGroups -type server -maxresultsize *
.EXAMPLE
    Get-LocalGroups -computer COMPUTER01


#>
#Requires -version 3
function global:Get-LocalGroups
{
    [CmdletBinding()]
    [OutputType([int])]
    Param
    (
        # Basic Computer Parameter. If nothing else, we can get the local groups of a single computer. It is not mandatory since we have other ways to get a list of things to grab. 
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [String[]]$ComputerName,

        # The output file. We can write to a CSV or to the pipeline, so if an outfile exists, we assume that it goes to a file, otherwise, it goes to the pipeline. 
        [Parameter(Mandatory=$false)] 
        $OutFile,

        # The Max Result size. Can be * or a number, otherwise it is 100
        [Parameter(Mandatory=$false)]
        $MaxResultSize=100,

        # Which group do we want to grab. Default is Administrators
        [Parameter(Mandatory=$false)]
        $group="Administrators",


        # The Type, can be either server or workstation
        [Parameter(Mandatory=$false)]
        [string]$type,

        [Parameter(Mandatory=$false)]
        [switch]$OverWrite,

        # We can have a custom $type and put in an ADComputer filter of our own here
        [Parameter(Mandatory=$false)]
        [string]$Filter
    )

    Begin
    {
        # Other random Vars we might use
        #$CurrentComputerName
        $ComputersToProcess = @()
        $ResultSet = @()

        # Do Checks on all the parameters to see which way we are going to run this

        # Single Computer, or collection of ADComputers, but not both.
        if (($type) -and ($ComputerName))
        {
            Write-Error "You cannot specify both an AD type and a ComputerName. Please use either the type or computername parameter, but not both"
            break
        }

        # If neither, assume local machine name
        if (-not($type) -and -not($ComputerName))
        {
            write-host "assuming local computer"
            $ComputersToProcess=@(".")
            $CurrentComputerName = $env:COMPUTERNAME
        }

        if ($ComputerName)
        {
            #we have a single computername, continue, and run the script on it
            for ($i=0; $i -lt $ComputerName.Count; $i++)
            {
                $ComputersToProcess += $ComputerName[$i]
            }
        }

        # Do we have the AD cmdlets loaded if we are doing an ADComputer type?
        if ($type)
        {
            if (($type -eq "server") -or ($type -eq "workstation") -or ($type -eq "custom")) 
            {
                if (-not(Get-Module -name ActiveDirectory))
                {
                    Write-Verbose "The ActiveDirectory Module is not loaded on this system"
                    if(Get-module -listavailable | where-object {$_.name -eq "ActiveDirectory"})
                    {
                        Write-Verbose "ActiveDirectory Module has been found...loading"
                        Import-Module -name ActiveDirectory
                    }
                    else
                    {
                        Write-Error "Cannot find and load the Active Directory Module. This switch requires the Active Directory Module to be loaded"
                        break
                    }
                }
            
                Write-Verbose "Found the ActiveDirectory Modules and they are loaded"

            }
            else
            {
                Write-error "You have selected an invalid type. Please select either 'Server', 'Workstation', or 'custom'"
                break
            }
       }

        # Do we have a max result size?
        if ($MaxResultSize -eq "*") 
        {
            Write-Warning "You have asked for an unlimited result size. This may take a long time to process."
            $choice = ""
            while ($choice -notmatch "[y|n]")
            {
                $choice = read-host "Do you want to continue? (Y/N)"
            }
            if ($choice -eq "y")
            {
                #continue
            }
            else
            {
                break
            }
        }
        elseif (($MaxResultSize -is [int]) -and ($MaxResultSize -gt 1))
        {
            #Valid Choice - continue
        }
        else
        {
            #Not a valid input
            Write-Error "You have put an invalid entry for the Max Result Size. It must be an integer and greater than 1, or '*' for all"
            break
        }

        # Do a test on the outfile to overwrite if it exists
        if (($outfile) -and -not($OverWrite))
        {
            # Check if the outfile exists, if it does, give option to clear it out. 
            if (Test-path -Path $OutFile)
            {
                Write-Host "The file specified already exists. Do you wish to overwrite it, or to quit?"
                $choice = ""
                while ($choice -notmatch "[y|n]")
                {
                    $choice = Read-Host "Press y to overwrite, n to quit"
                }
                if ($choice -eq "y")
                {
                    Remove-Item $outfile
                }
                else
                {
                    break
                }
            }
        }
    }

    Process
    {
        Write-Verbose "Beginning Processing..."

        if (($type -eq "server") -and ($MaxResultSize -is [int]))
        {
            $AllTheComputers = Get-ADComputer -ResultSetSize $MaxResultSize -Filter {OperatingSystem -Like "*server*"}
            for ($i=0; $i -lt $AllTheComputers.Count; $i++)
            {
                $ComputersToProcess += [String]$AllTheComputers[$i].Name
            }
        }
        elseif (($type -eq "server") -and ($maxresultsize -eq "*"))
        {
            $AllTheComputers = Get-ADComputer -Filter {OperatingSystem -Like "*server*"}
            for ($i=0; $i -lt $AllTheComputers.Count; $i++)
            {
                $ComputersToProcess += [String]$AllTheComputers[$i].Name
            }
        }
        elseif (($type -eq "workstation") -and ($MaxResultSize -is [int]))
        {
            $AllTheComputers = Get-ADComputer -ResultSetSize $MaxResultSize -Filter {OperatingSystem -NotLike "*server*"}
            for ($i=0; $i -lt $AllTheComputers.Count; $i++)
            {
                $ComputersToProcess += [String]$AllTheComputers[$i].Name
            }
        }
        elseif (($type -eq "workstation") -and ($MaxResultSize -eq "*"))
        {
            $AllTheComputers = Get-ADComputer -Filter {OperatingSystem -NotLike "*server*"}
            for ($i=0; $i -lt $AllTheComputers.Count; $i++)
            {
                $ComputersToProcess += [String]$AllTheComputers[$i].Name
            }
        }
        elseif (($type -eq "custom")-and ($MaxResultSize -is [int]))
        {
            $AllTheComputers = Get-ADComputer -ResultSetSize $MaxResultSize -Filter $Filter
            for ($i=0; $i -lt $AllTheComputers.Count; $i++)
            {
                $ComputersToProcess += [String]$AllTheComputers[$i].Name
            }
        }
        elseif (($type -eq "custom")-and ($MaxResultSize -eq "*"))
        {
            $AllTheComputers = Get-ADComputer -Filter $Filter
            for ($i=0; $i -lt $AllTheComputers.Count; $i++)
            {
                $ComputersToProcess += [String]$AllTheComputers[$i].Name
            }
        }
        else
        {
            break
        }

        Write-verbose "Initialization complete - Ready to start gathering group information"


        # One way or another, we should have a $ComputersToProcess that is populated with our target machines
        foreach ($computer in $ComputersToProcess)
        {
            # If we are doing own computer, we want to send the "." to the command, but display its own hostname so it should ignore whatever is in the array
            if (-not($computer -eq "."))
            {
                $CurrentComputerName = $computer
            }

            # We are ready to grab the Group Members. $CurrentComputerName has the hostname for printing, 
            #   $computer is the computer name as we will send to the function, and $group is the group we are looking for

            Write-Verbose "We are ready to get the groups of $CurrentComputerName"

            $GroupMembers = Process-Groups -ComputerName $computer -LocalGroup $group

            #TODO add in logic for printing the information

            if ($outfile)
            {
                #code for putting it into excel #TODO
                Write-Verbose "Writing information for $CurrentComputerName to file"

                #Create the array of objects in $ResultSet
                for ($i=0; $i -lt $GroupMembers.Count; $i++)
                {
                    $ObjData = @{ComputerName = $CurrentComputerName; GroupMember = $GroupMembers[$i]}
                    $tempObject = New-Object PSObject -Property $ObjData
                    Export-Csv -InputObject $tempObject -Path $outfile -append
                }
            }

            else
            {
                # Print that stuff out
                Write-Verbose "We will be printing information out to the screen"

                Write-Host "Computer: $CurrentComputerName"
                Write-Host "----------------------"
                for ($i=0; $i -lt $GroupMembers.Count; $i++)
                {
                    Write-Host $GroupMembers[$i]
                }
                Write-Host ""
            }
        }
        Write-Verbose "We have completed the information gathering and printing stage"
    }

    End
    {
        Write-Verbose "Our script has completed...exiting"
    }
}

function Process-Groups
{
    Param(
    [Parameter(Mandatory=$true)]
    [String] $ComputerName,
    [Parameter(Mandatory=$true)]
    [String] $LocalGroup
    )

    #Other Vars
    $GroupMembers = @()

    $group = [ADSI]"WinNT://$ComputerName/$LocalGroup,group"
    
    if ($group.Path)
    {
        #The group exists since it has a path property

        #Process an array with the members
        $grMem = @($group.psbase.Invoke("Members"))
        for ($i = 0; $i -lt $grMem.Count; $i++)
        {
            $GroupMembers += $grMem[$i].GetType().InvokeMember("Name",'GetProperty',$null,$grMem[$i],$null)
        }
    }
    else
    {
        #Group Does not Exist, return such info
        $GroupMembers[0] = "No Such Group"
    }

    return $GroupMembers

}


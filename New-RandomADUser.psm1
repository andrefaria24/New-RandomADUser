#Requires -Modules ActiveDirectory

# Function to generate random Active Directory users
function New-RandomADUser {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true, HelpMessage = "The domain name (e.g., contoso.com)")]
        [string]$Domain,

        [Parameter(Mandatory = $true, HelpMessage = "The organizational unit (OU) to create users in (e.g., 'OU=Users,DC=contoso,DC=com')")]
        [string]$OU,

        [Parameter(Mandatory = $false, HelpMessage = "The number of users to generate (default: 1)")]
        [int]$Count = 1,

        [Parameter(Mandatory = $false, HelpMessage = "Prefix for usernames (e.g., 'test')")]
        [string]$Prefix = ""
    )

    # Function to generate a random password
    function Get-RandomPassword {
        $passwordChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()"
        $passwordLength = 16
        $passwordCharArray = $passwordChars.ToCharArray()
        $password = -join (1..$passwordLength | ForEach-Object { $passwordCharArray | Get-Random })
        return $password
    }

    # Function to generate a random name
    function Get-RandomName {
        $firstNames = Get-Content -Path "$PSScriptRoot\files\firstnames.txt"
        $lastNames = Get-Content -Path "$PSScriptRoot\files\lastnames.txt"
        $firstName = Get-Random -InputObject $firstNames
        $lastName = Get-Random -InputObject $lastNames
        return @{ FirstName = $firstName; LastName = $lastName }
    }

    # Main loop to create users
    for ($i = 0; $i -lt $Count; $i++) {
        $randomName = Get-RandomName
        $firstName = $randomName.FirstName
        $lastName = $randomName.LastName
        $username = "$Prefix$($firstName.ToLower()).$($lastName.ToLower())"
        $userPrincipalName = "$username@$Domain"
        $password = Get-RandomPassword

        if ($PSCmdlet.ShouldProcess("$Domain\$username", "Create Active Directory User")) {
            try {
                New-ADUser -Name "$firstName $lastName" `
                           -GivenName $firstName `
                           -Surname $lastName `
                           -SamAccountName $username `
                           -UserPrincipalName $userPrincipalName `
                           -AccountPassword (ConvertTo-SecureString $password -AsPlainText -Force) `
                           -Path $OU `
                           -Enabled $true `
                           -ChangePasswordAtLogon $true `
                           -ErrorAction Stop

                Write-Verbose "Created user: $username (Password: $password)"
                Write-Output "User '$username' created successfully."
            }
            catch {
                Write-Error "Failed to create user '$username': $($_.Exception.Message)"
            }
        }
    }
}

# Export the function
Export-ModuleMember -Function New-RandomADUser
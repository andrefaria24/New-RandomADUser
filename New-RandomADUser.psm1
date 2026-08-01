#Requires -Modules ActiveDirectory

$firstNamesPath = Join-Path -Path $PSScriptRoot -ChildPath 'files\firstnames.txt'
$lastNamesPath = Join-Path -Path $PSScriptRoot -ChildPath 'files\lastnames.txt'

try {
    $script:FirstNames = @(Get-Content -LiteralPath $firstNamesPath -Encoding UTF8 -ErrorAction Stop)
    $script:LastNames = @(Get-Content -LiteralPath $lastNamesPath -Encoding UTF8 -ErrorAction Stop)
}
catch {
    throw "Failed to load the bundled name data: $($_.Exception.Message)"
}

if ($script:FirstNames.Count -eq 0 -or $script:LastNames.Count -eq 0) {
    throw 'The bundled name data must contain at least one first name and one last name.'
}

function Get-CryptographicRandomIndex {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.RandomNumberGenerator]$RandomNumberGenerator,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 256)]
        [int]$UpperBound
    )

    $randomByte = New-Object byte[] 1
    $unbiasedLimit = 256 - (256 % $UpperBound)

    do {
        $RandomNumberGenerator.GetBytes($randomByte)
    } while ([int]$randomByte[0] -ge $unbiasedLimit)

    return [int]$randomByte[0] % $UpperBound
}

function Get-RandomPassword {
    [CmdletBinding()]
    param(
        [ValidateRange(4, 256)]
        [int]$Length = 16
    )

    $characterSets = @(
        'abcdefghijklmnopqrstuvwxyz'
        'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        '0123456789'
        '!@#$%^&*()'
    )
    $allCharacters = ($characterSets -join '').ToCharArray()
    $passwordCharacters = New-Object char[] $Length
    $randomNumberGenerator = [System.Security.Cryptography.RandomNumberGenerator]::Create()

    try {
        # Add one character from every required category.
        for ($position = 0; $position -lt $characterSets.Count; $position++) {
            $characters = $characterSets[$position].ToCharArray()
            $index = Get-CryptographicRandomIndex -RandomNumberGenerator $randomNumberGenerator -UpperBound $characters.Length
            $passwordCharacters[$position] = $characters[$index]
        }

        # Fill the remaining positions from the complete character set.
        for ($position = $characterSets.Count; $position -lt $Length; $position++) {
            $index = Get-CryptographicRandomIndex -RandomNumberGenerator $randomNumberGenerator -UpperBound $allCharacters.Length
            $passwordCharacters[$position] = $allCharacters[$index]
        }

        # Shuffle so the required character categories are not in predictable positions.
        for ($position = $passwordCharacters.Length - 1; $position -gt 0; $position--) {
            $swapIndex = Get-CryptographicRandomIndex -RandomNumberGenerator $randomNumberGenerator -UpperBound ($position + 1)
            $temporaryCharacter = $passwordCharacters[$position]
            $passwordCharacters[$position] = $passwordCharacters[$swapIndex]
            $passwordCharacters[$swapIndex] = $temporaryCharacter
        }
    }
    finally {
        $randomNumberGenerator.Dispose()
    }

    return -join $passwordCharacters
}

function New-SamAccountNameCandidate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BaseName,

        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 9999)]
        [int]$CollisionIndex
    )

    $maximumLength = 20
    $suffix = if ($CollisionIndex -eq 0) {
        ''
    }
    else {
        $CollisionIndex.ToString([System.Globalization.CultureInfo]::InvariantCulture)
    }
    $maximumBaseLength = $maximumLength - $suffix.Length

    if ($BaseName.Length -gt $maximumBaseLength) {
        $BaseName = $BaseName.Substring(0, $maximumBaseLength)
    }

    return "$BaseName$suffix"
}

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

    # Function to generate a random name
    function Get-RandomName {
        $firstName = Get-Random -InputObject $script:FirstNames
        $lastName = Get-Random -InputObject $script:LastNames
        return @{ FirstName = $firstName; LastName = $lastName }
    }

    $reservedUsernames = New-Object 'System.Collections.Generic.HashSet[string]'

    # Main loop to create users
    for ($i = 0; $i -lt $Count; $i++) {
        $randomName = Get-RandomName
        $firstName = $randomName.FirstName
        $lastName = $randomName.LastName
        $baseUsername = "$Prefix$firstName.$lastName".ToLowerInvariant()
        $password = Get-RandomPassword
        $collisionIndex = 0
        $attemptCompleted = $false

        while ($collisionIndex -le 9999) {
            $username = New-SamAccountNameCandidate -BaseName $baseUsername -CollisionIndex $collisionIndex
            $normalizedUsername = $username.ToLowerInvariant()

            if ($reservedUsernames.Contains($normalizedUsername)) {
                $collisionIndex++
                continue
            }

            $userPrincipalName = "$username@$Domain"
            $commonName = if ($collisionIndex -eq 0) {
                "$firstName $lastName"
            }
            else {
                "$firstName $lastName $collisionIndex"
            }

            if (-not $PSCmdlet.ShouldProcess("$Domain\$username", "Create Active Directory User")) {
                $attemptCompleted = $true
                break
            }

            try {
                New-ADUser -Name $commonName `
                           -GivenName $firstName `
                           -Surname $lastName `
                           -SamAccountName $username `
                           -UserPrincipalName $userPrincipalName `
                           -AccountPassword (ConvertTo-SecureString $password -AsPlainText -Force) `
                           -Path $OU `
                           -Enabled $true `
                           -ChangePasswordAtLogon $true `
                           -ErrorAction Stop

                [void]$reservedUsernames.Add($normalizedUsername)
                Write-Verbose "Created user: $username"
                Write-Output "User '$username' created successfully."
                $attemptCompleted = $true
                break
            }
            catch {
                if ($_.Exception -is [Microsoft.ActiveDirectory.Management.ADIdentityAlreadyExistsException] -or
                    $_.CategoryInfo.Category -eq [System.Management.Automation.ErrorCategory]::ResourceExists) {
                    [void]$reservedUsernames.Add($normalizedUsername)
                    Write-Verbose "Username '$username' already exists. Retrying with a numeric suffix."
                    $collisionIndex++
                    continue
                }

                Write-Error "Failed to create user '$username': $($_.Exception.Message)" -ErrorAction Stop
            }
        }

        if (-not $attemptCompleted) {
            throw "Unable to create a unique username for '$firstName $lastName' after 10,000 attempts."
        }
    }
}

# Export the function
Export-ModuleMember -Function New-RandomADUser

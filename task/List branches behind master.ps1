#-----------------------------------------------------#
#                      Variables                      #
#-----------------------------------------------------#

[String]$Project = "$env:SYSTEM_TEAMPROJECT"

[String]$OrgUri = "$env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI"

[String]$Repo = "$env:BUILD_REPOSITORY_NAME"

[String]$BaseApiUrl = "${OrgUri}${Project}/_apis/git/repositories/${Repo}";

[String]$ApiVersion = "api-version=$env:API_VERSION"

$Headers = @{ Authorization = "Bearer $env:SYSTEM_ACCESSTOKEN" }

#-----------------------------------------------------#
#                Branches behind Master               #
#-----------------------------------------------------#

$featureBranchesUrl = "${BaseApiUrl}/stats/branches?${ApiVersion}"

$featureBranchesResponse = Invoke-RestMethod -Uri $featureBranchesUrl `
                            -Headers $Headers `
                            -Method Get

# Filter out the behind data of FEATURE branches
[array]$behindBranches = $featureBranchesResponse.value | Where-Object {$_.name.StartsWith("FEATURE/") -and $_.behindCount -gt 0}

Write-Host "========================== Feature branches behind master : $($behindBranches.Count) =========================="
$behindBranches | Format-Table -Property name,behindCount,aheadCount

$behindBranchesNamesList = $behindBranches.name -join ";"
Write-Output "##vso[task.setvariable variable=behindMaster;isOutput=true]$behindBranchesNamesList"
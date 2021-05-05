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
#               Abandon conflicting PRs               #
#-----------------------------------------------------#
[String]$pullRequestId = "$env:PULLREQUESTID"
[array]$createdPRs = @($pullRequestId)

if($pullRequestId.Contains(';')) {
    $createdPRs = $pullRequestId.Split(';')
}

[array]$conflictingPRs = @()

foreach($PRId in $createdPRs) {
    $PRUrl = "${BaseApiUrl}/pullRequests/${PRId}?${ApiVersion}"
    $getPRResponse = Invoke-RestMethod -Uri $PRUrl `
                        -Headers $Headers `
                        -Method Get
    
    if ($getPRResponse.mergeStatus -eq "conflicts") {
        $conflictingPRs += $getPRResponse
    }
}

Write-Host "========================== Detected $($conflictingPRs.Count) PR(s) with merge conflicts. =========================="

if ($conflictingPRs.Count -eq 0) {
    Write-Host "Job done."
    exit 0
}

Write-Host "Abandonning PRs..." -NoNewline

foreach($PR in $conflictingPRs) {
    $PRUrl = "${BaseApiUrl}/pullRequests/$($PR.pullRequestId)?${ApiVersion}"

    $abandonPRBody = ConvertTo-Json @{
        status = "abandoned";
    }

    $abandonPRBody = Invoke-RestMethod -Uri $PRUrl `
                        -Body $abandonPRBody `
                        -ContentType "application/json" `
                        -Headers $Headers `
                        -Method Patch
}

Write-Host "Success"

#-----------------------------------------------------#
#              Create dedicated branches              #
#-----------------------------------------------------#

foreach($PR in $conflictingPRs) {
    # Create a new branch
    $refreshBranchName = "refs/heads/REFRESH-FEATURE/$($PR.targetRefName.TrimStart('refs/heads/FEATURE/'))"

    $refreshBranchUrl = "${BaseApiUrl}/refs?${ApiVersion}"
    $refreshBranchBody = ConvertTo-Json @(@{
        name = $refreshBranchName
        newObjectId = $PR.lastMergeTargetCommit.commitId
        oldObjectId = "0000000000000000000000000000000000000000"
    })

    Write-Host "Creating branch ${refreshBranchName}..." -NoNewline

    $refreshBranchResponse = Invoke-RestMethod -Uri $refreshBranchUrl `
                                -Body $refreshBranchBody `
                                -ContentType "application/json" `
                                -Headers $Headers `
                                -Method Post

    Write-Host $(If ($refreshBranchResponse.value.success) {"Success"} Else {"Failed ($($refreshBranchResponse.value.updateStatus))"})
}
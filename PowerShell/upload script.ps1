﻿### SCRIPT TO UPLOAD FILETO AZURE DLS.
param(
    [Parameter(Mandatory=$false)]
    [String] $logsDirectory = "PATH\TO\LogFile", ## ADD LOG PATH
    [Parameter(Mandatory=$true)]
    [String] $encryptedKeyFilePath,  ##PATH TO FILE WITH KEY GENERATED IN A PREVIOUS STEP (SEE CREATE KEY.PS1)
    [Parameter(Mandatory=$false)]
    [String] $tenantID ,             ## tenant
    [Parameter(Mandatory=$true)]
    [String] $azureServicePrincipalAppId,                        ## Principal Service Application ID
    [Parameter(Mandatory=$true)]
    [String] $sourceFileDir,            #source directory for file to be copies
    [Parameter(Mandatory=$true)]
    [String] $sourceFileNamePattern,    # pathern in case of file with variable
    [Parameter(Mandatory=$true)]
    [String] $targetFileDir,            #target directory (in ADLS, or ABS)
    [Parameter(Mandatory=$true)]
    [String]$dataLakeStoreName
)

################################################################################################    log file  #################################################################################


Function LogWrite
{
   Param ([string]$logstring)

   $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")

   $Line = "$Stamp $logstring"

   Add-content $Logfile -value $Line
}
###############################################################################################################################################################################################

#####################################################################################   Copy and Delete Functions  ############################################################################


Function CopyFileToADLS
{
    param ([string] $SourceFile,[string]  $DestinationFile)

    ## insert the new file.
    LogWrite "Moving file $SourceFile to $DestinationFile"
    try
    {
        Import-AzureRmDataLakeStoreItem -Account $dataLakeStoreName -Destination $DestinationFile -Path $SourceFile
    }
    catch
    {
        $ErrorMessage = $_.Exception.Message
        LogWrite  $ErrorMessage
        throw $_
        exit

    }

    LogWrite "File $SourceFile moved to $DestinationFile"

}


Function DeleteFromOnPrem
{
    param ([string] $SourceFile)

    ## deleting the source file
    LogWrite "Deleting file $SourceFile"
    try
    {
    Remove-Item -Path $SourceFile -Force
    }
    catch
    {
        $ErrorMessage = $_.Exception.Message
        LogWrite  $ErrorMessage
        throw $_
        exit
    }
    LogWrite "$SourceFile deleted"


}
###############################################################################################################################################################################################

Set-StrictMode -Version 3

## log start date
$start_script=get-date;
$logSuffix=get-date -format yyyymmddhhmmss
$Logfile = Join-Path -Path $logsDirectory -ChildPath "UploadDataToDls_$logSuffix.log"

## authentication to Azure
try
{
    ## Principal Service credentials:
    $pwdTxt = Get-Content $encryptedKeyFilePath  ##this key is generated by a separate one time script
    $SecurePassword = $pwdTxt | ConvertTo-SecureString

    $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $azureServicePrincipalAppId, $SecurePassword
    $credential = Login-AzureRmAccount   -Credential $cred -TenantId $TenantID -ServicePrincipal ##-outvariable AzureRmAccount
}
catch
{
    $ErrorMessage = $_.Exception.Message
    LogWrite  $ErrorMessage
    throw $_
}


## log authentication
LogWrite "Authenticating as "
LogWRite ($credential.Context | Out-String)
LogWrite "Target Data Lake Store: $dataLakeStoreName"


Get-ChildItem $sourceFileDir -Filter $sourceFileNamePattern |
Foreach-Object {
    $sourceFilePath = $_.FullName
    $targetFileName = $_.Name
   
    #echo "Uploading $_.FullName"

    ## Check if the source file exists
    if(-NOT (Test-Path -Path $sourceFilePath))
    {
        LogWrite "ERROR. $sourceFilePath doesn't exist "
        exit
    }


    #check if the folder to which the file is to be moved exists. If not, it will be created.
    Get-AzureRmDataLakeStoreItem -AccountName $dataLakeStoreName -Path $targetFileDir -ev notexists -ea 0 | Out-Null

    # Create new folder, if it doesn't exist
    if($notexists)
    {
        LogWrite "creating new folder: $targetFileDir"
        try
        {
            New-AzureRmDataLakeStoreItem -Folder -AccountName $dataLakeStoreName -Path $targetFileDir -ErrorAction Stop
        }
        catch
        {
            $ErrorMessage = $_.Exception.Message
            LogWrite  $ErrorMessage
            throw $_

        }

    }
    else
    {
        LogWrite "Folder: $targetFileDir exists. Skipping folder creation"
    }


    $targetFilePath = Join-Path -Path $targetFileDir -ChildPath $targetFileName
    #check if the file to be moved is already in the target folder. If yes, it will a
    Get-AzureRmDataLakeStoreItem -AccountName $dataLakeStoreName -Path $targetFilePath -ev notexists -ea 0 | Out-Null


    # Move the file, if it doesn't already exist
    if($notexists)
    {
        $start_import=get-date;
        CopyFileToADLS $sourceFilePath $targetFilePath
        $end_import=get-date;
        DeleteFromOnPrem $sourceFilePath
    }
    else
    {
        ## delete the file already in the ADLS folder
        LogWrite "File $targetFilePath already EXISTS. Deleting it"
        try
        {
            Remove-AzureRmDataLakeStoreItem -Account $dataLakeStoreName -Path $targetFilePath -force
        }
        catch
        {
            $ErrorMessage = $_.Exception.Message
            LogWrite  $ErrorMessage
            throw $_
            exit

        }
        LogWrite "File $targetFilePath deleted"

        $start_import=get-date;
        CopyFileToADLS $sourceFilePath $targetFilePath
        $end_import=get-date;

        DeleteFromOnPrem $sourceFilePath

    }
    if(!$end_import) {
        $Load_time = ($end_import-$start_import)
        LogWrite "Total load time as $Load_time"
    }
   
}


## logging time

$end_script=get-date;
$script_time = ($end_script-$start_script)


LogWrite "Total script time as $script_time"


## error handling
## need to log what errors
## need to exit if an error occurss




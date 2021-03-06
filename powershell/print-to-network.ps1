# TODO Needs better error logging, does not work within ScriptBlock
# TODO Need to check if Printto verb actually exists

# Prints the file located in a directory structure such as **/PrintServerName/PrinterName/printme.pdf

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true,Position=0)]
    [string]
    $FilePath=30,

    [switch]
    $Remove
    )

Function New-PrintObject ($Path) {
  $pathParts = $Path.Split('\')[-2..-3]

  New-Object PsObject -Property @{
    Server = $pathParts[1];
    Printer = $pathParts[0];
    File = $Path}
}

$printDoc = {
    Param ([String] $File, [String] $Printer, [bool] $RemoveFileOnSuccess)

    $logName = "$(Split-Path $File)\$((Get-Item $File).BaseName)"
    $stdErrLog = "$logName.err"
    $stdOutLog = "$lofName.log"
    try
    {
        $proc = Start-Process -FilePath $File -Verb Printto -PassThru -ArgumentList $Printer
        $timeouted = $null
        Write-Host $Remove
        $proc | Wait-Process -Timeout 60 -ErrorAction SilentlyContinue -ErrorVariable timeouted

        if ($timeouted)
        {
          # terminate the process
          $proc | Stop-Process
        }

        if ($proc.ExitCode -ne 0)
        {
          "Exit code was: $($proc.ExitCode)" | Out-File $stdErrLog
        }
        elseif ($RemoveFileOnSuccess)
        {
          try
          {

            Remove-Item -Path $File
          }
          catch
          {
            $_ | Out-File $stdErrLog
          }
        }
    }
    catch
    {
        $_ | Out-File $stdErrLog
    }
}

# Must cast this or else the array will default to a string[]
try {
  $printObjs = @()
  $printObjs += get-childitem -Path $FilePath -Recurse -File -ErrorAction Stop |  ForEach-Object { New-PrintObject $_.FullName }
}
catch {
  Throw "Path does not exist: $FilePath"
}

[System.Management.Automation.Job[]]$jobs = @()

foreach($printObj in $printObjs)
{
  $targetPrinter = '"\\{0}\{1}"' -f $printObj.Server,$printObj.Printer

  $jobs += Start-Job -Name "Printing $($printObj.File)" -ScriptBlock $printDoc -ArgumentList $printObj.File, $targetPrinter, $Remove
}

if ($jobs.length) {
  Wait-Job -Job $jobs | Remove-Job
}

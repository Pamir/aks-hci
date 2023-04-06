# Define the path to the private key file
$privateKeyFile = "V:\AKS-HCI\WorkingDir\.ssh\akshci_rsa"


# Define the local file path and remote file path
$localFilePath = "C:\dev\projects\citi\fabrikam.crt"
$remoteFilePath = "C:\Windows\fabrikam.crt"
$certificateStoreLocation = "Cert:\LocalMachine\Root"

$labelSelector = "beta.kubernetes.io/os=windows"

$nodeIps = kubectl get nodes  -l $labelSelector -o wide | Where-Object { $_ -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' } | ForEach-Object { $_.Split([char[]]@(" "), [System.StringSplitOptions]::RemoveEmptyEntries)[5] }

# Copy the local file to each Windows node using scp and write the output to the console
foreach ($ip in $nodeIps) {
    $copyFileCommand = "scp -i `"$privateKeyFile`" -o StrictHostKeyChecking=no `"$localFilePath`" administrator@$ip`:`"$remoteFilePath`""
    $output = Invoke-Expression $copyFileCommand
    Write-Output "File copied to $ip `n$output"

    $importCertificateCommand = "Import-Certificate -FilePath $remoteFilePath -CertStoreLocation $certificateStoreLocation"
    $output =  & ssh -i $privateKeyFile -o StrictHostKeyChecking=no administrator@$ip  powershell -command `"$importCertificateCommand`"
    Write-Output $output
}

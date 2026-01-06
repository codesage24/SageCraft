$source = $PSScriptRoot
$target = "C:\Program Files\Ascension Launcher\resources\client\Interface\AddOns\SageCraft"

$allowedExtensions = @( ".toc", ".lua", ".xml" )

Remove-Item $target -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $target | Out-Null

Get-ChildItem $source -Recurse -File | 
    Where-Object { $allowedExtensions -contains $_.Extension.ToLower() } |
    ForEach-Object {
        $dest = $_.FullName.Replace($source, $target)
        New-Item -ItemType Directory -Path (Split-Path $dest) -Force | Out-Null
        Copy-Item $_.FullName $dest -Force
    }

Write-Host "SageCraft AddOn deployed..."

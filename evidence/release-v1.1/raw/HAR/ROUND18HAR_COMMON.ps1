$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$Pkg=$PSScriptRoot;$Root=Split-Path -Parent $Pkg
$Expected='EC4C359BFC4D68E866A09520F790955B26C7725D203E262F36662D0A3073EF27'
$Previous='2E0E0FB0C73844512B97B0C4D26EBD8EFEE297950CE8A754E8C1C9737E194480'
$PhysicalLog='E8D3AA7AE5DFF73DE161335731A5FCA9C1D7D141EC833C0986500842101153DA'
$Serial='03036621022521015400'
$ModelHash='1D0E9419EC4E12AEF73CCF4FFD122703E94C48344A96BC7C5F0F2772C2152CE3'
$SourceMap=@(
 @('kernel_src_gpu_round18haq_lmh.rs','kernel\src\gpu\round18haq_lmh.rs'),
 @('kernel_src_gpu_round18haq_proj.rs','kernel\src\gpu\round18haq_proj.rs'),
 @('kernel_src_gpu_round18hap.rs','kernel\src\gpu\round18hap.rs'),
 @('kernel_src_gpu_round18haq.rs','kernel\src\gpu\round18haq.rs'),
 @('kernel_src_gpu_round18hao.rs','kernel\src\gpu\round18hao.rs'),
 @('kernel_src_gpu_round18han.rs','kernel\src\gpu\round18han.rs'),
 @('kernel_src_gpu_round18ham.rs','kernel\src\gpu\round18ham.rs'),
 @('kernel_src_gpu_intel.rs','kernel\src\gpu\intel.rs'),
 @('kernel_src_gpu_round18haj.rs','kernel\src\gpu\round18haj.rs'),
 @('kernel_src_ml_router.rs','kernel\src\ml\router.rs'),
 @('kernel_src_ml_attention.rs','kernel\src\ml\attention.rs'),
 @('kernel_src_ml_transformer.rs','kernel\src\ml\transformer.rs'),
 @('kernel_src_ml_inference.rs','kernel\src\ml\inference.rs'),
 @('kernel_src_ml_tokenizer.rs','kernel\src\ml\tokenizer.rs'),
 @('kernel_src_main.rs','kernel\src\main.rs'),
 @('kernel_src_amp.rs','kernel\src\amp.rs')
)
function Sha([string]$p){(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash}
function Flush([string]$p){
 $s=[IO.File]::Open($p,'Open','ReadWrite','Read');try{$s.Flush($true)}finally{$s.Dispose()}
}
function PinnedUsb(){
 $disks=@(Get-Disk|Where-Object{$_.SerialNumber -and $_.SerialNumber.Trim() -eq $Serial -and $_.BusType -eq 'USB'})
 if($disks.Count -ne 1){throw 'Pinned USB absent/ambiguous'}
 $parts=@(Get-Partition -DiskNumber $disks[0].Number|Where-Object DriveLetter)
 if($parts.Count -ne 1){throw 'USB mount ambiguous'}
 $v=$parts[0]|Get-Volume
 if($v.FileSystem -ne 'FAT32' -or $v.HealthStatus -ne 'Healthy'){throw 'USB filesystem is not healthy FAT32'}
 "$($parts[0].DriveLetter):\"
}
function UnderUsb([string]$usb,[string]$relative){
 $prefix=[IO.Path]::GetFullPath($usb).TrimEnd('\')+'\'
 $path=[IO.Path]::GetFullPath((Join-Path $prefix $relative))
 if(-not $path.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe USB path'}
 $path
}
function DeployImage([string]$image,[string]$hash,[string]$usb){
 if((Sha $image) -ne $hash){throw 'Source image hash mismatch'}
 $kernel=UnderUsb $usb 'boot\kernel';$old=Sha $kernel
 if($old -notin @($Previous,$Expected)){throw 'Unrecognized current USB kernel'}
 $backupDir=UnderUsb $usb 'boot\rollback\ROUND18HAR'
 New-Item -ItemType Directory -Path $backupDir -Force|Out-Null
 $backup=UnderUsb $usb ("boot\rollback\ROUND18HAR\pre_"+$old+'.kernel')
 if(Test-Path $backup){if((Sha $backup) -ne $old){throw 'Existing backup mismatch'}}
 else{Copy-Item -LiteralPath $kernel -Destination $backup}
 Flush $backup;if((Sha $backup) -ne $old){throw 'Backup readback failed'}
 $temp=UnderUsb $usb 'boot\kernel.round18har.tmp'
 $swap=UnderUsb $usb 'boot\kernel.round18har.swap'
 if((Test-Path $temp) -or (Test-Path $swap)){throw 'Existing staging files require inspection'}
 Copy-Item -LiteralPath $image -Destination $temp
 Flush $temp;if((Sha $temp) -ne $hash){throw 'Staged image mismatch'}
 Move-Item -LiteralPath $kernel -Destination $swap
 try{
  Move-Item -LiteralPath $temp -Destination $kernel
  Flush $kernel;if((Sha $kernel) -ne $hash){throw 'USB final readback mismatch'}
  Remove-Item -LiteralPath $swap
 }catch{
  if(Test-Path $kernel){Remove-Item -LiteralPath $kernel}
  if(Test-Path $swap){Move-Item -LiteralPath $swap -Destination $kernel};throw
 }
}

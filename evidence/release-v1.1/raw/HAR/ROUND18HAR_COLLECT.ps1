[CmdletBinding()]
param([string]$LogPath='E:\AETHLOG.TXT',[int]$BootIndex=1,[switch]$Finalize,
      [string]$OutputDirectory='')
if(-not $OutputDirectory){$OutputDirectory=Join-Path $PSScriptRoot 'hardware'}
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$raw=[IO.File]::ReadAllText($LogPath).Replace([string][char]0,'') -replace '\r?\n\[LOG-CONT\] ',''
$start=$raw.LastIndexOf('ROUND18HAR Projection steady qualification revision=1')
if($start -lt 0){throw 'Missing exact HAR boot marker (stale log)'}
$raw=$raw.Substring($start);$issues=[Collections.Generic.List[string]]::new()
function Rows([string]$tag){@([regex]::Matches($raw,'(?m)^\['+[regex]::Escape($tag)+'\].*$')|ForEach-Object Value)}
function Field([string]$line,[string]$name){
 $m=[regex]::Match($line,'(?:^| )'+[regex]::Escape($name)+'=(\S+)')
 if($m.Success){$m.Groups[1].Value}else{''}
}
function N([string]$line,[string]$name){
 $v=0.0
 if(-not [double]::TryParse((Field $line $name),[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$v) -or
    [double]::IsNaN($v) -or [double]::IsInfinity($v) -or $v -lt 0){
    $issues.Add("INVALID_NUMBER:$name");return -1.0
 };$v
}
function Require([string]$line,[string]$name,[string]$value){
 if((Field $line $name) -ne $value){$issues.Add("INVARIANT:$name expected=$value")}
}
function Index([object[]]$lines,[string]$tag){
 $m=@{}
 foreach($line in $lines){
  $id=N $line 'request'
  if($id -lt 1 -or $id -ne [Math]::Floor($id)){$issues.Add("BAD_ID:$tag");continue}
  if($m.ContainsKey([int]$id)){$issues.Add("DUPLICATE:$tag/$id")}else{$m[[int]$id]=$line}
 };return ,$m
}
$e=Index @(Rows 'E2E-DECODE') 'E2E'
$o=Index @(Rows 'BASELINE-DH-OPERATORS'|Where-Object{(Field $_ 'phase') -eq 'DECODE'}) 'OP'
$l=Index @(Rows 'GPU-HAI-LIVE-WINDOW') 'LIVE'
$a=Index @(Rows 'ATTN-HAI-WINDOW') 'ATTN'
$m=Index @(Rows 'GPU-HAJ-MAINT-WINDOW') 'MAINT'
$p=Index @(Rows 'GPU-HAJ-FFN-PHASE'|Where-Object{(Field $_ 'phase') -eq 'DECODE'}) 'FFN'
$ipc=Index @(Rows 'IPC-HAJ-WINDOW') 'IPC'
$b=Index @(Rows 'BASELINE-DH-BYTES') 'BYTES'
$ttft=Index @(Rows 'E2E-TTFT') 'TTFT'
$ham=Index @(Rows 'GPU-HAM-WINDOW') 'HAM'
$han=Index @(Rows 'GPU-HAN-WINDOW') 'HAN'
$hao=Index @(Rows 'GPU-HAO-WINDOW') 'HAO'
$hap=Index @(Rows 'GPU-HAP-WINDOW') 'HAP'
$haq=Index @(Rows 'GPU-HAQ-WINDOW') 'HAQ'
$lmh=Index @(Rows 'GPU-HAQ-LMH-WINDOW') 'HAR_LMH'
$fz=Index @(Rows 'FZ-ENGINE') 'FZ'
$complete=$true;$metrics=[Collections.Generic.List[object]]::new()
foreach($id in 1..8){if(-not $e.ContainsKey($id)){$complete=$false;$issues.Add("MISSING_REQUEST:$id")}}
foreach($id in @($e.Keys|Sort-Object)){
 $joined=$true
 foreach($map in @($o,$l,$a,$m,$p,$ipc,$b,$ttft,$ham,$han,$hao,$hap,$haq,$lmh,$fz)){
  if(-not $map.ContainsKey($id)){$joined=$false;$complete=$false;$issues.Add("MISSING_JOIN:$id")}
 }
 if(-not $joined){continue}
 $tokens=N $e[$id] 'tokens';$forwards=N $b[$id] 'decode_forwards'
 if($tokens -le 0 -or $tokens -ne (N $o[$id] 'tokens')){$issues.Add("TOKEN_COUNT:$id")}
 if($forwards -ne $tokens-1){$issues.Add("TERMINAL_FORWARD_COUNT:$id")}
 if((N $p[$id] 'calls') -ne 16*$forwards -or (N $a[$id] 'decode_calls') -ne 16*$forwards){$issues.Add("PHASE_CALLS:$id")}
 if((N $p[$id] 'q6_calls') -ne 8*$forwards){$issues.Add("FAMILY_CALLS:$id")}
 $attempts=N $l[$id] 'attempts'
 if($attempts -le 0){$issues.Add("NO_LIVE:$id")}
 foreach($field in @('published','atomic_submissions','completed_fences')){
  if((N $l[$id] $field) -ne $attempts){$issues.Add("PRODUCTION_COUNTS:$id/$field")}
 }
 foreach($field in @('attempt_mask','published_mask')){Require $l[$id] $field '0xffff'}
 Require $l[$id] 'fallback_mask' '0x0';Require $l[$id] 'gate_up_invalid' '0'
 Require $l[$id] 'q6_samples' '0';Require $l[$id] 'q6_promoted' '0'
 Require $a[$id] 'exact_mask' '0xf';Require $a[$id] 'failures' '0';Require $a[$id] 'disabled' '0'
 Require $m[$id] 'failures' '0';Require $m[$id] 'disabled' '0'
 foreach($ri in 1..([Math]::Min($id,4))){Require $m[$id] "mask$ri" '0xffff'}
 Require $ipc[$id] 'failed' '0';Require $ipc[$id] 'success' '1'
 if((N $ipc[$id] 'expected_bytes') -le 0 -or (N $ipc[$id] 'expected_bytes') -ne (N $ipc[$id] 'enqueued_bytes')){$issues.Add("IPC_BYTES:$id")}
 foreach($f in @('precode_tsc','prep_tsc','submit_tsc','fence_tsc','readback_tsc','posthash_tsc','restore_tsc')){
  if((N $p[$id] $f) -le 0 -and $forwards -gt 0){$issues.Add("MISSING_PHASE_TIME:$id/$f")}
 }
 if($id -ge 4){Require $l[$id] 'gate_up_samples' '4';Require $l[$id] 'gate_up_exact' '4'}
 $metrics.Add([pscustomobject]@{request=$id;tokens=$tokens;tps=(N $e[$id] 'e2e_tps');
  ffn=(N $o[$id] 'ffn_per_token');attention=(N $o[$id] 'attention_per_token');lmh=(N $o[$id] 'lm_head_per_token');
  ttft_us=(N $ttft[$id] 'total_ttft_us');tokenize_us=(N $ttft[$id] 'tokenize_us');
  readset_calls=(N $p[$id] 'readset_calls');compact_preflush_calls=(N $p[$id] 'compact_preflush_calls')})
 if((N $p[$id] 'readset_calls') -ne (N $p[$id] 'calls')){$issues.Add("HAK_BASELINE_LOST:$id")}
 if((N $p[$id] 'compact_preflush_calls') -gt (N $p[$id] 'calls')){$issues.Add("PREFLUSH_COUNT:$id")}
}
foreach($map in @($o,$l,$a,$m,$p,$ipc,$b,$ttft,$ham,$han,$hao,$hap,$haq,$lmh,$fz)){
 foreach($id in $map.Keys){if(-not $e.ContainsKey($id)){$complete=$false;$issues.Add("UNFINISHED_REQUEST:$id")}}
}
$pairKeys=@{}
foreach($line in @(Rows 'GPU-HAJ-MAINT-PAIR')){
 $id=N $line 'request';$layer=N $line 'layer';$key="$id/$layer"
 if($pairKeys.ContainsKey($key)){$issues.Add("DUPLICATE_PAIR:$key")}
 $pairKeys[$key]=$line
 if($id -lt 1 -or $id -gt 4 -or $layer -lt 0 -or $layer -gt 15 -or $layer -ne [Math]::Floor($layer)){$issues.Add("BAD_PAIR_KEY:$key")}
 Require $line 'transport_clean' '1';Require $line 'bitwise' '1';Require $line 'publish' '0'
 Require $line 'init_policy' 'DENSE_PLUS_GUARDS';Require $line 'candidate_padding' '0xff';Require $line 'preflush' 'DENSE_PLUS_GUARDS';Require $line 'baseline' 'HAK'
 foreach($f in @('control_readback_tsc','candidate_readback_tsc','control_total_tsc','candidate_total_tsc')){
  if((N $line $f) -le 0){$issues.Add("PAIR_TIME:$key")}
 }
}
foreach($id in 1..4){foreach($layer in 0..15){if(-not $pairKeys.ContainsKey("$id/$layer")){$issues.Add("MISSING_PAIR:$id/$layer")}}}
$preKeys=@{}
foreach($line in @(Rows 'GPU-HAL-PREFLUSH-PAIR')){
 $id=N $line 'request';$layer=N $line 'layer';$key="$id/$layer"
 if($preKeys.ContainsKey($key)){$issues.Add("DUPLICATE_PREFLUSH_PAIR:$key")};$preKeys[$key]=$true
 if(-not $pairKeys.ContainsKey($key)){$issues.Add("UNJOINED_PREFLUSH_PAIR:$key");continue}
 Require $line 'control_preflush_lines' '6144';Require $line 'candidate_preflush_lines' '1539'
 Require $line 'seed_visibility' 'FULL_FLUSH_BEFORE_DENSE_INIT';Require $line 'timing' 'EXCLUDES_MEASURED_SHADOW_SEED'
 $seed=N $line 'candidate_poison_seed_tsc';$rawCandidate=N $line 'candidate_raw_total_tsc'
 if($seed -le 0 -or $seed -ge $rawCandidate){$issues.Add("PREFLUSH_SEED:$key")}
 if($rawCandidate-$seed -ne (N $pairKeys[$key] 'candidate_total_tsc') -or
    (N $line 'control_raw_total_tsc') -ne (N $pairKeys[$key] 'control_total_tsc')){$issues.Add("PREFLUSH_ADJUSTMENT:$key")}
 foreach($f in @('control_prep_adjusted_tsc','candidate_prep_adjusted_tsc')){
  if((N $line $f) -le 0){$issues.Add("PREFLUSH_PREP:$key")}
 }
}
foreach($key in $pairKeys.Keys){if(-not $preKeys.ContainsKey($key)){$issues.Add("MISSING_PREFLUSH_PAIR:$key")}}
$gtKeys=@{}
foreach($line in @(Rows 'GPU-HAJ-GT-PAIR')){
 $id=N $line 'request';$layer=N $line 'layer';$key="$id/$layer"
 if($gtKeys.ContainsKey($key)){$issues.Add("DUPLICATE_GT_PAIR:$key")}
 $gtKeys[$key]=$true
 if(-not $pairKeys.ContainsKey($key)){$issues.Add("UNJOINED_GT_PAIR:$key")}
 Require $line 'valid' '1';Require $line 'production_timestamps' '0'
 foreach($arm in @('control','candidate')){foreach($stage in @('gate_up','swiglu','down')){
  if((N $line ($arm+'_'+$stage+'_ticks')) -le 0){$issues.Add("GT_PAIR_TIME:$key")}
 }}
}
foreach($key in $pairKeys.Keys){if(-not $gtKeys.ContainsKey($key)){$issues.Add("MISSING_GT_PAIR:$key")}}
$hamPairs=@{};$hamBegin=@{}
foreach($line in @(Rows 'GPU-HAM-BEGIN')){
 $id=N $line 'request';$layer=N $line 'layer';$key="$id/$layer"
 if($hamBegin.ContainsKey($key)){$issues.Add("HAM_DUPLICATE_BEGIN:$key")};$hamBegin[$key]=$line
 Require $line 'candidate_first' ([string][int](($id+$layer)%2 -eq 0))
 Require $line 'capture' 'ALL_INTERMEDIATES';Require $line 'shadow_only' '1'
}
foreach($line in @(Rows 'GPU-HAM-PAIR')){
 $id=N $line 'request';$layer=N $line 'layer';$key="$id/$layer"
 if($hamPairs.ContainsKey($key)){$issues.Add("HAM_DUPLICATE_PAIR:$key")};$hamPairs[$key]=$line
 if($id -lt 1 -or $id -gt 4 -or $id -ne [Math]::Floor($id) -or $layer -lt 0 -or $layer -gt 15 -or $layer -ne [Math]::Floor($layer)){$issues.Add("HAM_BAD_KEY:$key")}
 if(-not $hamBegin.ContainsKey($key)){$issues.Add("HAM_MISSING_BEGIN:$key")}
 foreach($f in @('transport_clean','bitwise','gt_valid')){Require $line $f '1'}
 Require $line 'candidate_publish' '0';Require $line 'compared_values' '26624';Require $line 'disabled' '0'
 if((Field $line 'q6') -notin @('0','1')){$issues.Add("HAM_BAD_FAMILY:$key")}
 foreach($arm in @('control','candidate')){foreach($stage in @('gate_up_ticks','swiglu_ticks','down_ticks','graph_tsc')){
  if((N $line ($arm+'_'+$stage)) -le 0){$issues.Add("HAM_PAIR_TIME:$key")}
 }}
}
foreach($id in 1..4){
 foreach($layer in 0..15){if(-not $hamPairs.ContainsKey("$id/$layer")){$issues.Add("HAM_MISSING_PAIR:$id/$layer")}}
 $family=@($hamPairs.Values|Where-Object{(Field $_ 'request') -eq [string]$id -and (Field $_ 'q6') -eq '1'})
 if($family.Count -ne 8){$issues.Add("HAM_FAMILY_CENSUS:$id")}
}
foreach($key in $hamBegin.Keys){if(-not $hamPairs.ContainsKey($key)){$issues.Add("HAM_UNFINISHED_PAIR:$key")}}
$hamCode=@(Rows 'GPU-HAM-CODE')
if($hamCode.Count -ne 1){$issues.Add('HAM_CODE_INSTALL_COUNT')}else{
 foreach($kv in @(@('action','INSTALL'),@('bytes','17008'),@('removed_instructions','36'),@('relocated_branches','2'),@('slot','0x36000'),@('baseline_slot','0x31000'),@('weights','0x4d000'),@('verified','1'),@('baseline_untouched','1'))){Require $hamCode[0] $kv[0] $kv[1]}
}
$hamLive=0.0;$hamPromoted=$false
foreach($id in @($ham.Keys|Sort-Object)){
 $line=$ham[$id];Require $line 'failures' '0';Require $line 'disabled' '0';Require $line 'installs' '1'
 Require $line 'slot' '0x36000';Require $line 'baseline' 'HAL_GYZ';Require $line 'math' 'DEAD_SHR_ONLY'
 foreach($ri in 1..([Math]::Min($id,4))){Require $line "mask$ri" '0xffff'}
 $totals=@{control_ticks=0.0;candidate_ticks=0.0;control_graph_tsc=0.0;candidate_graph_tsc=0.0}
 foreach($pair in $hamPairs.Values){if((N $pair 'request') -le [Math]::Min($id,2)){
  $totals.control_ticks+=N $pair 'control_gate_up_ticks';$totals.candidate_ticks+=N $pair 'candidate_gate_up_ticks'
  $totals.control_graph_tsc+=N $pair 'control_graph_tsc';$totals.candidate_graph_tsc+=N $pair 'candidate_graph_tsc'
 }}
 foreach($f in $totals.Keys){if((N $line $f) -ne $totals[$f]){$issues.Add("HAM_TOTAL_MISMATCH:$id/$f")}}
 $promoted=Field $line 'promoted'
 if($promoted -notin @('0','1')){$issues.Add("HAM_BAD_PROMOTION:$id")}
 if($promoted -eq '1'){
  if($id -lt 2 -or $totals.candidate_ticks -le 0 -or $totals.candidate_graph_tsc -le 0 -or
     $totals.control_ticks*1000 -lt $totals.candidate_ticks*1020 -or
     $totals.control_graph_tsc*1000 -lt $totals.candidate_graph_tsc*1005){$issues.Add("HAM_UNQUALIFIED_PROMOTION:$id")}
  if($id -ge 3 -and (-not $han.ContainsKey($id) -or (Field $han[$id] 'promoted') -ne '1')){Require $line 'live_mask' '0xffff';if((N $line 'live') -le 0){$issues.Add("HAM_NO_LIVE:$id")}}
 }elseif((N $line 'live') -gt 0){$issues.Add("HAM_UNPROMOTED_LIVE:$id")}
 $live=N $line 'live';if($live -lt $hamLive){$issues.Add("HAM_LIVE_REGRESSED:$id")};$hamLive=$live;$hamPromoted=$promoted -eq '1'
 if($l.ContainsKey($id) -and $live -gt (N $l[$id] 'published')){$issues.Add("HAM_LIVE_EXCEEDS_GRAPH:$id")}
}
if(@(Rows 'GPU-HAM-REJECT').Count -or @(Rows 'GPU-HAM-DIFF').Count){$issues.Add('HAM_CANDIDATE_REJECTED')}
$hanPairs=@{};$hanBegin=@{}
foreach($line in @(Rows 'GPU-HAN-BEGIN')){
 $id=N $line 'request';$layer=N $line 'layer';$key="$id/$layer"
 if($hanBegin.ContainsKey($key)){$issues.Add("HAN_DUPLICATE_BEGIN:$key")};$hanBegin[$key]=$line
 Require $line 'candidate_first' ([string][int](($id+$layer)%2 -eq 0))
 Require $line 'capture' 'ALL_INTERMEDIATES';Require $line 'shadow_only' '1'
}
foreach($line in @(Rows 'GPU-HAN-PAIR')){
 $id=N $line 'request';$layer=N $line 'layer';$key="$id/$layer"
 if($hanPairs.ContainsKey($key)){$issues.Add("HAN_DUPLICATE_PAIR:$key")};$hanPairs[$key]=$line
 if($id -lt 1 -or $id -gt 4 -or $id -ne [Math]::Floor($id) -or $layer -lt 0 -or $layer -gt 15 -or $layer -ne [Math]::Floor($layer)){$issues.Add("HAN_BAD_KEY:$key")}
 if(-not $hanBegin.ContainsKey($key)){$issues.Add("HAN_MISSING_BEGIN:$key")}
 foreach($f in @('transport_clean','bitwise','gt_valid')){Require $line $f '1'}
 Require $line 'candidate_publish' '0';Require $line 'compared_values' '26624';Require $line 'disabled' '0'
 if((Field $line 'q6') -notin @('0','1')){$issues.Add("HAN_BAD_FAMILY:$key")}
 foreach($arm in @('control','candidate')){foreach($stage in @('gate_up_ticks','swiglu_ticks','down_ticks','graph_tsc')){
  if((N $line ($arm+'_'+$stage)) -le 0){$issues.Add("HAN_PAIR_TIME:$key")}
 }}
}
foreach($id in 1..4){
 foreach($layer in 0..15){if(-not $hanPairs.ContainsKey("$id/$layer")){$issues.Add("HAN_MISSING_PAIR:$id/$layer")}}
 $family=@($hanPairs.Values|Where-Object{(Field $_ 'request') -eq [string]$id -and (Field $_ 'q6') -eq '1'})
 if($family.Count -ne 8){$issues.Add("HAN_FAMILY_CENSUS:$id")}
}
foreach($key in $hanBegin.Keys){if(-not $hanPairs.ContainsKey($key)){$issues.Add("HAN_UNFINISHED_PAIR:$key")}}
$hanCode=@(Rows 'GPU-HAN-CODE')
if($hanCode.Count -ne 1){$issues.Add('HAN_CODE_INSTALL_COUNT')}else{
 foreach($kv in @(@('action','INSTALL'),@('bytes','12272'),@('instructions_saved_vs_ham','296'),@('coeff_instructions_per_row','26'),@('unpack_sends_changed','0'),@('slot','0x3b000'),@('baseline_slot','0x36000'),@('weights','0x4d000'),@('verified','1'),@('baseline_untouched','1'))){Require $hanCode[0] $kv[0] $kv[1]}
}
$hanLive=0.0;$hanPromoted=$false
foreach($id in @($han.Keys|Sort-Object)){
 $line=$han[$id];Require $line 'failures' '0';Require $line 'disabled' '0';Require $line 'installs' '1'
 Require $line 'slot' '0x3b000';Require $line 'baseline' 'HAM_DCE';Require $line 'math' 'SIMD8_COEFFICIENTS_UNCHANGED_FP_ORDER'
 foreach($ri in 1..([Math]::Min($id,4))){Require $line "mask$ri" '0xffff'}
 $totals=@{control_ticks=0.0;candidate_ticks=0.0;control_graph_tsc=0.0;candidate_graph_tsc=0.0}
 foreach($pair in $hanPairs.Values){if((N $pair 'request') -le [Math]::Min($id,2)){
  $totals.control_ticks+=N $pair 'control_gate_up_ticks';$totals.candidate_ticks+=N $pair 'candidate_gate_up_ticks'
  $totals.control_graph_tsc+=N $pair 'control_graph_tsc';$totals.candidate_graph_tsc+=N $pair 'candidate_graph_tsc'
 }}
 foreach($f in $totals.Keys){if((N $line $f) -ne $totals[$f]){$issues.Add("HAN_TOTAL_MISMATCH:$id/$f")}}
 $promoted=Field $line 'promoted'
 if($promoted -notin @('0','1')){$issues.Add("HAN_BAD_PROMOTION:$id")}
 if($promoted -eq '1'){
  if(-not $ham.ContainsKey($id) -or (Field $ham[$id] 'promoted') -ne '1'){$issues.Add("HAN_BASELINE_NOT_QUALIFIED:$id")}
  if($id -lt 2 -or $totals.candidate_ticks -le 0 -or $totals.candidate_graph_tsc -le 0 -or
     $totals.control_ticks*1000 -lt $totals.candidate_ticks*1020 -or
     $totals.control_graph_tsc*1000 -lt $totals.candidate_graph_tsc*1005){$issues.Add("HAN_UNQUALIFIED_PROMOTION:$id")}
  if($id -ge 3 -and (-not $hap.ContainsKey($id) -or (Field $hap[$id] 'promoted') -ne '1')){Require $line 'live_mask' '0xffff';if((N $line 'live') -le 0){$issues.Add("HAN_NO_LIVE:$id")}}
 }elseif((N $line 'live') -gt 0){$issues.Add("HAN_UNPROMOTED_LIVE:$id")}
 $live=N $line 'live';if($live -lt $hanLive){$issues.Add("HAN_LIVE_REGRESSED:$id")};$hanLive=$live;$hanPromoted=$promoted -eq '1'
 if($l.ContainsKey($id) -and $ham.ContainsKey($id) -and $live+(N $ham[$id] 'live') -gt (N $l[$id] 'published')){$issues.Add("HAN_LIVE_EXCEEDS_GRAPH:$id")}
}
if(@(Rows 'GPU-HAN-REJECT').Count -or @(Rows 'GPU-HAN-DIFF').Count){$issues.Add('HAN_CANDIDATE_REJECTED')}
$haoPairs=@{};$haoBegin=@{}
foreach($line in @(Rows 'GPU-HAO-BEGIN')){
 $id=N $line 'request';$layer=N $line 'layer';$key="$id/$layer"
 if($haoBegin.ContainsKey($key)){$issues.Add("HAO_DUPLICATE_BEGIN:$key")};$haoBegin[$key]=$line
 Require $line 'candidate_first' ([string][int](($id+$layer)%2 -eq 0))
 Require $line 'capture' 'ALL_INTERMEDIATES';Require $line 'shadow_only' '1'
}
foreach($line in @(Rows 'GPU-HAO-PAIR')){
 $id=N $line 'request';$layer=N $line 'layer';$key="$id/$layer"
 if($haoPairs.ContainsKey($key)){$issues.Add("HAO_DUPLICATE_PAIR:$key")};$haoPairs[$key]=$line
 if($id -lt 1 -or $id -gt 4 -or $id -ne [Math]::Floor($id) -or $layer -lt 0 -or $layer -gt 15 -or $layer -ne [Math]::Floor($layer)){$issues.Add("HAO_BAD_KEY:$key")}
 if(-not $haoBegin.ContainsKey($key)){$issues.Add("HAO_MISSING_BEGIN:$key")}
 if($hanPairs.ContainsKey($key)){Require $line 'q6' (Field $hanPairs[$key] 'q6')}else{$issues.Add("HAO_MISSING_PARENT_PAIR:$key")}
 foreach($f in @('transport_clean','bitwise','gt_valid')){Require $line $f '1'}
 Require $line 'candidate_publish' '0';Require $line 'compared_values' '26624';Require $line 'disabled' '0'
 if((Field $line 'q6') -notin @('0','1')){$issues.Add("HAO_BAD_FAMILY:$key")}
 foreach($arm in @('control','candidate')){foreach($stage in @('gate_up_ticks','swiglu_ticks','down_ticks','graph_tsc')){
  if((N $line ($arm+'_'+$stage)) -le 0){$issues.Add("HAO_PAIR_TIME:$key")}
 }}
}
foreach($id in 1..4){
 foreach($layer in 0..15){if(-not $haoPairs.ContainsKey("$id/$layer")){$issues.Add("HAO_MISSING_PAIR:$id/$layer")}}
 $family=@($haoPairs.Values|Where-Object{(Field $_ 'request') -eq [string]$id -and (Field $_ 'q6') -eq '1'})
 if($family.Count -ne 8){$issues.Add("HAO_FAMILY_CENSUS:$id")}
}
foreach($key in $haoBegin.Keys){if(-not $haoPairs.ContainsKey($key)){$issues.Add("HAO_UNFINISHED_PAIR:$key")}}
$haoCode=@(Rows 'GPU-HAO-CODE')
if($haoCode.Count -ne 1){$issues.Add('HAO_CODE_INSTALL_COUNT')}else{
 foreach($kv in @(@('action','INSTALL'),@('bytes','7616'),@('instructions_saved_vs_gyq','166'),@('coeff_instructions_per_row','26'),@('unpack_sends_changed','0'),@('slot','0x40000'),@('gate_slot','0x3b000'),@('weights','0x4d000'),@('verified','1'),@('baseline_untouched','1'))){Require $haoCode[0] $kv[0] $kv[1]}
}
$haoTarget=0
foreach($pair in $haoPairs.Values){if((Field $pair 'request') -eq '1' -and (Field $pair 'q6') -eq '0'){$haoTarget=$haoTarget -bor (1 -shl [int](N $pair 'layer'))}}
$haoTargetHex='0x{0:x}' -f $haoTarget
$haoLive=0.0;$haoQ4Live=0.0;$haoPromoted=$false
foreach($id in @($hao.Keys|Sort-Object)){
 $line=$hao[$id];Require $line 'failures' '0';Require $line 'disabled' '0';Require $line 'installs' '1'
 Require $line 'slot' '0x40000';Require $line 'baseline' 'HAN_GATE_GYQ_DOWN';Require $line 'math' 'Q4_DOWN_VECTOR_SAME_FP_ORDER';Require $line 'speed_scope' 'Q4_ONLY';Require $line 'target_mask' $haoTargetHex
 foreach($ri in 1..([Math]::Min($id,4))){Require $line "mask$ri" '0xffff'}
 $totals=@{control_ticks=0.0;candidate_ticks=0.0;control_graph_tsc=0.0;candidate_graph_tsc=0.0}
 foreach($pair in $haoPairs.Values){if((N $pair 'request') -le [Math]::Min($id,2) -and (Field $pair 'q6') -eq '0'){
  $totals.control_ticks+=N $pair 'control_down_ticks';$totals.candidate_ticks+=N $pair 'candidate_down_ticks'
  $totals.control_graph_tsc+=N $pair 'control_graph_tsc';$totals.candidate_graph_tsc+=N $pair 'candidate_graph_tsc'
 }}
 foreach($f in $totals.Keys){if((N $line $f) -ne $totals[$f]){$issues.Add("HAO_TOTAL_MISMATCH:$id/$f")}}
 $promoted=Field $line 'promoted'
 if($promoted -notin @('0','1')){$issues.Add("HAO_BAD_PROMOTION:$id")}
 if($promoted -eq '1'){
  if(-not $han.ContainsKey($id) -or (Field $han[$id] 'promoted') -ne '1'){$issues.Add("HAO_BASELINE_NOT_QUALIFIED:$id")}
  if($id -lt 2 -or $totals.candidate_ticks -le 0 -or $totals.candidate_graph_tsc -le 0 -or
     $totals.control_ticks*1000 -lt $totals.candidate_ticks*1020 -or
     $totals.control_graph_tsc*1000 -lt $totals.candidate_graph_tsc*1005){$issues.Add("HAO_UNQUALIFIED_PROMOTION:$id")}
  if($id -ge 3 -and (-not $haq.ContainsKey($id) -or (Field $haq[$id] 'promoted') -ne '1')){Require $line 'live_mask' '0xffff';Require $line 'q4_mask' $haoTargetHex;if((N $line 'live') -le 0 -or (N $line 'q4_live') -le 0){$issues.Add("HAO_NO_LIVE:$id")}}
 }elseif((N $line 'live') -gt 0){$issues.Add("HAO_UNPROMOTED_LIVE:$id")}
 $live=N $line 'live';if($live -lt $haoLive){$issues.Add("HAO_LIVE_REGRESSED:$id")};$haoLive=$live;$haoPromoted=$promoted -eq '1'
 $q4Live=N $line 'q4_live';if($q4Live -lt $haoQ4Live -or $q4Live -gt $live){$issues.Add("HAO_Q4_COUNT:$id")};$haoQ4Live=$q4Live
 if($l.ContainsKey($id) -and $q4Live -gt (N $l[$id] 'q4_count')){$issues.Add("HAO_Q4_EXCEEDS_GRAPH:$id")}
 if($l.ContainsKey($id) -and $han.ContainsKey($id) -and $live -gt ((N $han[$id] 'live')+$(if($hap.ContainsKey($id)){N $hap[$id] 'live'}else{0}))){$issues.Add("HAO_LIVE_EXCEEDS_GRAPH:$id")}
}
if(@(Rows 'GPU-HAO-REJECT').Count -or @(Rows 'GPU-HAO-DIFF').Count){$issues.Add('HAO_CANDIDATE_REJECTED')}
$hapPairs=@{};$hapBegin=@{}
foreach($line in @(Rows 'GPU-HAP-BEGIN')){
 $id=N $line 'request';$layer=N $line 'layer';$key="$id/$layer"
 if($hapBegin.ContainsKey($key)){$issues.Add("HAP_DUPLICATE_BEGIN:$key")};$hapBegin[$key]=$line
 Require $line 'candidate_first' ([string][int](($id+$layer)%2 -eq 0))
 Require $line 'capture' 'ALL_INTERMEDIATES';Require $line 'shadow_only' '1'
}
foreach($line in @(Rows 'GPU-HAP-PAIR')){
 $id=N $line 'request';$layer=N $line 'layer';$key="$id/$layer"
 if($hapPairs.ContainsKey($key)){$issues.Add("HAP_DUPLICATE_PAIR:$key")};$hapPairs[$key]=$line
 if($id -lt 1 -or $id -gt 4 -or $id -ne [Math]::Floor($id) -or $layer -lt 0 -or $layer -gt 15 -or $layer -ne [Math]::Floor($layer)){$issues.Add("HAP_BAD_KEY:$key")}
 if(-not $hapBegin.ContainsKey($key)){$issues.Add("HAP_MISSING_BEGIN:$key")}
 if($haoPairs.ContainsKey($key)){Require $line 'q6' (Field $haoPairs[$key] 'q6')}else{$issues.Add("HAP_MISSING_PARENT_PAIR:$key")}
 foreach($f in @('transport_clean','bitwise','gt_valid')){Require $line $f '1'}
 Require $line 'candidate_publish' '0';Require $line 'compared_values' '26624';Require $line 'disabled' '0'
 if((Field $line 'q6') -notin @('0','1')){$issues.Add("HAP_BAD_FAMILY:$key")}
 foreach($arm in @('control','candidate')){foreach($stage in @('gate_up_ticks','swiglu_ticks','down_ticks','graph_tsc')){
  if((N $line ($arm+'_'+$stage)) -le 0){$issues.Add("HAP_PAIR_TIME:$key")}
 }}
}
foreach($id in 1..4){
 foreach($layer in 0..15){if(-not $hapPairs.ContainsKey("$id/$layer")){$issues.Add("HAP_MISSING_PAIR:$id/$layer")}}
 $family=@($hapPairs.Values|Where-Object{(Field $_ 'request') -eq [string]$id -and (Field $_ 'q6') -eq '1'})
 if($family.Count -ne 8){$issues.Add("HAP_FAMILY_CENSUS:$id")}
}
foreach($key in $hapBegin.Keys){if(-not $hapPairs.ContainsKey($key)){$issues.Add("HAP_UNFINISHED_PAIR:$key")}}
$hapCode=@(Rows 'GPU-HAP-CODE')
if($hapCode.Count -ne 1){$issues.Add('HAP_CODE_INSTALL_COUNT')}else{
 foreach($kv in @(@('action','INSTALL'),@('bytes','11312'),@('instructions_saved_vs_han','60'),@('coeff_instructions_per_row','20'),@('unpack_sends_changed','0'),@('slot','0x45000'),@('baseline_slot','0x3b000'),@('weights','0x4d000'),@('verified','1'),@('baseline_untouched','1'))){Require $hapCode[0] $kv[0] $kv[1]}
}
$hapLive=0.0;$hapPromoted=$false
foreach($id in @($hap.Keys|Sort-Object)){
 $line=$hap[$id];Require $line 'failures' '0';Require $line 'disabled' '0';Require $line 'installs' '1'
 Require $line 'slot' '0x45000';Require $line 'baseline' 'HAO_DOWN_HAN_GATE';Require $line 'math' 'VALUE_FLOW_SAME_FP_ORDER'
 foreach($ri in 1..([Math]::Min($id,4))){Require $line "mask$ri" '0xffff'}
 $totals=@{control_ticks=0.0;candidate_ticks=0.0;control_graph_tsc=0.0;candidate_graph_tsc=0.0}
 foreach($pair in $hapPairs.Values){if((N $pair 'request') -le [Math]::Min($id,2)){
  $totals.control_ticks+=N $pair 'control_gate_up_ticks';$totals.candidate_ticks+=N $pair 'candidate_gate_up_ticks'
  $totals.control_graph_tsc+=N $pair 'control_graph_tsc';$totals.candidate_graph_tsc+=N $pair 'candidate_graph_tsc'
 }}
 foreach($f in $totals.Keys){if((N $line $f) -ne $totals[$f]){$issues.Add("HAP_TOTAL_MISMATCH:$id/$f")}}
 $promoted=Field $line 'promoted'
 if($promoted -notin @('0','1')){$issues.Add("HAP_BAD_PROMOTION:$id")}
 if($promoted -eq '1'){
  if(-not $hao.ContainsKey($id) -or (Field $hao[$id] 'promoted') -ne '1'){$issues.Add("HAP_BASELINE_NOT_QUALIFIED:$id")}
  if($id -lt 2 -or $totals.candidate_ticks -le 0 -or $totals.candidate_graph_tsc -le 0 -or
     $totals.control_ticks*1000 -lt $totals.candidate_ticks*1020 -or
     $totals.control_graph_tsc*1000 -lt $totals.candidate_graph_tsc*1005){$issues.Add("HAP_UNQUALIFIED_PROMOTION:$id")}
  if($id -ge 3){Require $line 'live_mask' '0xffff';if((N $line 'live') -le 0){$issues.Add("HAP_NO_LIVE:$id")}}
 }elseif((N $line 'live') -gt 0){$issues.Add("HAP_UNPROMOTED_LIVE:$id")}
 $live=N $line 'live'
 if($id -ge 5 -and $id -le 8 -and $promoted -eq '1'){
  $prev=$id-1
  if(-not $hap.ContainsKey($prev) -or -not $l.ContainsKey($prev) -or -not $l.ContainsKey($id) -or -not $p.ContainsKey($id)){$issues.Add("HAP_STEADY_LIVE_EVIDENCE:$id")}
  else{
   Require $hap[$prev] 'promoted' '1'
   $delta=$live-(N $hap[$prev] 'live');$publishedDelta=(N $l[$id] 'published')-(N $l[$prev] 'published')
   if($delta -ne $publishedDelta -or $delta -lt (N $p[$id] 'calls') -or $delta -le 0){$issues.Add("HAP_STEADY_LIVE_DELTA:$id")}
  }
 }
 if($live -lt $hapLive){$issues.Add("HAP_LIVE_REGRESSED:$id")};$hapLive=$live;$hapPromoted=$promoted -eq '1'
 if($l.ContainsKey($id) -and $hao.ContainsKey($id) -and ($live+(N $han[$id] 'live')+(N $ham[$id] 'live') -gt (N $l[$id] 'published') -or $live -gt ((N $hao[$id] 'live')+$(if($haq.ContainsKey($id)){N $haq[$id] 'live'}else{0})))){$issues.Add("HAP_LIVE_EXCEEDS_GRAPH:$id")}
}
if(@(Rows 'GPU-HAP-REJECT').Count -or @(Rows 'GPU-HAP-DIFF').Count){$issues.Add('HAP_CANDIDATE_REJECTED')}
$haqPairs=@{};$haqBegin=@{}
foreach($line in @(Rows 'GPU-HAQ-BEGIN')){
 $id=N $line 'request';$layer=N $line 'layer';$key="$id/$layer"
 if($haqBegin.ContainsKey($key)){$issues.Add("HAR_DUPLICATE_BEGIN:$key")};$haqBegin[$key]=$line
 Require $line 'candidate_first' ([string][int](($id+$layer)%2 -eq 0))
 Require $line 'capture' 'ALL_INTERMEDIATES';Require $line 'shadow_only' '1'
}
foreach($line in @(Rows 'GPU-HAQ-PAIR')){
 $id=N $line 'request';$layer=N $line 'layer';$key="$id/$layer"
 if($haqPairs.ContainsKey($key)){$issues.Add("HAR_DUPLICATE_PAIR:$key")};$haqPairs[$key]=$line
 if($id -lt 1 -or $id -gt 4 -or $id -ne [Math]::Floor($id) -or $layer -lt 0 -or $layer -gt 15 -or $layer -ne [Math]::Floor($layer)){$issues.Add("HAR_BAD_KEY:$key")}
 if($haoPairs.ContainsKey($key)){Require $line 'q6' (Field $haoPairs[$key] 'q6')}else{$issues.Add("HAR_PARENT_PAIR_MISSING:$key")}
 if(-not $haqBegin.ContainsKey($key)){$issues.Add("HAR_MISSING_BEGIN:$key")}
 if($hanPairs.ContainsKey($key)){Require $line 'q6' (Field $hanPairs[$key] 'q6')}else{$issues.Add("HAR_MISSING_PARENT_PAIR:$key")}
 foreach($f in @('transport_clean','bitwise','gt_valid')){Require $line $f '1'}
 Require $line 'candidate_publish' '0';Require $line 'compared_values' '26624';Require $line 'disabled' '0'
 if((Field $line 'q6') -notin @('0','1')){$issues.Add("HAR_BAD_FAMILY:$key")}
 foreach($arm in @('control','candidate')){foreach($stage in @('gate_up_ticks','swiglu_ticks','down_ticks','graph_tsc')){
  if((N $line ($arm+'_'+$stage)) -le 0){$issues.Add("HAR_PAIR_TIME:$key")}
 }}
}
foreach($id in 1..4){
 foreach($layer in 0..15){if(-not $haqPairs.ContainsKey("$id/$layer")){$issues.Add("HAR_MISSING_PAIR:$id/$layer")}}
 $family=@($haqPairs.Values|Where-Object{(Field $_ 'request') -eq [string]$id -and (Field $_ 'q6') -eq '1'})
 if($family.Count -ne 8){$issues.Add("HAR_FAMILY_CENSUS:$id")}
}
foreach($key in $haqBegin.Keys){if(-not $haqPairs.ContainsKey($key)){$issues.Add("HAR_UNFINISHED_PAIR:$key")}}
$haqCode=@(Rows 'GPU-HAQ-CODE')
if($haqCode.Count -ne 1){$issues.Add('HAR_CODE_INSTALL_COUNT')}else{
 foreach($kv in @(@('action','INSTALL'),@('bytes','7136'),@('instructions_saved_vs_hao','30'),@('coeff_instructions_per_row','20'),@('unpack_sends_changed','0'),@('slot','0x48000'),@('gate_slot','0x45000'),@('weights','0x4d000'),@('verified','1'),@('baseline_untouched','1'))){Require $haqCode[0] $kv[0] $kv[1]}
}
$haqTarget=0
foreach($pair in $haqPairs.Values){if((Field $pair 'request') -eq '1' -and (Field $pair 'q6') -eq '0'){$haqTarget=$haqTarget -bor (1 -shl [int](N $pair 'layer'))}}
$haqTargetHex='0x{0:x}' -f $haqTarget
$haqLive=0.0;$haqQ4Live=0.0;$haqPromoted=$false
foreach($id in @($haq.Keys|Sort-Object)){
 $line=$haq[$id];Require $line 'failures' '0';Require $line 'disabled' '0';Require $line 'installs' '1'
 Require $line 'slot' '0x48000';Require $line 'baseline' 'HAP_GATE_HAO_DOWN';Require $line 'math' 'Q4_DOWN_VALUE_FLOW_SAME_FP_ORDER';Require $line 'speed_scope' 'Q4_ONLY';Require $line 'target_mask' $haqTargetHex
 foreach($ri in 1..([Math]::Min($id,4))){Require $line "mask$ri" '0xffff'}
 $totals=@{control_ticks=0.0;candidate_ticks=0.0;control_graph_tsc=0.0;candidate_graph_tsc=0.0}
 foreach($pair in $haqPairs.Values){if((N $pair 'request') -le [Math]::Min($id,2) -and (Field $pair 'q6') -eq '0'){
  $totals.control_ticks+=N $pair 'control_down_ticks';$totals.candidate_ticks+=N $pair 'candidate_down_ticks'
  $totals.control_graph_tsc+=N $pair 'control_graph_tsc';$totals.candidate_graph_tsc+=N $pair 'candidate_graph_tsc'
 }}
 foreach($f in $totals.Keys){if((N $line $f) -ne $totals[$f]){$issues.Add("HAR_TOTAL_MISMATCH:$id/$f")}}
 $promoted=Field $line 'promoted'
 if($promoted -notin @('0','1')){$issues.Add("HAR_BAD_PROMOTION:$id")}
 if($promoted -eq '1'){
  if(-not $hap.ContainsKey($id) -or (Field $hap[$id] 'promoted') -ne '1'){$issues.Add("HAR_BASELINE_NOT_QUALIFIED:$id")}
  if($id -lt 2 -or $totals.candidate_ticks -le 0 -or $totals.candidate_graph_tsc -le 0 -or
     $totals.control_ticks*1000 -lt $totals.candidate_ticks*1020 -or
     $totals.control_graph_tsc*1000 -lt $totals.candidate_graph_tsc*1005){$issues.Add("HAR_UNQUALIFIED_PROMOTION:$id")}
  if($id -ge 3){Require $line 'live_mask' '0xffff';Require $line 'q4_mask' $haqTargetHex;if((N $line 'live') -le 0 -or (N $line 'q4_live') -le 0){$issues.Add("HAR_NO_LIVE:$id")}}
 }elseif((N $line 'live') -gt 0){$issues.Add("HAR_UNPROMOTED_LIVE:$id")}
 $live=N $line 'live';if($live -lt $haqLive){$issues.Add("HAR_LIVE_REGRESSED:$id")};$haqLive=$live;$haqPromoted=$promoted -eq '1'
 $q4Live=N $line 'q4_live';if($q4Live -lt $haqQ4Live -or $q4Live -gt $live){$issues.Add("HAR_Q4_COUNT:$id")};$haqQ4Live=$q4Live
 if($l.ContainsKey($id) -and $q4Live -gt (N $l[$id] 'q4_count')){$issues.Add("HAR_Q4_EXCEEDS_GRAPH:$id")}
 if($hap.ContainsKey($id) -and $live -gt (N $hap[$id] 'live')){$issues.Add("HAR_LIVE_EXCEEDS_GATE:$id")}
 if($hao.ContainsKey($id) -and $l.ContainsKey($id) -and $live+(N $hao[$id] 'live') -gt (N $l[$id] 'published')){$issues.Add("HAR_DOWN_OWNERS_OVERLAP:$id")}
 if($promoted -eq '1' -and $id -ge 5 -and $id -le 8){
  $prev=$id-1
  if(-not $haq.ContainsKey($prev) -or -not $l.ContainsKey($prev)){$issues.Add("HAR_MISSING_PREVIOUS:$id")}
  else {
   Require $haq[$prev] 'promoted' '1'
   if($live-(N $haq[$prev] 'live') -ne (N $l[$id] 'published')-(N $l[$prev] 'published')){$issues.Add("HAR_STEADY_LIVE_DELTA:$id")}
   if($q4Live-(N $haq[$prev] 'q4_live') -ne (N $l[$id] 'q4_count')-(N $l[$prev] 'q4_count')){$issues.Add("HAR_STEADY_Q4_DELTA:$id")}
  }
 }
}
if(@(Rows 'GPU-HAQ-REJECT').Count -or @(Rows 'GPU-HAQ-DIFF').Count){$issues.Add('HAR_CANDIDATE_REJECTED')}

$lmhPairs=Index @(Rows 'GPU-HAQ-LMH-PAIR') 'LMH_PAIR'
$lmhBegin=Index @(Rows 'GPU-HAQ-LMH-BEGIN') 'LMH_BEGIN'
foreach($id in 1..4){
 if(-not $lmhPairs.ContainsKey($id) -or -not $lmhBegin.ContainsKey($id)){$issues.Add("LMH_MISSING_PAIR:$id");continue}
 $line=$lmhPairs[$id];Require $line 'compared_values' '128256';Require $line 'bitwise' '1';Require $line 'transport_clean' '1';Require $line 'candidate_publish' '0';Require $line 'disabled' '0'
 Require $lmhBegin[$id] 'full_logits' '128256';Require $lmhBegin[$id] 'shadow_only' '1';Require $lmhBegin[$id] 'candidate_first' ([string][int]($id%2 -eq 0))
 foreach($field in @('wall','submit','gt')){foreach($arm in @('control','candidate')){if((N $line ($arm+'_'+$field)) -le 0){$issues.Add("LMH_PAIR_TIME:$id")}}}
}
if($lmhPairs.Count -ne 4 -or $lmhBegin.Count -ne 4){$issues.Add('LMH_PAIR_CENSUS')}
$lmhLive=0.0;$lmhPromoted=$false
foreach($id in @($lmh.Keys|Sort-Object)){
 $line=$lmh[$id];Require $line 'failures' '0';Require $line 'disabled' '0';Require $line 'arithmetic' 'VARIANT20_UNCHANGED';Require $line 'headers' 'ROTATING_HAB';Require $line 'K' '2048';Require $line 'vocab' '128256';Require $line 'segments' '16';Require $line 'physical_pre_post_hash' '1'
 Require $line 'mask' ('0x{0:x}' -f ((1 -shl [Math]::Min($id,4))-1))
 $totals=@{}
 foreach($f in @('wall','submit','gt')){foreach($arm in @('control','candidate')){
  $key=$arm+'_'+$f;$sum=0.0
  foreach($ri in 1..([Math]::Min($id,2))){if($lmhPairs.ContainsKey($ri)){$sum+=N $lmhPairs[$ri] $key}}
  $totals[$key]=$sum;if((N $line $key) -ne $sum){$issues.Add("LMH_TOTAL:$id/$key")}
 }}
 $promoted=Field $line 'promoted';if($promoted -notin @('0','1')){$issues.Add("LMH_PROMOTED_VALUE:$id")}
 if($promoted -eq '1'){
  if($id -lt 2 -or $totals.candidate_wall -le 0 -or $totals.candidate_submit -le 0 -or $totals.candidate_gt -le 0 -or
   $totals.control_wall*1000 -lt $totals.candidate_wall*1005 -or $totals.control_submit*1000 -lt $totals.candidate_submit*1020 -or $totals.control_gt*1000 -lt $totals.candidate_gt*1020){$issues.Add("LMH_UNQUALIFIED_PROMOTION:$id")}
 }
 $live=N $line 'live';if($live -lt $lmhLive -or ($promoted -eq '0' -and $live -gt 0)){$issues.Add("LMH_LIVE_INVALID:$id")}
 if($fz.ContainsKey($id)){
  Require $fz[$id] 'lmh_failures' '0';Require $fz[$id] 'lmh_segments' '16'
  if((N $fz[$id] 'lmh_attempts') -ne (N $fz[$id] 'lmh_completed') -or $live -gt (N $fz[$id] 'lmh_completed')){$issues.Add("LMH_FZ_COUNTER:$id")}
 }
 if($id -ge 5 -and $id -le 8 -and $promoted -eq '1'){
  $prev=$id-1
  if(-not $lmh.ContainsKey($prev) -or -not $fz.ContainsKey($prev) -or -not $fz.ContainsKey($id)){$issues.Add("LMH_STEADY_MISSING:$id")}
  else{
   Require $lmh[$prev] 'promoted' '1'
   $delta=$live-(N $lmh[$prev] 'live')
   if($delta -ne (N $fz[$id] 'lmh_completed')-(N $fz[$prev] 'lmh_completed') -or $delta -lt (N $e[$id] 'tokens')){$issues.Add("LMH_STEADY_LIVE_DELTA:$id")}
  }
 }
 $lmhLive=$live;$lmhPromoted=$promoted -eq '1'
}
if(@(Rows 'GPU-HAQ-LMH-REJECT').Count){$issues.Add('LMH_REJECTED')}

# Independent projection paths: 0=single2048, 1=single512, 2=QKV3072.
$projPairs=@{};$projWindows=@{};$projBegin=@{}
foreach($line in @(Rows 'GPU-HAR-PROJ-BEGIN')){
 $key="$(Field $line 'request')/$(Field $line 'path')";if($projBegin.ContainsKey($key)){$issues.Add("PROJ_DUPLICATE_BEGIN:$key")};$projBegin[$key]=$line
}
foreach($line in @(Rows 'GPU-HAR-PROJ-PAIR')){
 $ri=N $line 'request';$path=N $line 'path';$key="$ri/$path"
 if($projPairs.ContainsKey($key)){$issues.Add("PROJ_DUPLICATE_PAIR:$key")};$projPairs[$key]=$line
 if($ri -notin 1..4 -or $path -notin 0..2){$issues.Add("PROJ_BAD_PAIR_KEY:$key");continue}
 if(-not $projBegin.ContainsKey($key)){$issues.Add("PROJ_MISSING_BEGIN:$key")}else{Require $projBegin[$key] 'values' ([string]@(2048,512,3072)[$path]);Require $projBegin[$key] 'shadow_only' '1'}
 Require $line 'compared_values' ([string]@(2048,512,3072)[$path]);Require $line 'bitwise' '1';Require $line 'transport_clean' '1';Require $line 'candidate_publish' '0';Require $line 'disabled' '0'
 foreach($f in @('control_wall','candidate_wall','control_wait','candidate_wait')){if((N $line $f) -le 0){$issues.Add("PROJ_PAIR_TIME:$key")}}
}
foreach($ri in 1..4){foreach($path in 0..2){if(-not $projPairs.ContainsKey("$ri/$path")){$issues.Add("PROJ_MISSING_PAIR:$ri/$path")}}}
if($projPairs.Count -ne 12 -or $projBegin.Count -ne 12){$issues.Add('PROJ_PAIR_CENSUS')}
# HAR: warm-up correctness is mandatory but warm-up cost never enters steady totals.
$warmups=@{}
foreach($line in @(Rows 'GPU-HAR-PROJ-WARMUP')){
 $ri=N $line 'request';$path=N $line 'path';$key="$ri/$path"
 if($warmups.ContainsKey($key)){$issues.Add("HAR_DUPLICATE_WARMUP:$key")};$warmups[$key]=$line
 if($ri -notin 1..4 -or $path -notin 0..2){$issues.Add("HAR_BAD_WARMUP_KEY:$key");continue}
 Require $line 'compared_values' ([string]@(2048,512,3072)[$path])
 foreach($f in @('bitwise','transport_clean')){Require $line $f '1'}
 foreach($f in @('candidate_publish','measured')){Require $line $f '0'}
 foreach($f in @('control_wall','candidate_wall','control_wait','candidate_wait')){if((N $line $f) -le 0){$issues.Add("HAR_WARMUP_TIME:$key")}}
}
if($warmups.Count -ne 12){$issues.Add('HAR_WARMUP_CENSUS')}
foreach($ri in 1..4){foreach($path in 0..2){
 $key="$ri/$path";if(-not $warmups.ContainsKey($key)){$issues.Add("HAR_MISSING_WARMUP:$key")}
 foreach($index in @($projBegin,$projPairs)){if($index.ContainsKey($key)){
  Require $index[$key] 'warmup_pairs' '1';Require $index[$key] 'measured_pairs' '2';Require $index[$key] 'paired_order' 'ABBA_OR_BAAB'
 }}
}}
foreach($line in @(Rows 'GPU-HAR-PROJ-WINDOW')){
 Require $line 'qualification' 'STEADY_ABBA';Require $line 'warmup_pairs' '1';Require $line 'measured_pairs' '2'
}
$projCode=@(Rows 'GPU-HAR-PROJ-CODE')
if($projCode.Count -ne 1){$issues.Add('PROJ_CODE_CENSUS')}else{
 foreach($kv in @(@('bytes','6960'),@('slot','0x4a000'),@('baseline_slot','0x29000'),@('arithmetic_order','UNCHANGED'),@('physical_hash','1'))){Require $projCode[0] $kv[0] $kv[1]}
}
foreach($line in @(Rows 'GPU-HAR-PROJ-WINDOW')){
 $ri=N $line 'request';$path=N $line 'path';$key="$ri/$path"
 if($projWindows.ContainsKey($key)){$issues.Add("PROJ_DUPLICATE_WINDOW:$key")};$projWindows[$key]=$line
 if(-not $e.ContainsKey([int]$ri) -or $ri -ne [Math]::Floor($ri) -or $path -notin 0..2){$issues.Add("PROJ_BAD_WINDOW_KEY:$key")}
}
$projPromoted=@($false,$false,$false);$projLive=@(0.0,0.0,0.0)
foreach($ri in @($e.Keys|Sort-Object)){foreach($path in 0..2){
 $key="$ri/$path";if(-not $projWindows.ContainsKey($key)){$complete=$false;$issues.Add("PROJ_MISSING_WINDOW:$key");continue}
 $line=$projWindows[$key];Require $line 'mask' ('0x{0:x}' -f ((1 -shl [Math]::Min($ri,4))-1))
 foreach($kv in @(@('failures','0'),@('disabled','0'),@('slot','0x4a000'),@('baseline','ED79'),@('arithmetic_order','UNCHANGED'),@('physical_pre_post_hash','1'))){Require $line $kv[0] $kv[1]}
 $totals=@{}
 foreach($f in @('control_wall','candidate_wall','control_wait','candidate_wait')){
  $sum=0.0;foreach($id in 1..([Math]::Min($ri,2))){if($projPairs.ContainsKey("$id/$path")){$sum+=N $projPairs["$id/$path"] $f}}
  $totals[$f]=$sum;if((N $line $f) -ne $sum){$issues.Add("PROJ_TOTAL:$key/$f")}
 }
 $promoted=Field $line 'promoted'
 if($promoted -notin @('0','1')){$issues.Add("PROJ_BAD_PROMOTION:$key")}
 if($promoted -eq '1' -and ($ri -lt 2 -or $totals.candidate_wall -le 0 -or $totals.candidate_wait -le 0 -or $totals.control_wall*1000 -lt $totals.candidate_wall*1005 -or $totals.control_wait*1000 -lt $totals.candidate_wait*1020)){$issues.Add("PROJ_UNQUALIFIED:$key")}
 $live=N $line 'live';$completed=N $line 'completed';$attempts=N $line 'attempts'
 if($live -lt $projLive[$path] -or $live -gt $completed -or $completed -ne $attempts -or ($promoted -eq '0' -and $live -gt 0)){$issues.Add("PROJ_COUNTERS:$key")}
 if($ri -ge 5 -and $ri -le 8 -and $promoted -eq '1'){
  $prev="$($ri-1)/$path"
  if(-not $projWindows.ContainsKey($prev)){$issues.Add("PROJ_STEADY_MISSING:$key")}
  else{Require $projWindows[$prev] 'promoted' '1';$delta=$live-(N $projWindows[$prev] 'live')
   if($delta -le 0 -or $delta -ne $completed-(N $projWindows[$prev] 'completed')){$issues.Add("PROJ_STEADY_LIVE_DELTA:$key")}
  }
 }
 $projLive[$path]=$live;$projPromoted[$path]=$promoted -eq '1'
}}
if(@(Rows 'GPU-HAR-PROJ-REJECT').Count){$issues.Add('PROJ_REJECTED')}

if(@(Rows 'TOKENIZER-HAJ-INDEX').Count){$issues.Add('QUARANTINED_INDEX_RAN')}
if([regex]::Matches($raw,'\[tokenizer\] GgufTokenizer: vocab=128256,').Count -ne 1){$issues.Add('LEGACY_TOKENIZER_LIFETIME_COUNT')}
$adj=@(Rows 'TOKENIZER-HAK-ADJ')
if($adj.Count -lt $e.Count){$issues.Add('ADJACENCY_EVIDENCE_INCOMPLETE')}
foreach($line in $adj){
 Require $line 'cached' '1';Require $line 'model_index' '0'
 $initial=N $line 'initial_pairs';$scans=N $line 'rank_scans';$legacy=N $line 'legacy_equivalent_scans'
 if($scans -gt 3*$initial -or $scans -lt $initial -or $scans -gt $legacy){$issues.Add('ADJACENCY_SCAN_BOUND')}
}
if(@(Rows 'GPU-HAI-Q6-PAIR').Count){$issues.Add('REJECTED_Q6_LAB_REPLAYED')}
$fatal=[regex]::Matches($raw,'Fence timeout:|GPU FAULT DETECTED|CRASH-PANIC|recovery_delta=[1-9]|WATCHDOG[^\r\n]*TIMEOUT|kind=UNKNOWN_TRACE|\[GPU-HAI-LAYER-FALLBACK\]').Count
if(@(Rows 'BASELINE-DH-GATE'|Where-Object{(Field $_ 'class') -eq '7'}).Count){$issues.Add('LEGACY_GATE_ACTUAL_FAILURE')}
$steady=@($metrics|Where-Object{$_.request -ge 5 -and $_.request -le 8 -and $_.tokens -eq 128})
$tps=if($steady.Count -eq 4){($steady|Measure-Object tps -Average).Average}else{0}
$class='HAR_NUMERIC_COMPLETE_REVIEW_PENDING'
if($fatal){$class='HAR_FATAL'}
elseif(-not $complete){$class='HAR_INCOMPLETE'}
elseif($issues.Count){$class='HAR_EVIDENCE_OR_INVARIANT_FAIL'}
elseif($steady.Count -ne 4){$class='HAR_STEADY_MATRIX_INCOMPLETE'}
elseif($tps -lt 6.42){$class='HAR_E2E_REGRESSION'}
elseif(-not $haqPromoted -and -not $lmhPromoted -and -not ($projPromoted -contains $true)){$class='HAR_VALID_NO_PROMOTION_REVIEW_PENDING'}
$result=[pscustomobject]@{class=$class;requests=$e.Count;complete=$complete;pairs=$pairKeys.Count;
 proj_pairs=$projPairs.Count;proj_warmups=$warmups.Count;proj_promoted=$projPromoted;proj_live=$projLive;
 haq_pairs=$haqPairs.Count;haq_promoted=$haqPromoted;haq_live=$haqLive;haq_q4_live=$haqQ4Live;lmh_pairs=$lmhPairs.Count;lmh_promoted=$lmhPromoted;lmh_live=$lmhLive;
 hap_pairs=$hapPairs.Count;hap_promoted=$hapPromoted;hap_live=$hapLive;
 hao_pairs=$haoPairs.Count;hao_promoted=$haoPromoted;hao_live=$haoLive;hao_q4_live=$haoQ4Live;
 han_pairs=$hanPairs.Count;han_promoted=$hanPromoted;han_live=$hanLive;
 ham_pairs=$hamPairs.Count;ham_promoted=$hamPromoted;ham_live=$hamLive;
 steady_tps=$tps;fatal=$fatal;issues=@($issues.ToArray());metrics=@($metrics.ToArray());
 semantic_review='PENDING_PHYSICAL_ANSWER_REVIEW';last_pixel_present='UNMEASURED';
 log_sha256=(Get-FileHash -LiteralPath $LogPath).Hash}
New-Item -ItemType Directory -Path $OutputDirectory -Force|Out-Null
$stem="boot$($BootIndex)_$($result.log_sha256)"
$dest=Join-Path $OutputDirectory ($stem+'_AETHLOG.TXT')
if(-not(Test-Path -LiteralPath $dest)){Copy-Item -LiteralPath $LogPath -Destination $dest}
if($Finalize){$result|ConvertTo-Json -Depth 6|Set-Content (Join-Path $OutputDirectory ($stem+'_RESULT.json')) -Encoding UTF8}
$result
if($Finalize -and $class -notin @('HAR_NUMERIC_COMPLETE_REVIEW_PENDING','HAR_VALID_NO_PROMOTION_REVIEW_PENDING')){throw "HAR not closed: $class"}

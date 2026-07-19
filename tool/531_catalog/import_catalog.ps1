param(
  [Parameter(Mandatory = $true)][string]$SourceXlsx,
  [string]$DartOutput = 'lib/features/poc_531/catalog/catalog.generated.dart',
  [string]$CoverageOutput = 'tool/531_catalog/catalog-coverage.json'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Read-Sheet([IO.Compression.ZipArchive]$archive, [string]$path) {
  $entry = $archive.GetEntry($path)
  if ($null -eq $entry) { throw "Missing worksheet: $path" }
  $reader = [IO.StreamReader]::new($entry.Open())
  try { [xml]$xml = $reader.ReadToEnd() } finally { $reader.Dispose() }
  $rows = @()
  foreach ($row in $xml.SelectNodes("//*[local-name()='row']")) {
    $values = @()
    foreach ($cell in $row.SelectNodes("./*[local-name()='c']")) {
      $value = $cell.SelectSingleNode("./*[local-name()='v']")
      $values += if ($null -eq $value) { '' } else { $value.InnerText }
    }
    $rows += ,$values
  }
  return $rows
}

function Dart-String([string]$value) {
  if ($null -eq $value) { return "''" }
  return "'" + $value.Replace('\', '\\').Replace("'", "\'").Replace("`r", '').Replace("`n", '\n') + "'"
}

function Classify-Kind([string]$nature, [string]$family) {
  $text = "$nature $family".ToLowerInvariant()
  if ($text -match 'transition|combinaison') { return 'transition' }
  if ($text -match 'schedule|fréquence') { return 'schedule' }
  if ($text -match 'protocole|deload|test') { return 'protocol' }
  if ($text -match 'règle|principe|training max|progression|mesure') { return 'rule' }
  if ($text -match 'composant|variation|supplemental|assistance|warm-up|condition') { return 'component' }
  return 'documentation'
}

function Classify-Status([string]$status) {
  $text = $status.ToLowerInvariant()
  if ($text -match 'superseded|supplant') { return 'superseded' }
  if ($text -match 'legacy') { return 'legacy' }
  if ($text -match 'restriction') { return 'restricted' }
  return 'current'
}

$executable = @{
  'PL-001' = @{ generator='canonical-powerlifting'; frequencies='3, 4'; levels='ExperienceLevel.intermediate'; goals='TrainingGoal.strength, TrainingGoal.powerliftingPreparation' }
  'BY-026' = @{ generator='canonical-beyond'; frequencies='3, 4'; levels='ExperienceLevel.intermediate'; goals='TrainingGoal.strength' }
  'FV-236' = @{ generator='canonical-forever-original-fsl'; frequencies='4'; levels='ExperienceLevel.beginner'; goals='TrainingGoal.strength, TrainingGoal.generalPreparation' }
  'FV-141' = @{ generator='canonical-bps'; frequencies='3'; levels='ExperienceLevel.beginner'; goals='TrainingGoal.generalPreparation' }
}
$archive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path $SourceXlsx))
try {
  $data = @()
  foreach ($sheet in @(
    @{ path = 'xl/worksheets/sheet2.xml'; supplement = $false },
    @{ path = 'xl/worksheets/sheet6.xml'; supplement = $true }
  )) {
    foreach ($row in (Read-Sheet $archive $sheet.path)) {
      if ($row.Count -lt 18 -or $row[0] -notmatch '^(OR|BY|FV|PL)-\d{3}$') { continue }
      $id = $row[0]
      $generation = if ($id -like 'BY-*') { 'beyond' } elseif ($id -like 'FV-*') { 'forever' } else { 'original' }
      $isExecutable = $executable.ContainsKey($id)
      $kind = if ($isExecutable) { 'executableTemplate' } else { Classify-Kind $row[5] $row[2] }
      $reason = if ($isExecutable) { $null } else { 'NEEDS_REVIEW: documentary row is not a complete, validated Core v5 generation strategy.' }
      $data += [ordered]@{
        id=$id; generation=$generation; family=$row[2]; name=$row[3]; variant=$row[4]
        kind=$kind; nature=$row[5]; status=(Classify-Status $row[15]); document=$row[1]; pages=$row[17]
        sourceKind=if ($sheet.supplement) { 'supplement' } else { 'canonical' }
        executable=$isExecutable; ambiguity=(-not $isExecutable); reason=$reason
        generatorId=if ($isExecutable) { $executable[$id].generator } else { $null }
        frequencies=if ($isExecutable) { $executable[$id].frequencies } else { '' }
        levels=if ($isExecutable) { $executable[$id].levels } else { '' }
        goals=if ($isExecutable) { $executable[$id].goals } else { '' }
      }
    }
  }
} finally { $archive.Dispose() }

if ($data.Count -ne 354) { throw "Expected 354 classified rows, got $($data.Count)." }
if (($data | Where-Object executable).Count -ne 4) { throw 'Expected exactly four executable Core v5 mappings.' }

$dart = [Collections.Generic.List[string]]::new()
$dart.Add("// GENERATED FILE. Run tool/531_catalog/import_catalog.ps1; do not edit.`nimport '../domain/models.dart';`nimport 'catalog_schema.dart';`n`nconst generatedCatalogEntries = <CatalogRecord>[")
foreach ($item in $data) {
  $reason = if ($null -eq $item.reason) { 'null' } else { Dart-String $item.reason }
  $generator = if ($null -eq $item.generatorId) { 'null' } else { Dart-String $item.generatorId }
  $requiresLeaderAnchor = ($item.generatorId -eq 'canonical-forever-original-fsl').ToString().ToLowerInvariant()
  $ambiguity = $item.ambiguity.ToString().ToLowerInvariant()
  $dart.Add("  CatalogRecord(definition: ProgramDefinition(id: $(Dart-String $item.id), name: $(Dart-String $item.name), family: $(Dart-String $item.family), variant: $(Dart-String $item.variant), generation: Generation.$($item.generation), status: ProgramStatus.$($item.status), sourceKind: SourceKind.$($item.sourceKind), entryKind: CatalogEntryKind.$($item.kind), frequencies: {$($item.frequencies)}, levels: {$($item.levels)}, goals: {$($item.goals)}, sources: [SourceProvenance(title: $(Dart-String $item.document), pages: $(Dart-String $item.pages))], generatorId: $generator, nonExecutableReason: $reason, requiresLeaderAnchor: $requiresLeaderAnchor), nature: $(Dart-String $item.nature), ambiguity: $ambiguity),")
}
$dart.Add('];')
$dartPath = Join-Path (Get-Location) $DartOutput
$coveragePath = Join-Path (Get-Location) $CoverageOutput
[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($dartPath)) | Out-Null
[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($coveragePath)) | Out-Null
[IO.File]::WriteAllLines($dartPath, $dart, [Text.UTF8Encoding]::new($false))

$byKind = [ordered]@{}
foreach ($kind in @('executableTemplate','component','rule','schedule','protocol','transition','documentation')) {
  $byKind[$kind] = @($data | Where-Object kind -eq $kind).Count
}
$coverage = [ordered]@{
  schemaVersion=1; sourceWorkbook=[IO.Path]::GetFileName($SourceXlsx)
  imported=$data.Count; classified=$data.Count; executable=@($data | Where-Object executable).Count
  nonExecutable=@($data | Where-Object { -not $_.executable }).Count
  ambiguous=@($data | Where-Object ambiguity).Count
  canonical=@($data | Where-Object sourceKind -eq 'canonical').Count
  supplement=@($data | Where-Object sourceKind -eq 'supplement').Count
  byGeneration=[ordered]@{original=@($data | Where-Object { $_.sourceKind -eq 'canonical' -and $_.generation -eq 'original' }).Count;beyond=@($data | Where-Object { $_.sourceKind -eq 'canonical' -and $_.generation -eq 'beyond' }).Count;forever=@($data | Where-Object { $_.sourceKind -eq 'canonical' -and $_.generation -eq 'forever' }).Count}
  byKind=$byKind
  executableMappings=@($data | Where-Object executable | ForEach-Object { [ordered]@{catalogId=$_.id;generatorId=$_.generatorId} })
  limitation='All non-executable rows remain NEEDS_REVIEW; documentary classification is complete, executable coverage is intentionally limited to validated Core v5 strategies.'
}
[IO.File]::WriteAllText($coveragePath, ($coverage | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
Write-Output "Imported and classified $($data.Count) rows; generated $DartOutput and $CoverageOutput."

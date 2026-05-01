$ErrorActionPreference = "Stop"
$srcDir = "c:\Users\kupry\Desktop\kalles"
$destDir = "c:\Users\kupry\Desktop\Freyeri Theme v1.0.2"

$queue = New-Object System.Collections.Generic.Queue[string]
$visited = New-Object System.Collections.Generic.HashSet[string]

$initialFiles = @(
    "sections/categories_section.liquid",
    "sections/iconbox.liquid",
    "sections/collections-list-carousel.liquid",
    "sections/collections-list-manual.liquid",
    "sections/collections-list.liquid",
    "sections/pricing-tables.liquid",
    "sections/product-list-simple.liquid",
    "sections/collection-products-deal.liquid",
    "sections/collection-products-banner.liquid",
    "sections/collection-products-banner2.liquid",
    "sections/banner-with-products3.liquid",
    "sections/shipping.liquid",
    "sections/testimonials.liquid",
    "sections/instagram-shop.liquid",
    "sections/slideshow.liquid",
    "sections/heading-template.liquid",
    "assets/base.css",
    "assets/theme.css",
    "assets/global.min.js",
    "assets/des_adm.min.js"
)

foreach ($f in $initialFiles) {
    if (-not $visited.Contains($f)) {
        $visited.Add($f) | Out-Null
        $queue.Enqueue($f)
    }
}

Write-Host "Analyzing dependencies..."

while ($queue.Count -gt 0) {
    $current = $queue.Dequeue()
    $fullPath = Join-Path $srcDir $current
    
    if (-not (Test-Path $fullPath)) {
        Write-Warning "File not found: $current"
        continue
    }

    # Only parse dependencies for text files
    if ($current -match "\.(liquid|css|js|json)$") {
        $content = [IO.File]::ReadAllText($fullPath, [System.Text.Encoding]::UTF8)

        # 1. Snippets (render or include)
        $matches = [regex]::Matches($content, '\{%-?\s*(?:render|include)\s*[''"]([^''"]+)[''"]')
        foreach ($m in $matches) {
            $dep = "snippets/" + $m.Groups[1].Value + ".liquid"
            if (-not $visited.Contains($dep)) {
                $visited.Add($dep) | Out-Null
                $queue.Enqueue($dep)
            }
        }

        # 2. Sections
        $matches = [regex]::Matches($content, '\{%-?\s*section\s*[''"]([^''"]+)[''"]')
        foreach ($m in $matches) {
            $dep = "sections/" + $m.Groups[1].Value + ".liquid"
            if (-not $visited.Contains($dep)) {
                $visited.Add($dep) | Out-Null
                $queue.Enqueue($dep)
            }
        }

        # 3. Assets
        $matches = [regex]::Matches($content, '[''"]([^''"]+)\.(css|js|woff2|woff|ttf|svg|png|jpg|gif)[''"]\s*\|\s*asset(?:_img)?_url')
        foreach ($m in $matches) {
            $dep = "assets/" + $m.Groups[1].Value + "." + $m.Groups[2].Value
            if (-not $visited.Contains($dep)) {
                $visited.Add($dep) | Out-Null
                $queue.Enqueue($dep)
            }
        }
        
        # 4. URL Assets
        $matches = [regex]::Matches($content, 'url\(\s*[''"]?([^''"\)]+\.(css|js|woff2|woff|ttf|svg|png|jpg|gif))[''"]?\s*\)')
        foreach ($m in $matches) {
            $dep = "assets/" + $m.Groups[1].Value
            if (-not $visited.Contains($dep)) {
                $visited.Add($dep) | Out-Null
                $queue.Enqueue($dep)
            }
        }
    }
}

Write-Host "Found $($visited.Count) total dependencies to copy."

# Create arrays for renaming mappings
$renameMaps = @()
foreach ($v in $visited) {
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($v)
    $fileName = [System.IO.Path]::GetFileName($v)
    $renameMaps += [PSCustomObject]@{
        OriginalRelative = $v
        BaseName = $baseName
        FileName = $fileName
    }
}

# Sort by length descending to replace longer names first
$renameMaps = $renameMaps | Sort-Object @{Expression={$_.BaseName.Length}; Descending=$true}

$copiedCount = 0
foreach ($v in $visited) {
    $srcPath = Join-Path $srcDir $v
    if (-not (Test-Path $srcPath)) { continue }

    $fileName = [System.IO.Path]::GetFileName($v)
    $dirName = [System.IO.Path]::GetDirectoryName($v)
    $newName = "kalles-" + $fileName
    $destPath = Join-Path (Join-Path $destDir $dirName) $newName

    # Ensure dest dir exists
    $destDirFull = [System.IO.Path]::GetDirectoryName($destPath)
    if (-not (Test-Path $destDirFull)) {
        New-Item -ItemType Directory -Path $destDirFull | Out-Null
    }

    Copy-Item -Path $srcPath -Destination $destPath -Force
    $copiedCount++
    
    if ($v -match "\.(liquid|css|js|json)$") {
        $content = [IO.File]::ReadAllText($destPath, [System.Text.Encoding]::UTF8)
        
        # Add [Kalles] to schema name
        if ($v.StartsWith("sections/")) {
            $content = [regex]::Replace($content, '(?s)({%\s*schema\s*%}.*?"name"\s*:\s*")([^"]+?)(")', {
                param($match)
                if (-not $match.Groups[2].Value.StartsWith("[Kalles] ")) {
                    return $match.Groups[1].Value + "[Kalles] " + $match.Groups[2].Value + $match.Groups[3].Value
                }
                return $match.Value
            })
        }
        
        # Rewrite references
        foreach ($rm in $renameMaps) {
            $bName = [regex]::Escape($rm.BaseName)
            $fName = [regex]::Escape($rm.FileName)
            
            # {%- render '...' -%}
            $content = [regex]::Replace($content, "(\{%-?\s*(?:render|include|section)\s*['""])($bName)(['""])", "`$1kalles-$($rm.BaseName)`$3")
            # asset_url
            $content = [regex]::Replace($content, "(['""])($fName)(['""]\s*\|\s*asset(?:_img)?_url)", "`$1kalles-$($rm.FileName)`$3")
            # url()
            $content = [regex]::Replace($content, "(url\(\s*['""]?)($fName)(['""]?\s*\))", "`$1kalles-$($rm.FileName)`$3")
        }

        [IO.File]::WriteAllText($destPath, $content, [System.Text.Encoding]::UTF8)
    }
}

Write-Host "Successfully copied and modified $copiedCount files."

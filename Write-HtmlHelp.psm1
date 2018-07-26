#requires -version 3
$script:BootstrapURI = "https://stackpath.bootstrapcdn.com/bootstrap/4.1.3/css/bootstrap.min.css"

function ConvertTo-HtmlString($ToConvert) {
    if ($ToConvert) {
        $String = ($ToConvert | Out-String).Trim()
		if ($String.StartsWith("syntaxItem")) {
			$String = $Help.Synopsis | Out-String
		} elseif ($String.StartsWith("parameter")) {
			$String = $Help.parameters.parameter | Out-String
		} elseif (!$String -or $String -eq "" -or $String.StartsWith("inputType") -or $String.StartsWith("returnValue")) {
			return "<strong>empty</strong>"
		}
		return $String.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')
	} else {
		return "<strong>empty</strong>"
	}
}

function Out-HtmlFile($Title, $Help, $Alias, $Path, $Module) {
	'<!doctype html>
	<html>
		<head>
			<meta charset="UTF-8">
			<link rel="stylesheet" type="text/css" href="../css/bootstrap.min.css">
			<title>' + $(ConvertTo-HtmlString($Help.Name)) + '</title>
		</head>
		<body>
			<nav class="navbar navbar-dark bg-dark navbar-static-top"><a class="navbar-brand" href="../index.html">' + $(ConvertTo-HtmlString($Module)) + '</a></nav>
			<table class="table table-striped">
				<thead class="thead-light">
					<tr>
						<th scope="col" colspan="2">' + $(ConvertTo-HtmlString($Help.Name)) + '</th>
					</tr>
				</thead>
				<tbody>
					<tr>
						<th scope="row">syntax</th>
						<td><pre>' + $(ConvertTo-HtmlString($Help.syntax)) + '</pre></td>
					</tr>
					<tr>
						<th scope="row">alias</th>
						<td><pre>' + $(ConvertTo-HtmlString($Alias.Name)) + '</pre></td>
					</tr>
					<tr>
						<th scope="row">description</th>
						<td><pre>' + $(ConvertTo-HtmlString($Help.description)) + '</pre></td>
					</tr>
					<tr>
						<th scope="row">parameters</th>
						<td><pre>' + $(ConvertTo-HtmlString($Help.parameters)) + '</pre></td>
					</tr>
					<tr>
						<th scope="row">examples</th>
						<td><pre>' + $(ConvertTo-HtmlString($Help.examples)) + '</pre></td>
					</tr>
					<tr>
						<th scope="row">input types</th>
						<td><pre>' + $(ConvertTo-HtmlString($Help.inputTypes)) + '</pre></td>
					</tr>
					<tr>
						<th scope="row">return values</th>
						<td><pre>' + $(ConvertTo-HtmlString($Help.returnValues)) + '</pre></td>
					</tr>
				</tbody>
			</table>
		</body>
	</html>' | Out-File "$Path\$Title.html" -Encoding utf8
}

function Write-IndexPage($Path, $CmdletPath, $Module) {
	$Helpfiles = Get-ChildItem -Path $CmdletPath
	'<!doctype html>
	<html>
		<head>
			<meta charset="UTF-8">
			<link rel="stylesheet" type="text/css" href="css/bootstrap.min.css">
			<title>' + $(ConvertTo-HtmlString($Module)) + '</title>
		</head>
		<body>
			<nav class="navbar navbar-dark bg-dark navbar-static-top"><a class="navbar-brand" href="#">' + $(ConvertTo-HtmlString($Module)) + '</a></nav>
			<table class="table table-striped">
				<tbody>' +
				$(foreach ($Helpfile in $Helpfiles) {
					$Cmd = $Helpfile.Name | Out-String
					$Cmd = $Cmd.Substring(0,$Cmd.Length-7)
					$Synopsis = (Get-Help $Cmd).Synopsis | Out-String
					'<tr>
						<th><a href="html/' + $Helpfile + '">' + $Cmd + '</a></th>
						<th>' + $(if($Synopsis -notmatch $Cmd) { $Synopsis } else { "" }) + '</th>
					</tr>' }) +
				'</tbody>
			</table>
		</body>
	</html>' | Out-File "$Path\index.html" -Encoding utf8
}

function Write-HtmlHelp {
	<#
	.SYNOPSIS
		creates html help files for each cmdlet in a module

	.PARAMETER Module
		the powershell module you wish to get the help files for the cmdlets

	.PARAMETER Path
		the path where the files will be stored
	#>
	[CmdletBinding()]
	param (
		[Parameter(Position=0, Mandatory=$true)]
		[String] $Module,
		[Parameter(Position=1, Mandatory=$true)]
		[String] $Path
	)
    try {
		$ProgressPreference = "SilentlyContinue"
		$ErrorActionPreference = "Stop"
		$Cmdlet = Get-Command -CommandType Cmdlet -Module $Module
		if (!$Cmdlet) {
			throw "module '$Module' not available.."
		}
		$Path = "$Path\$Module"
		$CmdletPath = "$Path\html"
		$StylePath = "$Path\css"
	    if (Test-Path $Path) {
		    throw "directory '$Path' already present.."
	    }
		New-Item -ItemType Directory -Path $Path | Out-Null
	    New-Item -ItemType Directory -Path $CmdletPath | Out-Null
		New-Item -ItemType Directory -Path $StylePath | Out-Null
	    foreach ($Cmd in $Cmdlet) {
		    $Cmd | Add-Member Help (Get-Help -Name $Cmd -Full) -Force
		    $Cmd | Add-Member Alias (Get-Alias -Definition $Cmd -ErrorAction SilentlyContinue) -Force
		    Out-HtmlFile -Title $Cmd.Name -Help $Cmd.Help -Alias $Cmd.Alias -Path $CmdletPath -Module $Module
	    }
	    Write-IndexPage -Path $Path -CmdletPath $CmdletPath -Module $Module
        Invoke-WebRequest -Uri $BootstrapURI -OutFile "$StylePath\bootstrap.min.css"
    } catch {
        Write-Error "failed to write html help: $_"
    }
}

Export-ModuleMember -Function Write-HtmlHelp
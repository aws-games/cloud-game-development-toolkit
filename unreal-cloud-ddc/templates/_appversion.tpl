{{- define "jupiter.appversion" -}}
{{- $versionFile := .Files.Get "version.yaml" | fromYaml -}}
{{- $globals := default nil .Values.global -}}
{{- $globalOverride := default nil $globals.OverrideAppVersion -}}
{{- $versionFileVersion := $versionFile.version -}}
{{- $override := default $versionFileVersion $globalOverride -}}
{{- default .Chart.AppVersion $override -}}
{{- end -}}
{{- define "cloudcart.name" -}}
{{- printf "%s-cloudcart" .Release.Name | trunc 50 | trimSuffix "-" -}}
{{- end -}}

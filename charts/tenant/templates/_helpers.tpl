{{- define "tenant.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
platform.example.io/tenant: {{ .Values.name }}
{{- end -}}

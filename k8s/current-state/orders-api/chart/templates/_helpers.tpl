{{- define "orders-api.labels" -}}
app.kubernetes.io/name: orders-api
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: asteria
app.kubernetes.io/managed-by: {{ .Release.Service }}
asteria.io/deployment-method: helm
{{- end }}

{{- define "orders-api.selectorLabels" -}}
app.kubernetes.io/name: orders-api
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

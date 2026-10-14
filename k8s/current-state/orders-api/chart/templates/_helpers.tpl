{{- define "orders-api.labels" -}}
app.kubernetes.io/name: orders-api
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: asteria
app.kubernetes.io/managed-by: {{ .Release.Service }}
asteria.io/deployment-method: helm
{{- end }}

{{- define "orders-api.image" -}}
{{- if .Values.image.digest -}}
{{- if not (regexMatch "^sha256:[a-f0-9]{64}$" .Values.image.digest) -}}
{{- fail "image.digest must be sha256 followed by 64 lowercase hexadecimal characters" -}}
{{- end -}}
{{- printf "%s@%s" .Values.image.repository .Values.image.digest -}}
{{- else -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}
{{- end -}}

{{- define "orders-api.selectorLabels" -}}
app.kubernetes.io/name: orders-api
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

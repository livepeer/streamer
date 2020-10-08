{{/*
Expand the name of the chart.
*/}}
{{- define "stream-monitor.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "stream-monitor.fullname" -}}
{{- $name := .Chart.Name }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "stream-monitor.streamName" -}}
{{- if contains .root.Chart.Name .root.Release.Name }}
{{- printf "%s-%s" .root.Release.Name .stream.name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s-%s" .root.Release.Name .root.Chart.Name .stream.name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "stream-monitor.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "stream-monitor.selectorLabels" -}}
app.kubernetes.io/name: {{ include "stream-monitor.name" .root }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
test.livepeer.io/name: {{ .stream.name }}
test.livepeer.io/duration: {{ .stream.duration }}
test.livepeer.io/injest_region: {{ .stream.injest_region }}
test.livepeer.io/playback_region: {{ .stream.playback_region }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "stream-monitor.labels" -}}
helm.sh/chart: {{ include "stream-monitor.chart" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "stream-monitor.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "stream-monitor.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

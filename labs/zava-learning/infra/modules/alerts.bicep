// Symptom-only alert rules + Azure Monitor action group.
// IMPORTANT: alert names/descriptions describe the OBSERVED SYMPTOM only and must
// never reveal the root cause (NSG / LB / AppGW / app) — that is the SRE Agent's job.
@description('Azure region for the alert rules (must be a real region, not global).')
param location string
@description('Resource name suffix token.')
param resourceToken string
@description('Tags applied to all resources.')
param tags object = {}
@description('Log Analytics workspace resource id (alert scope).')
param logAnalyticsWorkspaceId string
@description('Application Gateway resource id (scope for the backend-unhealthy metric alert).')
param applicationGatewayId string

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-zava-azmon-${resourceToken}'
  location: 'global'
  tags: tags
  properties: {
    groupShortName: 'zavaAzMon'
    enabled: true
    // Alerts fire into Azure Monitor; the SRE Agent picks them up as incidents.
    webhookReceivers: []
  }
}

resource quizLaunchFailing 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'Zava-quiz-launch-failing'
  location: location
  tags: tags
  properties: {
    description: 'Students are unable to launch quizzes from the portal.'
    severity: 1
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    scopes: [ logAnalyticsWorkspaceId ]
    criteria: {
      allOf: [
        {
          query: 'ContainerAppConsoleLogs_CL\n| where ContainerAppName_s == "learner-portal"\n| where Log_s has "quiz_launch_failed"\n| summarize AggregatedValue = count() by bin(TimeGenerated, 5m)'
          metricMeasureColumn: 'AggregatedValue'
          timeAggregation: 'Total'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: { numberOfEvaluationPeriods: 1, minFailingPeriodsToAlert: 1 }
        }
      ]
    }
    skipQueryValidation: true
    autoMitigate: false
    actions: { actionGroups: [ actionGroup.id ] }
  }
}

resource portal5xxElevated 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'Zava-portal-5xx-elevated'
  location: location
  tags: tags
  properties: {
    description: 'Elevated rate of failed responses from the student portal.'
    severity: 2
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    scopes: [ logAnalyticsWorkspaceId ]
    criteria: {
      allOf: [
        {
          query: 'ContainerAppConsoleLogs_CL\n| where ContainerAppName_s == "learner-portal"\n| where Log_s has_any ("unavailable", "502", "503")\n| summarize AggregatedValue = count() by bin(TimeGenerated, 5m)'
          metricMeasureColumn: 'AggregatedValue'
          timeAggregation: 'Total'
          operator: 'GreaterThan'
          threshold: 5
          failingPeriods: { numberOfEvaluationPeriods: 1, minFailingPeriodsToAlert: 1 }
        }
      ]
    }
    skipQueryValidation: true
    autoMitigate: false
    actions: { actionGroups: [ actionGroup.id ] }
  }
}

resource quizApiLatencyElevated 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'Zava-quiz-api-latency-elevated'
  location: location
  tags: tags
  properties: {
    description: 'Quiz responses are slower than usual for students.'
    severity: 2
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    scopes: [ logAnalyticsWorkspaceId ]
    criteria: {
      allOf: [
        {
          query: 'ContainerAppConsoleLogs_CL\n| where ContainerAppName_s == "assessment-api"\n| where Log_s has "ms="\n| extend ms = toint(extract(@"ms=(\\d+)", 1, Log_s))\n| where isnotnull(ms)\n| summarize AggregatedValue = percentile(ms, 95) by bin(TimeGenerated, 5m)'
          metricMeasureColumn: 'AggregatedValue'
          timeAggregation: 'Average'
          operator: 'GreaterThan'
          threshold: 500
          failingPeriods: { numberOfEvaluationPeriods: 1, minFailingPeriodsToAlert: 1 }
        }
      ]
    }
    skipQueryValidation: true
    autoMitigate: false
    actions: { actionGroups: [ actionGroup.id ] }
  }
}

resource gradeExportsFailing 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'Zava-grade-exports-failing'
  location: location
  tags: tags
  properties: {
    description: 'Zava reporting: nightly grade exports are failing to produce export files.'
    severity: 2
    enabled: true
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    scopes: [ logAnalyticsWorkspaceId ]
    criteria: {
      allOf: [
        {
          query: 'Syslog\n| where ProcessName == "zava-export"\n| where SyslogMessage has "FAILED"\n| summarize AggregatedValue = count() by bin(TimeGenerated, 5m)'
          metricMeasureColumn: 'AggregatedValue'
          timeAggregation: 'Total'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: { numberOfEvaluationPeriods: 1, minFailingPeriodsToAlert: 1 }
        }
      ]
    }
    skipQueryValidation: true
    autoMitigate: false
    // Not wired to an action group receiver. The disk scenario's break-disk.ps1 injects the
    // fault; this rule fires in Azure Monitor as portal evidence, and the SRE Agent picks it
    // up as an incident through the Azure Monitor incident integration.
    actions: {}
  }
}

// Native platform-metric alert (no logs required): fires when App Gateway reports an unhealthy
// backend — e.g. when a connectivity fault (legacy NSG DENY) blackholes App Gateway -> apps and the
// log-based query rules see no portal traffic. This is the Azure Monitor incident source for the
// connectivity-blackhole scenario; the SRE Agent picks it up and investigates.
resource portalUnreachable 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Zava-portal-unreachable'
  location: 'global'
  tags: tags
  properties: {
    description: 'Students cannot reach the learner portal — App Gateway backend is unhealthy.'
    severity: 1
    enabled: true
    scopes: [ applicationGatewayId ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'UnhealthyHosts'
          metricNamespace: 'Microsoft.Network/applicationGateways'
          metricName: 'UnhealthyHostCount'
          operator: 'GreaterThanOrEqual'
          threshold: 1
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    autoMitigate: true
    actions: [ { actionGroupId: actionGroup.id } ]
  }
}

output actionGroupId string = actionGroup.id
output actionGroupName string = actionGroup.name

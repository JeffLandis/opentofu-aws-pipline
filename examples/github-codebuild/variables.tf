variable "region" {
  type = string
  default = "ap-southeast-1"
}

variable "s3_buckets" {
  type = list(any)
}

variable "pipeline" {
  type = object({
    codestar_connections                = any
    codestar_connection_hosts           = any
    host_vpc_configurations             = any
    pipelines                           = any
    pipeline_artifact_stores            = any
    pipeline_stages                     = any
    pipeline_stage_actions              = any
    pipeline_triggers                   = any
    pipeline_trigger_git_configurations = any
    git_configuration_filters           = any
    pipeline_variables                  = any
    codestarsourceconnection_action_configurations = any
    codebuild_action_configurations     = any
    tags                                = map(string)
  })
}

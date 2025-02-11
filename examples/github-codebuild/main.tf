terraform {
  required_providers {
    aws = {
      source = "opentofu/aws"
      version = "5.80.0"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
        default-tag = "true"
    }
  }
}

module "pipeline" {
  source = "../../"
    region                              = var.region
    codestar_connections                = var.pipeline.codestar_connections
    codestar_connection_hosts           = var.pipeline.codestar_connection_hosts
    host_vpc_configurations             = var.pipeline.host_vpc_configurations
    pipelines                           = var.pipeline.pipelines
    pipeline_artifact_stores            = var.pipeline.pipeline_artifact_stores
    pipeline_stages                     = var.pipeline.pipeline_stages
    pipeline_stage_actions              = var.pipeline.pipeline_stage_actions
    pipeline_triggers                   = var.pipeline.pipeline_triggers
    pipeline_trigger_git_configurations = var.pipeline.pipeline_trigger_git_configurations
    git_configuration_filters           = var.pipeline.git_configuration_filters
    pipeline_variables                  = var.pipeline.pipeline_variables
    tags                                = var.pipeline.tags
    codestarsourceconnection_action_configurations = var.pipeline.codestarsourceconnection_action_configurations
    codebuild_action_configurations     = var.pipeline.codebuild_action_configurations
}

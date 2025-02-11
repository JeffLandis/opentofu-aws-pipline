locals {

  default_artifact_store_bucket = {
    prefix = "codepipeline"
    force_destroy = true
    tags = var.tags
  }

  pipeline_artifact_stores = {
    for val in var.pipeline_artifact_stores: val.name => merge(
      val,
      {
        location = coalesce(val.location, try(one(module.default_artifact_store_bucket).buckets[local.default_artifact_store_bucket.prefix].name, null))
        encryption_key = val.encryption_key == null ? {} : val.encryption_key 
      }
    )
  }

  pipelines = {
    for val in var.pipelines: val.name => merge(
      val,
      {
        artifact_stores = [ for k,v in local.pipeline_artifact_stores: v if contains(val.artifact_store_names, k) ]
        stages =  [ for k,v in local.pipeline_stages: v if contains(val.stage_names, v.name) ]
        triggers =  [ for k,v in local.pipeline_triggers: v if contains(val.trigger_names, k) ]
        variables =  [ for v in var.pipeline_variables: v if contains(val.variable_names, coalesce(v.key, v.name)) ]
      }
    )
  }

  pipeline_stages = {
    for i, val in var.pipeline_stages: "${i}/${val.name}" => merge(
      val,
      {
        action = one([ for k,v in local.pipeline_stage_actions: v if val.action_name == k ])
      }
    )
  }

  pipeline_stage_actions = {
    for psa in var.pipeline_stage_actions: psa.name => merge(
      psa,
      {
        configuration = merge(
          try(lookup(local.codebuild_action_configurations, psa.configuration_name, {}), {}),
          try(lookup(local.codestarsourceconnection_action_configurations, psa.configuration_name, {}), {}),
          psa.configuration == null ? {} : psa.configuration
        )
      }
    )
  }

  codebuild_action_configurations = {
    for val in var.codebuild_action_configurations: val.name => {
      ProjectName = val.project_name
      PrimarySource = val.primary_source
      BatchEnabled = val.batch_enabled
      CombineArtifacts = val.combine_artifacts
      EnvironmentVariables = jsonencode(val.environment_variables)
    }
  }

  codestarsourceconnection_action_configurations = {
    for val in var.codestarsourceconnection_action_configurations: val.name => {
        ConnectionArn = aws_codestarconnections_connection.this[val.codestar_connection_name].arn
        FullRepositoryId = val.full_repository_id
        BranchName = val.branch_name
        OutputArtifactFormat = val.output_artifact_format
        DetectChanges = val.detect_changes
    }
  }

  pipeline_triggers = {
    for val in var.pipeline_triggers: val.name => {
      name = val.name
      provider_type = val.provider_type
      git_configuration = local.pipeline_trigger_git_configurations[val.git_configuration_name]
    }
  }

  pipeline_trigger_git_configurations = {
    for val in var.pipeline_trigger_git_configurations: val.name => {
      source_action_name = val.source_action_name
      pull_requests = [ 
        for val in val.pull_request_filters: {
          events = val.events
          branches = try(local.git_configuration_filters[val.branch_filter_name], null)
          file_paths = try(local.git_configuration_filters[val.file_path_filter_name], null)
        }
      ]
      pushes = [ 
        for val in val.push_filters: {
          branches = try(local.git_configuration_filters[val.branch_filter_name], null)
          file_paths = try(local.git_configuration_filters[val.file_path_filter_name], null)
          tags = try(local.git_configuration_filters[val.tag_filter_name], null)
        }
      ]
    }
  }

  git_configuration_filters = {
    for val in var.git_configuration_filters: val.name => {
      for k, v in val: k => v if k != "name"
    }
  }
}

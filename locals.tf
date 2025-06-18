locals {

  # default_artifact_store_bucket = {
  #   prefix = "codepipeline"
  #   force_destroy = true
  #   tags = var.tags
  # }

  # buckets = [ for k,v in module.s3_buckets.buckets: merge(
  #     v,
  #     {
  #       key = one([ for val in var.artifact_store_buckets: val.key if coalesce(val.prefix, val.name) == k  ])
  #       prefix = one([ for val in var.artifact_store_buckets: val.prefix if val.prefix == k ])
  #     }
  #   )
  # ]

  pipeline_artifact_stores = {
    for val in var.artifact_stores: val.name => merge(
      val,
      {
        location = module.s3_buckets.buckets[val.artifact_store_bucket].name
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
        variables =  [ for v in var.variables: v if contains(val.variable_names, coalesce(v.key, v.name)) ]
      }
    )
  }

  pipeline_stages = {
    for i, val in var.stages: "${i}/${val.name}" => merge(
      val,
      {
        action = lookup(local.stage_actions, val.action_key, {})
      }
    )
  }

  stage_actions_parents_merged = { for k,v in var.stage_actions: k => {
      for attr_name, attr_value in v: attr_name => try(
        coalesce(concat([attr_value], [for parent in reverse(v.parent_keys): var.stage_actions[parent][attr_name]])...), null
      )
    }
  }

  stage_actions = { for k,v in local.stage_actions_parents_merged: k=> merge(
        v,
        {
          configuration = merge(
            try(lookup(local.codebuild_action_configurations, v.configuration_key, {}), {}),
            try(lookup(local.codestarsourceconnection_action_configurations, v.configuration_key, {}), {}),
            v.configuration == null ? {} : v.configuration
          )
        }
      )
  }

  codebuild_action_configurations = {
    for k,v in var.codebuild_action_configurations: k => {
      ProjectName = v.project_name
      PrimarySource = v.primary_source
      BatchEnabled = v.batch_enabled
      CombineArtifacts = v.combine_artifacts
      EnvironmentVariables = jsonencode(v.environment_variables)
    }
  }

  codestarsourceconnection_action_configurations = {
    for k,v in var.codestarsourceconnection_action_configurations: k => {
        ConnectionArn = aws_codestarconnections_connection.this[v.codestar_connection_name].arn
        FullRepositoryId = v.full_repository_id
        BranchName = v.branch_name
        OutputArtifactFormat = v.output_artifact_format
        DetectChanges = v.detect_changes
    }
  }

  pipeline_triggers = {
    for val in var.triggers: val.name => {
      name = val.name
      provider_type = val.provider_type
      git_configuration = local.pipeline_trigger_git_configurations[val.git_configuration_name]
    }
  }

  pipeline_trigger_git_configurations = {
    for val in var.trigger_git_configurations: val.name => {
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

  codebuild_actions = {
    for k,v in aws_codepipeline.this: k => {
      artifact_store_buckets = [ for b in v.artifact_store: b.location if b.type == "S3" ]
      code_build_project_names = [ for a in flatten(v.stage[*].action): a.configuration.ProjectName if a.provider == "CodeBuild" ]
    }
    if length([ for a in flatten(v.stage[*].action): a.configuration.ProjectName if a.provider == "CodeBuild" ]) > 0
  }

  artifact_store_buckets = [
    { for k,v in local.codebuild_actions: k => v.artifact_store_buckets }
  ]

  code_build_project_names = [
    { for k,v in local.codebuild_actions: k => v.code_build_project_names }
  ]

}

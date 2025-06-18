output "pipelines" {
  value = aws_codepipeline.this
}

output "artifact_store_buckets" {
  value = module.s3_buckets[*].buckets
}

output "artifact_stores_for_codebuild" {
  value = flatten([
    for k,v in local.codebuild_actions: [
      for p in v.code_build_project_names: {
        codebuild_project_name = p
        artifact_store_buckets = v.artifact_store_buckets
      }
    ]
  ])
}

# output "stage_actions" {
#   value = local.stage_actions
# }

# output "codestarconnections_connections" {
#   value = aws_codestarconnections_connection.this
# }

# output "iam_role" {
#   value = aws_iam_role.codepipeline
# }

# output "local_pipelines" {
#   value = local.pipelines
# }

# output "aws_iam_policy_document" {
#   value = data.aws_iam_policy_document.codepipeline_policy
# }

# output "default_artifact_store_bucket" {
#   value = flatten([ 
#     for val in module.default_artifact_store_bucket[*].buckets: 
#       concat(
#         [ for k,v in val: v.arn ],
#         [ for k,v in val: "${v.arn}/*" ]
#       )
#     ])
# }

# output "aws_codestarconnections_connection" {
#   value = [ for k,v in aws_codestarconnections_connection.this: v.arn ]
# }

# output "pipeline_stages_indexed" {
#   value = local.pipeline_stages_indexed
# }

# output "pipeline_stages" {
#   value = local.pipeline_stages
# }

# output "codebuild_action_configurations" {
#   value = var.codebuild_action_configurations
# }

# output "pipeline_artifact_stores" {
#   value = local.pipeline_artifact_stores
# }

# output "pipeline_stage_actions" {
#   value = local.pipeline_stage_actions
# }

# output "pipeline_triggers" {
#   value = local.pipeline_triggers
# }

# output "pipeline_trigger_git_configurations" {
#   value = {
#     loc = local.pipeline_trigger_git_configurations
#     var = var.pipeline_trigger_git_configurations
#   }
# }

# output "git_configuration_filters" {
#   value = local.git_configuration_filters
# }

# output "pipeline_variables" {
#   value = var.pipeline_variables
# }

# output "tags" {
#   value = var.tags
# }

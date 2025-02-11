module "default_artifact_store_bucket" {
  source = "git::https://github.com/JeffLandis/opentofu-aws-s3.git?ref=v0.1.0"
  count = anytrue([for val in var.pipeline_artifact_stores: val.location == null]) ? 1 : 0
  buckets = [ local.default_artifact_store_bucket ]
}

# The aws_codestarconnections_connection resource is created in the state PENDING. 
# Authentication with the connection provider must be completed in the AWS Console. 
# See the AWS documentation for details. 
# https://docs.aws.amazon.com/dtconsole/latest/userguide/connections-update.html
resource "aws_codestarconnections_connection" "this" {
  for_each      = { for val in var.codestar_connections : val.name => val }
  name          = each.key
  provider_type = each.value.provider_type
}

resource "aws_iam_role" "codepipeline" {
  for_each = toset([ for v in local.pipelines: v.role_name ])
  name = each.value
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  for_each = aws_iam_role.codepipeline
  name   = "${each.value.name}Policy"
  role   = each.value.id
  policy = data.aws_iam_policy_document.codepipeline_policy.json
}

resource "aws_codepipeline" "this" {
  for_each = local.pipelines
  name = each.value.name
  pipeline_type = each.value.pipeline_type
  execution_mode = each.value.execution_mode
  role_arn = aws_iam_role.codepipeline[each.value.role_name].arn
  tags = merge(var.tags, each.value.tags)

  dynamic "artifact_store" {
    for_each = each.value.artifact_stores
    content {
      location = artifact_store.value.location
      type = artifact_store.value.type
      region = artifact_store.value.region
      dynamic "encryption_key" {
        for_each = artifact_store.value.encryption_key
        content {
          id = encryption_key.value["id"]
          type = encryption_key.value["type"]
        }
      }
    }
  }

  dynamic "stage" {
    for_each = each.value.stages
    content {
      name = stage.value.name
      action {
        name = stage.value.action.name
        category = stage.value.action.category
        owner = stage.value.action.owner
        provider = stage.value.action.provider
        version = stage.value.action.version
        input_artifacts = stage.value.action.input_artifacts
        output_artifacts = stage.value.action.output_artifacts
        role_arn = aws_iam_role.codepipeline[stage.value.action.role_name].arn
        run_order = stage.value.action.run_order
        region = stage.value.action.region
        namespace = stage.value.action.namespace
        configuration = stage.value.action.configuration
      }
    }
  }

  dynamic "trigger" {
    for_each = each.value.triggers
    content {
      provider_type = trigger.value.provider_type
      git_configuration {
        source_action_name = trigger.value.git_configuration.source_action_name
        dynamic "pull_request" {
          for_each = trigger.value.git_configuration.pull_requests
          content {
            events = pull_request.value.events
            dynamic "branches" {
              for_each = pull_request.value.branches == null ? [] : [pull_request.value.branches]
              content {
                includes = branches.value["includes"]
                excludes = branches.value["excludes"]
              }
            }
            dynamic "file_paths" {
              for_each = pull_request.value.file_paths == null ? [] : [pull_request.value.file_paths]
              content {
                includes = file_paths.value.includes
                excludes = file_paths.value.excludes
              }
            }
          }
        }
        dynamic "push" {
          for_each = trigger.value.git_configuration.pushes
          content {
            dynamic "tags" {
              for_each = push.value.tags == null ? [] : [push.value.tags]
              content {
                includes = tags.value.includes
                excludes = tags.value.excludes
              }
            }
            dynamic "branches" {
              for_each = push.value.branches == null ? [] : [push.value.branches]
              content {
                includes = branches.value.includes
                excludes = branches.value.excludes
              }
            }
            dynamic "file_paths" {
              for_each = push.value.file_paths == null ? [] : [push.value.file_paths]
              content {
                includes = file_paths.value.includes
                excludes = file_paths.value.excludes
              }
            }
          }
        }
      }
    }
  }

  dynamic "variable" {
    for_each = each.value.variables
    content {
      name = variable.value.name
      default_value = variable.value.default_value
      description = variable.value.description
    }
  }
}

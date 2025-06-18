#####################################################################
# REGION
#####################################################################
variable "region" {
  type = string
  description = "Default region"
}

#####################################################################
# S3 BUCKETS
#####################################################################
variable "artifact_store_buckets" {
  type = list(object({
    name = optional(string, null)
    prefix = optional(string, null)
    force_destroy = optional(bool, true)
    tags = optional(map(string), {})
  }))
  default = []
  nullable = false
  validation {
    condition = alltrue([
      for v in var.artifact_store_buckets : anytrue([
        alltrue([ v.name != null, try(length(v.name), 0) > 0, try(length(v.name), 80) < 64 ]),
        alltrue([ v.prefix != null, try(length(v.prefix), 0) > 0, try(length(v.prefix), 80) < 38 ])
      ])
    ])
    error_message = <<-EOT
A valid bucket 'name' or 'prefix' is required, 'name' has precedence.
Must be lowercase, 'name' less than 64 characters and 'prefix' less than 38 characters.
EOT
  }
  description = <<-EOT
List of S3 buckets. At a minimum, 'name' **or** 'prefix' is required, 'name' has precedence.
The `name` or `prefix` is used as `artifact_store_bucket` in `artifact_stores` variable and must be unique to identify each bucket.
This will create private buckets with the following configuration. An IAM policy will be added to the build projects role for access.
(versioning disabled, encrypted with aws/s3 KMS key, block all public access, bucket owner enforced, no bucket policy)
If you require a special configuration then you'll need to create the bucket separately and provide the bucket's name.

[Bucket naming rules](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucketnamingrules.html)
| Attribute Name                         | Required?   | Default             | Description                                                                                                           |
|:---------------------------------------|:-----------:|:-------------------:|:----------------------------------------------------------------------------------------------------------------------|
| name                                   | conditional | null                | Name of the bucket, lowercase and less than 64 characters. Must specify name OR prefix.                               |
| prefix                                 | conditional | null                | Creates unique bucket name beginning with prefix, lowercase and less than 38 characters. Must specify name OR prefix. |
| force_destroy                          | optional    | true                | Whether all objects should be deleted when bucket is destroyed.                                                       |
| tags                                   | optional    | { }                 | A map of tags to assign to the bucket.                                                                                |      
EOT
}

#####################################################################
# CODESTAR CONNECTIONS
#####################################################################
variable "codestar_connections" {
  type = list(object({
    name = string
    provider_type = optional(string, null)
    host_name = optional(string, null)
    tags = optional(map(string), {})
  }))
  default = []
  description = <<-EOT
List of CodeStar Connections.
Connections are created in the PENDING state. Authentication with the connection provider must be completed in the AWS Console.

[Update a pending connection](https://docs.aws.amazon.com/dtconsole/latest/userguide/connections-update.html). 
| Attribute Name | Required?   | Default | Description                                                                                                                                                            |
|:---------------|:-----------:|:-------:|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| name           | required    |         | The name of the connection to be created.                                                                                                                              |
| provider_type  | conditional |         | Name of provider where your third-party code repository is configured (Bitbucket, GitHub, GitHubEnterpriseServer, GitLab, GitLabSelfManaged). Conflicts with host_arn. |
| host_name      | conditional |         | Name of host from codestarconnection_hosts. Either provider_type **or** host_name is required but not both.                                                          |
| tags           | optional    | { }     | A map of tags to assign to the resource.                                                                                                                               |
EOT
}

#####################################################################
# CODESTAR CONNECTION HOSTS
#####################################################################
variable "codestar_connection_hosts" {
  type = list(object({
    name = optional(string, null)
    provider_endpoint = string
    provider_type = optional(string, "GitHubEnterpriseServer")
    vpc_configuration_name = optional(string, null)
  }))
  default = []
  description = <<-EOT
List of CodeStar Connection Hosts.
Hosts are created in the PENDING state. Authentication with the host provider must be completed in the AWS Console.

[Set up a pending host](https://docs.aws.amazon.com/dtconsole/latest/userguide/connections-host-setup.html). 
| Attribute Name         | Required? | Default                | Description                                                                                                 |
|:-----------------------|:---------:|:----------------------:|:------------------------------------------------------------------------------------------------------------|
| name                   | required  |                        | Name of the host to be created. The name must be unique in the calling AWS account.                         |
| provider_endpoint      | required  |                        | Endpoint of the infrastructure where your provider type is installed.                                       |
| provider_type          | optional  | GitHubEnterpriseServer | Name of the installed provider to be associated with your connection. Default is GitHubEnterpriseServer.    |
| vpc_configuration_name | optional  | null                   | Name of the VPC configuration from host_vpc_configurations.                                                 |
EOT
}

#####################################################################
# CODESTAR CONNECTION HOST VPC CONFIGURATIONS
#####################################################################
variable "host_vpc_configurations" {
  type = list(object({
    name = string
    vpc_id = string
    subnet_ids = list(string)
    security_group_ids = list(string)
    tls_certificate = optional(string, null)
  }))
  default = []
  description = <<-EOT
List of VPC configurations for Codestar connection hosts.
| Attribute Name     | Required? | Default | Description                                                                                                 |
|:-------------------|:---------:|:-------:|:------------------------------------------------------------------------------------------------------------|
| name               | required  |         | Unique name to identify configuration, used as vpc_configuration_name in codestarconnection_hosts variable. |
| vpc_id             | required  |         | VPC id connected to the infrastructure where your provider type is installed.                               |
| subnet_ids         | required  |         | List of subnet ids associated with the VPC where your provider type is installed.                           |
| security_group_ids | required  |         | List of security group ids associated with the VPC where your provider type is installed.                   |
| tls_certificate    | optional  | null    | Value of the TLS certificate associated with the infrastructure where your provider type is installed.      |
EOT
}

#####################################################################
# PIPELINES 
#####################################################################
variable "pipelines" {
  type = list(object({
    name = string
    pipeline_type = optional(string, "V1")
    role_name = string
    role_policy = optional(string, null)
    execution_mode = optional(string, "SUPERSEDED")
    artifact_store_names = list(string)
    stage_names = list(string)
    trigger_names = optional(list(string), [])
    variable_names = optional(list(string), [])
    tags = optional(map(string), {})
  }))
  default = []
  description = <<-EOT
List of AWS [CodePipelines](https://docs.aws.amazon.com/codepipeline/latest/userguide/pipeline-requirements.html).

Resource: [aws_codepipeline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codepipeline)
| Attribute Name       | Required? | Default | Description                                                                                 |
|:---------------------|:---------:|:-------:|:--------------------------------------------------------------------------------------------|
| name                 | required  |            | Name of the pipeline. Maximum length of 100. Pattern: [A-Za-z0-9.@\-_]+                  |
| pipeline_type        | optional  | V1         | Type of the pipeline. Possible values are: V1 and V2. Default value is V1.               |
| role_name            | required  |            | IAM service role name that grants CodePipeline permission to make calls to AWS services. |
| execution_mode       | optional  | SUPERSEDED | Method pipeline will use to handle multiple executions (QUEUED, SUPERSEDED, PARALLEL).   |
| artifact_store_names | required  | [ ]        | List of names of artifact_stores. At least 1 required.                          |
| stage_names          | required  | [ ]        | List of names of stages. At least 2 required.                                   |
| trigger_names        | optional  | [ ]        | List of names of triggers. Valid only when pipeline_type is V2.                 |
| variable_names       | optional  | [ ]        | List of keys or names of variables. Valid only when pipeline_type is V2.        |
| tags                 | optional  | { }        | A map of tags to assign to the resource.                                                 |
EOT
}

#####################################################################
## PIPELINE ARTIFACT STORES
#####################################################################
variable "artifact_stores" {
  type = list(object({
    name = string
    artifact_store_bucket = string
    type = optional(string, "S3")
    region = optional(string, null)
    encryption_key = optional(object({
      id = string
      type = optional(string, "KMS") }), null)
  }))
  default = []
  description = <<-EOT
List of artifact stores for storage of input and output artifacts. At least 1 is required.
| Attribute Name        | Required?   | Default | Description                                                                                                                |
|:----------------------|:-----------:|:-------:|:---------------------------------------------------------------------------------------------------------------------------|
| name                  | required    |         | Unique name to identify the artifact store, used as artifact_store_names in pipelines variable.                            |
| artifact_store_bucket | required    |         | The `name` or `prefix` from the `artifact_store_bucket` variable that identifies the artifact store S3 bucket.             |
| type                  | optional    | S3      | Type of artifact store. Defaults to S3.                                                                                    |
| region                | optional    | null    | Region where the artifact store is located. Only required for a cross-region pipeline.                                     |
| encryption_key        | optional    | null    | Encryption key to use to encrypt data in artifact store. Defaults to default key for S3.                                   |
| &ensp; id             | required    |         | KMS key ARN or ID.                                                                                                         |
| &ensp; type           | optional    | KMS     | Type of key, currently only KMS is supported.                                                                              |
EOT
}

#####################################################################
## PIPELINE STAGES
#####################################################################
variable "stages" {
  type = list(object({
    name = string
    action_key = string
  }))
  default = []
  description = <<-EOT
List of stages that can be included in a pipeline stages.  At least 2 are required. 
| Attribute Name | Required? | Default | Description                                                                               |
|:---------------|:---------:|:-------:|:------------------------------------------------------------------------------------------|
| name           | required  |         | Unique name to identify the stage, used as stage_names in pipelines variable.             |
| action_key     | required  |         | Key from `stage_actions` variable that identifies the action configuration for the stage. |
EOT
}

#####################################################################
## PIPELINE STAGE ACTIONS
#####################################################################
variable "stage_actions" {
  type = map(object({
    name = optional(string, null)
    category = optional(string, null) # Source | Build | Deploy | Test | Invoke | Approval | Compute
    owner = optional(string, null) # AWS | ThirdParty | Custom
    provider = optional(string, null)
    version = optional(string, null)
    input_artifacts = optional(list(string), null)
    output_artifacts = optional(list(string), null)
    role_name = optional(string, null)
    run_order = optional(number, null)
    region = optional(string, null)
    namespace = optional(string, null)
    configuration = optional(map(string), {})
    configuration_key = optional(string, null)
    parent_keys = optional(list(string), [])
    is_parent = optional(bool, false)
  }))
  default = { }
  description = <<-EOT
Map of stage actions that can be included in pipeline stages. The map's key is used as `action_key` in `stages` variable and must be unique to identify each stage action. 
The configuration_key and configuration attributes specify the provider's configuration. 
Normally you would use one or the other, configuration_key for one of the predefined variables or configuration for something not defined here. 
If both are used, the key-value map provided as configuration will be merged into the configuration specified in configuration_key.

[Configuration Parameters](https://docs.aws.amazon.com/codepipeline/latest/userguide/structure-configuration-examples.html)
| Attribute Name     | Required? | Default | Description                                                                                                                                                                                                      |
|:-------------------|:---------:|:-------:|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| name               | required  |         | The action declaration's name.                                                                                                                                      |
| category           | required  |         | Category defines what kind of action can be taken in the stage (Approval, Build, Deploy, Invoke, Source and Test).                                                                                               |
| owner              | required  |         | The creator of the action being called (AWS, Custom, ThirdParty).                                                                                                                                                |
| provider           | required  |         | [Provider](https://docs.aws.amazon.com/codepipeline/latest/userguide/actions-valid-providers.html) of the service being called by the action.                                                                    |
| version            | required  |         | String that describes the action version.                                                                                                                                                                        |
| input_artifacts    | optional  | null    | List of artifact names to be worked on.                                                                                                                                                                          |
| output_artifacts   | optional  | null    | List of artifact names to output.                                                                                                                                                                                |
| role_name          | optional  | null    | Name of the IAM service role that performs the declared action. This is assumed through the roleArn for the pipeline.                                                                                            |
| run_order          | optional  | null    | Order in which actions are run.                                                                                                                                                                                  |
| region             | optional  | null    | Action declaration's AWS Region, such as us-east-1.                                                                                                                                                              |
| namespace          | optional  | null    | Variable namespace associated with the action. All variables produced as output by this action fall under this namespace.                                                                                        |
| configuration      | optional  | null    | Key-value pairs that specify input values for an action. This allows custom configurations that are not defined as a variable.                                                                                   |
| configuration_key  | optional  | null    | Key of a configuration from one of the pipeline stage action configurations variables. (`codestarsourceconnection_action_configurations`, `codebuild_action_configurations`)                                     |
| parent_key         | optional  | null    | Key of parent `stage_actions` variable. Configuration will inherit values from parent variable. Useful for reusing default values.                                                                               | 
| is_parent          | optional  | false   | If set to true, this stage action configuration can only be used as a parent. Useful for setting default values to be reused by child stage actions.                                                             |
EOT
}

#####################################################################
## PIPELINE TRIGGERS
#####################################################################
variable "triggers" {
  type = list(object({
    name = string
    provider_type = optional(string, "CodeStarSourceConnection")
    git_configuration_name = string
  }))
  default = [ ]
  description = <<-EOT
List of filter criteria and source stage that can trigger a pipeline.
| Attribute Name         | Required? | Default                  | Description                                                                                                        |
|:-----------------------|:---------:|:------------------------:|:-------------------------------------------------------------------------------------------------------------------|
| name                   | required  |                          | Unique name to identify the trigger, used as trigger_names in pipelines variable.                                  |
| provider_type          | optional  | CodeStarSourceConnection | The source provider for the event. Defaults to CodeStarSourceConnection.                                           |
| git_configuration_name | required  |                          | Name of configuration from trigger_git_configurations that provides criteria that can trigger a pipeline. |
EOT
}

#####################################################################
## PIPELINE TRIGGER GIT CONFIGURATIONS
#####################################################################
variable "trigger_git_configurations" {
  type = list(object({
    name = string
    source_action_name = string
    push_filters = optional(list(object({
      branch_filter_name = optional(string, null)
      file_path_filter_name = optional(string, null)
      tag_filter_name = optional(string, null)
    })), [])
    pull_request_filters = optional(list(object({
      events = optional(list(string), null)
      branch_filter_name = optional(string, null)
      file_path_filter_name = optional(string, null)
    })), [])
  }))
  default = [ ]
  description = <<-EOT
Map of Git-based Configurations for source actions that can trigger a pipeline.
No filters: starts your pipeline on any push to the default branch specified as part of action configuration.
Specify filters: starts your pipeline on a specific filter and fetches the exact commit.

[git_configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codepipeline#git_configuration-2)
| Attribute Name       | Required?   | Default  | Description                                                                                                      |
|:---------------------|:-----------:|:--------:|:-----------------------------------------------------------------------------------------------------------------|
| name                         | required    |          | Unique name to identify the configuration, used as git_configuration_name in triggers variable. |
| source_action_name           | required    |          | Name of the pipeline source action where the trigger configuration is specified.                         |
| push_filters                 | optional    | null     | List of filters to filter a git push.                                                                    |
| &ensp; branch_filter_name    | optional    | null     | Name of filter from git_configuration_filters to filter a push by git branches.                          |
| &ensp; file_path_filter_name | optional    | null     | Name of filter from git_configuration_filters to filter a push by file paths.                            |
| &ensp; tag_filter_name       | optional    | null     | Name of filter from git_configuration_filters to filter a push by git tags.                              |
| pull_request_filters         | optional    | null     | List of filters to filter a git pull request.                                                            |
| &ensp; events                | optional    | null     | List of pull request events to filter on (OPEN, UPDATED, CLOSED). Filters on all events by default.      |      
| &ensp; branch_filter_name    | optional    |          | Name of filter from git_configuration_filters to filter a pull request by git branches.                                  |
| &ensp; file_path_filter_name | optional    |          | Name of filter from git_configuration_filters to filter a pull request by file paths.                                  |
EOT
}

#####################################################################
## PIPELINE TRIGGER GIT CONFIGURATION FILTERS
#####################################################################
variable "git_configuration_filters" {
  type = list(object({
    name = string
    includes = optional(list(string), null)
    excludes = optional(list(string), null)
  }))
  default = [ ]
  description = <<-EOT
A map that defines lists of patterns for branches, tags, or file paths that are to be included or excluded as criteria to start a pipeline.

[Examples for trigger filters](https://docs.aws.amazon.com/codepipeline/latest/userguide/pipelines-filter.html#pipelines-filter-examples)
| Attribute Name      | Required? | Default  | Description                                                                                                                                 |
|:--------------------|:---------:|:--------:|:--------------------------------------------------------------------------------------------------------------------------------------------|
| name                | required  |          | Unique name to identify the filter, used as pull_request_filter_names or push_filter_names in trigger_git_configurations variable. |                                                                                                |
| &ensp; includes     | optional  | null     | List of patterns that are included as criteria to trigger a pipeline.                                                                       |    
| &ensp; excludes     | optional  | null     | List of patterns that are excluded as criteria to trigger a pipeline.                                                                       |
EOT
}

#####################################################################
## PIPELINE VARIABLES
#####################################################################
variable "variables" {
  type = list(object({
    key = optional(string, null)
    name = string
    default_value = optional(string, null)
    description = optional(string, null)
  }))
  default = [ ]
  description = <<-EOT
A map that defines pipeline-level variables for a pipeline resource. Use `key` to assign variables to a pipline when the duplicate names are used with differing values`.
| Attribute Name | Required? | Default  | Description                                                                                                                                                                                          |
|:---------------|:---------:|:--------:|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| key            | optional  | null     | Unique name to identify a pipline variable, used as `variable_names` in `piplines` variable. If not specified, `name` will be used.                                                                  |
| name           | required  |          | Name of a pipeline-level variable. Must be unique in the pipeline, max length 128. Also used as `variable_names` in `pipelines` variable when `key` is not provided. Regex Pattern: [A-Za-z0-9@\-_]+ |
| default_value  | optional  | null     | The default value of a pipeline-level variable, max length 1000.                                                                                                                                     |
| description    | optional  | null     | The description of a pipeline-level variable, max length 200.                                                                                                                                        | 
EOT
}

######################################################
# TAGS
######################################################
variable "tags" {
  type = map(string)
  nullable = false
  default = {}
  description = "Map of tags to assign to all resources in module"
}

# --------------------------------------------------------------------
################ PIPELINE STAGE ACTION CONFIGURATIONS ################
# --------------------------------------------------------------------
######################################################################
# PIPELINE STAGE ACTION SOURCE CODESTARSOURCECONNECTION CONFIGURATIONS
######################################################################
variable "codestarsourceconnection_action_configurations" {
  type = map(object({
    codestar_connection_name = string
    full_repository_id = string
    branch_name = string
    output_artifact_format = optional(string, "CODE_ZIP")
    detect_changes = optional(bool, false)
  }))
  default = { }
  description = <<-EOT
Map of configurations for CodeStarSourceConnection actions. The map's key is used as `configuration_key` in `stage_actions` variable and must be unique to identify each configuration. 

[CodeStarSourceConnection action reference](https://docs.aws.amazon.com/codepipeline/latest/userguide/action-reference-CodestarConnectionSource.html)
| Attribute Name           | Required? | Default  | Description                                                                                                 |
|:-------------------------|:---------:|:--------:|:------------------------------------------------------------------------------------------------------------|
| codestar_connection_name | required  |          | Codestar connection name from `codestar_connections` variable.                                                |
| full_repository_id       | required  |          | Oowner and name of the repository where source changes are to be detected. Example: some-user/my-repo       |
| branch_name              | required  |          | Name of the branch where source changes are to be detected.                                                 |
| output_artifact_format   | optional  | CODE_ZIP | Specifies the output artifact format (CODEBUILD_CLONE_REF or CODE_ZIP).                                     |
| detect_changes           | optional  | false    | Automatically start pipeline when a new commit is made on configured repository and branch (true, false).   |
EOT
}

#####################################################################
## PIPELINE STAGE ACTION BUILD/TEST CODEBUILD CONFIGURATIONS
#####################################################################
variable "codebuild_action_configurations" {
  type = map(object({
    project_name = string
    primary_source = optional(string, null)
    batch_enabled = optional(bool, false)
    combine_artifacts = optional(bool, false)
    environment_variables = optional(list(object({
      name = optional(string, null)
      value = optional(string, null)
      type = optional(string, "PLAINTEXT")
    })), null)
  }))
  default = { }
  description = <<-EOT
Map of configurations for CodeBuild actions. The map's key is used as `configuration_key` in `stage_actions` variable and must be unique to identify each configuration. 

[CodeBuild action reference](https://docs.aws.amazon.com/codepipeline/latest/userguide/action-reference-CodeBuild.html)
| Attribute Name        | Required?   | Default   | Description                                                                                                                    |
|:----------------------|:-----------:|:---------:|:-------------------------------------------------------------------------------------------------------------------------------|
| project_name          | required    |           | The name of the build project in CodeBuild.                                                                                    |
| primary_source        | conditional | null      | Name of the input artifact that CodeBuild will look for the build spec file. Required if there are multiple input artifacts.   | 
| batch_enabled         | optional    | false     | Allows the action to run multiple builds in the same build execution.                                                          |
| combine_artifacts     | optional    | false     | Combines build artifacts from a batch build into single artifact file. The batch_enabled parameter must be enabled.            |
| environment_variables | optional    | null      | List of environment variables for the CodeBuild action in your pipeline.                                                       | 
| &ensp; name           | required    |           | Name or key of the environment variable.                                                                                       |    
| &ensp; value          | required    |           | Value of environment variable. For PARAMETER_STORE or SECRETS_MANAGER types, must be the name of the store parameter.          |
| &ensp; type           | optional    | PLAINTEXT | Type of environment variable (PARAMETER_STORE, SECRETS_MANAGER, PLAINTEXT). Defaults to PLAINTEXT.                             |
EOT
}

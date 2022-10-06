# `Infrastructure`

Contains Terraform code to create infrastructure necessary for __icx-proxy__ components.

All Terraform components are divided into two folders: modules and workflows.

### `Modules Folder`

The __module/__ subdirectory contains nested modules, which are divided into several smaller 
modules that are easy to use.
For convenience, in each module, Terraform code is divided into several files. The main ones are:

* ___data_lookups.ft__ - contain the data sources uses for module.
* ___module.tf__ - contain the main set of configurations for module.
* ___variables.tf__ - contain the variable definitions for module.

In the __ecs__ module, the Terraform code is split into two more files:

* ___auto_scale.tf__ - contain a set of configurations auto scale for module.
* ___iam.tf__ - contain the IAM policies uses for module.

```
── modules
   ├── alb
   │   ├── _data_lookups.tf
   │   ├── _module.tf
   │   └── _variables.tf
   ├── cdn-alb
   │   └── ...
   ├── ecr
   │   └── ...
   ├── ecs
   │   ├── _auto_scale.tf
   │   ├── _data_lookups.tf
   │   ├── _iam.tf
   │   ├── _module.tf
   │   └── _variables.tf
   ├── kms
   │   ├── _data_lookups.tf
   │   ├── _module.tf
   │   └── _variables.tf
   ├── nlb
   │   └── ...
   ├── redis
   │   └── ...
   ├── sg
   │   └── ...
   └── ssm
       └── ...
```

### `Workflows Folder`

The __workflows/__ subdirectory contains two directories dev and qa for the respective environments and files:

* __global_locals.tf__ - contain the local values for all modules.
* __global_vars.tf__ - contain the variable definitions for all modules.
* __linker.sh__ - script to create symbolic links to global_vars.tf, global_locals.tf, and provider.tf files for root modules.
* __provider.tf__ - contain the provider configuration for all modules.

This arrangement of these files is done in order to avoid repeated repetition of the same values in modules.

The __DEV__ environment is identical to __QA__ in terms of the contents of the directory, 
the differences are only in *.tfvars files in the __input/__ directories of the modules.

For convenience, in each module, Terraform code is divided into several files:

* ___constants.tf__ - contain the local values for root modules.
* ___data_lookups.ft__ - contain the data sources uses for root modules.
* ___{name_of_module}.tf__ - contain the main configuration for root modules.
* ___variables.tf__ - contain the variable definitions for root modules.
* __versions.tf__ - contain configuration for storing Terraform state data files.

```
── workflows
   ├── dev
   │   ├── 00_kms
   │   │   ├── input
   │   │   │   └── dev_us-east-1.tfvars
   │   │   ├── _data_lookups.tf
   │   │   ├── _kms.tf
   │   │   └── versions.tf
   │   ├── 01_sg
   │   │   ├── input
   │   │   │   └── dev_us-east-1.tfvars
   │   │   ├── _constants.tf
   │   │   ├── _data_lookups.tf
   │   │   ├── _kms.tf
   │   │   ├── _variables.tf
   │   │   └── versions.tf
   │   ├── 02_alb
   │   │   ├── input
   │   │   │   └── dev_us-east-1.tfvars
   │   │   ├── _alb.tf
   │   │   ├── _data_lookups.tf
   │   │   ├── _variables.tf
   │   │   └── versions.tf
   │   ├── 03_ecr
   │   │   ├── input
   │   │   │   └── dev_us-east-1.tfvars
   │   │   ├── _data_lookups.tf
   │   │   ├── _ecr.tf
   │   │   ├── _variables.tf
   │   │   └── versions.tf
   │   ├── 04_ssm
   │   │   ├── input
   │   │   │   └── dev_us-east-1.tfvars
   │   │   ├── _constants.tf
   │   │   ├── _data_lookups.tf
   │   │   ├── _ssm.tf
   │   │   ├── _variables.tf
   │   │   └── versions.tf
   │   ├── 05_redis
   │   │   ├── input
   │   │   │   └── dev_us-east-1.tfvars
   │   │   ├── _data_lookups.tf
   │   │   ├── _redis.tf
   │   │   ├── _variables.tf
   │   │   └── versions.tf
   │   ├── 06_ecs
   │   │   ├── input
   │   │   │   └── dev_us-east-1.tfvars
   │   │   ├── _data_lookups.tf
   │   │   ├── _ecs.tf
   │   │   ├── _variables.tf
   │   │   └── versions.tf
   │   └── 07_cdn
   │   │   ├── input
   │   │   │   └── dev_us-east-1.tfvars
   │   │   ├── _cdn.tf
   │   │   ├── _data_lookups.tf
   │   │   ├── _variables.tf
   │   │   └── versions.tf
   ├── qa
   │   └── ...
   ├── global_locals.tf
   ├── global_vars.tf
   ├── linker.sh
   └── provider.tf
```

### `Storing State Files`

Terraform state files are stored remotely in s3 bucket. The configuration for storing Terraform state 
data files is located in each module in the versions.tf file.

```
terraform {
  required_version = ">= 0.13.1"

  required_providers {
    aws = ">= 3.50"
  }
  backend "s3" {
    bucket  = "terraform-state-storage-us-east-1"
    region  = "us-east-1"
    key     = "icx-proxy/qa/kms.tfstate"
    profile = "origyn-root"  
  }
}
```

Where:

* __bucket__ is the name of the S3 bucket to use.
* __region__ is the AWS region where the S3 bucket lives.
* __key__ is the file path within the S3 bucket where the Terraform state file should be written. 
Formed from the association of variables {APP_NAME}/{ENVIRONMENT}/{MODULE_NAME}.tfstate
* __profile__ is the AWS profile what needs to use.

With this backend enabled, Terraform will automatically pull the latest state 
from this S3 bucket before running a command, and automatically push the latest state to 
the S3 bucket after running a command.
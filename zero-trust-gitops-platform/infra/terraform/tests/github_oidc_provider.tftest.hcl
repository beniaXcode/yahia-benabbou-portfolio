# Native terraform test, run against a mocked AWS provider — no real AWS
# account or network access needed. Covers C6: every trust policy this
# module produces must pin an exact ref/environment and aud, never a
# wildcard subject.

mock_provider "aws" {}

variables {
  github_org          = "beniaXcode"
  github_repo         = "yahia-benabbou-portfolio"
  build_ref           = "refs/heads/main"
  deploy_environments = ["dev", "staging", "prod"]
}

run "build_role_trust_policy_is_exact" {
  command = apply

  module {
    source = "../modules/github-oidc-provider"
  }

  assert {
    condition     = strcontains(aws_iam_role.build.assume_role_policy, "repo:beniaXcode/yahia-benabbou-portfolio:ref:refs/heads/main")
    error_message = "build role's trust policy must pin the exact ref subject claim"
  }

  assert {
    condition     = strcontains(aws_iam_role.build.assume_role_policy, "sts.amazonaws.com")
    error_message = "build role's trust policy must require aud = sts.amazonaws.com"
  }

  assert {
    condition     = !strcontains(aws_iam_role.build.assume_role_policy, "beniaXcode/*") && !strcontains(aws_iam_role.build.assume_role_policy, "\"sub\":\"*\"")
    error_message = "build role's trust policy must never contain a wildcard subject"
  }
}

run "deploy_role_trust_policy_is_exact_per_environment" {
  command = apply

  module {
    source = "../modules/github-oidc-provider"
  }

  assert {
    condition     = strcontains(aws_iam_role.deploy["prod"].assume_role_policy, "repo:beniaXcode/yahia-benabbou-portfolio:environment:prod")
    error_message = "prod deploy role's trust policy must pin the exact environment subject claim"
  }

  assert {
    condition     = !strcontains(aws_iam_role.deploy["prod"].assume_role_policy, "environment:*")
    error_message = "prod deploy role's trust policy must never wildcard the environment"
  }

  assert {
    condition     = aws_iam_role.deploy["prod"].assume_role_policy != aws_iam_role.deploy["dev"].assume_role_policy
    error_message = "each environment must get its own distinct trust policy, never a shared one"
  }
}

run "no_role_exceeds_the_aws_session_ceiling" {
  command = apply

  module {
    source = "../modules/github-oidc-provider"
  }

  assert {
    condition     = aws_iam_role.build.max_session_duration <= 43200
    error_message = "max_session_duration must stay within AWS's allowed ceiling"
  }
}

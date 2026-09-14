# C2: no static AWS credentials anywhere in this Terraform. In-cluster AWS
# access is EKS Pod Identity; CI access is GitHub OIDC → STS. An
# aws_iam_access_key resource means a long-lived credential exists.
package main

deny contains msg if {
	some rc in input.resource_changes
	rc.type == "aws_iam_access_key"
	is_create_or_update(rc.change.actions)
	msg := sprintf("%s: aws_iam_access_key must never be created (C2 — use OIDC federation or Pod Identity instead of a static credential)", [rc.address])
}

# Every place this platform stores something at rest is encrypted with a
# customer-managed KMS key: Secrets Manager secrets, ECR images, S3 state.
package main

deny contains msg if {
	some rc in input.resource_changes
	rc.type == "aws_secretsmanager_secret"
	is_create_or_update(rc.change.actions)
	is_blank(object.get(rc.change.after, "kms_key_id", ""))
	not is_unknown_after(rc, "kms_key_id")
	msg := sprintf("%s: Secrets Manager secret has no kms_key_id — must be KMS-encrypted", [rc.address])
}

deny contains msg if {
	some rc in input.resource_changes
	rc.type == "aws_ecr_repository"
	is_create_or_update(rc.change.actions)
	not ecr_uses_kms(object.get(rc.change.after, "encryption_configuration", []))
	msg := sprintf("%s: ECR repository must set encryption_configuration to use KMS, not the AES256 default", [rc.address])
}

ecr_uses_kms(encs) if {
	some e in encs
	e.encryption_type == "KMS"
}

deny contains msg if {
	some rc in input.resource_changes
	rc.type == "aws_s3_bucket"
	is_create_or_update(rc.change.actions)
	not any_s3_sse_configured
	msg := sprintf("%s: an aws_s3_bucket is created with no aws_s3_bucket_server_side_encryption_configuration anywhere in this plan", [rc.address])
}

any_s3_sse_configured if {
	some rc in input.resource_changes
	rc.type == "aws_s3_bucket_server_side_encryption_configuration"
	is_create_or_update(rc.change.actions)
}

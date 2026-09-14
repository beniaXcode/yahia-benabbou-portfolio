# Every S3 bucket this platform creates must have all four public-access
# protections on — no exceptions, since this repo's only bucket is
# Terraform state.
package main

deny contains msg if {
	some rc in input.resource_changes
	rc.type == "aws_s3_bucket"
	is_create_or_update(rc.change.actions)
	not any_s3_public_access_block_configured
	msg := sprintf("%s: an aws_s3_bucket is created with no fully-blocking aws_s3_bucket_public_access_block anywhere in this plan", [rc.address])
}

any_s3_public_access_block_configured if {
	some rc in input.resource_changes
	rc.type == "aws_s3_bucket_public_access_block"
	is_create_or_update(rc.change.actions)
	after := rc.change.after
	after.block_public_acls == true
	after.block_public_policy == true
	after.ignore_public_acls == true
	after.restrict_public_buckets == true
}

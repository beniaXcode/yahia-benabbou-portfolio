# Least privilege: no IAM policy statement (inline role/user policy,
# standalone policy, or a resource-based policy such as an ECR/Secrets
# Manager policy) may Allow Action "*".
package main

deny contains msg if {
	some rc in input.resource_changes
	is_create_or_update(rc.change.actions)
	policy := object.get(rc.change.after, "policy", "")
	is_string(policy)
	policy != ""
	doc := json.unmarshal(policy)
	some stmt in as_array(doc.Statement)
	object.get(stmt, "Effect", "") == "Allow"
	action_is_wildcard(object.get(stmt, "Action", []))
	msg := sprintf("%s: an IAM policy statement allows Action \"*\" — name the exact actions this principal needs", [rc.address])
}

action_is_wildcard(a) if {
	a == "*"
}

action_is_wildcard(a) if {
	some x in a
	x == "*"
}

# Copy this file to config.ps1 and fill in your own lab values. config.ps1 is git-ignored.

# Your lab tenant's primary domain, for example contoso.onmicrosoft.com
$DEMO_TENANT_DOMAIN = "<TENANT_DOMAIN>"

# Your lab tenant ID (GUID). Used when stamping sensitivity labels into the sample files.
$DEMO_TENANT_ID = "<TENANT_ID>"

# The users the demo applies to. They need a Microsoft 365 Copilot licence.
# Object IDs: az ad user show --id user@domain --query id -o tsv
$DEMO_USER_OBJECT_IDS = @("<USER1_OBJECT_ID>", "<USER2_OBJECT_ID>")
$DEMO_USER_UPNS       = @("<USER1_UPN>", "<USER2_UPN>")

# Names used by the scripts. You can keep these.
$DEMO_LABEL_POLICY = "AI Demo - Sensitivity labels"
$DEMO_DLP_POLICY   = "AI Demo - Copilot DLP"

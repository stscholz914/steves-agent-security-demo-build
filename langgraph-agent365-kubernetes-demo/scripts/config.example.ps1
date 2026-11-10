# Copy this file to config.ps1 (same folder) and fill in your values. config.ps1 is git-ignored, so it is never published.
# The scripts read these values so you never have to type IDs on the command line.

# Azure / Microsoft Entra
$env:DEMO_TENANT_ID           = "<TENANT_ID>"             # Entra admin center > Overview > Tenant ID
$env:DEMO_BLUEPRINT_APP_ID    = "<BLUEPRINT_APP_ID>"      # Agent blueprint > Application (client) ID
$env:DEMO_BLUEPRINT_OBJECT_ID = "<BLUEPRINT_OBJECT_ID>"   # Agent blueprint > Object ID
$env:DEMO_AGENT_ID            = "<AGENT_IDENTITY_ID>"     # Agent identity > Object ID

# Azure OpenAI (printed by 10-create-azure-openai.ps1)
$env:DEMO_OPENAI_RESOURCE_GROUP = "rg-a365-langgraph"
$env:DEMO_OPENAI_ACCOUNT        = "<OPENAI_ACCOUNT_NAME>"
$env:DEMO_OPENAI_ENDPOINT       = "https://<OPENAI_ACCOUNT_NAME>.openai.azure.com/"
$env:DEMO_OPENAI_DEPLOYMENT     = "gpt-4.1-mini"

# AWS
$env:DEMO_AWS_REGION   = "us-east-2"     # use a region your AWS account is allowed to use
$env:DEMO_CLUSTER_NAME = "a365-demo"
$env:DEMO_NODE_TYPE    = "m7i-flex.large" # Free Tier accounts only accept Free Tier eligible types; any 2 vCPU / 4 GB+ type works otherwise

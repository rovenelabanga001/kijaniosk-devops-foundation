# Question 1: The Idempotency Gap

- Terraform achieves idempotency through its state file — a JSON document stored locally at terraform.tfstate or remotely in a backend like GCS or S3. The state file is Terraform's memory of the world.
  It records every resource Terraform has ever created: its type, its configuration values, and critically, the real infrastructure identifiers assigned by the provider
  — things like a GCP instance ID, a VPC ID, or a firewall rule name.dempotency

- When you run terraform apply, Terraform does three things in sequence. First it reads the desired state from your HCL configuration.
  Second it reads the current known state from the state file. Third it calls the provider API to read the actual state of each resource.
  It then computes a diff between desired and actual. If they match, it does nothing. If they differ, it creates, updates, or destroys resources to converge actual toward desired. No guard conditions are needed in the configuration because the guard is the state comparison itself
  — it happens at the engine level, not the resource level

- What specifically is stored: for each resource, the state file records the resource type, the logical name you gave it in HCL, every input attribute you declared, every computed attribute the provider returned (like an assigned IP address),
  and the provider-specific unique ID that allows Terraform to find the resource again on subsequent runs

- **The divergence scenario** — where the state file says do nothing but reality has drifted — is called state drift.
  It happens when infrastructure is changed outside Terraform: an engineer manually edits a firewall rule in the GCP console,
  a colleague deletes a VM directly, or an automated process modifies a security group.
  The state file still reflects the last known good state Terraform created. On the next `terraform plan`,
  Terraform compares desired state against the state file, sees no difference, and reports no changes needed.
  It never notices the manual edit because it didn't refresh actual infrastructure state

- The correct response is terraform refresh followed by `terraform plan`. `terraform refresh` queries the provider APIs for every resource in the state file and updates the state file to reflect reality.
  The subsequent `terraform plan` then shows the true diff between desired and actual. In modern Terraform, `terraform plan -refresh-only` is preferred —
  it shows you what drifted without making changes, so you can decide whether to let Terraform correct the drift or update the configuration to accept the change.

# Question 2: Declarative Specification Quality

- **Gap 1:** The SSH username is provider-specific and undocumented as a requirement.
  The spec records rovenelabanga2001 as the SSH username and notes it is derived from the Google account name.
  But it does not specify what the username should be on a reproduced server, or that a consistent predictable username is a requirement at all.
  If a different engineer reproduced this on AWS, the default username would be ubuntu. On DigitalOcean it would be root.
  On Azure it would be whatever they specified at creation.

  Terraform filling this gap with a provider default would produce a server where the SSH username is different from what every downstream script,
  Ansible inventory, and runbook expects. The server would be accessible but nothing that connects to it would work without manual adjustment.
  The spec should state: required SSH username: kijanikiosk — create this user during provisioning, do not rely on provider-derived defaults.

- **Gap 2:** The firewall source IP is a personal IP, not a specification.
  The spec records 41.90.187.119/32 as the SSH source. This is the engineer's home IP at the time of writing.
  It will be wrong tomorrow when they move to a different network, and completely wrong for any other engineer trying to reproduce the spec.
  A Terraform configuration built from this spec would encode a personal IP as infrastructure — it would apply successfully but produce a server that only one person can SSH into from one location.
  The spec should instead state: SSH source: variable, supplied at apply time — must be a /32 representing the operator's current IP.
  This turns a hardcoded accident into a deliberate parameterisation decision.

  What this tells you about specification quality and automation reliability: Automation is a precision instrument.
  It does exactly what the specification says, including the gaps. Where the spec is silent, the tool fills in a default —
  and defaults are chosen for general cases, not your specific situation. A low-quality spec produces automation that applies without errors and provisions the wrong thing.
  That failure mode is worse than an error, because it looks like success. The relationship is direct: specification quality is the ceiling on automation reliability.
  You cannot automate your way out of an underspecified intent.

# Question 3: Tool Boundary

### Task 1: Creating a firewall rule that allows port 80 from anywhere → Terraform

Firewall rules are infrastructure — they exist at the network layer, independent of any running VM, and they have a lifecycle (create, update, destroy) that needs to be tracked in state.
Terraform is the right tool because it can express the rule declaratively, track it in state, and ensure it is recreated if deleted outside Terraform.

### Task 2: Installing nginx 1.24.0 on a running VM → Ansible

Package installation is configuration, not infrastructure. It happens inside a running VM, it depends on the OS package manager, and it needs to be repeatable across many VMs of the same role.

### Task 3: Verifying nginx responds to HTTP requests after installation → bash (or Ansible, defensible)

This is a verification step, not a provisioning or configuration step. It has no persistent state to track and no desired end-state to converge toward — it either passes or fails.
A simple bash curl -f http://localhost:80 with an appropriate exit code is the right tool. It is readable, fast, and composable with other verification steps in a pipeline.

The defensible Ansible answer: Ansible's uri module can make HTTP requests and assert on the response, and running it as part of a post-configuration verification play keeps all server-related automation in one tool.

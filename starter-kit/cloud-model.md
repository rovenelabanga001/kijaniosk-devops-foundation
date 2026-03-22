To determine which cloud model the KijaniKiosk system uses, we have to look at how much of the "stack" the engineering team manages versus how much is handled by the cloud provider.

Based on our architecture—using a backend framework, an S3 storage location, and a javascript frontend framework—the system is a hybrid of PaaS and IaaS characteristics, typically referred to as a Modern Cloud Native Application.

# 1. The Backend (Render/AWS/Azure): PaaS
The web-facing service is primarily PaaS (Platform as a Service).

**Why**: You focus on writing the backend code. You don't manually install the Operating System, patch the kernel, or manage the physical hardware.

The "Platform": Tools like Render or AWS App Runner provide the runtime environment , the web server , and the deployment pipeline. You simply provide the code and a requirements depending on your tech stack.

# 2. The Storage (S3): PaaS / Managed Service
The backend storage for reconciliation files is a Managed Service, which falls under the PaaS umbrella.

**Why**: You don't manage a "Virtual Hard Drive" (IaaS). Instead, you interact with an API to "Put" and "Get" objects. AWS handles the disk redundancy, scaling, and underlying file system.

# 3. The Infrastructure (VPC & Networking): IaaS
The components that protect the internal services (Private Subnets, NAT Gateways, and IAM) are IaaS (Infrastructure as a Service) elements.

**Why**: As a DevOps engineer, you are architecting the "virtual" version of a physical data center. You define the network boundaries, route tables, and access controls. You are renting the raw networking capability and configuring it yourself.
# IBM Cloud VPC + Client-to-Site VPN + Qiskit Runtime — Terraform Plan

## Top-Level Overview

Create a complete, variable-driven Terraform automation that provisions:

1. **VPC** with 3 availability zones and 3 subnets (one per zone)
2. **Secrets Manager** — use an existing instance (looked up by name) or create a new `standard` plan instance in the same region
3. **EasyRSA PKI** — CA, VPN server cert, and client cert generated via a `null_resource` local-exec provisioner and imported into Secrets Manager using `ibm_sm_imported_certificate`
4. **IAM service-to-service authorization** — VPN for VPC → Secrets Manager (SecretsReader)
5. **Client-to-Site VPN server** (`ibm_is_vpn_server`) using certificate authentication, `client_idle_timeout = 600`
6. **Qiskit Runtime service instance** — `quantum-computing` service, `paygo-standard` plan, `instance_limit_seconds = 600` (≈$1,000 USD)
   > Note: 600 seconds of QPU time ≈ $1,000 USD at current pricing; this is set via `parameters` on `ibm_resource_instance`.
7. **Two VPEs** in the VPC:
   - Qiskit / IBM Quantum Platform (`quantum-computing` CRN for the target region)
   - IAM (`iam` provider infrastructure service)

All names, CIDR ranges, and region are driven by input variables.

---

## File Layout

```
terraform/
├── main.tf              # root orchestration, provider
├── variables.tf         # all input variables
├── outputs.tf           # key outputs (VPN client profile path, cert CRNs, etc.)
├── vpc.tf               # VPC and subnets
├── secrets_manager.tf   # conditional SM lookup / create + IAM auth
├── pki.tf               # null_resource easyrsa local-exec + ibm_sm_imported_certificate
├── vpn.tf               # ibm_is_vpn_server + VPN routes
├── qiskit.tf            # ibm_resource_instance quantum-computing
└── vpe.tf               # ibm_is_virtual_endpoint_gateway × 2
```

---

## Variables (variables.tf)

| Variable | Type | Default | Purpose |
|---|---|---|---|
| `ibmcloud_api_key` | string | — | IBM Cloud API key (sensitive) |
| `region` | string | `"us-east"` | Deployment region |
| `resource_group_name` | string | `"default"` | Resource group |
| `prefix` | string | `"qsk"` | Name prefix for all resources |
| `vpc_cidr` | string | `"10.0.0.0/16"` | VPC address prefix (informational) |
| `zone1_cidr` | string | `"10.0.1.0/24"` | Zone 1 subnet CIDR |
| `zone2_cidr` | string | `"10.0.2.0/24"` | Zone 2 subnet CIDR |
| `zone3_cidr` | string | `"10.0.3.0/24"` | Zone 3 subnet CIDR |
| `vpn_client_ip_pool` | string | `"172.16.0.0/22"` | Client IP pool for VPN |
| `vpn_port` | number | `443` | VPN server port |
| `vpn_protocol` | string | `"udp"` | VPN protocol |
| `existing_secrets_manager_name` | string | `""` | If set, look up SM by name; otherwise create one |
| `secrets_manager_plan` | string | `"standard"` | SM plan when creating new instance |
| `qiskit_instance_name` | string | `"qiskit-paygo"` | Name of the Qiskit Runtime instance |
| `qiskit_limit_seconds` | number | `600` | QPU cost limit in seconds |

---

## Sub-Tasks

---

### Sub-Task 1 — Provider, Backend, and Variables

**Status:** `[ ] pending`

**Intent:** Establish the foundational Terraform files — provider configuration (IBM Cloud, `null`), backend stub, and the full variable definitions.

**Expected Outcomes:**
- `main.tf` with `required_providers` block (IBM-Cloud/ibm ≥ 1.67, hashicorp/null)
- `variables.tf` with all variables from the table above, with descriptions and defaults
- `outputs.tf` skeleton (empty outputs to be filled later)
- Provider block parameterised by `var.ibmcloud_api_key` and `var.region`

**Todo List:**
1. Write `main.tf` with `terraform {}` block and `provider "ibm"` block.
2. Write `variables.tf` with all variables.
3. Write `outputs.tf` as an empty skeleton.

**Relevant Context:**
- IBM Cloud provider: `IBM-Cloud/ibm`; region must match target VPC region.
- `null` provider needed for the EasyRSA local-exec provisioner.

---

### Sub-Task 2 — VPC, Address Prefixes, and Subnets

**Status:** `[ ] pending`

**Intent:** Create the VPC with three address prefixes and three subnets (one per availability zone in the chosen region).

**Expected Outcomes:**
- `ibm_is_vpc` resource named `${var.prefix}-vpc`
- Three `ibm_is_vpc_address_prefix` resources for zone 1/2/3 using the zone CIDR variables
- Three `ibm_is_subnet` resources: `${var.prefix}-subnet-1`, `-2`, `-3`

**Todo List:**
1. Create `vpc.tf` with `ibm_is_vpc`.
2. Add three `ibm_is_vpc_address_prefix` blocks using `"${var.region}-1"`, `"${var.region}-2"`, `"${var.region}-3"`.
3. Add three `ibm_is_subnet` resources, each referencing the corresponding address prefix and zone.

**Relevant Context:**
- Subnets in zone `${var.region}-1/2/3` must be created **after** `ibm_is_vpc_address_prefix` to avoid CIDR conflicts.
- VPE reserved IPs in Sub-Task 7 will bind to `subnet-1`.

---

### Sub-Task 3 — Secrets Manager (Conditional Create or Lookup)

**Status:** `[ ] pending`

**Intent:** Use an existing Secrets Manager instance if `var.existing_secrets_manager_name` is non-empty; otherwise create a new `standard` plan instance. Expose the instance ID uniformly regardless of path.

**Expected Outcomes:**
- `data "ibm_resource_instance"` block (conditionally active via `count = var.existing_secrets_manager_name != "" ? 1 : 0`) to look up an existing SM instance by name and service `secrets-manager`.
- `resource "ibm_resource_instance" "sm"` (conditionally active via `count = var.existing_secrets_manager_name == "" ? 1 : 0`) to create a new SM instance with `plan = var.secrets_manager_plan` (`"standard"`), `location = var.region`.
- A `locals` block that resolves `local.sm_instance_id` to either the looked-up or created instance ID/GUID.

**Todo List:**
1. Write `secrets_manager.tf` with the conditional `data` source and `resource` for SM.
2. Add `locals { sm_instance_id = ... }` using `one()` or ternary to pick the active ID.
3. Add `ibm_iam_authorization_policy` resource:
   - Subject: `serviceName = "is"`, `resourceType = "vpn-server"`
   - Target: `serviceName = "secrets-manager"`, `resource = ibm_sm_secret_group.pki_group.secret_group_id`
   - Role: `SecretsReader`
4. Add `ibm_sm_secret_group` resource named `${var.prefix}-vpn-certs`.

**Relevant Context:**
- `data "ibm_resource_instance"` requires `name`, `service = "secrets-manager"`, `location = var.region`.
- IAM auth documented at: https://cloud.ibm.com/docs/vpc?topic=vpc-client-to-site-authentication
- The `ibm_iam_auth_token` and `ibm_iam_account_settings` data sources are needed to populate `accountId` in the authorization policy subject/resource attributes (see `l2fprod` reference implementation).

---

### Sub-Task 4 — EasyRSA PKI via Local-Exec + Import Certificates

**Status:** `[ ] pending`

**Intent:** Use a `null_resource` with a `local-exec` provisioner to run the EasyRSA 3 commands on the Terraform operator's machine, generate CA + server cert + client cert, then import them into Secrets Manager using `ibm_sm_imported_certificate`.

**Expected Outcomes:**
- `null_resource "easyrsa_pki"` that:
  1. Clones `https://github.com/OpenVPN/easy-rsa.git` into a temp dir (idempotent — skip if dir exists)
  2. Runs `./easyrsa init-pki`, `build-ca nopass`, `build-server-full vpn-server.vpn.ibm.com nopass`, `build-client-full client1.vpn.ibm.com nopass`
  3. Copies cert/key files to a local `./pki-output/` directory referenced by subsequent resources
- `ibm_sm_imported_certificate "server_cert"` using `local_file` data sources for cert, key, and CA as intermediate
- `ibm_sm_imported_certificate "client_cert"` using cert and CA as intermediate (no private key for client in SM — only CA needed for VPN server to verify clients)
- `local_file` resources to persist generated certs to `./pki-output/` for operator use

**Todo List:**
1. Create `pki.tf` with the `null_resource` local-exec shell script.
2. Use `triggers = { always_run = timestamp() }` only if regeneration is desired; otherwise use a file hash trigger so it only re-runs if output files are missing.
3. Add `data "local_file"` resources to read the generated PEM files after the null_resource runs (`depends_on`).
4. Add `ibm_sm_imported_certificate "server_cert"` in the SM instance, using `local.sm_instance_id` and the secret group from Sub-Task 3.
5. Add `ibm_sm_imported_certificate "client_cert"` (cert + intermediate only, no private key).
6. Add `local_file` resources to write cert/key files to `./pki-output/`.

**Relevant Context:**
- IBM docs easyrsa workflow: https://cloud.ibm.com/docs/vpc?topic=vpc-client-to-site-authentication
- Server cert import requires: `certificate`, `private_key`, `intermediate` (CA cert)
- Client cert import requires: `certificate`, `intermediate` (CA cert)
- EasyRSA output paths: `./easyrsa3/pki/ca.crt`, `./pki/issued/*.crt`, `./pki/private/*.key`
- The `null_resource` must have `depends_on = [local.sm_instance_id]` (via the SM resource/data).

---

### Sub-Task 5 — Client-to-Site VPN Server

**Status:** `[ ] pending`

**Intent:** Deploy the `ibm_is_vpn_server` resource using certificate-based authentication with the imported server and client CA certificates from Secrets Manager.

**Expected Outcomes:**
- `ibm_is_vpn_server "main"` resource with:
  - `certificate_crn` = CRN of the server cert secret
  - `client_authentication { method = "certificate", client_ca_crn = <server_cert_crn> }` (same CA signs both)
  - `client_ip_pool = var.vpn_client_ip_pool`
  - `client_idle_timeout = 600`
  - `enable_split_tunneling = true` (so only traffic to the VPC CIDR goes through VPN)
  - `subnets` = first subnet of each zone (or all three for HA)
  - `port = var.vpn_port`, `protocol = var.vpn_protocol`
- VPN routes added via `ibm_is_vpn_server_route` to reach private VPC CIDRs

**Todo List:**
1. Create `vpn.tf` with `ibm_is_vpn_server`.
2. Set `certificate_crn = ibm_sm_imported_certificate.server_cert.crn`.
3. Set `client_ca_crn = ibm_sm_imported_certificate.server_cert.crn` (same CA signs server and client).
4. Add `ibm_is_vpn_server_route` resources for each zone CIDR.
5. Export the VPN server ID and hostname in `outputs.tf`.

**Relevant Context:**
- `ibm_is_vpn_server` resource: https://registry.terraform.io/providers/IBM-cloud/ibm/latest/docs/resources/is_vpn_server
- `client_idle_timeout` default is 600; setting explicitly per user requirement.
- The VPN server must be in the same VPC as the subnets.

---

### Sub-Task 6 — Qiskit Runtime Service Instance

**Status:** `[ ] pending`

**Intent:** Create a new IBM Quantum Platform (Qiskit Runtime) service instance on the Pay-As-You-Go plan (`paygo-standard`) in the target region with a cost limit of 600 seconds (≈ $1,000 USD).

**Expected Outcomes:**
- `ibm_resource_instance "qiskit"` with:
  - `service = "quantum-computing"`
  - `plan = "paygo-standard"`
  - `location = var.region`
  - `parameters = { instance_limit_seconds = tostring(var.qiskit_limit_seconds) }`
- Output: instance CRN

**Todo List:**
1. Create `qiskit.tf` with `ibm_resource_instance "qiskit"`.
2. Set `name = var.qiskit_instance_name`.
3. Set `parameters = { instance_limit_seconds = tostring(var.qiskit_limit_seconds) }` where `var.qiskit_limit_seconds = 600`.
4. Add the instance CRN to `outputs.tf`.

**Relevant Context:**
- IBM Quantum cost limit docs: https://quantum.cloud.ibm.com/docs/en/guides/manage-cost
- `instance_limit_seconds` is set via the `parameters` map on `ibm_resource_instance`.
- Service name is `quantum-computing`; plan is `paygo`.
- Region must match a supported Quantum region (`us-east` or `eu-de`).

---

### Sub-Task 7 — Virtual Private Endpoints (Qiskit + IAM)

**Status:** `[ ] pending`

**Intent:** Create two VPE gateways inside the VPC so that workloads can reach IBM Quantum Platform API and IAM over the private network backbone.

**Expected Outcomes:**
- `ibm_is_virtual_endpoint_gateway "qiskit_vpe"` targeting the Quantum Platform CRN for the region
  - `crn:v1:bluemix:public:quantum-computing:us-east:::endpoint:private.us-east.quantum.cloud.ibm.com` (for `us-east`)
  - `resource_type = "provider_cloud_service"`
  - Reserved IPs bound to all three subnets
- `ibm_is_virtual_endpoint_gateway "iam_vpe"` targeting IAM
  - `crn = "crn:v1:bluemix:public:iam-svcs:global:::endpoint:private.iam.cloud.ibm.com"` + `resource_type = "provider_cloud_service"`
  - Reserved IPs bound to all three subnets
- `ibm_is_virtual_endpoint_gateway_ip` binding for each subnet/VPE combination

**Todo List:**
1. Create `vpe.tf` with both VPE gateway resources.
2. Use `target { crn = local.qiskit_endpoint_crn, resource_type = "provider_cloud_service" }` for Qiskit, where `local.qiskit_endpoint_crn` is derived from `var.region`.
3. Use `target { name = "iam", resource_type = "provider_infrastructure_service" }` for IAM.
4. Add `ips` blocks referencing all three subnets for HA.
5. Add explicit `depends_on = [ibm_resource_instance.qiskit]` on the Qiskit VPE so it is only created after the service instance is active.
6. Add VPE outputs (IDs) to `outputs.tf`.

**Relevant Context:**
- Qiskit VPE CRNs:
  - `us-east`: `crn:v1:bluemix:public:quantum-computing:us-east:::endpoint:private.us-east.quantum.cloud.ibm.com`
  - `eu-de`: `crn:v1:bluemix:public:quantum-computing:eu-de:::endpoint:private.eu-de.quantum.cloud.ibm.com`
- `ibm_is_virtual_endpoint_gateway` resource docs: https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_virtual_endpoint_gateway
- VPE source docs: https://qiskit.qotlabs.org/docs/security/virtual-private-endpoints

---

### Sub-Task 8 — Outputs

**Status:** `[ ] pending`

**Intent:** Expose all operational values an operator needs after `terraform apply`.

**Expected Outcomes:**
Populated `outputs.tf` with:
- `vpc_id`
- `subnet_ids` (list of 3)
- `secrets_manager_id`
- `server_cert_crn`
- `client_cert_crn`
- `vpn_server_id`, `vpn_server_hostname`
- `qiskit_instance_crn`
- `qiskit_vpe_id`, `iam_vpe_id`
- `pki_output_path` — path to local `./pki-output/` directory

**Todo List:**
1. Fill `outputs.tf` with all outputs listed above.
2. Mark cert-related outputs as `sensitive = true` where appropriate.

---

## Architecture Diagram

```
IBM Cloud Region (var.region)
┌────────────────────────────────────────────────────────┐
│  VPC (var.prefix-vpc)                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐             │
│  │ Zone 1   │  │ Zone 2   │  │ Zone 3   │             │
│  │ Subnet-1 │  │ Subnet-2 │  │ Subnet-3 │             │
│  └────┬─────┘  └──────────┘  └──────────┘             │
│       │                                                 │
│  VPN Server (cert auth, idle=600s, split-tunnel)        │
│  VPE: IBM Quantum (private.us-east.quantum.cloud.ibm.com│
│  VPE: IAM (iam)                                         │
└───────────────────────────┬────────────────────────────┘
                            │ Private Backbone
              ┌─────────────┴────────────┐
              │ IBM Quantum Runtime       │
              │ IAM                       │
              └───────────────────────────┘

Secrets Manager (existing or new "standard" plan)
  └─ Secret Group: vpn-certs
       ├─ server cert (ibm_sm_imported_certificate)
       └─ client cert (ibm_sm_imported_certificate)

IAM S2S Auth: VPN for VPC → SM secret-group (SecretsReader)

Local (Terraform operator machine)
  └─ null_resource: easyrsa init-pki → build-ca → build-server → build-client
       └─ pki-output/: ca.crt, server.crt, server.key, client.crt, client.key
```

---

## Key Dependencies

```
variables.tf
   └─> vpc.tf (subnets)
          └─> secrets_manager.tf (IAM auth needs SM)
                 └─> pki.tf (easyrsa + SM import, needs SM ID + secret group)
                        └─> vpn.tf (needs cert CRNs)
   └─> qiskit.tf (independent)
   └─> vpe.tf (needs subnet IDs from vpc.tf)
```
